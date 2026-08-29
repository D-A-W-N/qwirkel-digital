import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/onboarding/onboarding_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingPrefs', () {
    test('hasSeenOnboarding is false until markSeen is called', () async {
      final prefs = OnboardingPrefs();

      expect(await prefs.hasSeenOnboarding(), isFalse);

      await prefs.markSeen();

      expect(await prefs.hasSeenOnboarding(), isTrue);
    });
  });
}
