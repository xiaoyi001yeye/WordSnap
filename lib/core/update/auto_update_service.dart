import 'dart:io';

import 'package:flutter/material.dart';

import '../storage/app_settings_service.dart';
import 'github_release_update_source.dart';
import 'native_update_service.dart';
import 'update_dialog.dart';
import 'update_installer.dart';
import 'update_logger.dart';
import 'update_models.dart';
import 'version_comparator.dart';

class AutoUpdateService {
  AutoUpdateService({
    required this.settingsService,
    UpdateConfig config = const UpdateConfig(
      owner: 'xiaoyi001yeye',
      repo: 'WordSnap',
    ),
    NativeUpdateService nativeUpdateService = const NativeUpdateService(),
    VersionComparator comparator = const VersionComparator(),
  })  : _config = config,
        _nativeUpdateService = nativeUpdateService,
        _comparator = comparator {
    _source = GitHubReleaseUpdateSource(
      config: _config,
      comparator: _comparator,
    );
    _installer = UpdateInstaller(nativeUpdateService: _nativeUpdateService);
  }

  final AppSettingsService settingsService;
  final UpdateConfig _config;
  final NativeUpdateService _nativeUpdateService;
  final VersionComparator _comparator;
  late final GitHubReleaseUpdateSource _source;
  late final UpdateInstaller _installer;
  bool _isChecking = false;
  bool _isDialogVisible = false;

  Future<void> checkAutomatically(BuildContext context) async {
    if (!Platform.isAndroid) {
      UpdateLogger.info('Automatic update check skipped', {
        'reason': 'not_android',
      });
      return;
    }
    if (_isChecking) {
      UpdateLogger.info('Automatic update check skipped', {
        'reason': 'already_checking',
      });
      return;
    }
    if (_isDialogVisible) {
      UpdateLogger.info('Automatic update check skipped', {
        'reason': 'dialog_visible',
      });
      return;
    }
    if (!settingsService.shouldCheckForUpdates(_config.checkInterval)) {
      UpdateLogger.info('Automatic update check skipped', {
        'reason': 'interval_not_elapsed',
      });
      return;
    }

    UpdateLogger.info('Automatic update check started');
    final result = await _checkForUpdates();
    if (!context.mounted) {
      UpdateLogger.info('Automatic update check result ignored', {
        'reason': 'context_unmounted',
        'status': result.status.name,
      });
      return;
    }

    UpdateLogger.info('Automatic update check finished', {
      'status': result.status.name,
    });
    if (result.hasUpdate) {
      await _showUpdateDialog(context, result.update!);
    }
  }

  Future<void> checkManually(BuildContext context) async {
    if (_isChecking) {
      UpdateLogger.info('Manual update check skipped', {
        'reason': 'already_checking',
      });
      _showSnackBar(context, '正在检查更新...');
      return;
    }

    UpdateLogger.clear();
    UpdateLogger.info('Manual update check started');
    final result = await _checkForUpdates();
    if (!context.mounted) {
      UpdateLogger.info('Manual update check result ignored', {
        'reason': 'context_unmounted',
        'status': result.status.name,
      });
      return;
    }

    UpdateLogger.info('Manual update check finished', {
      'status': result.status.name,
      if (result.message != null) 'message': result.message,
    });
    switch (result.status) {
      case UpdateCheckStatus.updateAvailable:
        await _showUpdateDialog(context, result.update!);
        break;
      case UpdateCheckStatus.noUpdate:
        _showSnackBar(context, result.message ?? '已是最新版本。');
        break;
      case UpdateCheckStatus.unsupported:
      case UpdateCheckStatus.failed:
        _showSnackBar(context, result.message ?? '检查更新失败，请稍后重试。');
        break;
    }
  }

  Future<UpdateCheckResult> _checkForUpdates() async {
    if (!Platform.isAndroid) {
      UpdateLogger.info('Update check unsupported', {
        'platform': 'non_android',
      });
      return UpdateCheckResult.unsupported('当前平台暂不支持应用内升级。');
    }

    _isChecking = true;
    try {
      UpdateLogger.info('Reading Android update platform info');
      final platformInfo = await _nativeUpdateService.getAndroidPlatformInfo();
      UpdateLogger.info('Android update platform info loaded', {
        'versionName': platformInfo.versionName,
        'versionCode': platformInfo.versionCode,
        'supportedAbis': platformInfo.supportedAbis.join(','),
        'canRequestPackageInstalls': platformInfo.canRequestPackageInstalls,
      });
      UpdateLogger.info('Fetching latest GitHub release', {
        'owner': _config.owner,
        'repo': _config.repo,
      });
      final release = await _source.fetchLatestRelease();
      UpdateLogger.info('Latest GitHub release loaded', {
        'tagName': release.tagName,
        'version': release.version,
        'assetCount': release.assets.length,
      });

      final compareResult = _comparator.compare(
        platformInfo.versionName,
        release.version,
      );
      UpdateLogger.info('Compared update versions', {
        'currentVersion': platformInfo.versionName,
        'latestVersion': release.version,
        'compareResult': compareResult,
      });
      if (compareResult <= 0) {
        await settingsService.markUpdateCheckedNow();
        return UpdateCheckResult.noUpdate('已是最新版本。');
      }

      final asset = _source.selectAndroidApkAsset(
        release,
        platformInfo.supportedAbis,
      );
      if (asset == null) {
        UpdateLogger.info('No Android APK asset found for release', {
          'tagName': release.tagName,
          'assetNames': release.assets.map((asset) => asset.name).join(','),
        });
        return UpdateCheckResult.failed('发现新版本，但安装包还在生成，请稍后重试。');
      }

      UpdateLogger.info('Selected Android APK asset', {
        'assetName': asset.name,
        'assetSize': asset.size,
      });
      await settingsService.markUpdateCheckedNow();
      return UpdateCheckResult.update(
        AvailableUpdate(
          currentVersion: platformInfo.versionName,
          release: release,
          asset: asset,
        ),
      );
    } on UpdateSourceException catch (error, stackTrace) {
      UpdateLogger.error('Update source failed', error, stackTrace);
      return UpdateCheckResult.failed(error.message);
    } on NativeUpdateException catch (error, stackTrace) {
      UpdateLogger.error('Native update bridge failed', error, stackTrace);
      return UpdateCheckResult.failed(error.message);
    } catch (error, stackTrace) {
      UpdateLogger.error('Unexpected update check failure', error, stackTrace);
      return UpdateCheckResult.failed('检查更新失败，请稍后重试。');
    } finally {
      _isChecking = false;
      UpdateLogger.info('Update check ended');
    }
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    AvailableUpdate update,
  ) async {
    if (_isDialogVisible) {
      UpdateLogger.info('Update dialog skipped', {
        'reason': 'already_visible',
      });
      return;
    }
    _isDialogVisible = true;
    UpdateLogger.info('Showing update dialog', {
      'currentVersion': update.currentVersion,
      'latestVersion': update.latestVersion,
      'assetName': update.asset.name,
    });
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return UpdateDialog(
            update: update,
            installer: _installer,
          );
        },
      );
    } finally {
      _isDialogVisible = false;
      UpdateLogger.info('Update dialog closed');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
