import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'update_models.dart';

/// Applies a previously-checked update: downloads it, verifies it, extracts
/// it, and on explicit confirmation swaps it into place and relaunches the
/// app. Implemented per-platform (macOS/Linux/Windows);
/// [update_controller.dart] depends only on this interface so it can be
/// tested with a fake.
abstract class UpdateApplier {
  Future<void> prepare({
    required ReleaseAsset asset,
    required ReleaseAsset checksumAsset,
    required void Function(double progress) onProgress,
  });

  /// Swaps the prepared update into place and relaunches the app. On
  /// success this does not return — the process exits.
  Future<void> confirmApply();

  /// Removes a stale `.bak` sibling left over from a previous update, if
  /// any. Safe to call unconditionally early at startup: its presence is
  /// exactly the proof that the current process is a successfully-booted
  /// post-update relaunch.
  Future<void> cleanupStaleBackup();
}

class UpdateApplyException implements Exception {
  UpdateApplyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads [asset] to a file placed next to [installPath] (same
/// filesystem, so the later rename-swap is atomic rather than a cross-volume
/// copy), reporting progress via [onProgress] when the response provides a
/// content length.
Future<File> downloadAssetNextTo({
  required String installPath,
  required ReleaseAsset asset,
  required http.Client client,
  required void Function(double progress) onProgress,
}) async {
  final parent = File(installPath).parent;
  final target = File('${parent.path}/.qwirkle-update-download');
  if (await target.exists()) {
    await target.delete();
  }

  final request = http.Request('GET', Uri.parse(asset.downloadUrl));
  final response = await client.send(request);
  if (response.statusCode != 200) {
    throw UpdateApplyException(
      'Download fehlgeschlagen (${response.statusCode}).',
    );
  }

  final total = response.contentLength;
  var received = 0;
  final sink = target.openWrite();
  try {
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total != null && total > 0) {
        onProgress(received / total);
      }
    }
  } finally {
    await sink.close();
  }
  return target;
}

/// Fetches a small `.sha256` sidecar file and returns the hex digest it
/// contains (the CI-generated format is `<hex>  <filename>`).
Future<String> fetchChecksumHex({
  required ReleaseAsset checksumAsset,
  required http.Client client,
}) async {
  final response = await client.get(Uri.parse(checksumAsset.downloadUrl));
  if (response.statusCode != 200) {
    throw UpdateApplyException(
      'Prüfsumme konnte nicht geladen werden (${response.statusCode}).',
    );
  }
  final text = utf8.decode(response.bodyBytes).trim();
  final hex = text.split(RegExp(r'\s+')).first;
  return hex.toLowerCase();
}

Future<void> verifyChecksum({
  required File file,
  required String expectedHex,
}) async {
  final digest = await sha256.bind(file.openRead()).first;
  final actualHex = digest.toString().toLowerCase();
  if (actualHex != expectedHex.toLowerCase()) {
    throw UpdateApplyException('Prüfsumme stimmt nicht überein.');
  }
}

/// Renames [from] to [to], retrying a few times with a short backoff — a
/// freshly-placed bundle can transiently be touched by Spotlight/file
/// indexing right after extraction.
Future<void> retryingRename(String from, String to) async {
  const attempts = 3;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      await Directory(from).rename(to);
      return;
    } on FileSystemException {
      if (attempt == attempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
    }
  }
}

Future<void> makeExecutable(String path) async {
  final result = await Process.run('chmod', ['+x', path]);
  if (result.exitCode != 0) {
    throw UpdateApplyException('Konnte Programmdatei nicht ausführbar machen.');
  }
}
