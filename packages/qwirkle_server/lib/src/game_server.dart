import 'dart:async';
import 'dart:io';

import 'package:qwirkle_net/qwirkle_net.dart';

import 'room_store.dart';

/// Der eigentliche Internet-Multiplayer-Server: HTTP/WebSocket-Aufbau
/// (`HttpServer` + `WebSocketTransformer`, wie schon `SignalingServer` es
/// vormacht) plus Persistenz auf Platte über [RoomStore]. Die
/// Raum-/Zugvalidierungslogik selbst liegt komplett in `qwirkle_net`s
/// [RoomManager]/[RoomSession] - dieser Server verdrahtet sie nur mit
/// echten Netzwerk-/Dateisystem-Ressourcen.
class GameServer {
  final RoomStore store;
  late final RoomManager manager;
  HttpServer? _http;
  Timer? _cleanupTimer;

  GameServer({required Directory dataDir, Duration? retention})
    : store = RoomStore(
        dataDir: dataDir,
        retention: retention ?? const Duration(days: 14),
      ) {
    manager = RoomManager(
      onRoomChanged: (room) => unawaited(store.save(room)),
    );
  }

  int get port => _http?.port ?? 0;

  /// Lädt zuvor persistierte Räume, startet den HTTP/WebSocket-Listener und
  /// eine stündliche Aufräum-Routine für verwaiste Räume (siehe
  /// [RoomStore.cleanupExpired]).
  Future<void> start({String address = '0.0.0.0', int port = 0}) async {
    await store.loadInto(manager);

    final server = await HttpServer.bind(address, port);
    _http = server;
    server.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        manager.acceptTransport(WebSocketTransport(socket));
      } else if (request.uri.path == '/health') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('ok')
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Nur WebSocket-Verbindungen werden unterstützt.')
          ..close();
      }
    });

    _cleanupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => unawaited(store.cleanupExpired(manager)),
    );
  }

  /// Schließt den Listener und wartet, bis alle noch laufenden
  /// Persistenz-Schreibvorgänge abgeschlossen sind - wichtig bei einem
  /// Redeploy, damit ein neu startender Prozess nie mit einem noch aktiven
  /// Schreibvorgang des alten Prozesses um dieselbe Raum-Datei konkurriert.
  Future<void> close() async {
    _cleanupTimer?.cancel();
    await _http?.close(force: true);
    await store.waitForPendingSaves();
  }
}
