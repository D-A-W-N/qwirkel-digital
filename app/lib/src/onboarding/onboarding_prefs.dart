import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Merkt sich, ob die Person das Einführungs-Intro (Onboarding) beim
/// allerersten App-Start schon gesehen hat - deliberately separate from
/// [AppSettings] (siehe `update_prefs.dart` für dasselbe Muster), da es sich
/// um internes Bookkeeping handelt, keinen von der Person änderbaren
/// Einstellungswert.
class OnboardingPrefs {
  static const _seenKey = 'onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}

final onboardingPrefsProvider = Provider<OnboardingPrefs>(
  (ref) => OnboardingPrefs(),
);
