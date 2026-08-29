import 'package:flutter/foundation.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import '../common/human_readable_error.dart';

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

  /// Punktwert der aktuell vorbereiteten (noch nicht bestätigten) Steine,
  /// live neu berechnet bei jeder Änderung von [pendingPlacements].
  int? pendingScore;

  /// Felder, die der Bot in seinem letzten Zug belegt hat (für eine kurze
  /// visuelle Hervorhebung). Wird geleert, sobald die Gegenseite reagiert.
  Set<Position> lastBotPlacements = {};

  /// Kurze textuelle Zusammenfassung des letzten Bot-Zugs (Platzierung,
  /// Tausch oder Aussetzen), z. B. für die Statuszeile.
  String? lastBotSummary;

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

    final candidatePlacements = [
      for (final entry in pendingPlacements.entries)
        TilePlacement(position: entry.key, tile: entry.value),
      TilePlacement(position: position, tile: hand[handIndex]),
    ];

    try {
      final score = game.board.scorePlacement(candidatePlacements);
      pendingPlacements[position] = hand[handIndex];
      _handIndexByPosition[position] = handIndex;
      pendingScore = score;
      lastError = null;
      lastBotPlacements = {};
      lastBotSummary = null;
    } on InvalidMoveException catch (e) {
      // notifyListeners() darf hier NICHT übersprungen werden: ohne ihn
      // bleibt `lastError` zwar gesetzt, aber die UI (ref.watch) bekommt nie
      // mit, dass sich der Zustand geändert hat, und zeigt weder eine
      // Fehlermeldung noch sonst eine Reaktion - der Zug scheint einfach
      // stillschweigend zu scheitern (Nutzer-Feedback: "konnte keinen
      // anderen Stein platzieren, scheint mir ein Bug").
      lastError = _humanReadableMessage(e.reason, e.message);
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  /// Nimmt eine vorläufige Platzierung wieder zurück auf die Hand.
  void unstageTile(Position position) {
    pendingPlacements.remove(position);
    _handIndexByPosition.remove(position);
    lastError = null;
    pendingScore = _recomputePendingScore();
    notifyListeners();
  }

  void resetPendingPlacements() {
    pendingPlacements.clear();
    _handIndexByPosition.clear();
    pendingScore = null;
    lastError = null;
    notifyListeners();
  }

  /// Berechnet den Punktwert der verbliebenen [pendingPlacements] neu (z. B.
  /// nach einem [unstageTile]) - liefert `null`, falls die verbleibenden
  /// Steine für sich genommen (noch) keinen gültigen Zug ergeben.
  int? _recomputePendingScore() {
    if (pendingPlacements.isEmpty) return null;
    final placements = [
      for (final entry in pendingPlacements.entries)
        TilePlacement(position: entry.key, tile: entry.value),
    ];
    try {
      return game.board.scorePlacement(placements);
    } on InvalidMoveException {
      return null;
    }
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
      pendingScore = null;
    } on InvalidMoveException catch (e) {
      lastError = _humanReadableMessage(e.reason, e.message);
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
      lastBotPlacements = {};
      lastBotSummary = null;
    } on Object catch (e) {
      lastError = humanReadableError(e);
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
    lastBotPlacements = {};
    lastBotSummary = null;
    notifyListeners();
  }

  bool get isCurrentPlayerBot => game.currentPlayer.isBot;

  String _humanReadableMessage(
    InvalidMoveReason reason,
    String fallback,
  ) {
    switch (reason) {
      case InvalidMoveReason.emptyPlacement:
        return 'Bitte platziere mindestens einen Stein.';
      case InvalidMoveReason.tooManyTiles:
        return 'Ein Zug kann maximal 6 Steine enthalten.';
      case InvalidMoveReason.duplicatePosition:
        return 'Ein Feld kann im selben Zug nur einmal belegt werden.';
      case InvalidMoveReason.positionOccupied:
        return 'Dieses Feld ist bereits belegt.';
      case InvalidMoveReason.gapInLine:
        return 'Die Steine müssen lückenlos aneinander anschließen.';
      case InvalidMoveReason.notConnected:
        return 'Mindestens ein neuer Stein muss an einen bestehenden Stein angrenzen.';
      case InvalidMoveReason.attributeMismatch:
        return 'Eine Reihe braucht entweder gleiche Farben oder gleiche Formen.';
      case InvalidMoveReason.duplicateTileInLine:
        return 'In einer Reihe darf derselbe Stein nicht mehrfach vorkommen.';
      case InvalidMoveReason.lineTooLong:
        return 'Eine Reihe darf höchstens 6 Steine haben.';
    }
  }

  /// Lässt die KI des aktuellen (Bot-)Spielers ihren Zug ausführen.
  void playBotTurn() {
    final player = game.currentPlayer;
    final difficulty = player.botDifficulty;
    if (difficulty == null) return;

    final decision = Bot(difficulty: difficulty).decide(game);
    try {
      lastMoveScore = decision.applyTo(game);
      lastError = null;
      if (decision.isPlay) {
        final placements = decision.placements!;
        lastBotPlacements = placements.map((p) => p.position).toSet();
        final count = placements.length;
        lastBotSummary =
            '${player.name} legte $count Stein${count == 1 ? '' : 'e'} '
            '(+${lastMoveScore ?? 0} Punkte).';
      } else if (decision.isExchange) {
        final count = decision.exchangeTiles!.length;
        lastBotPlacements = {};
        lastBotSummary =
            '${player.name} tauschte $count Stein${count == 1 ? '' : 'e'}.';
      } else {
        lastBotPlacements = {};
        lastBotSummary = '${player.name} setzte aus.';
      }
    } on InvalidMoveException catch (e) {
      // Sollte bei einem vom Bot generierten Zug nicht vorkommen, aber zur
      // Sicherheit wird ausgesetzt, damit die Partie nicht hängen bleibt.
      lastError = _humanReadableMessage(e.reason, e.message);
      lastBotPlacements = {};
      lastBotSummary = null;
      game.passTurn();
    }
    pendingPlacements.clear();
    _handIndexByPosition.clear();
    selectedForExchange.clear();
    notifyListeners();
  }
}
