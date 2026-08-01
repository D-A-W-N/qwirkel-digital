import 'package:flutter/foundation.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

/// UI-Zustand rund um eine [QwirkleGame]-Partie: hält den noch nicht
/// bestätigten Zug (pending placements) und die Tausch-Auswahl, bevor sie
/// an die Spiel-Engine übergeben werden.
class GameController extends ChangeNotifier {
  final QwirkleGame game;

  /// Noch nicht bestätigte Platzierungen des aktuellen Zugs.
  final Map<Position, Tile> pendingPlacements = {};

  /// Welcher Hand-Index (des aktuellen Spielers) für welche Position benutzt wurde.
  final Map<Position, int> _handIndexByPosition = {};

  /// Für den Tausch ausgewählte Hand-Indizes.
  final Set<int> selectedForExchange = {};

  String? lastError;
  int? lastMoveScore;

  GameController(this.game);

  bool get isOver => game.isOver;

  /// Die Hand des aktuellen Spielers, mit bereits platzierten (pending)
  /// Steinen als `null`-Lücke, damit sie nicht doppelt angezeigt werden.
  List<Tile?> get handSlots {
    final hand = game.currentPlayer.hand;
    final slots = List<Tile?>.from(hand);
    for (final index in _handIndexByPosition.values) {
      if (index < slots.length) slots[index] = null;
    }
    return slots;
  }

  bool get hasPendingPlacements => pendingPlacements.isNotEmpty;

  bool get hasExchangeSelection => selectedForExchange.isNotEmpty;

  /// Platziert den Hand-Stein bei [handIndex] (vorläufig) auf [position].
  void stageTile(int handIndex, Position position) {
    final hand = game.currentPlayer.hand;
    if (handIndex < 0 || handIndex >= hand.length) return;
    if (game.board.tileAt(position) != null) return;
    if (pendingPlacements.containsKey(position)) return;
    if (_handIndexByPosition.containsValue(handIndex)) return;

    pendingPlacements[position] = hand[handIndex];
    _handIndexByPosition[position] = handIndex;
    lastError = null;
    notifyListeners();
  }

  /// Nimmt eine vorläufige Platzierung wieder zurück auf die Hand.
  void unstageTile(Position position) {
    pendingPlacements.remove(position);
    _handIndexByPosition.remove(position);
    notifyListeners();
  }

  void resetPendingPlacements() {
    pendingPlacements.clear();
    _handIndexByPosition.clear();
    lastError = null;
    notifyListeners();
  }

  /// Bestätigt den vorläufigen Zug und übergibt ihn an die Engine.
  void confirmMove() {
    if (pendingPlacements.isEmpty) return;
    final placements = [
      for (final entry in pendingPlacements.entries)
        TilePlacement(position: entry.key, tile: entry.value),
    ];
    try {
      lastMoveScore = game.playTiles(placements);
      lastError = null;
      pendingPlacements.clear();
      _handIndexByPosition.clear();
    } on InvalidMoveException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  void toggleExchangeSelection(int handIndex) {
    if (selectedForExchange.contains(handIndex)) {
      selectedForExchange.remove(handIndex);
    } else {
      selectedForExchange.add(handIndex);
    }
    notifyListeners();
  }

  void clearExchangeSelection() {
    selectedForExchange.clear();
    notifyListeners();
  }

  void confirmExchange() {
    if (selectedForExchange.isEmpty) return;
    final hand = game.currentPlayer.hand;
    final tiles = [for (final i in selectedForExchange) hand[i]];
    try {
      game.exchangeTiles(tiles);
      lastError = null;
    } on Object catch (e) {
      lastError = e.toString();
    }
    selectedForExchange.clear();
    notifyListeners();
  }

  void passTurn() {
    game.passTurn();
    pendingPlacements.clear();
    _handIndexByPosition.clear();
    selectedForExchange.clear();
    lastError = null;
    notifyListeners();
  }

  bool get isCurrentPlayerBot => game.currentPlayer.isBot;

  /// Lässt die KI des aktuellen (Bot-)Spielers ihren Zug ausführen.
  void playBotTurn() {
    final player = game.currentPlayer;
    final difficulty = player.botDifficulty;
    if (difficulty == null) return;

    final decision = Bot(difficulty: difficulty).decide(game);
    try {
      lastMoveScore = decision.applyTo(game);
      lastError = null;
    } on InvalidMoveException catch (e) {
      // Sollte bei einem vom Bot generierten Zug nicht vorkommen, aber zur
      // Sicherheit wird ausgesetzt, damit die Partie nicht hängen bleibt.
      lastError = e.message;
      game.passTurn();
    }
    pendingPlacements.clear();
    _handIndexByPosition.clear();
    selectedForExchange.clear();
    notifyListeners();
  }
}
