import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/update/version_comparator.dart';

void main() {
  group('isNewerVersion', () {
    test('newer tag counts as an update', () {
      expect(isNewerVersion('0.3.0', 'v0.4.0'), isTrue);
    });

    test('older tag does not count as an update', () {
      expect(isNewerVersion('0.3.0', 'v0.2.0'), isFalse);
    });

    test('equal version does not count as an update', () {
      expect(isNewerVersion('0.3.0', 'v0.3.0'), isFalse);
    });

    test('tag without leading v is handled', () {
      expect(isNewerVersion('0.3.0', '0.4.0'), isTrue);
    });

    test('malformed tag never counts as an update', () {
      expect(isNewerVersion('0.3.0', 'not-a-version'), isFalse);
    });
  });
}
