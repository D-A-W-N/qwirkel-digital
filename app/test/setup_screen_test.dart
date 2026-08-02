import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/setup/setup_screen.dart';
import 'package:qwirkle_digital/src/settings/app_settings.dart';

void main() {
  testWidgets('SetupScreen zeigt die Anleitung im Dialog an', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SetupScreen())),
    );

    await tester.tap(find.text('Anleitung'));
    await tester.pumpAndSettle();

    expect(find.text('Spielziel'), findsOneWidget);
    expect(find.text('Bilde Reihen aus Farben oder Formen.'), findsOneWidget);
  });

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
