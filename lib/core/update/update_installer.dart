import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'native_update_service.dart';
import 'update_models.dart';

class UpdateInstaller {
  UpdateInstaller({
    NativeUpdateService nativeUpdateService = const NativeUpdateService(),
  }) : _nativeUpdateService = nativeUpdateService;

  final NativeUpdateService _nativeUpdateService;
  http.Client? _activeClient;
  bool _isCancelled = false;

  Future<bool> canInstallApk() {
    return _nativeUpdateService.canRequestPackageInstalls();
  }

  Future<void> openInstallPermissionSettings() {
    return _nativeUpdateService.openInstallPermissionSettings();
  }

  Future<File> downloadApk({
    required AvailableUpdate update,
    required void Function(double progress) onProgress,
  }) async {
    _isCancelled = false;
    final client = http.Client();
    _activeClient = client;
    IOSink? sink;
    var didCloseSink = false;

    try {
      final request = http.Request('GET', Uri.parse(update.asset.downloadUrl))
        ..headers[HttpHeaders.userAgentHeader] = 'WordSnap update downloader';
      final response = await client.send(request).timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const UpdateInstallException('安装包下载失败。');
      }

      final output = await _prepareOutputFile(update);
      sink = output.openWrite();
      var receivedBytes = 0;
      final contentLength = response.contentLength ?? 0;
      final totalBytes = contentLength > 0 ? contentLength : update.asset.size;

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          throw const UpdateInstallException('下载已取消。');
        }
        receivedBytes += chunk.length;
        sink.add(chunk);
        if (totalBytes > 0) {
          onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();
      didCloseSink = true;
      onProgress(1);
      return output;
    } on UpdateInstallException {
      rethrow;
    } catch (_) {
      if (_isCancelled) {
        throw const UpdateInstallException('下载已取消。');
      }
      throw const UpdateInstallException('安装包下载失败，请稍后重试。');
    } finally {
      if (!didCloseSink) {
        await sink?.close();
      }
      client.close();
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
    }
  }

  void cancelDownload() {
    _isCancelled = true;
    _activeClient?.close();
    _activeClient = null;
  }

  Future<void> installApk(File apkFile) {
    return _nativeUpdateService.installApk(apkFile.path);
  }

  Future<File> _prepareOutputFile(AvailableUpdate update) async {
    final baseDirectory =
        await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final updateDirectory = Directory(p.join(baseDirectory.path, 'updates'));
    if (!updateDirectory.existsSync()) {
      await updateDirectory.create(recursive: true);
    }

    final safeVersion = update.latestVersion.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]'),
      '_',
    );
    final fileName = 'wordsnap-v$safeVersion-${update.asset.name}';
    final output = File(p.join(updateDirectory.path, fileName));
    if (output.existsSync()) {
      await output.delete();
    }
    return output;
  }
}

class UpdateInstallException implements Exception {
  const UpdateInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}
