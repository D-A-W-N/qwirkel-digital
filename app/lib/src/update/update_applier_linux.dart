import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'update_applier.dart';
import 'update_models.dart';

class LinuxUpdateApplier implements UpdateApplier {
  LinuxUpdateApplier(this._client);

  final http.Client _client;

  late String _bundleDir;
  late String _exeName;

  String get _backupPath => '$_bundleDir.bak';
  String get _extractDirPath => p.join(p.dirname(_bundleDir), '.qwirkle-update-extract');

  @override
  Future<void> prepare({
    required ReleaseAsset asset,
    required ReleaseAsset checksumAsset,
    required void Function(double progress) onProgress,
  }) async {
    _bundleDir = p.dirname(Platform.resolvedExecutable);
    _exeName = p.basename(Platform.resolvedExecutable);

    final tarball = await downloadAssetNextTo(
      installPath: _bundleDir,
      asset: asset,
      client: _client,
      onProgress: onProgress,
    );

    final expectedHex = await fetchChecksumHex(
      checksumAsset: checksumAsset,
      client: _client,
    );
    await verifyChecksum(file: tarball, expectedHex: expectedHex);

    final extractDir = Directory(_extractDirPath);
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    final result = await Process.run('tar', ['-xzf', tarball.path, '-C', extractDir.path]);
    if (result.exitCode != 0) {
      throw UpdateApplyException('Entpacken fehlgeschlagen: ${result.stderr}');
    }

    await makeExecutable(p.join(extractDir.path, _exeName));

    await tarball.delete();
  }

  @override
  Future<void> confirmApply() async {
    await retryingRename(_bundleDir, _backupPath);
    try {
      await retryingRename(_extractDirPath, _bundleDir);
    } catch (_) {
      await retryingRename(_backupPath, _bundleDir);
      rethrow;
    }

    final newExe = p.join(_bundleDir, _exeName);
    await Process.start(newExe, [], mode: ProcessStartMode.detached);
    exit(0);
  }

  @override
  Future<void> cleanupStaleBackup() async {
    // Called unconditionally at startup, independent of prepare() — must
    // locate the bundle itself rather than rely on _bundleDir, which is
    // only set once prepare() has actually run in this process.
    final bundleDir = p.dirname(Platform.resolvedExecutable);
    final backup = Directory('$bundleDir.bak');
    if (await backup.exists()) {
      await backup.delete(recursive: true);
    }
    final extractDir = Directory(
      p.join(p.dirname(bundleDir), '.qwirkle-update-extract'),
    );
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
  }
}
