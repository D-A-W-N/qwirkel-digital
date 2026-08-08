import 'dart:async';
import 'dart:io';

import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';
import 'package:test/test.dart';

/// Minimaler Test-Server: nimmt WebSocket-Verbindungen entgegen und reicht
/// sie an einen gemeinsamen [RoomManager] weiter - genau das, was
/// `qwirkle_server`s `GameServer` im echten Backend zusätzlich zu
/// Persistenz/Env-Konfiguration tut.
class _TestServer {
  final RoomManager manager = RoomManager();
  HttpServer? _http;

  Future<int> start() async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    _http = server;
    server.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        manager.acceptTransport(WebSocketTransport(socket));
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..close();
      }
    });
    return server.port;
  }

  Future<void> close() => _http?.close(force: true) ?? Future.value();
}

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
  group('RoomManager/RoomSession über WebSocket (Loopback)', () {
    late _TestServer server;
    late int port;

    setUp(() async {
      server = _TestServer();
      port = await server.start();
    });

    tearDown(() async {
      await server.close();
    });

    test(
      'Erster Beitritt ohne Raum-Code erstellt einen neuen Raum, Ersteller:in wird Owner',
      () async {
        final anna = await _connect(port, name: 'Anna');
        addTearDown(anna.close);

        expect(anna.roomCode, isNotNull);
        expect(anna.reconnectToken, isNotNull);
        expect(anna.isRoomOwner, isTrue);
        expect(server.manager.room(anna.roomCode!), isNotNull);
      },
    );

    test(
      'Zweite:r Spieler:in tritt per Raum-Code bei, beide sehen die Lobby',
      () async {
        final anna = await _connect(port, name: 'Anna');
        addTearDown(anna.close);

        final lobbyFuture = anna.lobbyUpdates.firstWhere(
          (l) => l.players.length == 2,
        );
        final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);
        addTearDown(ben.close);
        final lobby = await lobbyFuture;

        expect(lobby.players.map((p) => p.name), containsAll(['Anna', 'Ben']));
        expect(lobby.canStart, isTrue);
        expect(ben.isRoomOwner, isFalse);
      },
    );

    test(
      'Unbekannter Raum-Code liefert einen Fehler statt einer Verbindung',
      () async {
        final socket = await WebSocket.connect('ws://127.0.0.1:$port');
        final session = ClientSession();
        addTearDown(session.close);
        final errorFuture = session.errors.first;

        unawaited(
          session
              .connectVia(
                WebSocketTransport(socket),
                name: 'Geist',
                roomCode: 'NOPE1',
              )
              .catchError((_) {}),
        );

        final error = await errorFuture;
        expect(error, contains('Unbekannter'));
      },
    );

    test(
      'Owner startet die Partie, beide Seiten bekommen einen zugeschnittenen Zustand',
      () async {
        final anna = await _connect(port, name: 'Anna');
        addTearDown(anna.close);
        final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);
        addTearDown(ben.close);

        final annaState = anna.stateUpdates.first;
        final benState = ben.stateUpdates.first;
        anna.sendStartGame();

        final annaSnapshot = await annaState;
        final benSnapshot = await benState;

        expect(
          annaSnapshot.yourPlayerIndex,
          isNot(benSnapshot.yourPlayerIndex),
        );
        expect(
          annaSnapshot.players[annaSnapshot.yourPlayerIndex].hand,
          isNotNull,
        );
        expect(annaSnapshot.players[benSnapshot.yourPlayerIndex].hand, isNull);
      },
    );

    test('Nur der Owner darf die Partie starten', () async {
      final anna = await _connect(port, name: 'Anna');
      addTearDown(anna.close);
      final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);
      addTearDown(ben.close);

      final errorFuture = ben.errors.first;
      ben.sendStartGame();
      final error = await errorFuture;

      expect(error, contains('Raumersteller'));
      final room = server.manager.room(anna.roomCode!)!;
      expect(room.isGameStarted, isFalse);
    });

    test('Zug wird validiert und an beide Seiten verteilt', () async {
      final anna = await _connect(port, name: 'Anna');
      addTearDown(anna.close);
      final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);
      addTearDown(ben.close);

      final annaState = anna.stateUpdates.first;
      final benState = ben.stateUpdates.first;
      anna.sendStartGame();
      await annaState;
      await benState;

      final room = server.manager.room(anna.roomCode!)!;
      final game = room.game!;
      // Deterministische Ausgangslage erzwingen, unabhängig von der
      // zufälligen Starthand/Startspieler-Ermittlung.
      game.currentPlayerIndex = 0;
      game.players[0].hand = [const Tile(TileColor.red, TileShape.circle)];

      final updated = ben.stateUpdates.first;
      anna.sendMove([
        const TilePlacement(
          position: Position(0, 0),
          tile: Tile(TileColor.red, TileShape.circle),
        ),
      ]);
      final afterMove = await updated;

      expect(afterMove.board.length, 1);
      expect(afterMove.currentPlayerIndex, 1);
    });

    test(
      'Getrennter Sitzplatz wird nach Spielstart NICHT automatisch übersprungen',
      () async {
        final anna = await _connect(port, name: 'Anna');
        addTearDown(anna.close);
        final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);

        final annaState = anna.stateUpdates.first;
        anna.sendStartGame();
        await annaState;

        final room = server.manager.room(anna.roomCode!)!;
        final game = room.game!;
        game.currentPlayerIndex = 1; // Ben ist am Zug.

        await ben.close();
        // Der Trennungs-Handler läuft asynchron über den Stream - kurz
        // nachgeben, damit er sicher durchgelaufen ist.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(game.currentPlayerIndex, 1); // unverändert, kein Auto-Skip
        expect(game.isOver, isFalse);
      },
    );

    test(
      'Eine getrennte Person wird für die anderen live als nicht verbunden '
      'markiert, statt dass die Partie kommentarlos zu warten scheint',
      () async {
        // Regression: `_handleDisconnect` setzte vorher nur die lokale
        // `RoomSeat.connected`-Flagge, ohne die anderen Sitzplätze über
        // einen neuen Spielstand zu informieren - Anna hätte nie erfahren,
        // dass Ben getrennt ist.
        final anna = await _connect(port, name: 'Anna');
        addTearDown(anna.close);
        final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);

        final annaState = anna.stateUpdates.first;
        anna.sendStartGame();
        await annaState;

        final annaSeesDisconnect = anna.stateUpdates.firstWhere(
          (s) => !s.players[1].connected,
        );
        await ben.close();

        final snapshot = await annaSeesDisconnect;
        expect(snapshot.players[1].connected, isFalse);
        expect(snapshot.players[0].connected, isTrue);
      },
    );

    test(
      'Reconnect mit gültigem Token übernimmt denselben Sitzplatz',
      () async {
        final anna = await _connect(port, name: 'Anna');
        addTearDown(anna.close);
        final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);

        final annaState = anna.stateUpdates.first;
        final firstBenState = ben.stateUpdates.first;
        anna.sendStartGame();
        await annaState;
        await firstBenState;

        final benToken = ben.reconnectToken!;
        final benRoomCode = ben.roomCode!;
        await ben.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final benAgain = await _connect(
          port,
          name: 'Ben',
          roomCode: benRoomCode,
          reconnectToken: benToken,
        );
        addTearDown(benAgain.close);
        // Der Zustand nach Reconnect kommt als eigene Nachricht NACH dem
        // Welcome, auf dessen Empfang `connectVia` bereits zurückkehrt -
        // explizit abwarten statt sofort `latestSnapshot` zu prüfen.
        await benAgain.stateUpdates.first;

        expect(benAgain.latestSnapshot, isNotNull);
        final room = server.manager.room(anna.roomCode!)!;
        // Kein zusätzlicher dritter Sitzplatz entstanden.
        expect(room.seats.length, 2);
        expect(
          room.seats
              .where((s) => s.reconnectToken == benToken)
              .single
              .connected,
          isTrue,
        );
      },
    );

    test('Ein Reconnect wird auch den anderen Sitzplätzen live mitgeteilt, '
        'nicht nur dem zurückkehrenden', () async {
      // Regression: vorher wurde nach einem erfolgreichen Reconnect der
      // neue Zustand nur an den zurückkehrenden Sitzplatz selbst
      // gesendet - Anna hätte nie erfahren, dass Ben wieder verbunden ist.
      final anna = await _connect(port, name: 'Anna');
      addTearDown(anna.close);
      final ben = await _connect(port, name: 'Ben', roomCode: anna.roomCode);

      final annaState = anna.stateUpdates.first;
      final firstBenState = ben.stateUpdates.first;
      anna.sendStartGame();
      await annaState;
      await firstBenState;

      final annaSeesDisconnect = anna.stateUpdates.firstWhere(
        (s) => !s.players[1].connected,
      );
      final benToken = ben.reconnectToken!;
      final benRoomCode = ben.roomCode!;
      await ben.close();
      await annaSeesDisconnect;

      final annaSeesReconnect = anna.stateUpdates.firstWhere(
        (s) => s.players[1].connected,
      );
      final benAgain = await _connect(
        port,
        name: 'Ben',
        roomCode: benRoomCode,
        reconnectToken: benToken,
      );
      addTearDown(benAgain.close);

      final snapshot = await annaSeesReconnect;
      expect(snapshot.players[1].connected, isTrue);
    });
  });
}
