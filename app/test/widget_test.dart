// Rauchtest: Setup-Bildschirm lädt und startet ein lokales Spiel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qwirkle_digital/main.dart';

void main() {
  testWidgets('Setup-Screen zeigt Spieleranzahl und Startknopf', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: QwirkleApp()));

    expect(find.text('2'), findsOneWidget);
    final startButton = find.text('Spiel starten');
    expect(startButton, findsOneWidget);

    expect(tester.takeException(), isNull);

    await tester.ensureVisible(startButton);
    await tester.tap(startButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Qwirkle · Beutel:'), findsOneWidget);
  });
}
