import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qwirkle_digital/src/update/github_release_client.dart';

void main() {
  group('GithubReleaseClient', () {
    test('parses a successful release response', () async {
      final client = MockClient((request) async {
        expect(request.headers['User-Agent'], isNotNull);
        return http.Response(
          '''
          {
            "tag_name": "v0.4.0",
            "html_url": "https://example.invalid/releases/v0.4.0",
            "body": "Notes",
            "assets": [
              {"name": "qwirkle-digital-macos.zip", "browser_download_url": "https://example.invalid/macos.zip"}
            ]
          }
          ''',
          200,
        );
      });

      final release = await GithubReleaseClient(client).fetchLatestRelease();

      expect(release.tagName, 'v0.4.0');
      expect(release.assets, hasLength(1));
      expect(release.assets.first.name, 'qwirkle-digital-macos.zip');
    });

    test('a non-200 status throws, never silently "up to date"', () async {
      final client = MockClient((request) async => http.Response('rate limited', 403));

      expect(
        () => GithubReleaseClient(client).fetchLatestRelease(),
        throwsA(isA<GithubReleaseException>()),
      );
    });

    test('malformed JSON throws', () async {
      final client = MockClient((request) async => http.Response('not json', 200));

      expect(
        () => GithubReleaseClient(client).fetchLatestRelease(),
        throwsA(isA<GithubReleaseException>()),
      );
    });

    test('404 (no releases yet) throws', () async {
      final client = MockClient((request) async => http.Response('not found', 404));

      expect(
        () => GithubReleaseClient(client).fetchLatestRelease(),
        throwsA(isA<GithubReleaseException>()),
      );
    });
  });
}
