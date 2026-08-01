import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('Tile', () {
    test('gleiche Farbe/Symbol sind gleich (Wert-Gleichheit)', () {
      expect(
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.circle),
      );
    });

    test('unterschiedliche Steine sind ungleich', () {
      expect(
        const Tile(TileColor.red, TileShape.circle),
        isNot(const Tile(TileColor.red, TileShape.cross)),
      );
    });

    test('sharesAttributeWith erkennt gemeinsame Farbe oder Symbol', () {
      const a = Tile(TileColor.red, TileShape.circle);
      const b = Tile(TileColor.red, TileShape.cross);
      const c = Tile(TileColor.blue, TileShape.circle);
      const d = Tile(TileColor.blue, TileShape.cross);
      expect(a.sharesAttributeWith(b), isTrue);
      expect(a.sharesAttributeWith(c), isTrue);
      expect(a.sharesAttributeWith(d), isFalse);
    });
  });
}
