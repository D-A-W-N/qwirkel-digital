import 'package:qwirkle_core/qwirkle_core.dart';

/// JSON-(De-)Serialisierung für die reinen Datentypen aus `qwirkle_core`.
///
/// Bewusst getrennt von `qwirkle_core` gehalten, damit das Kern-Package frei
/// von Netzwerk-/Serialisierungs-Belangen bleibt.
Map<String, dynamic> tileToJson(Tile tile) => {
  'color': tile.color.name,
  'shape': tile.shape.name,
};

Tile tileFromJson(Map<String, dynamic> json) => Tile(
  TileColor.values.byName(json['color'] as String),
  TileShape.values.byName(json['shape'] as String),
);

Map<String, dynamic> positionToJson(Position position) => {
  'x': position.x,
  'y': position.y,
};

Position positionFromJson(Map<String, dynamic> json) =>
    Position(json['x'] as int, json['y'] as int);

Map<String, dynamic> placementToJson(TilePlacement placement) => {
  'position': positionToJson(placement.position),
  'tile': tileToJson(placement.tile),
};

TilePlacement placementFromJson(Map<String, dynamic> json) => TilePlacement(
  position: positionFromJson(json['position'] as Map<String, dynamic>),
  tile: tileFromJson(json['tile'] as Map<String, dynamic>),
);

List<Map<String, dynamic>> placementsToJson(List<TilePlacement> placements) =>
    placements.map(placementToJson).toList();

List<TilePlacement> placementsFromJson(List<dynamic> json) =>
    json.map((e) => placementFromJson(e as Map<String, dynamic>)).toList();

List<Map<String, dynamic>> tilesToJson(List<Tile> tiles) =>
    tiles.map(tileToJson).toList();

List<Tile> tilesFromJson(List<dynamic> json) =>
    json.map((e) => tileFromJson(e as Map<String, dynamic>)).toList();

/// Sicht auf einen Spieler aus Netzwerksicht: die eigene Hand ist nur für den
/// jeweils empfangenden Client sichtbar, bei anderen Spielern nur die Anzahl.
class PlayerView {
  final String id;
  final String name;
  final int score;
  final bool isBot;
  final int handCount;
  final List<Tile>? hand;

  const PlayerView({
    required this.id,
    required this.name,
    required this.score,
    required this.isBot,
    required this.handCount,
    this.hand,
  });

  factory PlayerView.of(Player player, {required bool includeHand}) =>
      PlayerView(
        id: player.id,
        name: player.name,
        score: player.score,
        isBot: player.isBot,
        handCount: player.hand.length,
        hand: includeHand ? List.unmodifiable(player.hand) : null,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'score': score,
    'isBot': isBot,
    'handCount': handCount,
    if (hand != null) 'hand': tilesToJson(hand!),
  };

  factory PlayerView.fromJson(Map<String, dynamic> json) => PlayerView(
    id: json['id'] as String,
    name: json['name'] as String,
    score: json['score'] as int,
    isBot: json['isBot'] as bool,
    handCount: json['handCount'] as int,
    hand: json['hand'] != null
        ? tilesFromJson(json['hand'] as List<dynamic>)
        : null,
  );
}

/// Vollständiger, für einen bestimmten Empfänger zugeschnittener Spielstand.
class GameStateSnapshot {
  final List<PlayerView> players;
  final int currentPlayerIndex;
  final int bagRemaining;
  final bool isOver;
  final List<TilePlacement> board;
  final int yourPlayerIndex;

  const GameStateSnapshot({
    required this.players,
    required this.currentPlayerIndex,
    required this.bagRemaining,
    required this.isOver,
    required this.board,
    required this.yourPlayerIndex,
  });

  /// Baut den Snapshot aus [game] auf, wobei nur die Hand von
  /// [recipientPlayerIndex] mitgeschickt wird.
  factory GameStateSnapshot.forRecipient(
    QwirkleGame game,
    int recipientPlayerIndex,
  ) {
    return GameStateSnapshot(
      players: [
        for (var i = 0; i < game.players.length; i++)
          PlayerView.of(
            game.players[i],
            includeHand: i == recipientPlayerIndex,
          ),
      ],
      currentPlayerIndex: game.currentPlayerIndex,
      bagRemaining: game.bag.remaining,
      isOver: game.isOver,
      board: [
        for (final entry in game.board.cells.entries)
          TilePlacement(position: entry.key, tile: entry.value),
      ],
      yourPlayerIndex: recipientPlayerIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'currentPlayerIndex': currentPlayerIndex,
    'bagRemaining': bagRemaining,
    'isOver': isOver,
    'board': placementsToJson(board),
    'yourPlayerIndex': yourPlayerIndex,
  };

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) =>
      GameStateSnapshot(
        players: (json['players'] as List<dynamic>)
            .map((e) => PlayerView.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentPlayerIndex: json['currentPlayerIndex'] as int,
        bagRemaining: json['bagRemaining'] as int,
        isOver: json['isOver'] as bool,
        board: placementsFromJson(json['board'] as List<dynamic>),
        yourPlayerIndex: json['yourPlayerIndex'] as int,
      );
}
