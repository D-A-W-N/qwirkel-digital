import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('QwirkleGame', () {
    test('teilt Starthände aus und bestimmt den Startspieler', () {
      final benHand = [
        const Tile(TileColor.orange, TileShape.circle),
        const Tile(TileColor.orange, TileShape.cross),
        const Tile(TileColor.purple, TileShape.diamond),
        const Tile(TileColor.yellow, TileShape.square),
        const Tile(TileColor.green, TileShape.star),
        const Tile(TileColor.blue, TileShape.clover),
      ];
      final annaHand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
        const Tile(TileColor.red, TileShape.square),
        const Tile(TileColor.blue, TileShape.star),
        const Tile(TileColor.green, TileShape.clover),
      ];
      final bag = TileBag.fromTiles([...benHand, ...annaHand]);
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');

      final game = QwirkleGame(players: [anna, ben], bag: bag);

      expect(anna.hand, annaHand);
      expect(ben.hand, benHand);
      expect(game.currentPlayer, anna); // Anna hat die längere Reihe (4)
    });

    test('playTiles vergibt Punkte, zieht Nachschub und wechselt den Spieler',
        () {
      final annaHand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
        const Tile(TileColor.blue, TileShape.star),
        const Tile(TileColor.green, TileShape.clover),
        const Tile(TileColor.purple, TileShape.square),
      ];
      final benHand = [
        const Tile(TileColor.orange, TileShape.circle),
        const Tile(TileColor.orange, TileShape.cross),
        const Tile(TileColor.yellow, TileShape.diamond),
        const Tile(TileColor.yellow, TileShape.square),
        const Tile(TileColor.green, TileShape.star),
        const Tile(TileColor.blue, TileShape.clover),
      ];
      // Zusätzliche Nachschub-Steine, die nach dem Zug gezogen werden.
      final refill = [const Tile(TileColor.purple, TileShape.star)];
      final bag = TileBag.fromTiles([...refill, ...benHand, ...annaHand]);
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');

      final game = QwirkleGame(players: [anna, ben], bag: bag);
      expect(game.currentPlayer, anna);

      final placedTile = const Tile(TileColor.red, TileShape.circle);
      final score = game.playTiles(
        [TilePlacement(position: const Position(0, 0), tile: placedTile)],
      );

      expect(score, 1); // erster Zug, einzelner Stein
      expect(anna.score, 1);
      expect(anna.hand.contains(placedTile), isFalse);
      expect(anna.hand.length, 6); // Nachschub gezogen
      expect(anna.hand.contains(const Tile(TileColor.purple, TileShape.star)),
          isTrue);
      expect(game.currentPlayer, ben); // Zug gewechselt
    });

    test('letzter Stein bei leerem Beutel beendet das Spiel mit Bonus', () {
      final bag = TileBag.standard();
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben], bag: bag);

      // Simuliert den Spielendstand: Beutel leer, Anna hat nur noch 1 Stein
      // und ist am Zug.
      bag.draw(bag.remaining);
      anna.hand = [const Tile(TileColor.red, TileShape.circle)];
      game.currentPlayerIndex = 0;

      final score = game.playTiles([
        TilePlacement(
          position: const Position(0, 0),
          tile: const Tile(TileColor.red, TileShape.circle),
        ),
      ]);

      expect(score, 1 + 6); // 1 Punkt + 6 Bonus für leere Hand
      expect(anna.score, 7);
      expect(anna.hand, isEmpty);
      expect(game.isOver, isTrue);
    });

    test('exchangeTiles tauscht Steine und wechselt den Spieler', () {
      final annaHand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
        const Tile(TileColor.blue, TileShape.star),
        const Tile(TileColor.green, TileShape.clover),
        const Tile(TileColor.purple, TileShape.square),
      ];
      final benHand = [
        const Tile(TileColor.orange, TileShape.circle),
        const Tile(TileColor.orange, TileShape.cross),
        const Tile(TileColor.yellow, TileShape.diamond),
        const Tile(TileColor.yellow, TileShape.square),
        const Tile(TileColor.green, TileShape.star),
        const Tile(TileColor.blue, TileShape.clover),
      ];
      final extra = [const Tile(TileColor.purple, TileShape.star)];
      final bag = TileBag.fromTiles([...extra, ...benHand, ...annaHand]);
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben], bag: bag);

      final toExchange = [const Tile(TileColor.red, TileShape.circle)];
      game.exchangeTiles(toExchange);

      expect(anna.hand.contains(const Tile(TileColor.red, TileShape.circle)),
          isFalse);
      expect(anna.hand.length, 6);
      expect(anna.score, 0);
      expect(game.currentPlayer, ben);
      expect(bag.remaining, 1); // getauschter Stein zurück im Beutel
    });

    test('playTiles wirft, wenn der Spieler den Stein nicht besitzt', () {
      final annaHand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
        const Tile(TileColor.blue, TileShape.star),
        const Tile(TileColor.green, TileShape.clover),
        const Tile(TileColor.purple, TileShape.square),
      ];
      final benHand = [
        const Tile(TileColor.orange, TileShape.circle),
        const Tile(TileColor.orange, TileShape.cross),
        const Tile(TileColor.yellow, TileShape.diamond),
        const Tile(TileColor.yellow, TileShape.square),
        const Tile(TileColor.green, TileShape.star),
        const Tile(TileColor.blue, TileShape.clover),
      ];
      final bag = TileBag.fromTiles([...benHand, ...annaHand]);
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben], bag: bag);
      expect(game.currentPlayer, anna);

      // Ben's Farbe/Symbol-Kombination "yellow-diamond" ist nicht in Annas Hand.
      const foreignTile = Tile(TileColor.yellow, TileShape.diamond);
      expect(
        () => game.playTiles(
          [TilePlacement(position: const Position(0, 0), tile: foreignTile)],
        ),
        throwsArgumentError,
      );
    });
  });
}
