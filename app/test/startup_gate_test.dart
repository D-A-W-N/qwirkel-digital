import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/onboarding/onboarding_prefs.dart';
import 'package:qwirkle_digital/src/onboarding/startup_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Zeigt beim allerersten Start das Onboarding, danach den SetupScreen',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StartupGate())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Willkommen bei Qwirkle Digital'), findsOneWidget);
      expect(find.text('Qwirkle · Spielmodus'), findsNothing);

      // Durch alle Seiten bis zum Abschluss tippen.
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Los geht's"));
      await tester.pumpAndSettle();

      expect(find.text('Qwirkle · Spielmodus'), findsOneWidget);
      expect(await OnboardingPrefs().hasSeenOnboarding(), isTrue);
    },
  );

  testWidgets(
    'Überspringt das Onboarding direkt zum SetupScreen, wenn es schon '
    'gesehen wurde',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StartupGate())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Qwirkle · Spielmodus'), findsOneWidget);
      expect(find.text('Willkommen bei Qwirkle Digital'), findsNothing);
    },
  );

  testWidgets('Überspringen-Button beendet das Onboarding sofort', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: StartupGate())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Überspringen'));
    await tester.pumpAndSettle();

    expect(find.text('Qwirkle · Spielmodus'), findsOneWidget);
  });
}
