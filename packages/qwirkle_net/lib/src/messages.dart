import 'dart:convert';

import 'package:qwirkle_core/qwirkle_core.dart';

import 'serialization.dart';

/// Basisklasse aller Netzwerknachrichten des Qwirkle-Sync-Protokolls.
///
/// Jede Nachricht kennt ihren `type`-Diskriminator für die JSON-Kodierung.
/// [encode]/[decodeMessage] übernehmen das Zeilen-Framing (ein JSON-Objekt
/// pro Zeile, newline-getrennt) für den Transport über Sockets.
abstract class NetMessage {
  String get type;

  Map<String, dynamic> toJson();

  /// Kodiert die Nachricht als einzelne, newline-terminierte JSON-Zeile.
  String encode() => '${jsonEncode({'type': type, ...toJson()})}\n';
}

/// Client -> Host: Beitrittswunsch mit gewünschtem Anzeigenamen.
///
/// [roomCode]/[reconnectToken] werden nur vom `qwirkle_server`-Backend
/// genutzt (mehrere Räume auf einem Port) - `HostSession` (LAN, ein Prozess
/// = eine Partie) ignoriert sie. `roomCode == null` bedeutet dort "neuen Raum
/// erstellen", ein gesetzter [reconnectToken] fordert die Rückgabe eines
/// zuvor verlassenen Sitzplatzes an, statt einen neuen zu vergeben.
class JoinMessage extends NetMessage {
  final String name;
  final String? roomCode;
  final String? reconnectToken;

  JoinMessage(this.name, {this.roomCode, this.reconnectToken});

  @override
  String get type => 'join';

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    if (roomCode != null) 'roomCode': roomCode,
    if (reconnectToken != null) 'reconnectToken': reconnectToken,
  };

  factory JoinMessage.fromJson(Map<String, dynamic> json) => JoinMessage(
    json['name'] as String,
    roomCode: json['roomCode'] as String?,
    reconnectToken: json['reconnectToken'] as String?,
  );
}

/// Host -> Client: Bestätigt die Verbindung und weist eine Spieler-Identität
/// zu. Im `qwirkle_server`-Backend zusätzlich mit dem (neu oder wieder
/// vergebenen) Einladungscode des Raums sowie einem Reconnect-Token, das der
/// Client lokal speichert, um nach einer Trennung denselben Sitzplatz per
/// [JoinMessage.reconnectToken] zurückzufordern.
class WelcomeMessage extends NetMessage {
  final String playerId;
  final String? roomCode;
  final String? reconnectToken;

  /// Nur `qwirkle_server`-Backend: ob dieser Sitzplatz die Owner-Rechte hat
  /// (`StartGameMessage`/`RestartGameMessage` senden darf). Vom Server
  /// bestätigt statt vom Client selbst hergeleitet, damit auch ein
  /// reconnectender Owner seine Rolle zuverlässig zurückbekommt.
  final bool isOwner;

  WelcomeMessage(
    this.playerId, {
    this.roomCode,
    this.reconnectToken,
    this.isOwner = false,
  });

  @override
  String get type => 'welcome';

  @override
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    if (roomCode != null) 'roomCode': roomCode,
    if (reconnectToken != null) 'reconnectToken': reconnectToken,
    if (isOwner) 'isOwner': isOwner,
  };

  factory WelcomeMessage.fromJson(Map<String, dynamic> json) =>
      WelcomeMessage(
        json['playerId'] as String,
        roomCode: json['roomCode'] as String?,
        reconnectToken: json['reconnectToken'] as String?,
        isOwner: json['isOwner'] as bool? ?? false,
      );
}

/// Raumbesitzer:in -> Server: startet die Partie mit allen aktuell im Raum
/// befindlichen Spieler:innen (`qwirkle_server`-Backend; entspricht
/// `HostSession.startGame()`, das im LAN-Modus lokal statt über die
/// Leitung aufgerufen wird).
class StartGameMessage extends NetMessage {
  StartGameMessage();

  @override
  String get type => 'startGame';

  @override
  Map<String, dynamic> toJson() => {};

  factory StartGameMessage.fromJson(Map<String, dynamic> json) =>
      StartGameMessage();
}

