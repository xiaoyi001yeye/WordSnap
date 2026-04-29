import 'dart:io';

import 'package:flutter/services.dart';

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

    final result = await _channel.invokeMapMethod<String, Object?>(
      'getUpdatePlatformInfo',
    );
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
    final result = await _channel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return result ?? false;
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<void> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      throw const NativeUpdateException('当前平台暂不支持应用内安装升级。');
    }
    await _channel.invokeMethod<void>('installApk', <String, Object?>{
      'apkPath': apkPath,
    });
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
