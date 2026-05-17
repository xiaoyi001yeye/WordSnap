class UpdateConfig {
  const UpdateConfig({
    this.manifestUrl = const String.fromEnvironment(
      'WORDSNAP_UPDATE_MANIFEST_URL',
      defaultValue:
          'http://39.104.67.175/downloads/wordsnap/manifests/latest-android-stable.json',
    ),
    this.checkInterval = const Duration(hours: 24),
  });

  final String manifestUrl;
  final Duration checkInterval;

  Uri get latestManifestUri => Uri.parse(manifestUrl);
}

class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.apiUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final String apiUrl;
  final int size;
}

class ReleaseVersionInfo {
  const ReleaseVersionInfo({
    required this.tagName,
    required this.version,
    required this.versionCode,
    required this.notes,
    required this.publishedAt,
    required this.assets,
  });

  final String tagName;
  final String version;
  final int versionCode;
  final String notes;
  final DateTime? publishedAt;
  final List<UpdateAsset> assets;
}

class AndroidUpdatePlatformInfo {
  const AndroidUpdatePlatformInfo({
    required this.versionName,
    required this.versionCode,
    required this.supportedAbis,
    required this.canRequestPackageInstalls,
  });

  final String versionName;
  final int versionCode;
  final List<String> supportedAbis;
  final bool canRequestPackageInstalls;
}

class AvailableUpdate {
  const AvailableUpdate({
    required this.currentVersion,
    required this.release,
    required this.asset,
  });

  final String currentVersion;
  final ReleaseVersionInfo release;
  final UpdateAsset asset;

  String get latestVersion => release.version;
}

enum UpdateCheckStatus {
  updateAvailable,
  noUpdate,
  unsupported,
  failed,
}

class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.status,
    this.update,
    this.message,
  });

  final UpdateCheckStatus status;
  final AvailableUpdate? update;
  final String? message;

  bool get hasUpdate => status == UpdateCheckStatus.updateAvailable;

  factory UpdateCheckResult.update(AvailableUpdate update) {
    return UpdateCheckResult._(
      status: UpdateCheckStatus.updateAvailable,
      update: update,
    );
  }

  factory UpdateCheckResult.noUpdate(String message) {
    return UpdateCheckResult._(
      status: UpdateCheckStatus.noUpdate,
      message: message,
    );
  }

  factory UpdateCheckResult.unsupported(String message) {
    return UpdateCheckResult._(
      status: UpdateCheckStatus.unsupported,
      message: message,
    );
  }

  factory UpdateCheckResult.failed(String message) {
    return UpdateCheckResult._(
      status: UpdateCheckStatus.failed,
      message: message,
    );
  }
}
