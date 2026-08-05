import 'package:qwirkle_core/qwirkle_core.dart';

import 'room_session.dart';
import 'serialization.dart';

/// Voller (nicht Empfänger-gekürzter) Persistenz-Zustand eines
/// [RoomSession]-Raums für das `qwirkle_server`-Backend: übersteht
/// Prozess-Neustarts (Redeploys!) und mehrtägige Pausen zwischen Zügen.
/// Bewusst getrennt von `qwirkle_core` gehalten (wie
/// `GameStateSnapshot` in `serialization.dart`) - das Kern-Package bleibt
/// frei von Persistenz-/Netzwerk-Belangen.
Map<String, dynamic> roomSessionToJson(RoomSession room) => {
  'roomCode': room.roomCode,
  'lastActivity': room.lastActivity.toIso8601String(),
  'seats': [for (final seat in room.seats) _seatToJson(seat)],
  if (room.game != null) 'game': _gameToJson(room.game!),
};

Map<String, dynamic> _seatToJson(RoomSeat seat) => {
  'playerId': seat.playerId,
  'reconnectToken': seat.reconnectToken,
  'name': seat.name,
  'isOwner': seat.isOwner,
  if (seat.playerIndex != null) 'playerIndex': seat.playerIndex,
};

Map<String, dynamic> _gameToJson(QwirkleGame game) => {
  'board': placementsToJson([
    for (final entry in game.board.cells.entries)
      TilePlacement(position: entry.key, tile: entry.value),
  ]),
  'bagTiles': tilesToJson(game.bag.tiles),
  'players': [for (final p in game.players) _playerToJson(p)],
  'currentPlayerIndex': game.currentPlayerIndex,
  'isOver': game.isOver,
  'consecutivePasses': game.consecutivePasses,
};

Map<String, dynamic> _playerToJson(Player p) => {
  'id': p.id,
  'name': p.name,
  'score': p.score,
  'hand': tilesToJson(p.hand),
  if (p.botDifficulty != null) 'botDifficulty': p.botDifficulty!.name,
};

final RegExp _playerIdSuffix = RegExp(r'^p(\d+)$');

/// Baut einen [RoomSession] aus einem zuvor mit [roomSessionToJson]
/// erzeugten Zustand wieder auf. Alle Sitzplätze starten dabei als getrennt
/// (`connected: false`) - ein evtl. gespeicherter "verbunden"-Status ist
/// nach einem Prozess-Neustart ohnehin nicht mehr gültig, da kein Transport
/// überlebt; betroffene Spieler:innen müssen sich mit ihrem Reconnect-Token
/// neu melden.
RoomSession roomSessionFromJson(
  Map<String, dynamic> json, {
  void Function()? onChanged,
}) {
  final seatsJson = json['seats'] as List<dynamic>;

  var nextPlayerNumber = 1;
  for (final rawSeat in seatsJson) {
    final match = _playerIdSuffix.firstMatch(
      (rawSeat as Map<String, dynamic>)['playerId'] as String,
    );
    if (match == null) continue;
    final n = int.parse(match.group(1)!) + 1;
    if (n > nextPlayerNumber) nextPlayerNumber = n;
  }

  final gameJson = json['game'] as Map<String, dynamic>?;
  final game = gameJson == null ? null : _gameFromJson(gameJson);

  final room = RoomSession(
    roomCode: json['roomCode'] as String,
    onChanged: onChanged,
    initialGame: game,
    nextPlayerNumber: nextPlayerNumber,
  );
  room.lastActivity = DateTime.parse(json['lastActivity'] as String);
  for (final rawSeat in seatsJson) {
    final seatJson = rawSeat as Map<String, dynamic>;
    room.seats.add(
      RoomSeat(
        playerId: seatJson['playerId'] as String,
        reconnectToken: seatJson['reconnectToken'] as String,
        name: seatJson['name'] as String,
        isOwner: seatJson['isOwner'] as bool,
        playerIndex: seatJson['playerIndex'] as int?,
        connected: false,
      ),
    );
  }
  return room;
}

QwirkleGame _gameFromJson(Map<String, dynamic> json) {
  final players = [
    for (final rawPlayer in json['players'] as List<dynamic>)
      _playerFromJson(rawPlayer as Map<String, dynamic>),
  ];
  final game = QwirkleGame.restore(
    players: players,
    bag: TileBag.fromTiles(tilesFromJson(json['bagTiles'] as List<dynamic>)),
    currentPlayerIndex: json['currentPlayerIndex'] as int,
    isOver: json['isOver'] as bool,
    consecutivePasses: json['consecutivePasses'] as int,
  );
  game.board.apply(placementsFromJson(json['board'] as List<dynamic>));
  return game;
}

Player _playerFromJson(Map<String, dynamic> json) => Player(
  id: json['id'] as String,
  name: json['name'] as String,
  score: json['score'] as int,
  hand: tilesFromJson(json['hand'] as List<dynamic>),
  botDifficulty: json['botDifficulty'] != null
      ? BotDifficulty.values.byName(json['botDifficulty'] as String)
      : null,
);
