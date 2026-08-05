/// Host-autoritatives Netzwerk-Sync-Protokoll für Qwirkle-Digital.
///
/// Zwei Transport-/Sitzungsmodelle teilen sich dasselbe Nachrichtenprotokoll
/// (`messages.dart`) über die gemeinsame [MessageTransport]-Schnittstelle:
/// - LAN: [TcpTransport] + [HostSession] (Host als eingebetteter lokaler
///   Spieler, ein Prozess = eine Partie).
/// - Internet: [WebSocketTransport] + [RoomManager]/[RoomSession] gegen den
///   dedizierten, dauerhaft laufenden `qwirkle_server`-Backend-Prozess
///   (jeder Sitzplatz ist ein Netzwerk-Client, mit Reconnect-Tokens für
///   mehrtägige Partien trotz Verbindungsabbrüchen). `room_persistence.dart`
///   serialisiert dafür den vollen Raumzustand für die Server-seitige
///   Persistenz auf Platte.
library;

export 'src/client_session.dart';
export 'src/host_session.dart';
export 'src/messages.dart';
export 'src/room_manager.dart';
export 'src/room_persistence.dart';
export 'src/room_session.dart';
export 'src/serialization.dart';
export 'src/transport.dart';
