import 'package:shared_preferences/shared_preferences.dart';

/// Internal bookkeeping for the updater (throttle timestamp, dismissed
/// version) — deliberately separate from [AppSettings], which only holds
/// user-facing toggles.
class UpdatePrefs {
  static const _lastCheckKey = 'update_lastCheckAtMillis';
  static const _dismissedVersionKey = 'update_dismissedVersion';

  Future<DateTime?> lastCheckedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastCheckKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> markCheckedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<String?> dismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissedVersionKey);
  }

  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }
}
