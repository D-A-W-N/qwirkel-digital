import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/game/widgets/board_geometry.dart';

void main() {
  group('BoardGeometry', () {
    test('bildet Weltkoordinaten über einen festen Ursprung ab', () {
      const geometry = BoardGeometry(64);

      expect(geometry.pixelX(0), (BoardGeometry.origin) * 64);
      expect(geometry.pixelY(0), (BoardGeometry.origin) * 64);
      expect(geometry.pixelX(5), (BoardGeometry.origin + 5) * 64);
      expect(geometry.pixelX(-5), (BoardGeometry.origin - 5) * 64);
    });
  });
}
