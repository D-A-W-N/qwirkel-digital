import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'github_release_client.dart';
import 'update_applier.dart';
import 'update_applier_android.dart';
import 'update_applier_linux.dart';
import 'update_applier_macos.dart';
import 'update_applier_windows.dart';
import 'update_asset_selector.dart';
import 'update_models.dart';
import 'update_prefs.dart';
import 'version_comparator.dart';

final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final githubReleaseClientProvider = Provider<GithubReleaseClient>((ref) {
  return GithubReleaseClient(ref.watch(httpClientProvider));
});

final updatePrefsProvider = Provider<UpdatePrefs>((ref) => UpdatePrefs());

/// Overridable in Tests, damit sie nicht vom tatsächlichen Host-Betriebs-
/// system abhängen (z. B. CI-Runner unter Windows, wo der Updater als
/// [UpdateTargetPlatform.unsupported] gilt).
final targetPlatformProvider = Provider<UpdateTargetPlatform>(
  (ref) => currentTargetPlatform(),
);

final updateApplierProvider = Provider<UpdateApplier>((ref) {
  final client = ref.watch(httpClientProvider);
  switch (ref.watch(targetPlatformProvider)) {
    case UpdateTargetPlatform.macos:
      return MacosUpdateApplier(client);
    case UpdateTargetPlatform.linux:
      return LinuxUpdateApplier(client);
    case UpdateTargetPlatform.windows:
      return WindowsUpdateApplier(client);
    case UpdateTargetPlatform.android:
      return AndroidUpdateApplier(client);
    case UpdateTargetPlatform.unsupported:
      return _UnsupportedUpdateApplier();
  }
});

final updateControllerProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);

class UpdateController extends Notifier<UpdateState> {
  SelectedUpdateAssets? _pendingAssets;

  @override
  UpdateState build() => UpdateState.idle;

  bool get _isInFlight =>
      state.phase == UpdatePhase.checking ||
      state.phase == UpdatePhase.downloading ||
      state.phase == UpdatePhase.applying;

  /// Checks GitHub for a newer release. Safe to call in any build mode —
  /// this only checks and (on confirmation) downloads/verifies; the
  /// destructive swap only ever happens via an explicit [confirmApply]
  /// call from a user button press. Callers that want to skip nagging
  /// developers during debug runs should gate the *silent* startup call
  /// themselves (see `SetupScreen._runStartupUpdateFlow`).
  Future<void> checkForUpdate() async {
    if (_isInFlight) return;

    final platform = ref.read(targetPlatformProvider);
    if (platform == UpdateTargetPlatform.unsupported) {
      state = state.copyWith(phase: UpdatePhase.upToDate);
      return;
    }

    state = state.copyWith(phase: UpdatePhase.checking);

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final release = await ref.read(githubReleaseClientProvider).fetchLatestRelease();
      await ref.read(updatePrefsProvider).markCheckedNow();

      if (!isNewerVersion(packageInfo.version, release.tagName)) {
        state = state.copyWith(
          phase: UpdatePhase.upToDate,
          currentVersion: packageInfo.version,
        );
        return;
      }

      final assets = selectAssetForPlatform(release, platform);
      if (assets == null) {
        state = UpdateState(
          phase: UpdatePhase.error,
          currentVersion: packageInfo.version,
          latestVersion: release.tagName,
          releaseUrl: release.htmlUrl,
          errorMessage:
              'Dieses Release unterstützt keine automatische Aktualisierung.',
        );
        return;
      }

      _pendingAssets = assets;
      state = UpdateState(
        phase: UpdatePhase.available,
        currentVersion: packageInfo.version,
        latestVersion: release.tagName,
        releaseNotes: release.body,
        releaseUrl: release.htmlUrl,
      );
    } catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, errorMessage: e.toString());
    }
  }

  Future<void> downloadAndPrepare() async {
    final assets = _pendingAssets;
    if (assets == null || state.phase != UpdatePhase.available) return;

    state = state.copyWith(phase: UpdatePhase.downloading, downloadProgress: 0);
    try {
      await ref.read(updateApplierProvider).prepare(
        asset: assets.asset,
        checksumAsset: assets.checksumAsset,
        onProgress: (progress) {
          state = state.copyWith(
            phase: UpdatePhase.downloading,
            downloadProgress: progress,
          );
        },
      );
      state = state.copyWith(phase: UpdatePhase.readyToRelaunch, downloadProgress: 1);
    } catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, errorMessage: e.toString());
    }
  }

  /// Swaps the prepared update into place and relaunches the app. On
  /// success the process exits and this never returns.
  Future<void> confirmApply() async {
    if (state.phase != UpdatePhase.readyToRelaunch) return;
    state = state.copyWith(phase: UpdatePhase.applying);
    try {
      await ref.read(updateApplierProvider).confirmApply();
    } catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, errorMessage: e.toString());
    }
  }

  Future<void> dismiss() async {
    final version = state.latestVersion;
    if (version != null) {
      await ref.read(updatePrefsProvider).dismissVersion(version);
    }
    state = UpdateState.idle;
  }

  void reset() {
    state = UpdateState.idle;
  }
}

class _UnsupportedUpdateApplier implements UpdateApplier {
  @override
  Future<void> prepare({
    required ReleaseAsset asset,
    required ReleaseAsset checksumAsset,
    required void Function(double progress) onProgress,
  }) {
    throw UpdateApplyException('Automatische Updates werden auf dieser Plattform nicht unterstützt.');
  }

  @override
  Future<void> confirmApply() {
    throw UpdateApplyException('Automatische Updates werden auf dieser Plattform nicht unterstützt.');
  }

  @override
  Future<void> cleanupStaleBackup() async {}
}
