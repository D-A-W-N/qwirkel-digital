import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.animationsEnabled,
    required this.tipsEnabled,
  });

  final bool animationsEnabled;
  final bool tipsEnabled;

  AppSettings copyWith({bool? animationsEnabled, bool? tipsEnabled}) {
    return AppSettings(
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      tipsEnabled: tipsEnabled ?? this.tipsEnabled,
    );
  }

  static AppSettings defaults() {
    return const AppSettings(animationsEnabled: true, tipsEnabled: true);
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
  );
  if (ref.read(appSettingsProvider).animationsEnabled != settings.animationsEnabled ||
      ref.read(appSettingsProvider).tipsEnabled != settings.tipsEnabled) {
    ref.read(appSettingsProvider.notifier).state = settings;
  }
}

Future<void> saveAppSettings(AppSettings settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('animationsEnabled', settings.animationsEnabled);
  await prefs.setBool('tipsEnabled', settings.tipsEnabled);
}

Future<void> resetAppSettings(dynamic ref) async {
  final defaults = AppSettings.defaults();
  ref.read(appSettingsProvider.notifier).state = defaults;
  await saveAppSettings(defaults);
}
