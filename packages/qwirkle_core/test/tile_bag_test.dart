import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('TileBag', () {
    test('Standardbeutel enthält 108 Steine (6x6x3)', () {
      final bag = TileBag.standard();
      expect(bag.remaining, 108);
      expect(bag.isEmpty, isFalse);
    });

    test('jede Farbe/Symbol-Kombination kommt genau 3x vor', () {
      final bag = TileBag.standard();
      final drawn = bag.draw(108);
      final counts = <Tile, int>{};
      for (final tile in drawn) {
        counts[tile] = (counts[tile] ?? 0) + 1;
      }
      expect(counts.length, 36); // 6 Farben x 6 Symbole
      expect(counts.values.every((c) => c == 3), isTrue);
    });

    test('draw entfernt Steine aus dem Beutel', () {
      final bag = TileBag.standard();
      final hand = bag.draw(6);
      expect(hand.length, 6);
      expect(bag.remaining, 102);
    });

    test('draw liefert bei leerem Beutel weniger als angefragt', () {
      final bag = TileBag.standard();
      bag.draw(108);
      final rest = bag.draw(6);
      expect(rest, isEmpty);
      expect(bag.remaining, 0);
    });

    test('returnTiles legt Steine zurück in den Beutel', () {
      final bag = TileBag.standard();
      final hand = bag.draw(6);
      bag.returnTiles(hand);
      expect(bag.remaining, 108);
    });
  });
}
