import 'dart:async';
import 'dart:io';

import 'package:qwirkle_server/qwirkle_server.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionRateLimiter', () {
    test('erlaubt Versuche bis zum Limit', () {
      final limiter = ConnectionRateLimiter(
        maxAttempts: 3,
        window: const Duration(minutes: 1),
      );

      expect(limiter.allow('1.2.3.4'), isTrue);
      expect(limiter.allow('1.2.3.4'), isTrue);
      expect(limiter.allow('1.2.3.4'), isTrue);
    });

    test('lehnt Versuche über dem Limit innerhalb des Fensters ab', () {
      final limiter = ConnectionRateLimiter(
        maxAttempts: 2,
        window: const Duration(minutes: 1),
      );

      expect(limiter.allow('1.2.3.4'), isTrue);
      expect(limiter.allow('1.2.3.4'), isTrue);
      expect(limiter.allow('1.2.3.4'), isFalse);
      expect(limiter.allow('1.2.3.4'), isFalse);
    });

    test('behandelt verschiedene IPs unabhängig voneinander', () {
      final limiter = ConnectionRateLimiter(
        maxAttempts: 1,
        window: const Duration(minutes: 1),
      );

      expect(limiter.allow('1.1.1.1'), isTrue);
      expect(limiter.allow('1.1.1.1'), isFalse);
      expect(limiter.allow('2.2.2.2'), isTrue);
    });

    test(
      'erlaubt wieder Versuche, sobald das Fenster verstrichen ist',
      () async {
        final limiter = ConnectionRateLimiter(
          maxAttempts: 1,
          window: const Duration(milliseconds: 50),
        );

        expect(limiter.allow('1.2.3.4'), isTrue);
        expect(limiter.allow('1.2.3.4'), isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(limiter.allow('1.2.3.4'), isTrue);
      },
    );
  });

  group('clientIpOf', () {
    Future<HttpRequest> sendAndCapture({Map<String, String>? headers}) async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      addTearDown(server.close);
      final requestCompleter = Completer<HttpRequest>();
      server.listen((request) {
        requestCompleter.complete(request);
        request.response.close();
      });

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/'),
      );
      headers?.forEach(request.headers.set);
      final response = await request.close();
      await response.drain<void>();

      return requestCompleter.future;
    }

    test(
      'nutzt X-Forwarded-For, wenn gesetzt (Server hinter Reverse-Proxy)',
      () async {
        final request = await sendAndCapture(
          headers: {'X-Forwarded-For': '203.0.113.5, 10.0.0.1'},
        );

        expect(clientIpOf(request), '203.0.113.5');
      },
    );

    test('fällt ohne den Header auf die Socket-Adresse zurück', () async {
      final request = await sendAndCapture();

      expect(clientIpOf(request), '127.0.0.1');
    });
  });
}
