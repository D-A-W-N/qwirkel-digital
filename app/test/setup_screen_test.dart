import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/setup/setup_screen.dart';
import 'package:qwirkle_digital/src/settings/app_settings.dart';

void main() {
  testWidgets(
    'SetupScreen öffnet die Regeln-&-Hilfe-Seite mit Spielziel und Hausregeln',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.tap(find.text('Regeln & Hilfe'));
      await tester.pumpAndSettle();

      expect(find.text('Spielziel'), findsOneWidget);
      expect(
        find.text('Bilde Reihen aus Farben oder Formen.'),
        findsOneWidget,
      );
      expect(find.text('Hausregeln dieser App'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Startspieler:in'), 200);
      expect(find.text('Startspieler:in'), findsOneWidget);
    },
  );

  testWidgets(
    'Der Update-Bereich im Einstellungen-Sheet bleibt bei großer '
    'Systemschrift/kleinem Fenster erreichbar (scrollbar)',
    (tester) async {
      // Simuliert die Situation eines sehbehinderten Nutzers mit stark
      // vergrößerter Systemschrift auf einem eher kleinen Fenster - vorher
      // war das Sheet nicht scrollbar und der Update-Bereich (weit unten in
      // der Liste) dadurch weder sichtbar noch antippbar.
      // Breit genug, damit die (von diesem Fix unabhängigen) horizontalen
      // Zeilen der Spieler-Konfiguration bei größerer Schrift nicht
      // überlaufen - schmal in der Höhe ist hier der relevante Engpass.
      tester.view.physicalSize = const Size(1400, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const SetupScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Nach Updates suchen'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('settingsSheetScrollView')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Nach Updates suchen'), findsOneWidget);

      // Muss auch tatsächlich antippbar sein, nicht nur im Baum vorhanden.
      await tester.tap(find.text('Nach Updates suchen'));
      await tester.pump();
    },
  );

  test('App-Settings speichern Animations- und Tipps-Status', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appSettingsProvider).animationsEnabled, isTrue);
    expect(container.read(appSettingsProvider).tipsEnabled, isTrue);
    expect(container.read(appSettingsProvider).updateCheckEnabled, isTrue);
    expect(container.read(appSettingsProvider).botSpeed, BotSpeed.normal);

    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(animationsEnabled: false);
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(tipsEnabled: false);
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(updateCheckEnabled: false);
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(botSpeed: BotSpeed.fast);

    final settings = container.read(appSettingsProvider);
    expect(settings.animationsEnabled, isFalse);
    expect(settings.tipsEnabled, isFalse);
    expect(settings.updateCheckEnabled, isFalse);
    expect(settings.botSpeed, BotSpeed.fast);
  });

  test('App-Settings können auf Standardwerte zurückgesetzt werden', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(
          animationsEnabled: false,
          tipsEnabled: false,
          updateCheckEnabled: false,
          botSpeed: BotSpeed.slow,
        );

    try {
      await resetAppSettings(
        container,
      );
    } catch (error) {
      final settings = container.read(appSettingsProvider);
      expect(settings.animationsEnabled, isTrue);
      expect(settings.tipsEnabled, isTrue);
      expect(settings.updateCheckEnabled, isTrue);
      expect(settings.botSpeed, BotSpeed.normal);
      return;
    }

    final settings = container.read(appSettingsProvider);
    expect(settings.animationsEnabled, isTrue);
    expect(settings.tipsEnabled, isTrue);
    expect(settings.updateCheckEnabled, isTrue);
    expect(settings.botSpeed, BotSpeed.normal);
  });
}
