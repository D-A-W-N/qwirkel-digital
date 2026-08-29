import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/widgets/tile_view.dart';

void main() {
  const tile = Tile(TileColor.red, TileShape.circle);

  Color backgroundColorOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(TileView),
        matching: find.byType(Container),
      ),
    );
    return (container.decoration as BoxDecoration).color!;
  }

  testWidgets(
    'Der Kachel-Hintergrund unterscheidet sich zwischen Hell- und Dunkelmodus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(body: TileView(tile: tile)),
        ),
      );
      // `MaterialApp` animiert Theme-Wechsel implizit (`AnimatedTheme`) -
      // ohne `pumpAndSettle` läse man einen Zwischenwert der Überblendung
      // statt des endgültigen Farbtons.
      await tester.pumpAndSettle();
      final lightColor = backgroundColorOf(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(body: TileView(tile: tile)),
        ),
      );
      await tester.pumpAndSettle();
      final darkColor = backgroundColorOf(tester);

      // Vorher war der Hintergrund ein hartcodiertes Literal, unabhängig vom
      // Theme - in beiden Modi identisch. Jetzt kommt er aus dem
      // `ColorScheme`, muss sich also zwischen Hell- und Dunkelmodus
      // unterscheiden.
      expect(lightColor, isNot(equals(darkColor)));
    },
  );
}