/// Raumbesitzer:in -> Server: startet die Partie mit denselben Teilnehmer:innen
/// neu (`qwirkle_server`-Backend; entspricht `HostSession.restartGame()`).
class RestartGameMessage extends NetMessage {
  RestartGameMessage();

  @override
  String get type => 'restartGame';

  @override
  Map<String, dynamic> toJson() => {};

  factory RestartGameMessage.fromJson(Map<String, dynamic> json) =>
      RestartGameMessage();
}

/// Host -> alle Clients: aktuelle Warteliste vor Spielstart.
class LobbyMessage extends NetMessage {
  final List<({String id, String name})> players;
  final bool canStart;

  LobbyMessage(this.players, {required this.canStart});

  @override
  String get type => 'lobby';

  @override
  Map<String, dynamic> toJson() => {
    'players': [
      for (final p in players) {'id': p.id, 'name': p.name},
    ],
    'canStart': canStart,
  };

  factory LobbyMessage.fromJson(Map<String, dynamic> json) => LobbyMessage([
    for (final p in json['players'] as List<dynamic>)
      (
        id: (p as Map<String, dynamic>)['id'] as String,
        name: p['name'] as String,
      ),
  ], canStart: json['canStart'] as bool);
}

/// Host -> Client: vollständiger (für den Empfänger zugeschnittener) Spielstand.
class GameStateMessage extends NetMessage {
  final GameStateSnapshot snapshot;

  GameStateMessage(this.snapshot);

  @override
  String get type => 'state';

  @override
  Map<String, dynamic> toJson() => snapshot.toJson();

  factory GameStateMessage.fromJson(Map<String, dynamic> json) =>
      GameStateMessage(GameStateSnapshot.fromJson(json));
}

/// Client -> Host: Zug-Wunsch (Steine legen).
class MoveMessage extends NetMessage {
  final List<TilePlacement> placements;

  MoveMessage(this.placements);

  @override
  String get type => 'move';

  @override
  Map<String, dynamic> toJson() => {'placements': placementsToJson(placements)};

  factory MoveMessage.fromJson(Map<String, dynamic> json) =>
      MoveMessage(placementsFromJson(json['placements'] as List<dynamic>));
}

/// Client -> Host: Tausch-Wunsch.
class ExchangeMessage extends NetMessage {
  final List<Tile> tiles;

  ExchangeMessage(this.tiles);

  @override
  String get type => 'exchange';

  @override
  Map<String, dynamic> toJson() => {'tiles': tilesToJson(tiles)};

  factory ExchangeMessage.fromJson(Map<String, dynamic> json) =>
      ExchangeMessage(tilesFromJson(json['tiles'] as List<dynamic>));
}

/// Client -> Host: Aussetzen.
class PassMessage extends NetMessage {
  PassMessage();

  @override
  String get type => 'pass';

  @override
  Map<String, dynamic> toJson() => {};

  factory PassMessage.fromJson(Map<String, dynamic> json) => PassMessage();
}

/// Host -> Client: der zuletzt gesendete Zug-Wunsch war ungültig.
class ErrorMessage extends NetMessage {
  final String message;

  ErrorMessage(this.message);

  @override
  String get type => 'error';

  @override
  Map<String, dynamic> toJson() => {'message': message};

  factory ErrorMessage.fromJson(Map<String, dynamic> json) =>
      ErrorMessage(json['message'] as String);
}

/// Dekodiert eine empfangene JSON-Zeile in die passende [NetMessage].
NetMessage decodeMessage(String line) {
  final json = jsonDecode(line) as Map<String, dynamic>;
  final type = json['type'] as String;
  switch (type) {
    case 'join':
      return JoinMessage.fromJson(json);
    case 'welcome':
      return WelcomeMessage.fromJson(json);
    case 'lobby':
      return LobbyMessage.fromJson(json);
    case 'state':
      return GameStateMessage.fromJson(json);
    case 'move':
      return MoveMessage.fromJson(json);
    case 'exchange':
      return ExchangeMessage.fromJson(json);
    case 'pass':
      return PassMessage.fromJson(json);
    case 'startGame':
      return StartGameMessage.fromJson(json);
    case 'restartGame':
      return RestartGameMessage.fromJson(json);
    case 'error':
      return ErrorMessage.fromJson(json);
    default:
      throw FormatException('Unbekannter Nachrichtentyp: $type');
  }
}
