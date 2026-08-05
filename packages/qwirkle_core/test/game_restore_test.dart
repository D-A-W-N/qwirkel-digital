import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('QwirkleGame.restore', () {
    test('übernimmt Board, Hände, Punkte und Zugreihenfolge unverändert', () {
      final annaHand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
      ];
      final benHand = [const Tile(TileColor.blue, TileShape.star)];
      final remainingBag = [
        const Tile(TileColor.green, TileShape.clover),
        const Tile(TileColor.purple, TileShape.square),
      ];

      final anna = Player(id: 'a', name: 'Anna', hand: annaHand, score: 12);
      final ben = Player(id: 'b', name: 'Ben', hand: benHand, score: 7);

      final restored = QwirkleGame.restore(
        players: [anna, ben],
        bag: TileBag.fromTiles(remainingBag),
        currentPlayerIndex: 1,
        isOver: false,
        consecutivePasses: 1,
      );
      restored.board.apply([
        const TilePlacement(
          position: Position(0, 0),
          tile: Tile(TileColor.red, TileShape.circle),
        ),
      ]);

      expect(restored.players, [anna, ben]);
      expect(restored.players[0].hand, annaHand);
      expect(restored.players[0].score, 12);
      expect(restored.players[1].score, 7);
      expect(restored.currentPlayerIndex, 1);
      expect(restored.currentPlayer, ben);
      expect(restored.isOver, isFalse);
      expect(restored.bag.remaining, remainingBag.length);
      expect(
        restored.board.tileAt(const Position(0, 0)),
        const Tile(TileColor.red, TileShape.circle),
      );
    });

    test('konsekutive Pässe werden übernommen und beenden die Partie korrekt', () {
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');

      final restored = QwirkleGame.restore(
        players: [anna, ben],
        bag: TileBag.fromTiles(const []),
        currentPlayerIndex: 0,
        isOver: false,
        consecutivePasses: 1,
      );

      // Ein weiterer Pass (insgesamt 2 = players.length) muss die Partie beenden.
      restored.passTurn();

      expect(restored.isOver, isTrue);
    });

    test('nach dem Restore lässt sich die Partie normal fortsetzen', () {
      final anna = Player(
        id: 'a',
        name: 'Anna',
        hand: [const Tile(TileColor.red, TileShape.circle)],
      );
      final ben = Player(id: 'b', name: 'Ben');
      // Nachschub-Stein, damit Annas Hand nach dem Zug NICHT leer bleibt und
      // die Partie dadurch nicht sofort endet.
      final refill = [const Tile(TileColor.blue, TileShape.star)];

      final restored = QwirkleGame.restore(
        players: [anna, ben],
        bag: TileBag.fromTiles(refill),
        currentPlayerIndex: 0,
        isOver: false,
      );

      final score = restored.playTiles([
        const TilePlacement(
          position: Position(0, 0),
          tile: Tile(TileColor.red, TileShape.circle),
        ),
      ]);

      expect(score, 1); // isolierter erster Stein der Partie
      expect(anna.hand, refill);
      expect(restored.isOver, isFalse);
      expect(restored.currentPlayerIndex, 1);
      expect(restored.currentPlayer, ben);
    });
  });
}
