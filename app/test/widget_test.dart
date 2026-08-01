// Rauchtest: Setup-Bildschirm lädt und startet ein lokales Spiel.

import 'package:flutter_test/flutter_test.dart';

import 'package:qwirkle_digital/main.dart';

void main() {
  testWidgets('Setup-Screen zeigt Spieleranzahl und Startknopf', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QwirkleApp());

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Spiel starten'), findsOneWidget);

    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Qwirkle · Beutel:'), findsOneWidget);
  });
}
