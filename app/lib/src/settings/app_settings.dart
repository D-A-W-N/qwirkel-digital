import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.animationsEnabled,
    required this.tipsEnabled,
    required this.updateCheckEnabled,
  });

  final bool animationsEnabled;
  final bool tipsEnabled;
  final bool updateCheckEnabled;

  AppSettings copyWith({
    bool? animationsEnabled,
    bool? tipsEnabled,
    bool? updateCheckEnabled,
  }) {
    return AppSettings(
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      tipsEnabled: tipsEnabled ?? this.tipsEnabled,
      updateCheckEnabled: updateCheckEnabled ?? this.updateCheckEnabled,
    );
  }

  static AppSettings defaults() {
    return const AppSettings(
      animationsEnabled: true,
      tipsEnabled: true,
      updateCheckEnabled: true,
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
  );
  final current = ref.read(appSettingsProvider);
  if (current.animationsEnabled != settings.animationsEnabled ||
      current.tipsEnabled != settings.tipsEnabled ||
      current.updateCheckEnabled != settings.updateCheckEnabled) {
    ref.read(appSettingsProvider.notifier).state = settings;
  }
}

Future<void> saveAppSettings(AppSettings settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('animationsEnabled', settings.animationsEnabled);
  await prefs.setBool('tipsEnabled', settings.tipsEnabled);
  await prefs.setBool('updateCheckEnabled', settings.updateCheckEnabled);
}

Future<void> resetAppSettings(dynamic ref) async {
  final defaults = AppSettings.defaults();
  ref.read(appSettingsProvider.notifier).state = defaults;
  await saveAppSettings(defaults);
}
