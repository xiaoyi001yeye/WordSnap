import 'dart:io';

import 'package:flutter/services.dart';

import 'update_logger.dart';
import 'update_models.dart';

class NativeUpdateException implements Exception {
  const NativeUpdateException(this.message);

  final String message;

  @override
  String toString() => 'NativeUpdateException: $message';
}

class NativeUpdateService {
  const NativeUpdateService();

  static const MethodChannel _channel = MethodChannel('wordsnap/update');

  Future<AndroidUpdatePlatformInfo> getAndroidPlatformInfo() async {
    if (!Platform.isAndroid) {
      throw const NativeUpdateException('当前平台暂不支持应用内安装升级。');
    }

    UpdateLogger.info('Invoking native update method', {
      'method': 'getUpdatePlatformInfo',
    });
    Map<String, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<String, Object?>(
        'getUpdatePlatformInfo',
      );
    } catch (error, stackTrace) {
      UpdateLogger.error(
        'Native update method failed',
        error,
        stackTrace,
        {'method': 'getUpdatePlatformInfo'},
      );
      rethrow;
    }
    if (result == null) {
      throw const NativeUpdateException('无法读取当前应用版本信息。');
    }

    final abis = result['supportedAbis'];
    return AndroidUpdatePlatformInfo(
      versionName: result['versionName']?.toString() ?? '0.0.0',
      versionCode: _asInt(result['versionCode']),
      supportedAbis: abis is List
          ? abis.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      canRequestPackageInstalls:
          result['canRequestPackageInstalls'] != false,
    );
  }

  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) {
      return false;
    }
    UpdateLogger.info('Invoking native update method', {
      'method': 'canRequestPackageInstalls',
    });
    try {
      final result = await _channel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      final canInstall = result ?? false;
      UpdateLogger.info('Native install permission state loaded', {
        'canRequestPackageInstalls': canInstall,
      });
      return canInstall;
    } catch (error, stackTrace) {
      UpdateLogger.error(
        'Native update method failed',
        error,
        stackTrace,
        {'method': 'canRequestPackageInstalls'},
      );
      rethrow;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    UpdateLogger.info('Invoking native update method', {
      'method': 'openInstallPermissionSettings',
    });
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
      UpdateLogger.info('Native install permission settings opened');
    } catch (error, stackTrace) {
      UpdateLogger.error(
        'Native update method failed',
        error,
        stackTrace,
        {'method': 'openInstallPermissionSettings'},
      );
      rethrow;
    }
  }

  Future<void> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      throw const NativeUpdateException('当前平台暂不支持应用内安装升级。');
    }
    UpdateLogger.info('Invoking native update method', {
      'method': 'installApk',
      'apkPath': apkPath,
    });
    try {
      await _channel.invokeMethod<void>('installApk', <String, Object?>{
        'apkPath': apkPath,
      });
      UpdateLogger.info('Native install APK request completed', {
        'apkPath': apkPath,
      });
    } catch (error, stackTrace) {
      UpdateLogger.error(
        'Native update method failed',
        error,
        stackTrace,
        {
          'method': 'installApk',
          'apkPath': apkPath,
        },
      );
      rethrow;
    }
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
