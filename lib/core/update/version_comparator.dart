class VersionComparator {
  const VersionComparator();

  int compare(String currentVersion, String latestVersion) {
    final currentParts = _parseVersionParts(currentVersion);
    final latestParts = _parseVersionParts(latestVersion);
    final maxLength = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (var index = 0; index < maxLength; index++) {
      final current = index < currentParts.length ? currentParts[index] : 0;
      final latest = index < latestParts.length ? latestParts[index] : 0;
      if (latest > current) {
        return 1;
      }
      if (latest < current) {
        return -1;
      }
    }

    return 0;
  }

  String normalize(String version) {
    var value = version.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    final buildIndex = value.indexOf('+');
    if (buildIndex >= 0) {
      value = value.substring(0, buildIndex);
    }
    final prereleaseIndex = value.indexOf('-');
    if (prereleaseIndex >= 0) {
      value = value.substring(0, prereleaseIndex);
    }
    return value.trim();
  }

  List<int> _parseVersionParts(String version) {
    final normalized = normalize(version);
    final parts = normalized
        .split('.')
        .map((part) => RegExp(r'^\d+').firstMatch(part.trim())?.group(0))
        .whereType<String>()
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);

    if (parts.isEmpty) {
      return const [0];
    }
    return parts;
  }
}
