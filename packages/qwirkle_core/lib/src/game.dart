import 'board.dart';
import 'move.dart';
import 'player.dart';
import 'starting_player.dart';
import 'tile.dart';
import 'tile_bag.dart';

/// Steuert eine vollständige Qwirkle-Partie: Brett, Beutel, Spielerreihenfolge
/// und Zugausführung (Platzieren oder Steine tauschen).
class QwirkleGame {
  final Board board = Board();
  final TileBag bag;
  final List<Player> players;
  late int currentPlayerIndex;
  bool isOver = false;

  QwirkleGame({
    required this.players,
    TileBag? bag,
    Comparator<Player>? startingPlayerTieBreaker,
  }) : bag = bag ?? TileBag.standard() {
    assert(players.isNotEmpty, 'Es wird mindestens ein Spieler benötigt.');
    for (final player in players) {
      player.hand = this.bag.draw(6);
    }
    currentPlayerIndex = determineStartingPlayerIndex(
      players,
      tieBreaker: startingPlayerTieBreaker,
    );
  }

  Player get currentPlayer => players[currentPlayerIndex];

  /// Platziert [placements] für den aktuellen Spieler, validiert den Zug,
  /// vergibt Punkte, zieht Nachschub und zieht den nächsten Spieler.
  /// Wirft [InvalidMoveException] bei einem regelwidrigen Zug.
  int playTiles(List<TilePlacement> placements) {
    if (isOver) throw StateError('Das Spiel ist bereits beendet.');
    final player = currentPlayer;
    _requireHandContains(player, placements.map((p) => p.tile).toList());

    var points = board.scorePlacement(placements);
    board.apply(placements);
    for (final placement in placements) {
      _removeOneFromHand(player, placement.tile);
    }
    player.hand.addAll(bag.draw(placements.length));

    if (player.hand.isEmpty && bag.isEmpty) {
      points += 6;
      isOver = true;
    }
    player.score += points;
    _advanceTurn();
    return points;
  }

  /// Tauscht [tiles] des aktuellen Spielers gegen neue Steine aus dem Beutel.
  void exchangeTiles(List<Tile> tiles) {
    if (isOver) throw StateError('Das Spiel ist bereits beendet.');
    if (tiles.isEmpty) {
      throw ArgumentError('Es muss mindestens ein Stein getauscht werden.');
    }
    if (tiles.length > bag.remaining) {
      throw StateError('Der Beutel enthält nicht genug Steine für diesen Tausch.');
    }
    final player = currentPlayer;
    _requireHandContains(player, tiles);

    final drawn = bag.draw(tiles.length);
    for (final tile in tiles) {
      _removeOneFromHand(player, tile);
    }
    player.hand.addAll(drawn);
    bag.returnTiles(tiles);
    _advanceTurn();
  }

  void _requireHandContains(Player player, List<Tile> tiles) {
    final remaining = List<Tile>.from(player.hand);
    for (final tile in tiles) {
      final index = remaining.indexOf(tile);
      if (index == -1) {
        throw ArgumentError(
          '${player.name} hat den Stein $tile nicht auf der Hand.',
        );
      }
      remaining.removeAt(index);
    }
  }

  void _removeOneFromHand(Player player, Tile tile) {
    player.hand.removeAt(player.hand.indexOf(tile));
  }

  void _advanceTurn() {
    if (!isOver) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    }
  }
}
