import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/common/human_readable_error.dart';

void main() {
  group('humanReadableError', () {
    test('strips the "Invalid argument(s): " boilerplate from ArgumentError', () {
      final error = ArgumentError('Bitte gib einen Namen ein.');
      expect(humanReadableError(error), 'Bitte gib einen Namen ein.');
    });

    test('uses the plain message of a StateError', () {
      final error = StateError('Das Spiel ist bereits beendet.');
      expect(humanReadableError(error), 'Das Spiel ist bereits beendet.');
    });

    test('maps SocketException to a friendly connectivity message', () {
      final error = const SocketException('Connection refused (errno 111)');
      expect(
        humanReadableError(error),
        contains('Internetverbindung'),
      );
    });

    test('maps TimeoutException to a friendly message', () {
      final error = TimeoutException('future not completed');
      expect(humanReadableError(error), contains('Zeitüberschreitung'));
    });

    test('maps FormatException to a friendly message', () {
      final error = const FormatException('Unexpected character');
      expect(humanReadableError(error), contains('Ungültige'));
    });

    test(
      'passes custom exceptions with an already-clean toString() through unchanged',
      () {
        expect(
          humanReadableError(_CustomException('Prüfsumme stimmt nicht überein.')),
          'Prüfsumme stimmt nicht überein.',
        );
      },
    );
  });
}

class _CustomException implements Exception {
  _CustomException(this.message);
  final String message;

  @override
  String toString() => message;
}
