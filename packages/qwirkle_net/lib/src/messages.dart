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
class JoinMessage extends NetMessage {
  final String name;

  JoinMessage(this.name);

  @override
  String get type => 'join';

  @override
  Map<String, dynamic> toJson() => {'name': name};

  factory JoinMessage.fromJson(Map<String, dynamic> json) =>
      JoinMessage(json['name'] as String);
}

/// Host -> Client: Bestätigt die Verbindung und weist eine Spieler-Identität zu.
class WelcomeMessage extends NetMessage {
  final String playerId;

  WelcomeMessage(this.playerId);

  @override
  String get type => 'welcome';

  @override
  Map<String, dynamic> toJson() => {'playerId': playerId};

  factory WelcomeMessage.fromJson(Map<String, dynamic> json) =>
      WelcomeMessage(json['playerId'] as String);
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
    case 'error':
      return ErrorMessage.fromJson(json);
    default:
      throw FormatException('Unbekannter Nachrichtentyp: $type');
  }
}
