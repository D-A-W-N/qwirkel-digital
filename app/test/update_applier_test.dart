import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qwirkle_digital/src/update/update_applier_linux.dart';
import 'package:qwirkle_digital/src/update/update_applier_macos.dart';

// Regression test for a startup crash shipped in v0.3.0: cleanupStaleBackup()
// is called unconditionally on every app launch (see
// SetupScreen._runStartupUpdateFlow), independent of whether prepare() has
// ever run in this process. It used to read the `late` bundle-path field
// that prepare() sets, throwing LateInitializationError on every single
// startup. It must locate the bundle itself instead.
void main() {
  test(
    'MacosUpdateApplier.cleanupStaleBackup works without prepare() having run first',
    () async {
      final applier = MacosUpdateApplier(http.Client());
      try {
        await applier.cleanupStaleBackup();
      } catch (e) {
        // Any other exception (e.g. bundle path not resolvable in a test
        // environment) is fine — this guards specifically against the
        // LateInitializationError from reading an uninitialized field.
        expect(e.toString(), isNot(contains('LateInitializationError')));
      }
    },
  );

  test(
    'LinuxUpdateApplier.cleanupStaleBackup works without prepare() having run first',
    () async {
      final applier = LinuxUpdateApplier(http.Client());
      try {
        await applier.cleanupStaleBackup();
      } catch (e) {
        // See above.
        expect(e.toString(), isNot(contains('LateInitializationError')));
      }
    },
  );
}
