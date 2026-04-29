import 'dart:io';

import 'package:flutter/material.dart';

import '../storage/app_settings_service.dart';
import 'github_release_update_source.dart';
import 'native_update_service.dart';
import 'update_dialog.dart';
import 'update_installer.dart';
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
    if (!Platform.isAndroid ||
        _isChecking ||
        _isDialogVisible ||
        !settingsService.shouldCheckForUpdates(_config.checkInterval)) {
      return;
    }

    final result = await _checkForUpdates();
    if (!context.mounted) {
      return;
    }

    if (result.hasUpdate) {
      await _showUpdateDialog(context, result.update!);
    }
  }

  Future<void> checkManually(BuildContext context) async {
    if (_isChecking) {
      _showSnackBar(context, '正在检查更新...');
      return;
    }

    final result = await _checkForUpdates();
    if (!context.mounted) {
      return;
    }

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
      return UpdateCheckResult.unsupported('当前平台暂不支持应用内升级。');
    }

    _isChecking = true;
    try {
      final platformInfo = await _nativeUpdateService.getAndroidPlatformInfo();
      final release = await _source.fetchLatestRelease();
      await settingsService.markUpdateCheckedNow();

      final compareResult = _comparator.compare(
        platformInfo.versionName,
        release.version,
      );
      if (compareResult <= 0) {
        return UpdateCheckResult.noUpdate('已是最新版本。');
      }

      final asset = _source.selectAndroidApkAsset(
        release,
        platformInfo.supportedAbis,
      );
      if (asset == null) {
        return UpdateCheckResult.failed('发现新版本，但没有找到适合当前设备的安装包。');
      }

      return UpdateCheckResult.update(
        AvailableUpdate(
          currentVersion: platformInfo.versionName,
          release: release,
          asset: asset,
        ),
      );
    } on UpdateSourceException catch (error) {
      return UpdateCheckResult.failed(error.message);
    } on NativeUpdateException catch (error) {
      return UpdateCheckResult.failed(error.message);
    } catch (_) {
      return UpdateCheckResult.failed('检查更新失败，请稍后重试。');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    AvailableUpdate update,
  ) async {
    if (_isDialogVisible) {
      return;
    }
    _isDialogVisible = true;
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
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
