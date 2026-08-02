import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';
import 'package:test/test.dart';

void main() {
  group('Host/Client-Sync über TCP (Loopback)', () {
    late HostSession host;

    setUp(() async {
      host = HostSession(hostPlayerName: 'Host-Anna');
      await host.start(address: '127.0.0.1', port: 0);
    });

    tearDown(() async {
      await host.close();
    });

    test('Client tritt bei und erscheint in der Lobby', () async {
      final client = ClientSession();
      addTearDown(client.close);

      final firstLobbyUpdate = client.lobbyUpdates.first;
      await client.connect('127.0.0.1', host.port, name: 'Ben');
      final lobby = await firstLobbyUpdate;

      expect(
        lobby.players.map((p) => p.name),
        containsAll(['Host-Anna', 'Ben']),
      );
      expect(host.lobbyPlayers.length, 2);
    });

    test('Spielstart verteilt zugeschnittenen Zustand an den Client', () async {
      final client = ClientSession();
      addTearDown(client.close);

      final stateFuture = client.stateUpdates.first;
      await client.connect('127.0.0.1', host.port, name: 'Ben');

      final game = host.startGame();
      final snapshot = await stateFuture;

      expect(snapshot.yourPlayerIndex, 1);
      expect(snapshot.players.length, 2);
      // Eigene Hand ist sichtbar ...
      expect(snapshot.players[1].hand, isNotNull);
      expect(snapshot.players[1].hand!.length, 6);
      // ... die des Hosts nicht (nur die Anzahl).
      expect(snapshot.players[0].hand, isNull);
      expect(snapshot.players[0].handCount, 6);
      expect(game.players.length, 2);
    });

    test('Der letzte Snapshot bleibt für neue Listener verfügbar', () async {
      final client = ClientSession();
      addTearDown(client.close);

      await client.connect('127.0.0.1', host.port, name: 'Ben');
      host.startGame();

      final snapshot = await client.stateUpdates.first;
      expect(snapshot.yourPlayerIndex, 1);
      expect(client.latestSnapshot, isNotNull);
      expect(client.latestSnapshot!.players[1].hand, isNotNull);
    });

    test(
      'Zug des Clients wird über die Engine validiert und an alle verteilt',
      () async {
        final client = ClientSession();
        addTearDown(client.close);

        await client.connect('127.0.0.1', host.port, name: 'Ben');
        final firstState = client.stateUpdates.first;
        final game = host.startGame();
        await firstState; // Initialverteilung abwarten (Inhalt hier egal).

        // Deterministische Ausgangslage erzwingen, unabhängig von der
        // zufälligen Starthand/Startspieler-Ermittlung.
        game.currentPlayerIndex = 1;
        game.players[1].hand = [const Tile(TileColor.red, TileShape.circle)];

        final updated = client.stateUpdates.first;
        client.sendMove([
          const TilePlacement(
            position: Position(0, 0),
            tile: Tile(TileColor.red, TileShape.circle),
          ),
        ]);
        final afterMove = await updated;

        expect(afterMove.board.length, 1);
        expect(afterMove.currentPlayerIndex, 0);
        expect(game.players[1].score, greaterThan(0));
      },
    );

    test(
      'Zug außerhalb der Reihe liefert eine Fehlermeldung statt Zustandsänderung',
      () async {
        final client = ClientSession();
        addTearDown(client.close);

        await client.connect('127.0.0.1', host.port, name: 'Ben');
        final firstState = client.stateUpdates.first;
        final game = host.startGame();
        await firstState;

        game.currentPlayerIndex = 0; // Host ist am Zug, nicht der Client.

        final errorFuture = client.errors.first;
        client.sendMove([
          const TilePlacement(
            position: Position(0, 0),
            tile: Tile(TileColor.red, TileShape.circle),
          ),
        ]);
        final error = await errorFuture;

        expect(error, contains('nicht am Zug'));
        expect(game.board.isEmpty, isTrue);
      },
    );

    test('Host kann eine Partie neu starten und der Client bekommt einen neuen Snapshot', () async {
      final client = ClientSession();
      addTearDown(client.close);

      await client.connect('127.0.0.1', host.port, name: 'Ben');
      final firstState = client.stateUpdates.first;
      host.startGame();
      await firstState;

      final restartedSnapshotFuture = client.stateUpdates.first;
      host.restartGame();
      final restartedSnapshot = await restartedSnapshotFuture;

      expect(restartedSnapshot.yourPlayerIndex, 1);
      expect(restartedSnapshot.players.length, 2);
      expect(restartedSnapshot.isOver, isFalse);
      expect(restartedSnapshot.board.isEmpty, isTrue);
    });
  });
}
