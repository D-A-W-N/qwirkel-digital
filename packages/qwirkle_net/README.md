# qwirkle_net

Netzwerk-Session-Logik für Qwirkle-Digital-Multiplayer (Zugvalidierung läuft ausschließlich über [qwirkle_core](../qwirkle_core), nie client-seitig), über ein transportunabhängiges `MessageTransport`-Interface:

- LAN: host-autoritative `HostSession`/`ClientSession` über `TcpTransport`.
- Internet: `RoomManager`/`RoomSession` über `WebSocketTransport`, gegen den dedizierten `qwirkle_server`-Backend-Prozess (siehe [packages/qwirkle_server](../qwirkle_server)) - mit Reconnect-Tokens für mehrtägige Partien trotz Verbindungsabbrüchen und `room_persistence.dart` für die Server-seitige Persistenz auf Platte.

Siehe [Root-README](../../README.md) für Setup und Testbefehle.
