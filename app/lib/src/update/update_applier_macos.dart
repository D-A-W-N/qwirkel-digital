import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'update_applier.dart';
import 'update_models.dart';

/// Locates the running `.app` bundle from the executable path:
/// `<bundle>.app/Contents/MacOS/<exe>` → walk up three parents.
String _locateBundlePath() {
  final exeDir = p.dirname(Platform.resolvedExecutable); // .../Contents/MacOS
  final contentsDir = p.dirname(exeDir); // .../Contents
  final bundlePath = p.dirname(contentsDir); // .../Name.app
  if (!bundlePath.endsWith('.app')) {
    throw UpdateApplyException('Konnte App-Bundle nicht finden.');
  }
  return bundlePath;
}

class MacosUpdateApplier implements UpdateApplier {
  MacosUpdateApplier(this._client);

  final http.Client _client;

  late String _bundlePath;
  late String _extractedBundlePath;

  String get _backupPath => '$_bundlePath.bak';
  String get _extractDirPath =>
      p.join(p.dirname(_bundlePath), '.qwirkle-update-extract');

  @override
  Future<void> prepare({
    required ReleaseAsset asset,
    required ReleaseAsset checksumAsset,
    required void Function(double progress) onProgress,
  }) async {
    _bundlePath = _locateBundlePath();

    final zip = await downloadAssetNextTo(
      installPath: _bundlePath,
      asset: asset,
      client: _client,
      onProgress: onProgress,
    );

    final expectedHex = await fetchChecksumHex(
      checksumAsset: checksumAsset,
      client: _client,
    );
    await verifyChecksum(file: zip, expectedHex: expectedHex);

    final extractDir = Directory(_extractDirPath);
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    final result = await Process.run('ditto', ['-x', '-k', zip.path, extractDir.path]);
    if (result.exitCode != 0) {
      throw UpdateApplyException('Entpacken fehlgeschlagen: ${result.stderr}');
    }

    final extractedApp = await extractDir
        .list()
        .firstWhere(
          (entity) => entity is Directory && entity.path.endsWith('.app'),
          orElse: () => throw UpdateApplyException(
            'Kein App-Bundle im heruntergeladenen Update gefunden.',
          ),
        );
    _extractedBundlePath = extractedApp.path;

    await makeExecutable(
      p.join(_extractedBundlePath, 'Contents', 'MacOS', p.basenameWithoutExtension(_extractedBundlePath)),
    );

    await zip.delete();
  }

  @override
  Future<void> confirmApply() async {
    await retryingRename(_bundlePath, _backupPath);
    try {
      await retryingRename(_extractedBundlePath, _bundlePath);
    } catch (_) {
      // Roll back: put the original bundle back so the install isn't left
      // in a broken state.
      await retryingRename(_backupPath, _bundlePath);
      rethrow;
    }

    await Process.start('open', ['-n', _bundlePath], mode: ProcessStartMode.detached);
    exit(0);
  }

  @override
  Future<void> cleanupStaleBackup() async {
    final backup = Directory(_backupPath);
    if (await backup.exists()) {
      await backup.delete(recursive: true);
    }
    final extractDir = Directory(_extractDirPath);
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
  }
}
