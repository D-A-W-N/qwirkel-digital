import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/network_connection_config.dart';

void main() {
  group('NetworkConnectionConfig', () {
    test('normalisiert Namen und Port korrekt', () {
      final config = NetworkConnectionConfig(
        mode: 'lan',
        host: ' 127.0.0.1 ',
        port: '4040',
        name: '  Alice  ',
        signalingUrl: 'ws://example.test',
        inviteCode: 'room-1',
      );

      expect(config.effectiveName, 'Alice');
      expect(config.effectiveHost, '127.0.0.1');
      expect(config.effectivePort, 4040);
    });

    test('verwirft ungültige Ports', () {
      expect(
        () => NetworkConnectionConfig(
          mode: 'lan',
          host: 'localhost',
          port: 'abc',
          name: 'Bob',
          signalingUrl: 'ws://example.test',
          inviteCode: 'room-1',
        ),
        throwsArgumentError,
      );
    });
  });
}
