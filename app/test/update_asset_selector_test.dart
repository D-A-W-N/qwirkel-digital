import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/update/update_asset_selector.dart';
import 'package:qwirkle_digital/src/update/update_models.dart';

GithubRelease _releaseWithAssets(List<String> names) {
  return GithubRelease(
    tagName: 'v0.4.0',
    htmlUrl: 'https://example.invalid/release',
    body: 'Notes',
    assets: [
      for (final name in names)
        ReleaseAsset(name: name, downloadUrl: 'https://example.invalid/$name'),
    ],
  );
}

void main() {
  group('selectAssetForPlatform', () {
    test('picks the macOS asset and its checksum sidecar', () {
      final release = _releaseWithAssets([
        'qwirkle-digital-macos.zip',
        'qwirkle-digital-macos.zip.sha256',
        'qwirkle-digital-linux.tar.gz',
        'qwirkle-digital-linux.tar.gz.sha256',
      ]);

      final selected = selectAssetForPlatform(release, UpdateTargetPlatform.macos);

      expect(selected, isNotNull);
      expect(selected!.asset.name, 'qwirkle-digital-macos.zip');
      expect(selected.checksumAsset.name, 'qwirkle-digital-macos.zip.sha256');
    });

    test('picks the Linux asset and its checksum sidecar', () {
      final release = _releaseWithAssets([
        'qwirkle-digital-macos.zip',
        'qwirkle-digital-macos.zip.sha256',
        'qwirkle-digital-linux.tar.gz',
        'qwirkle-digital-linux.tar.gz.sha256',
      ]);

      final selected = selectAssetForPlatform(release, UpdateTargetPlatform.linux);

      expect(selected, isNotNull);
      expect(selected!.asset.name, 'qwirkle-digital-linux.tar.gz');
      expect(selected.checksumAsset.name, 'qwirkle-digital-linux.tar.gz.sha256');
    });

    test('picks the Windows asset and its checksum sidecar', () {
      final release = _releaseWithAssets([
        'qwirkle-digital-windows.zip',
        'qwirkle-digital-windows.zip.sha256',
        'qwirkle-digital-linux.tar.gz',
        'qwirkle-digital-linux.tar.gz.sha256',
      ]);

      final selected = selectAssetForPlatform(release, UpdateTargetPlatform.windows);

      expect(selected, isNotNull);
      expect(selected!.asset.name, 'qwirkle-digital-windows.zip');
      expect(selected.checksumAsset.name, 'qwirkle-digital-windows.zip.sha256');
    });

    test('picks the Android asset and its checksum sidecar', () {
      final release = _releaseWithAssets([
        'qwirkle-digital-android.apk',
        'qwirkle-digital-android.apk.sha256',
        'qwirkle-digital-linux.tar.gz',
        'qwirkle-digital-linux.tar.gz.sha256',
      ]);

      final selected = selectAssetForPlatform(release, UpdateTargetPlatform.android);

      expect(selected, isNotNull);
      expect(selected!.asset.name, 'qwirkle-digital-android.apk');
      expect(selected.checksumAsset.name, 'qwirkle-digital-android.apk.sha256');
    });

    test('returns null for an unsupported platform', () {
      final release = _releaseWithAssets([
        'qwirkle-digital-macos.zip',
        'qwirkle-digital-macos.zip.sha256',
      ]);

      expect(
        selectAssetForPlatform(release, UpdateTargetPlatform.unsupported),
        isNull,
      );
    });

    test('returns null when the checksum sidecar is missing (pre-checksum release)', () {
      final release = _releaseWithAssets(['qwirkle-digital-macos.zip']);

      expect(selectAssetForPlatform(release, UpdateTargetPlatform.macos), isNull);
    });

    test('returns null when the platform asset itself is missing', () {
      final release = _releaseWithAssets([
        'qwirkle-digital-linux.tar.gz',
        'qwirkle-digital-linux.tar.gz.sha256',
      ]);

      expect(selectAssetForPlatform(release, UpdateTargetPlatform.macos), isNull);
    });
  });
}
