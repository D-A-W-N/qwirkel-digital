import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_applier.dart';
import 'update_models.dart';

/// Muss exakt den Kanal-Namen treffen, den `MainActivity.kt`
/// (`configureFlutterEngine`) registriert.
const _updaterChannel = MethodChannel('com.streetkidz.qwirkle_digital/updater');

/// Android kann das eigene installierte Paket nicht wie die Desktop-
/// Plattformen per Datei-Swap ersetzen - stattdessen wird die
/// heruntergeladene APK an den System-Paketinstaller übergeben (über den
/// nativen MethodChannel), der die eigentliche Installation nach expliziter
/// Bestätigung der Person übernimmt.
class AndroidUpdateApplier implements UpdateApplier {
  AndroidUpdateApplier(this._client);

  final http.Client _client;

  late String _apkPath;

  Future<String> get _apkFilePath async =>
      p.join((await getTemporaryDirectory()).path, 'qwirkle-update.apk');

  @override
  Future<void> prepare({
    required ReleaseAsset asset,
    required ReleaseAsset checksumAsset,
    required void Function(double progress) onProgress,
  }) async {
    final cacheDir = await getTemporaryDirectory();

    final downloaded = await downloadAssetNextTo(
      installPath: p.join(cacheDir.path, 'placeholder'),
      asset: asset,
      client: _client,
      onProgress: onProgress,
    );

    final expectedHex = await fetchChecksumHex(
      checksumAsset: checksumAsset,
      client: _client,
    );
    await verifyChecksum(file: downloaded, expectedHex: expectedHex);

    // Der Installer-Intent verlangt (bzw. erwartet zuverlässig) eine
    // .apk-Dateiendung - der generische Download-Helfer legt die Datei
    // aber unter einem neutralen Namen ab.
    final targetPath = await _apkFilePath;
    if (await File(targetPath).exists()) {
      await File(targetPath).delete();
    }
    final renamed = await downloaded.rename(targetPath);
    _apkPath = renamed.path;
  }

  /// Übergibt die vorbereitete APK an den System-Paketinstaller (siehe
  /// `MainActivity.kt`). Kehrt zurück, sobald der Install-Intent gestartet
  /// wurde - anders als bei den Desktop-Appliern **kein** `exit(0)`: die
  /// eigentliche Installation läuft außerhalb dieses Prozesses im
  /// System-Dialog und erfordert eine explizite Bestätigung der Person.
  @override
  Future<void> confirmApply() async {
    try {
      await _updaterChannel.invokeMethod<void>('installApk', {
        'path': _apkPath,
      });
    } on PlatformException catch (e) {
      throw UpdateApplyException(
        e.message ?? 'Installation konnte nicht gestartet werden.',
      );
    }
  }

  @override
  Future<void> cleanupStaleBackup() async {
    // Kein Backup-Konzept wie bei Desktop (kein atomarer Swap) - nur eine
    // evtl. übrig gebliebene, nicht installierte APK aus einem vorherigen
    // Versuch aufräumen.
    final apkFile = File(await _apkFilePath);
    if (await apkFile.exists()) {
      await apkFile.delete();
    }
    final downloadFile = File(
      p.join((await getTemporaryDirectory()).path, '.qwirkle-update-download'),
    );
    if (await downloadFile.exists()) {
      await downloadFile.delete();
    }
  }
}
