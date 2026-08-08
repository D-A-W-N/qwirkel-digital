import 'dart:io';

/// Platforms the in-app updater knows how to apply an update on.
/// Everything else is [unsupported] — the updater stays inert.
enum UpdateTargetPlatform { macos, linux, windows, android, unsupported }

UpdateTargetPlatform currentTargetPlatform() {
  if (Platform.isMacOS) return UpdateTargetPlatform.macos;
  if (Platform.isLinux) return UpdateTargetPlatform.linux;
  if (Platform.isWindows) return UpdateTargetPlatform.windows;
  if (Platform.isAndroid) return UpdateTargetPlatform.android;
  return UpdateTargetPlatform.unsupported;
}

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;

  static ReleaseAsset fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String,
      downloadUrl: json['browser_download_url'] as String,
    );
  }
}

class GithubRelease {
  const GithubRelease({
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    required this.assets,
  });

  final String tagName;
  final String htmlUrl;
  final String body;
  final List<ReleaseAsset> assets;

  static GithubRelease fromJson(Map<String, dynamic> json) {
    return GithubRelease(
      tagName: json['tag_name'] as String,
      htmlUrl: json['html_url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      assets: (json['assets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ReleaseAsset.fromJson)
          .toList(),
    );
  }
}

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToRelaunch,
  applying,
  error,
}

class UpdateState {
  const UpdateState({
    required this.phase,
    this.currentVersion,
    this.latestVersion,
    this.releaseNotes,
    this.releaseUrl,
    this.downloadProgress,
    this.errorMessage,
  });

  final UpdatePhase phase;
  final String? currentVersion;
  final String? latestVersion;
  final String? releaseNotes;
  final String? releaseUrl;
  final double? downloadProgress;
  final String? errorMessage;

  static const idle = UpdateState(phase: UpdatePhase.idle);

  UpdateState copyWith({
    UpdatePhase? phase,
    String? currentVersion,
    String? latestVersion,
    String? releaseNotes,
    String? releaseUrl,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return UpdateState(
      phase: phase ?? this.phase,
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      releaseUrl: releaseUrl ?? this.releaseUrl,
      downloadProgress: downloadProgress,
      errorMessage: errorMessage,
    );
  }
}
