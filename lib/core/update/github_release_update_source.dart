import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'update_logger.dart';
import 'update_models.dart';
import 'version_comparator.dart';

class GitHubReleaseUpdateSource {
  GitHubReleaseUpdateSource({
    required this.config,
    http.Client? client,
    VersionComparator? comparator,
  })  : _client = client ?? http.Client(),
        _comparator = comparator ?? const VersionComparator();

  final UpdateConfig config;
  final http.Client _client;
  final VersionComparator _comparator;

  Future<ReleaseVersionInfo> fetchLatestRelease() async {
    UpdateLogger.info('Requesting latest release API', {
      'uri': config.latestReleaseUri,
    });
    final response = await _client
        .get(
          config.latestReleaseUri,
          headers: const <String, String>{
            HttpHeaders.acceptHeader: 'application/vnd.github+json',
            HttpHeaders.userAgentHeader: 'WordSnap update checker',
          },
        )
        .timeout(const Duration(seconds: 12));
    UpdateLogger.info('Latest release API responded', {
      'statusCode': response.statusCode,
      'bodyBytes': response.bodyBytes.length,
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const UpdateSourceException('没有读取到可用的版本发布信息。');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UpdateSourceException('版本发布信息格式不正确。');
    }
    final releaseJson = Map<String, Object?>.from(decoded);

    final tagName = _stringValue(releaseJson['tag_name']);
    if (tagName.isEmpty) {
      throw const UpdateSourceException('版本发布信息缺少 tag。');
    }

    final assets = releaseJson['assets'];
    final release = ReleaseVersionInfo(
      tagName: tagName,
      version: _comparator.normalize(tagName),
      notes: _formatReleaseNotes(_stringValue(releaseJson['body'])),
      publishedAt: DateTime.tryParse(_stringValue(releaseJson['published_at'])),
      assets: assets is List
          ? assets
              .whereType<Map>()
              .map((asset) => _parseAsset(Map<String, Object?>.from(asset)))
              .where((asset) => asset.downloadUrl.isNotEmpty)
              .toList(growable: false)
          : const <UpdateAsset>[],
    );
    UpdateLogger.info('Parsed latest release', {
      'tagName': release.tagName,
      'version': release.version,
      'assets': release.assets.map((asset) => asset.name).join(','),
    });
    return release;
  }

  UpdateAsset? selectAndroidApkAsset(
    ReleaseVersionInfo release,
    List<String> supportedAbis,
  ) {
    final apkAssets = release.assets
        .where((asset) => asset.name.toLowerCase().endsWith('.apk'))
        .toList(growable: false);
    UpdateLogger.info('Selecting Android APK asset', {
      'apkAssetNames': apkAssets.map((asset) => asset.name).join(','),
      'supportedAbis': supportedAbis.join(','),
    });
    if (apkAssets.isEmpty) {
      return null;
    }
    if (apkAssets.length == 1) {
      UpdateLogger.info('Selected only Android APK asset', {
        'assetName': apkAssets.first.name,
      });
      return apkAssets.first;
    }

    final loweredAbis =
        supportedAbis.map((abi) => abi.toLowerCase()).toList(growable: false);
    const preferredFallbacks = <String>[
      'arm64-v8a',
      'armeabi-v7a',
      'x86_64',
    ];
    final orderedAbis = <String>[
      ...loweredAbis,
      ...preferredFallbacks.where((abi) => !loweredAbis.contains(abi)),
    ];

    for (final abi in orderedAbis) {
      for (final asset in apkAssets) {
        if (asset.name.toLowerCase().contains(abi)) {
          UpdateLogger.info('Selected ABI-matched Android APK asset', {
            'abi': abi,
            'assetName': asset.name,
          });
          return asset;
        }
      }
    }

    UpdateLogger.info('Selected fallback Android APK asset', {
      'assetName': apkAssets.first.name,
    });
    return apkAssets.first;
  }

  UpdateAsset _parseAsset(Map<String, Object?> json) {
    return UpdateAsset(
      name: _stringValue(json['name']),
      downloadUrl: _stringValue(json['browser_download_url']),
      apiUrl: _stringValue(json['url']),
      size: _intValue(json['size']),
    );
  }

  String _formatReleaseNotes(String notes) {
    final normalized = notes.trim();
    if (normalized.isEmpty) {
      return '此版本包含体验优化和问题修复。';
    }
    if (normalized.length <= 1000) {
      return normalized;
    }
    return '${normalized.substring(0, 1000)}...';
  }

  static String _stringValue(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UpdateSourceException implements Exception {
  const UpdateSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}
