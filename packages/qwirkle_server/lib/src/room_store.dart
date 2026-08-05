import 'dart:convert';
import 'dart:io';

import 'package:qwirkle_net/qwirkle_net.dart';

/// Persistiert [RoomSession]s als eine JSON-Datei pro Raum auf Platte, damit
/// laufende Partien einen Prozess-Neustart (z. B. ein Redeploy über die
/// Pipeline) unbeschadet überstehen.
///
/// Schreibt atomar (temporäre Datei + `rename`), damit ein Absturz mitten im
/// Schreibvorgang nie eine halb geschriebene, kaputte Raum-Datei hinterlässt.
class RoomStore {
  final Directory dataDir;

  /// Räume, die länger als [retention] keine Aktivität hatten, gelten als
  /// verwaist und werden bei [cleanupExpired] entfernt.
  final Duration retention;

  RoomStore({required this.dataDir, this.retention = const Duration(days: 14)});

  /// Kettet aufeinanderfolgende [save]-Aufrufe pro Raum strikt
  /// hintereinander. Nötig, weil `RoomSession.onChanged` bei mehreren
  /// zustandsändernden Aktionen kurz hintereinander (z. B. Beitritt +
  /// sofortiger Zug) jeweils einen neuen, nicht abgewarteten [save]-Aufruf
  /// auslöst (`GameServer` ruft ihn bewusst per `unawaited` auf) - ohne
  /// diese Warteschlange würden zwei parallele Schreibvorgänge auf dieselbe
  /// Temp-Datei desselben Raums sich gegenseitig den `rename`-Zielpfad
  /// wegschnappen.
  final Map<String, Future<void>> _pendingSaves = {};

  File _fileFor(String roomCode) => File('${dataDir.path}/$roomCode.json');

  /// Wartet, bis alle aktuell laufenden [save]-Vorgänge abgeschlossen sind -
  /// vor dem Herunterfahren des Prozesses aufrufen (siehe `GameServer.close`),
  /// damit kein Schreibvorgang mitten im `rename` unterbrochen wird und ein
  /// eventueller neuer Prozess (Redeploy) nicht mit einem noch laufenden
  /// alten Schreibvorgang um dieselbe Temp-Datei konkurriert.
  Future<void> waitForPendingSaves() => Future.wait(_pendingSaves.values);

  /// Schreibt [room] auf Platte (atomar über eine Temp-Datei + `rename`),
  /// aufgerufen als `onChanged`-Hook nach jeder zustandsändernden Aktion.
  Future<void> save(RoomSession room) {
    final previous = _pendingSaves[room.roomCode] ?? Future<void>.value();
    final current = previous.then((_) => _writeNow(room));
    _pendingSaves[room.roomCode] = current;
    return current;
  }

  Future<void> _writeNow(RoomSession room) async {
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }
    final target = _fileFor(room.roomCode);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode(roomSessionToJson(room)));
    await tmp.rename(target.path);
  }

  Future<void> delete(String roomCode) async {
    _pendingSaves.remove(roomCode);
    final file = _fileFor(roomCode);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Lädt alle persistierten Räume und fügt sie in [manager] ein. Räume,
  /// deren letzte Aktivität bereits [retention] überschritten hat, werden
  /// dabei direkt übersprungen und von Platte gelöscht statt geladen.
  Future<void> loadInto(RoomManager manager) async {
    if (!dataDir.existsSync()) return;
    final now = DateTime.now();
    for (final entity in dataDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final json = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      final room = roomSessionFromJson(json);
      if (now.difference(room.lastActivity) > retention) {
        await entity.delete();
        continue;
      }
      manager.addRestoredRoom(room);
    }
  }

  /// Entfernt Räume ohne Aktivität seit [retention] sowohl aus [manager] als
  /// auch von Platte. Für einen periodischen Aufruf gedacht (siehe
  /// `GameServer`), damit sich verwaiste Partien nicht unbegrenzt ansammeln.
  Future<void> cleanupExpired(RoomManager manager) async {
    final now = DateTime.now();
    for (final room in List.of(manager.rooms)) {
      if (now.difference(room.lastActivity) > retention) {
        manager.removeRoom(room.roomCode);
        await delete(room.roomCode);
      }
    }
  }
}
