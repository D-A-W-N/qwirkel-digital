import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qwirkle_digital/src/setup/setup_screen.dart';

void main() {
  testWidgets('SetupScreen zeigt den Netzwerk-Startpunkt', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SetupScreen())),
    );

    // "Netzwerk spielen" liegt seit der Navigations-Umstrukturierung im
    // "Online"-Tab statt direkt auf dem Hauptbildschirm.
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();

    expect(find.text('Netzwerk spielen'), findsOneWidget);
  });
}
