import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qwirkle_digital/src/setup/setup_screen.dart';

void main() {
  testWidgets('SetupScreen zeigt den Netzwerk-Startpunkt', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetupScreen()));

    expect(find.text('Netzwerk spielen'), findsOneWidget);
  });
}
