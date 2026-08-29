import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/profile/player_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PlayerProfile startet mit leerem Anzeigenamen', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(playerProfileProvider).displayName, isEmpty);
  });

  test('update setzt den Anzeigenamen', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(playerProfileProvider.notifier)
        .update(const PlayerProfile(displayName: 'Anna'));

    expect(container.read(playerProfileProvider).displayName, 'Anna');
  });

  test(
    'savePlayerProfile persistiert den Namen über SharedPreferences',
    () async {
      await savePlayerProfile(const PlayerProfile(displayName: 'Ben'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('playerProfile.displayName'), 'Ben');
    },
  );
}
