import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/room_connection_manager.dart';
import 'package:qwirkle_digital/src/net/internet_room_history.dart';
import 'package:qwirkle_server/qwirkle_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

void main() {
  group('RoomConnectionManager', () {
    late GameServer server;
    late String serverUrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      server = GameServer(
        dataDir: Directory.systemTemp.createTempSync('room_manager_test_'),
      );
      await server.start(address: '127.0.0.1', port: 0);
      serverUrl = 'ws://127.0.0.1:${server.port}';
    });

    tearDown(() async {
      await server.close();
    });

    test('erstellt einen Raum und merkt ihn sich als lebende Verbindung', () async {
      final manager = RoomConnectionManager();
      addTearDown(manager.dispose);

      final entry = await manager.createInternetRoom(
        serverUrl: serverUrl,
        playerName: 'Anna',
        roomName: 'Testrunde',
      );

      expect(entry.roomCode, isNotNull);
      expect(manager.entryFor(entry.roomCode), same(entry));
      expect(manager.rooms, [entry]);
    });

    test(
      'joinInternetRoom für einen bereits live verbundenen Raum liefert '
      'denselben Eintrag zurück, statt einen zweiten Socket zu öffnen',
      () async {
        final anna = RoomConnectionManager();
        addTearDown(anna.dispose);
        final ben = RoomConnectionManager();
        addTearDown(ben.dispose);

        final annaEntry = await anna.createInternetRoom(
          serverUrl: serverUrl,
          playerName: 'Anna',
        );
        final benEntry = await ben.joinInternetRoom(
          serverUrl: serverUrl,
          playerName: 'Ben',
          roomCode: annaEntry.roomCode!,
        );

        final again = await ben.joinInternetRoom(
          serverUrl: serverUrl,
          playerName: 'Ben',
          roomCode: annaEntry.roomCode!,
        );

        expect(identical(again, benEntry), isTrue);
        expect(ben.rooms.length, 1);
      },
    );

    test(
      'leaveRoom entfernt die Verbindung aus dem Manager UND aus der '
      'dauerhaften Historie',
      () async {
        final manager = RoomConnectionManager();
        addTearDown(manager.dispose);

        final entry = await manager.createInternetRoom(
          serverUrl: serverUrl,
          playerName: 'Anna',
        );
        final roomCode = entry.roomCode!;
        expect(
          (await loadInternetRoomHistory()).map((e) => e.roomCode),
          contains(roomCode),
        );

        await manager.leaveRoom(roomCode);

        expect(manager.entryFor(roomCode), isNull);
        expect(
          (await loadInternetRoomHistory()).map((e) => e.roomCode),
          isNot(contains(roomCode)),
        );
      },
    );

    test(
      'benachrichtigt die Person, die am Zug ist, sofern ihr Raum nicht im '
      'Vordergrund steht - die andere Person bekommt keine Benachrichtigung',
      () async {
        final anna = RoomConnectionManager();
        addTearDown(anna.dispose);
        final ben = RoomConnectionManager();
        addTearDown(ben.dispose);

        final annaEntry = await anna.createInternetRoom(
          serverUrl: serverUrl,
          playerName: 'Anna',
        );
        final roomCode = annaEntry.roomCode!;
        final benEntry = await ben.joinInternetRoom(
          serverUrl: serverUrl,
          playerName: 'Ben',
          roomCode: roomCode,
        );

        // Keine der beiden Seiten hält den Raum im Vordergrund - egal, wer
        // zufällig beginnt, exakt eine Seite muss benachrichtigt werden.
        final annaNotification = anna.turnNotifications.first;
        final benNotification = ben.turnNotifications.first;
        final annaStateUpdate = annaEntry.session.stateUpdates.first;

        annaEntry.session.sendStartGame();
        final snapshot = await annaStateUpdate;
        final annaBegins = snapshot.currentPlayerIndex == snapshot.yourPlayerIndex;

        if (annaBegins) {
          expect(await annaNotification.timeout(const Duration(seconds: 5)), roomCode);
          expect(benNotification.timeout(const Duration(milliseconds: 200)), throwsA(anything));
        } else {
          expect(await benNotification.timeout(const Duration(seconds: 5)), roomCode);
          expect(
            annaNotification.timeout(const Duration(milliseconds: 200)),
            throwsA(anything),
          );
        }
        // benEntry wird hier nur referenziert, um sicherzustellen, dass der
        // Beitritt vor dem Spielstart abgeschlossen war.
        expect(benEntry.roomCode, roomCode);
      },
    );
  });
}
