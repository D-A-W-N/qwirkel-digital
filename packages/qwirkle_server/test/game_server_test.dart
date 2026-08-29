import 'dart:async';
import 'dart:io';

import 'package:qwirkle_net/qwirkle_net.dart';
import 'package:qwirkle_server/qwirkle_server.dart';
import 'package:test/test.dart';

Future<ClientSession> _connect(
  int port, {
  required String name,
  String? roomCode,
  String? reconnectToken,
}) async {
  final socket = await WebSocket.connect('ws://127.0.0.1:$port');
  final session = ClientSession();
  await session.connectVia(
    WebSocketTransport(socket),
    name: name,
    roomCode: roomCode,
    reconnectToken: reconnectToken,
  );
  return session;
}

void main() {
  group('GameServer', () {
    late Directory dataDir;

    setUp(() {
      dataDir = Directory.systemTemp.createTempSync('qwirkle_server_test_');
    });

    tearDown(() {
      if (dataDir.existsSync()) dataDir.deleteSync(recursive: true);
    });

    test('Health-Check antwortet ohne WebSocket-Upgrade mit 200', () async {
      final server = GameServer(dataDir: dataDir);
      await server.start(address: '127.0.0.1', port: 0);
      addTearDown(server.close);

      final response = await HttpClient()
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}/health'))
          .then((r) => r.close());

      expect(response.statusCode, 200);
    });

    test('Zwei Clients können über den Server einen Raum spielen', () async {
      final server = GameServer(dataDir: dataDir);
      await server.start(address: '127.0.0.1', port: 0);
      addTearDown(server.close);

      final anna = await _connect(server.port, name: 'Anna');
      addTearDown(anna.close);
      final ben = await _connect(
        server.port,
        name: 'Ben',
        roomCode: anna.roomCode,
      );
      addTearDown(ben.close);

      final annaState = anna.stateUpdates.first;
      anna.sendStartGame();
      final snapshot = await annaState;

      expect(snapshot.players.length, 2);
    });

    test(
      'Ein vor Spielstart leergelaufener Raum kann nicht gekapert werden',
      () async {
        // Regression: verließ die/der einzige Person einen Raum vor
        // Spielstart, blieb er als leerer RoomSession-Eintrag bestehen -
        // eine unbeteiligte Person, die denselben Code später verwendete,
        // wurde automatisch dessen neue:r Owner:in (`isOwner: seats.isEmpty`).
        final server = GameServer(dataDir: dataDir);
        await server.start(address: '127.0.0.1', port: 0);
        addTearDown(server.close);

        final anna = await _connect(server.port, name: 'Anna');
        final roomCode = anna.roomCode!;
        expect(server.manager.room(roomCode), isNotNull);

        await anna.close();
        // Der Trennungs-Handler läuft asynchron über den Stream - kurz
        // nachgeben, damit er sicher durchgelaufen ist.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          server.manager.room(roomCode),
          isNull,
          reason: 'Der leere Raum sollte sofort entfernt worden sein.',
        );

        final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}');
        final intruder = ClientSession();
        addTearDown(intruder.close);
        final errorFuture = intruder.errors.first;
        unawaited(
          intruder
              .connectVia(
                WebSocketTransport(socket),
                name: 'Unbeteiligt',
                roomCode: roomCode,
              )
              .catchError((_) {}),
        );

        final error = await errorFuture;
        expect(error, contains('Unbekannter'));
      },
    );

    test(
      'Zu viele Verbindungsversuche von einer IP werden mit 429 abgelehnt',
      () async {
        final server = GameServer(
          dataDir: dataDir,
          rateLimiter: ConnectionRateLimiter(
            maxAttempts: 2,
            window: const Duration(seconds: 10),
          ),
        );
        await server.start(address: '127.0.0.1', port: 0);
        addTearDown(server.close);

        final anna = await _connect(server.port, name: 'Anna');
        addTearDown(anna.close);
        final ben = await _connect(
          server.port,
          name: 'Ben',
          roomCode: anna.roomCode,
        );
        addTearDown(ben.close);

        // Der dritte Verbindungsversuch von derselben (Loopback-)IP
        // innerhalb des Fensters überschreitet das Limit - der Server lehnt
        // das WebSocket-Upgrade bereits per HTTP 429 ab, statt den Beitritt
        // überhaupt an RoomManager weiterzureichen.
        await expectLater(
          WebSocket.connect('ws://127.0.0.1:${server.port}'),
          throwsA(isA<WebSocketException>()),
        );
      },
    );

    test(
      'Ein neu persistierter Raum überlebt einen Server-Neustart (Redeploy-Szenario)',
      () async {
        final firstServer = GameServer(dataDir: dataDir);
        await firstServer.start(address: '127.0.0.1', port: 0);

        final anna = await _connect(firstServer.port, name: 'Anna');
        final ben = await _connect(
          firstServer.port,
          name: 'Ben',
          roomCode: anna.roomCode,
        );
        final annaState = anna.stateUpdates.first;
        final benState = ben.stateUpdates.first;
        anna.sendStartGame();
        await annaState;
        await benState;

        final roomCode = anna.roomCode!;
        final benToken = ben.reconnectToken!;
        final scoreBefore = ben.latestSnapshot!.players
            .map((p) => p.score)
            .toList();

        await anna.close();
        await ben.close();
        await firstServer.close();

        // Simuliert einen Redeploy: neuer Prozess, dieselbe Datenablage.
        final secondServer = GameServer(dataDir: dataDir);
        await secondServer.start(address: '127.0.0.1', port: 0);
        addTearDown(secondServer.close);

        final benAgain = await _connect(
          secondServer.port,
          name: 'Ben',
          roomCode: roomCode,
          reconnectToken: benToken,
        );
        addTearDown(benAgain.close);
        await benAgain.stateUpdates.first;

        expect(
          benAgain.latestSnapshot!.players.map((p) => p.score).toList(),
          scoreBefore,
        );
      },
    );
  });
}
