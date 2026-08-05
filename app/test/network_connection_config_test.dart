import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/network_connection_config.dart';

void main() {
  group('NetworkConnectionConfig', () {
    test('normalisiert Namen und Port korrekt', () {
      final config = NetworkConnectionConfig(
        mode: 'lan',
        isHosting: false,
        host: ' 127.0.0.1 ',
        port: '4040',
        name: '  Alice  ',
        serverUrl: 'ws://example.test',
        inviteCode: 'room-1',
      );

      expect(config.effectiveName, 'Alice');
      expect(config.effectiveHost, '127.0.0.1');
      expect(config.effectivePort, 4040);
      expect(config.isHosting, isFalse);
    });

    test('verwirft ungültige Ports', () {
      expect(
        () => NetworkConnectionConfig(
          mode: 'lan',
          isHosting: true,
          host: 'localhost',
          port: 'abc',
          name: 'Bob',
          serverUrl: 'ws://example.test',
          inviteCode: 'room-1',
        ),
        throwsArgumentError,
      );
    });
  });
}
