import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qwirkle_digital/src/update/update_applier.dart';
import 'package:qwirkle_digital/src/update/update_controller.dart';
import 'package:qwirkle_digital/src/update/update_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUpdateApplier implements UpdateApplier {
  bool prepareShouldThrow = false;
  bool prepareCalled = false;
  bool confirmApplyCalled = false;

  @override
  Future<void> prepare({
    required ReleaseAsset asset,
    required ReleaseAsset checksumAsset,
    required void Function(double progress) onProgress,
  }) async {
    prepareCalled = true;
    onProgress(0.5);
    onProgress(1.0);
    if (prepareShouldThrow) {
      throw UpdateApplyException('Entpacken fehlgeschlagen.');
    }
  }

  @override
  Future<void> confirmApply() async {
    confirmApplyCalled = true;
  }

  @override
  Future<void> cleanupStaleBackup() async {}
}

http.Client _clientReturningTag(String tagName, {int statusCode = 200}) {
  return MockClient((request) async {
    if (statusCode != 200) {
      return http.Response('error', statusCode);
    }
    return http.Response(
      '''
      {
        "tag_name": "$tagName",
        "html_url": "https://example.invalid/releases/$tagName",
        "body": "Notes for $tagName",
        "assets": [
          {"name": "qwirkle-digital-macos.zip", "browser_download_url": "https://example.invalid/macos.zip"},
          {"name": "qwirkle-digital-macos.zip.sha256", "browser_download_url": "https://example.invalid/macos.zip.sha256"},
          {"name": "qwirkle-digital-linux.tar.gz", "browser_download_url": "https://example.invalid/linux.tar.gz"},
          {"name": "qwirkle-digital-linux.tar.gz.sha256", "browser_download_url": "https://example.invalid/linux.tar.gz.sha256"},
          {"name": "qwirkle-digital-windows.zip", "browser_download_url": "https://example.invalid/windows.zip"},
          {"name": "qwirkle-digital-windows.zip.sha256", "browser_download_url": "https://example.invalid/windows.zip.sha256"}
        ]
      }
      ''',
      200,
    );
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Qwirkle Digital',
      packageName: 'digital.qwirkle',
      version: '0.3.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  ProviderContainer buildContainer({
    required http.Client client,
    required UpdateApplier applier,
  }) {
    final container = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(client),
        updateApplierProvider.overrideWithValue(applier),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('checkForUpdate transitions to available when a newer release exists', () async {
    final container = buildContainer(
      client: _clientReturningTag('v0.4.0'),
      applier: _FakeUpdateApplier(),
    );

    await container.read(updateControllerProvider.notifier).checkForUpdate();

    final state = container.read(updateControllerProvider);
    expect(state.phase, UpdatePhase.available);
    expect(state.currentVersion, '0.3.0');
    expect(state.latestVersion, 'v0.4.0');
  });

  test('checkForUpdate transitions to upToDate when already current', () async {
    final container = buildContainer(
      client: _clientReturningTag('v0.3.0'),
      applier: _FakeUpdateApplier(),
    );

    await container.read(updateControllerProvider.notifier).checkForUpdate();

    expect(container.read(updateControllerProvider).phase, UpdatePhase.upToDate);
  });

  test('checkForUpdate transitions to error on a failed request', () async {
    final container = buildContainer(
      client: _clientReturningTag('v0.4.0', statusCode: 500),
      applier: _FakeUpdateApplier(),
    );

    await container.read(updateControllerProvider.notifier).checkForUpdate();

    final state = container.read(updateControllerProvider);
    expect(state.phase, UpdatePhase.error);
    expect(state.errorMessage, isNotNull);
  });

  test('downloadAndPrepare moves to readyToRelaunch on success', () async {
    final applier = _FakeUpdateApplier();
    final container = buildContainer(
      client: _clientReturningTag('v0.4.0'),
      applier: applier,
    );
    final controller = container.read(updateControllerProvider.notifier);

    await controller.checkForUpdate();
    await controller.downloadAndPrepare();

    expect(applier.prepareCalled, isTrue);
    final state = container.read(updateControllerProvider);
    expect(state.phase, UpdatePhase.readyToRelaunch);
    expect(state.downloadProgress, 1.0);
  });

  test('downloadAndPrepare surfaces applier failures as an error state', () async {
    final applier = _FakeUpdateApplier()..prepareShouldThrow = true;
    final container = buildContainer(
      client: _clientReturningTag('v0.4.0'),
      applier: applier,
    );
    final controller = container.read(updateControllerProvider.notifier);

    await controller.checkForUpdate();
    await controller.downloadAndPrepare();

    final state = container.read(updateControllerProvider);
    expect(state.phase, UpdatePhase.error);
    expect(state.errorMessage, contains('Entpacken'));
  });

  test('dismiss persists the dismissed version and resets to idle', () async {
    final container = buildContainer(
      client: _clientReturningTag('v0.4.0'),
      applier: _FakeUpdateApplier(),
    );
    final controller = container.read(updateControllerProvider.notifier);

    await controller.checkForUpdate();
    await controller.dismiss();

    expect(container.read(updateControllerProvider).phase, UpdatePhase.idle);
    expect(await container.read(updatePrefsProvider).dismissedVersion(), 'v0.4.0');
  });
}
