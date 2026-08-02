import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'update_applier.dart';
import 'update_models.dart';

/// Quotes [value] as a PowerShell single-quoted string literal.
String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

/// Helper script that performs the actual swap after this process has
/// exited. Windows locks files opened by a running process, so unlike
/// macOS/Linux the running bundle cannot simply be renamed away — instead a
/// detached PowerShell process waits for the app to exit, copies the
/// extracted update over the install directory, and relaunches the app.
const _applyScript = r'''
param(
  [int]$ProcessId,
  [string]$SourceDir,
  [string]$TargetDir,
  [string]$ExeName
)
try { Wait-Process -Id $ProcessId -Timeout 30 -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 500
Copy-Item -Path (Join-Path $SourceDir '*') -Destination $TargetDir -Recurse -Force
Start-Process -FilePath (Join-Path $TargetDir $ExeName) -WorkingDirectory $TargetDir
Remove-Item -Path $SourceDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
''';

class WindowsUpdateApplier implements UpdateApplier {
  WindowsUpdateApplier(this._client);

  final http.Client _client;

  late String _bundleDir;
  late String _exeName;

  String get _extractDirPath =>
      p.join(p.dirname(_bundleDir), '.qwirkle-update-extract');

  @override
  Future<void> prepare({
    required ReleaseAsset asset,
    required ReleaseAsset checksumAsset,
    required void Function(double progress) onProgress,
  }) async {
    _bundleDir = p.dirname(Platform.resolvedExecutable);
    _exeName = p.basename(Platform.resolvedExecutable);

    final zip = await downloadAssetNextTo(
      installPath: _bundleDir,
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

    // Expand-Archive ships with PowerShell 5.0+ (every Windows 10/11) —
    // native tooling, consistent with `ditto`/`tar` on the other platforms.
    // The Windows zip contains the bundle files directly, without a wrapper
    // folder (see Compress-Archive in .github/workflows/desktop-build.yml).
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      'Expand-Archive -LiteralPath ${_psQuote(zip.path)} '
          '-DestinationPath ${_psQuote(extractDir.path)} -Force',
    ]);
    if (result.exitCode != 0) {
      throw UpdateApplyException('Entpacken fehlgeschlagen: ${result.stderr}');
    }

    await zip.delete();
  }

  @override
  Future<void> confirmApply() async {
    final scriptFile = File(
      p.join(Directory.systemTemp.path, 'qwirkle-update-apply-$pid.ps1'),
    );
    await scriptFile.writeAsString(_applyScript);

    // -ExecutionPolicy Bypass applies to this one invocation only; without
    // it many default Windows installs refuse to run any script at all.
    //
    // Deliberately *not* ProcessStartMode.detached: verified on a real
    // Windows machine that powershell.exe launched fully detached (no
    // console at all) exits before running a single line of the script —
    // dart:io's DETACHED_PROCESS flag leaves PowerShell's console host
    // unable to initialize. ProcessStartMode.normal works and is enough:
    // unlike Unix, a Windows child process is not tied to its parent's
    // lifetime, so it keeps running after this process calls exit(0) below.
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      scriptFile.path,
      '-ProcessId',
      pid.toString(),
      '-SourceDir',
      _extractDirPath,
      '-TargetDir',
      _bundleDir,
      '-ExeName',
      _exeName,
    ], mode: ProcessStartMode.normal);
    exit(0);
  }

  @override
  Future<void> cleanupStaleBackup() async {
    // Called unconditionally at startup, independent of prepare() — must
    // locate the bundle itself rather than rely on _bundleDir, which is
    // only set once prepare() has actually run in this process. Unlike
    // macOS/Linux there is no `.bak` here (the swap copies over the install
    // directory instead of renaming it), so only a leftover extract dir can
    // remain, e.g. after a crash between extraction and applying.
    final bundleDir = p.dirname(Platform.resolvedExecutable);
    final extractDir = Directory(
      p.join(p.dirname(bundleDir), '.qwirkle-update-extract'),
    );
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
  }
}
