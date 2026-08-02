import 'package:pub_semver/pub_semver.dart';

/// Whether [tagName] (a GitHub release tag, e.g. "v0.3.0") is newer than
/// [currentVersion] (e.g. "0.3.0", as reported by package_info_plus).
///
/// A tag that can't be parsed as semver never counts as an update — silently
/// missing an update is far preferable to erroring or false-positiving.
bool isNewerVersion(String currentVersion, String tagName) {
  final normalizedTag = tagName.startsWith('v')
      ? tagName.substring(1)
      : tagName;
  try {
    final current = Version.parse(currentVersion);
    final latest = Version.parse(normalizedTag);
    return latest > current;
  } on FormatException {
    return false;
  }
}
