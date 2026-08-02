import 'update_models.dart';

class SelectedUpdateAssets {
  const SelectedUpdateAssets({required this.asset, required this.checksumAsset});

  final ReleaseAsset asset;
  final ReleaseAsset checksumAsset;
}

const _assetNamesByPlatform = {
  UpdateTargetPlatform.macos: 'qwirkle-digital-macos.zip',
  UpdateTargetPlatform.linux: 'qwirkle-digital-linux.tar.gz',
};

/// Picks the release asset for [platform] plus its `.sha256` sidecar.
///
/// Returns null if the platform isn't supported, or if either the asset or
/// its checksum sidecar is missing — releases published before the checksum
/// step existed must not be auto-applied.
SelectedUpdateAssets? selectAssetForPlatform(
  GithubRelease release,
  UpdateTargetPlatform platform,
) {
  final assetName = _assetNamesByPlatform[platform];
  if (assetName == null) return null;

  ReleaseAsset? findByName(String name) {
    for (final asset in release.assets) {
      if (asset.name == name) return asset;
    }
    return null;
  }

  final asset = findByName(assetName);
  final checksumAsset = findByName('$assetName.sha256');
  if (asset == null || checksumAsset == null) return null;

  return SelectedUpdateAssets(asset: asset, checksumAsset: checksumAsset);
}
