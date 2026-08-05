import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';
import 'package:test/test.dart';

void main() {
  group('Raum-Persistenz-Roundtrip', () {
    test('Lobby-Raum (noch keine Partie) überlebt Serialisierung 1:1', () {
      final room = RoomSession(roomCode: 'ABCDE');
      room.seats.addAll([
        RoomSeat(
          playerId: 'p1',
          reconnectToken: 'token-anna',
          name: 'Anna',
          isOwner: true,
        ),
        RoomSeat(
          playerId: 'p2',
          reconnectToken: 'token-ben',
          name: 'Ben',
          isOwner: false,
        ),
      ]);

      final restored = roomSessionFromJson(roomSessionToJson(room));

      expect(restored.roomCode, 'ABCDE');
      expect(restored.isGameStarted, isFalse);
      expect(restored.seats.map((s) => s.playerId), ['p1', 'p2']);
      expect(restored.seats[0].isOwner, isTrue);
      expect(restored.seats[0].connected, isFalse);
      expect(restored.seats[1].reconnectToken, 'token-ben');
    });

    test(
      'Laufende Partie (Board/Bag/Hände/Punkte/Zugreihenfolge) überlebt Serialisierung',
      () {
        final room = RoomSession(roomCode: 'FGHJK');
        room.seats.addAll([
          RoomSeat(
            playerId: 'p1',
            reconnectToken: 'token-anna',
            name: 'Anna',
            isOwner: true,
            playerIndex: 0,
          ),
          RoomSeat(
            playerId: 'p2',
            reconnectToken: 'token-ben',
            name: 'Ben',
            isOwner: false,
            playerIndex: 1,
          ),
        ]);

        final anna = Player(
          id: 'p1',
          name: 'Anna',
          hand: [const Tile(TileColor.red, TileShape.circle)],
          score: 4,
        );
        final ben = Player(
          id: 'p2',
          name: 'Ben',
          hand: [const Tile(TileColor.blue, TileShape.star)],
          score: 9,
        );
        final remainingBag = [const Tile(TileColor.green, TileShape.clover)];
        final game = QwirkleGame.restore(
          players: [anna, ben],
          bag: TileBag.fromTiles(remainingBag),
          currentPlayerIndex: 1,
          isOver: false,
          consecutivePasses: 1,
        );
        game.board.apply([
          const TilePlacement(
            position: Position(0, 0),
            tile: Tile(TileColor.red, TileShape.circle),
          ),
        ]);
        // room.game ist read-only von außen - über den persistierten Zustand
        // selbst gesetzt, exakt der Weg, den `qwirkle_server` beim
        // Wiederaufbau aus einer JSON-Datei nutzt.
        final json = {
          'roomCode': room.roomCode,
          'lastActivity': room.lastActivity.toIso8601String(),
          'seats': [
            for (final s in room.seats)
              {
                'playerId': s.playerId,
                'reconnectToken': s.reconnectToken,
                'name': s.name,
                'isOwner': s.isOwner,
                'playerIndex': s.playerIndex,
              },
          ],
          'game': {
            'board': placementsToJson([
              for (final entry in game.board.cells.entries)
                TilePlacement(position: entry.key, tile: entry.value),
            ]),
            'bagTiles': tilesToJson(game.bag.tiles),
            'players': [
              for (final p in game.players)
                {
                  'id': p.id,
                  'name': p.name,
                  'score': p.score,
                  'hand': tilesToJson(p.hand),
                },
            ],
            'currentPlayerIndex': game.currentPlayerIndex,
            'isOver': game.isOver,
            'consecutivePasses': game.consecutivePasses,
          },
        };

        final restored = roomSessionFromJson(json);

        expect(restored.isGameStarted, isTrue);
        final restoredGame = restored.game!;
        expect(restoredGame.currentPlayerIndex, 1);
        expect(restoredGame.consecutivePasses, 1);
        expect(restoredGame.bag.remaining, 1);
        expect(
          restoredGame.board.tileAt(const Position(0, 0)),
          const Tile(TileColor.red, TileShape.circle),
        );
        expect(restoredGame.players[0].score, 4);
        expect(restoredGame.players[1].score, 9);
        expect(restoredGame.players[1].hand, [
          const Tile(TileColor.blue, TileShape.star),
        ]);

        // Die wiederhergestellte Partie lässt sich normal fortsetzen.
        expect(restoredGame.passTurn, returnsNormally);
      },
    );

    test('roomSessionToJson/roomSessionFromJson-Roundtrip einer laufenden Partie', () {
      final room = RoomSession(roomCode: 'LMNPQ');
      room.seats.addAll([
        RoomSeat(
          playerId: 'p1',
          reconnectToken: 'token-anna',
          name: 'Anna',
          isOwner: true,
          playerIndex: 0,
        ),
        RoomSeat(
          playerId: 'p2',
          reconnectToken: 'token-ben',
          name: 'Ben',
          isOwner: false,
          playerIndex: 1,
        ),
      ]);

      // RoomSession über den normalen Weg (RoomManager-Handshake) zu
      // starten würde echte Transporte brauchen; für einen reinen
      // Persistenz-Roundtrip genügt es, direkt über `roomSessionFromJson`
      // eine äquivalente Instanz mit eingebetteter Partie aufzubauen und
      // DIE dann zu serialisieren.
      final anna = Player(id: 'p1', name: 'Anna', score: 3);
      final ben = Player(id: 'p2', name: 'Ben', score: 5);
      final startedRoom = roomSessionFromJson({
        'roomCode': room.roomCode,
        'lastActivity': room.lastActivity.toIso8601String(),
        'seats': [
          for (final s in room.seats)
            {
              'playerId': s.playerId,
              'reconnectToken': s.reconnectToken,
              'name': s.name,
              'isOwner': s.isOwner,
              'playerIndex': s.playerIndex,
            },
        ],
        'game': {
          'board': <Map<String, dynamic>>[],
          'bagTiles': tilesToJson(TileBag.standard().tiles),
          'players': [
            {'id': anna.id, 'name': anna.name, 'score': anna.score, 'hand': <Map<String, dynamic>>[]},
            {'id': ben.id, 'name': ben.name, 'score': ben.score, 'hand': <Map<String, dynamic>>[]},
          ],
          'currentPlayerIndex': 0,
          'isOver': false,
          'consecutivePasses': 0,
        },
      });

      final roundTripped = roomSessionFromJson(roomSessionToJson(startedRoom));

      expect(roundTripped.roomCode, 'LMNPQ');
      expect(roundTripped.game!.players.map((p) => p.score), [3, 5]);
      expect(roundTripped.seats.map((s) => s.isOwner), [true, false]);
    });
  });
}
