import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qwirkle_digital/src/update/update_applier_android.dart';

// Same regression class as update_applier_test.dart's desktop appliers:
// cleanupStaleBackup() is called unconditionally on every app launch (see
// SetupScreen._runStartupUpdateFlow), independent of whether prepare() has
// ever run in this process. AndroidUpdateApplier has no `late` fields (it
// derives the cache path fresh via path_provider each time), but this guards
// against a future regression reintroducing that pattern.
void main() {
  test(
    'AndroidUpdateApplier.cleanupStaleBackup works without prepare() having run first',
    () async {
      final applier = AndroidUpdateApplier(http.Client());
      try {
        await applier.cleanupStaleBackup();
      } catch (e) {
        // path_provider has no platform channel implementation in a plain
        // `flutter test` run, so a MissingPluginException here is expected
        // and fine - this guards specifically against a LateInitializationError.
        expect(e.toString(), isNot(contains('LateInitializationError')));
      }
    },
  );
}
