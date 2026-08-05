import 'dart:async';
import 'dart:io';

import 'package:qwirkle_server/qwirkle_server.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final dataDir = Directory(Platform.environment['DATA_DIR'] ?? '/data/rooms');
  final retentionDays = int.parse(
    Platform.environment['ROOM_RETENTION_DAYS'] ?? '14',
  );

  final server = GameServer(
    dataDir: dataDir,
    retention: Duration(days: retentionDays),
  );
  await server.start(address: '0.0.0.0', port: port);
  stdout.writeln(
    'qwirkle_server läuft auf Port $port (Daten: ${dataDir.path}, '
    'Aufbewahrung: $retentionDays Tage)',
  );

  // Sauberes Herunterfahren bei `docker stop`/Redeploy: der letzte
  // Zustand wurde ohnehin schon nach jeder Aktion persistiert (kein
  // gesonderter Flush nötig), hier geht es nur darum, den Prozess nicht
  // durch das harte SIGKILL-Timeout der Container-Runtime beenden zu
  // lassen müssen.
  late final StreamSubscription<ProcessSignal> sigterm;
  sigterm = ProcessSignal.sigterm.watch().listen((_) async {
    await sigterm.cancel();
    await server.close();
    exit(0);
  });
}
