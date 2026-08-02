import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

TilePlacement _p(int x, int y, Tile tile) =>
    TilePlacement(position: Position(x, y), tile: tile);

void main() {
  group('Board.scorePlacement / apply', () {
    test('erster Zug: einzelner Stein zählt 1 Punkt', () {
      final board = Board();
      const tile = Tile(TileColor.red, TileShape.circle);
      final score = board.scorePlacement([_p(0, 0, tile)]);
      expect(score, 1);
    });

    test('erster Zug: Reihe aus 3 Steinen gleicher Farbe', () {
      final board = Board();
      final placements = [
        _p(0, 0, const Tile(TileColor.red, TileShape.circle)),
        _p(1, 0, const Tile(TileColor.red, TileShape.cross)),
        _p(2, 0, const Tile(TileColor.red, TileShape.diamond)),
      ];
      expect(board.scorePlacement(placements), 3);
      board.apply(placements);
      expect(
        board.tileAt(const Position(1, 0)),
        const Tile(TileColor.red, TileShape.cross),
      );
    });

    test('anschließender Zug verlängert die Reihe', () {
      final board = Board();
      board.apply([
        _p(0, 0, const Tile(TileColor.red, TileShape.circle)),
        _p(1, 0, const Tile(TileColor.red, TileShape.cross)),
        _p(2, 0, const Tile(TileColor.red, TileShape.diamond)),
      ]);
      final score = board.scorePlacement([
        _p(3, 0, const Tile(TileColor.red, TileShape.square)),
      ]);
      expect(score, 4); // gesamte Reihe (0,0)-(3,0)
    });

    test('einzelner Stein erzeugt zwei Reihen (horizontal + vertikal)', () {
      final board = Board();
      board.apply([
        _p(0, 0, const Tile(TileColor.red, TileShape.circle)),
        _p(1, 0, const Tile(TileColor.red, TileShape.cross)),
      ]);
      board.apply([_p(0, 1, const Tile(TileColor.blue, TileShape.circle))]);
      // Neuer Stein bei (1,1): teilt Symbol 'cross' mit (1,0) [vertikal]
      // und Farbe 'blue' mit (0,1) [horizontal].
      final score = board.scorePlacement([
        _p(1, 1, const Tile(TileColor.blue, TileShape.cross)),
      ]);
      expect(
        score,
        4,
      ); // 2 (horizontal: (0,1)+(1,1)) + 2 (vertikal: (1,0)+(1,1))
    });

    test('vollständige Reihe aus 6 Steinen gibt Qwirkle-Bonus', () {
      final board = Board();
      final placements = [
        _p(0, 0, const Tile(TileColor.green, TileShape.circle)),
        _p(1, 0, const Tile(TileColor.green, TileShape.cross)),
        _p(2, 0, const Tile(TileColor.green, TileShape.diamond)),
        _p(3, 0, const Tile(TileColor.green, TileShape.square)),
        _p(4, 0, const Tile(TileColor.green, TileShape.star)),
        _p(5, 0, const Tile(TileColor.green, TileShape.clover)),
      ];
      expect(board.scorePlacement(placements), 12); // 6 + 6 Bonus
    });

    test('wirft bei mehr als 6 Steinen pro Zug', () {
      final board = Board();
      final placements = [
        for (var i = 0; i < 7; i++)
          _p(i, 0, Tile(TileColor.red, TileShape.values[i % 6])),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.tooManyTiles,
          ),
        ),
      );
    });

    test('wirft bei Lücke innerhalb einer Reihe', () {
      final board = Board();
      final placements = [
        _p(0, 0, const Tile(TileColor.red, TileShape.circle)),
        _p(2, 0, const Tile(TileColor.red, TileShape.diamond)),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.gapInLine,
          ),
        ),
      );
    });

    test('wirft bei einer Mehrfachplatzierung mit Lücke in der neuen Reihe', () {
      final board = Board();
      board.apply([_p(0, 0, const Tile(TileColor.red, TileShape.circle))]);
      final placements = [
        _p(1, 0, const Tile(TileColor.red, TileShape.cross)),
        _p(3, 0, const Tile(TileColor.red, TileShape.diamond)),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.gapInLine,
          ),
        ),
      );
    });

    test('wirft bei Attributkonflikt (weder Farbe noch Symbol gleich)', () {
      final board = Board();
      final placements = [
        _p(0, 0, const Tile(TileColor.red, TileShape.circle)),
        _p(1, 0, const Tile(TileColor.blue, TileShape.cross)),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.attributeMismatch,
          ),
        ),
      );
    });

    test('wirft bei doppeltem Stein in derselben Reihe', () {
      final board = Board();
      board.apply([_p(0, 0, const Tile(TileColor.red, TileShape.circle))]);
      final placements = [
        _p(1, 0, const Tile(TileColor.red, TileShape.cross)),
        _p(2, 0, const Tile(TileColor.red, TileShape.circle)),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.duplicateTileInLine,
          ),
        ),
      );
    });

    test('wirft, wenn Zug nicht an vorhandene Steine angrenzt', () {
      final board = Board();
      board.apply([_p(0, 0, const Tile(TileColor.red, TileShape.circle))]);
      final placements = [_p(5, 5, const Tile(TileColor.blue, TileShape.star))];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.notConnected,
          ),
        ),
      );
    });

    test('wirft, wenn eine Reihe über 6 Steine hinaus verlängert würde', () {
      final board = Board();
      board.apply([
        _p(0, 0, const Tile(TileColor.green, TileShape.circle)),
        _p(1, 0, const Tile(TileColor.green, TileShape.cross)),
        _p(2, 0, const Tile(TileColor.green, TileShape.diamond)),
        _p(3, 0, const Tile(TileColor.green, TileShape.square)),
        _p(4, 0, const Tile(TileColor.green, TileShape.star)),
        _p(5, 0, const Tile(TileColor.green, TileShape.clover)),
      ]);
      // Es gibt keine 7. Form, aber Farbe wäre ohnehin ungültig -> lineTooLong
      // greift bereits vor der Attributprüfung.
      final placements = [
        _p(6, 0, const Tile(TileColor.green, TileShape.circle)),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.lineTooLong,
          ),
        ),
      );
    });

    test('wirft bei leerer Platzierung', () {
      final board = Board();
      expect(
        () => board.scorePlacement([]),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.emptyPlacement,
          ),
        ),
      );
    });

    test('wirft bei doppelt belegtem Feld im selben Zug', () {
      final board = Board();
      final placements = [
        _p(0, 0, const Tile(TileColor.red, TileShape.circle)),
        _p(0, 0, const Tile(TileColor.red, TileShape.cross)),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.duplicatePosition,
          ),
        ),
      );
    });

    test('wirft, wenn die Steine weder in einer Reihe noch einer Spalte liegen', () {
      final board = Board();
      final placements = [
        _p(0, 0, const Tile(TileColor.red, TileShape.circle)),
        _p(1, 1, const Tile(TileColor.red, TileShape.cross)),
      ];
      expect(
        () => board.scorePlacement(placements),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.notInLine,
          ),
        ),
      );
    });

    test(
      'Mehrfachplatzierung: jeder neue Stein wertet zusätzlich seine eigene Querreihe',
      () {
        final board = Board();
        board.apply([
          _p(0, -1, const Tile(TileColor.orange, TileShape.circle)),
          _p(1, -1, const Tile(TileColor.orange, TileShape.cross)),
        ]);
        final placements = [
          _p(0, 0, const Tile(TileColor.orange, TileShape.star)),
          _p(1, 0, const Tile(TileColor.orange, TileShape.diamond)),
        ];
        final score = board.scorePlacement(placements);
        // Hauptreihe horizontal (0,0)-(1,0): 2
        // + Querreihe bei x=0 ((0,-1)+(0,0)): 2
        // + Querreihe bei x=1 ((1,-1)+(1,0)): 2
        expect(score, 6);
      },
    );

    test('wirft bei belegtem Feld', () {
      final board = Board();
      board.apply([_p(0, 0, const Tile(TileColor.red, TileShape.circle))]);
      expect(
        () => board.scorePlacement([
          _p(0, 0, const Tile(TileColor.red, TileShape.cross)),
        ]),
        throwsA(
          isA<InvalidMoveException>().having(
            (e) => e.reason,
            'reason',
            InvalidMoveReason.positionOccupied,
          ),
        ),
      );
    });
  });
}
