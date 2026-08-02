import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/update/update_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UpdatePrefs', () {
    test('lastCheckedAt is null until markCheckedNow is called', () async {
      final prefs = UpdatePrefs();

      expect(await prefs.lastCheckedAt(), isNull);

      final before = DateTime.now();
      await prefs.markCheckedNow();
      final after = DateTime.now();

      final checkedAt = await prefs.lastCheckedAt();
      expect(checkedAt, isNotNull);
      expect(checkedAt!.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(checkedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('dismissedVersion round-trips', () async {
      final prefs = UpdatePrefs();

      expect(await prefs.dismissedVersion(), isNull);

      await prefs.dismissVersion('v0.4.0');

      expect(await prefs.dismissedVersion(), 'v0.4.0');
    });
  });
}
