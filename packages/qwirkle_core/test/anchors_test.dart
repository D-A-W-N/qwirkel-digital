import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('anchorPositions', () {
    test('ein leeres Brett hat nur den Ursprung als Anker', () {
      expect(anchorPositions(const []), {const Position(0, 0)});
    });

    test('ein einzelner Stein hat genau seine 4 Nachbarn als Anker', () {
      expect(
        anchorPositions(const [Position(0, 0)]),
        {
          const Position(1, 0),
          const Position(-1, 0),
          const Position(0, 1),
          const Position(0, -1),
        },
      );
    });

    test(
      'benachbarte belegte Felder zählen nicht als Anker des jeweils anderen',
      () {
        final anchors = anchorPositions(const [
          Position(0, 0),
          Position(1, 0),
        ]);

        expect(anchors.contains(const Position(0, 0)), isFalse);
        expect(anchors.contains(const Position(1, 0)), isFalse);
        expect(
          anchors,
          containsAll(const [
            Position(-1, 0),
            Position(0, 1),
            Position(0, -1),
            Position(2, 0),
            Position(1, 1),
            Position(1, -1),
          ]),
        );
      },
    );

    test(
      'zwei weit auseinanderliegende Cluster erzeugen keine Anker dazwischen',
      () {
        final anchors = anchorPositions(const [
          Position(0, 0),
          Position(0, 20),
        ]);

        expect(anchors.contains(const Position(0, 10)), isFalse);
        expect(anchors.length, 8);
      },
    );
  });
}
