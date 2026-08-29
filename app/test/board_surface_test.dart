import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/widgets/board_surface.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 800, child: child)),
);

void main() {
  group('BoardSurface', () {
    testWidgets(
      'rendert nur belegte Felder plus einen begrenzten Rand, nicht das '
      'volle Bounding-Rechteck - Zellenzahl bleibt bei weit '
      'auseinanderliegenden Steinen klein',
      (tester) async {
        // Zwei Steine 20 Felder auseinander (z. B. durch einen Brücken-Zug
        // erreichbar) - das alte Rechteck-Rendering hätte hier eine
        // ~24x5-Fläche (120 Zellen) gebaut, obwohl fast alles davon nie
        // ein gültiges Anlageziel sein kann.
        final board = {
          const Position(0, 0): const Tile(TileColor.red, TileShape.circle),
          const Position(0, 20): const Tile(TileColor.blue, TileShape.star),
        };

        await tester.pumpWidget(
          _wrap(
            BoardSurface(
              board: board,
              pendingPlacements: const {},
              canInteract: true,
              onDropTile: (_, _) {},
              onUnstage: (_) {},
              cellSize: 56,
              tileSize: 48,
            ),
          ),
        );

        final cellCount = find.byType(DragTarget<int>).evaluate().length;
        expect(
          cellCount,
          lessThan(40),
          reason:
              'Sollte deutlich unter der alten O(Bounding-Box)-Zellenzahl '
              'liegen (bei 20 Feldern Abstand: 24x5 = 120 Zellen).',
        );
      },
    );

    testWidgets(
      'ein leeres Brett zeigt den Ursprung als Anlageziel (plus '
      'kosmetischen Rand)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BoardSurface(
              board: const {},
              pendingPlacements: const {},
              canInteract: true,
              onDropTile: (_, _) {},
              onUnstage: (_) {},
              cellSize: 56,
              tileSize: 48,
            ),
          ),
        );

        // Ursprung (Ring 1, der einzige tatsächlich anlegbare Punkt beim
        // allerersten Zug) + dessen 4 Nachbarn (Ring 2, rein kosmetisch) =
        // 5 Zellen - kein leeres Einzelfeld ohne jeden visuellen Rahmen.
        expect(find.byType(DragTarget<int>).evaluate().length, 5);
      },
    );

    testWidgets(
      'jedes orthogonale Nachbarfeld eines Steins bleibt ein Drop-Ziel',
      (tester) async {
        final board = {
          const Position(0, 0): const Tile(TileColor.red, TileShape.circle),
        };

        await tester.pumpWidget(
          _wrap(
            BoardSurface(
              board: board,
              pendingPlacements: const {},
              canInteract: true,
              onDropTile: (_, _) {},
              onUnstage: (_) {},
              cellSize: 56,
              tileSize: 48,
            ),
          ),
        );

        // Alle 4 direkten Nachbarn müssen als Drop-Ziel existieren - das ist
        // die einzige Menge an Feldern, an der laut Spielregeln überhaupt
        // legal angelegt werden kann.
        expect(find.byType(DragTarget<int>).evaluate().length, greaterThanOrEqualTo(4));
      },
    );
  });
}
