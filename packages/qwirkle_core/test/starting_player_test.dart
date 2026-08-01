import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('longestPossibleRun', () {
    test('leere Hand ergibt 0', () {
      expect(longestPossibleRun([]), 0);
    });

    test('4 unterschiedliche Symbole gleicher Farbe ergeben 4', () {
      final hand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
        const Tile(TileColor.red, TileShape.square),
        const Tile(TileColor.blue, TileShape.star),
        const Tile(TileColor.green, TileShape.clover),
      ];
      expect(longestPossibleRun(hand), 4);
    });

    test('erkennt auch die längste Symbol-Reihe (gleiche Form, versch. Farben)',
        () {
      final hand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.blue, TileShape.circle),
        const Tile(TileColor.green, TileShape.circle),
        const Tile(TileColor.yellow, TileShape.circle),
        const Tile(TileColor.purple, TileShape.circle),
        const Tile(TileColor.orange, TileShape.star),
      ];
      expect(longestPossibleRun(hand), 5);
    });
  });

  group('determineStartingPlayerIndex', () {
    test('Spieler mit der längsten Reihe beginnt', () {
      final a = Player(id: 'a', name: 'Anna', hand: [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
      ]);
      final b = Player(id: 'b', name: 'Ben', hand: [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
      ]);
      expect(determineStartingPlayerIndex([a, b]), 1);
    });

    test('bei Gleichstand entscheidet der tieBreaker', () {
      final a = Player(id: 'a', name: 'Anna', hand: [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
      ]);
      final b = Player(id: 'b', name: 'Ben', hand: [
        const Tile(TileColor.blue, TileShape.star),
        const Tile(TileColor.blue, TileShape.clover),
      ]);
      final ages = {'a': 30, 'b': 20};
      final index = determineStartingPlayerIndex(
        [a, b],
        tieBreaker: (p1, p2) => ages[p1.id]!.compareTo(ages[p2.id]!),
      );
      expect(index, 1); // Ben ist jünger
    });

    test('ohne tieBreaker gewinnt der erste Kandidat deterministisch', () {
      final a = Player(id: 'a', name: 'Anna', hand: [
        const Tile(TileColor.red, TileShape.circle),
      ]);
      final b = Player(id: 'b', name: 'Ben', hand: [
        const Tile(TileColor.blue, TileShape.star),
      ]);
      expect(determineStartingPlayerIndex([a, b]), 0);
    });
  });
}
