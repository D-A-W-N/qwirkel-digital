import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wie lange die KI vor jedem Zug "nachdenkt", bevor sie ihn ausführt -
/// rein kosmetisch, damit der Zugwechsel für Mitspieler sichtbar bleibt.
enum BotSpeed {
  slow,
  normal,
  fast;

  Duration get turnDelay => switch (this) {
    BotSpeed.slow => const Duration(milliseconds: 1500),
    BotSpeed.normal => const Duration(milliseconds: 500),
    BotSpeed.fast => const Duration(milliseconds: 100),
  };

  String get label => switch (this) {
    BotSpeed.slow => 'Langsam',
    BotSpeed.normal => 'Normal',
    BotSpeed.fast => 'Schnell',
  };
}

class AppSettings {
  const AppSettings({
    required this.animationsEnabled,
    required this.tipsEnabled,
    required this.updateCheckEnabled,
    required this.botSpeed,
    required this.themeMode,
  });

  final bool animationsEnabled;
  final bool tipsEnabled;
  final bool updateCheckEnabled;
  final BotSpeed botSpeed;

  /// `system` (Standard) folgt der Geräteeinstellung; `light`/`dark`
  /// erzwingen ein festes Erscheinungsbild unabhängig davon.
  final ThemeMode themeMode;

  AppSettings copyWith({
    bool? animationsEnabled,
    bool? tipsEnabled,
    bool? updateCheckEnabled,
    BotSpeed? botSpeed,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      tipsEnabled: tipsEnabled ?? this.tipsEnabled,
      updateCheckEnabled: updateCheckEnabled ?? this.updateCheckEnabled,
      botSpeed: botSpeed ?? this.botSpeed,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  static AppSettings defaults() {
    return const AppSettings(
      animationsEnabled: true,
      tipsEnabled: true,
      updateCheckEnabled: true,
      botSpeed: BotSpeed.normal,
      themeMode: ThemeMode.system,
    );
  }
}

final appSettingsProvider = StateProvider<AppSettings>((ref) {
  return AppSettings.defaults();
});

Future<void> initializeAppSettings(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(
    animationsEnabled: prefs.getBool('animationsEnabled') ?? true,
    tipsEnabled: prefs.getBool('tipsEnabled') ?? true,
    updateCheckEnabled: prefs.getBool('updateCheckEnabled') ?? true,
    botSpeed: BotSpeed.values.firstWhere(
      (speed) => speed.name == prefs.getString('botSpeed'),
      orElse: () => BotSpeed.normal,
    ),
    themeMode: ThemeMode.values.firstWhere(
      (mode) => mode.name == prefs.getString('themeMode'),
      orElse: () => ThemeMode.system,
    ),
  );
  final current = ref.read(appSettingsProvider);
  if (current.animationsEnabled != settings.animationsEnabled ||
      current.tipsEnabled != settings.tipsEnabled ||
      current.updateCheckEnabled != settings.updateCheckEnabled ||
      current.botSpeed != settings.botSpeed ||
      current.themeMode != settings.themeMode) {
    ref.read(appSettingsProvider.notifier).state = settings;
  }
}

Future<void> saveAppSettings(AppSettings settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('animationsEnabled', settings.animationsEnabled);
  await prefs.setBool('tipsEnabled', settings.tipsEnabled);
  await prefs.setBool('updateCheckEnabled', settings.updateCheckEnabled);
  await prefs.setString('botSpeed', settings.botSpeed.name);
  await prefs.setString('themeMode', settings.themeMode.name);
}

Future<void> resetAppSettings(dynamic ref) async {
  final defaults = AppSettings.defaults();
  ref.read(appSettingsProvider.notifier).state = defaults;
  await saveAppSettings(defaults);
}
