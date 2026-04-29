import 'dart:io';

import 'package:flutter/material.dart';

import 'update_installer.dart';
import 'update_models.dart';

enum _UpdateDialogState {
  idle,
  permissionRequired,
  downloading,
  downloaded,
  failed,
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.update,
    required this.installer,
  });

  final AvailableUpdate update;
  final UpdateInstaller installer;

  @override
  State<UpdateDialog> createState() => _UpdateDialogStateState();
}

class _UpdateDialogStateState extends State<UpdateDialog> {
  _UpdateDialogState _state = _UpdateDialogState.idle;
  double _progress = 0;
  String _message = '';
  File? _downloadedApk;

  @override
  Widget build(BuildContext context) {
    final update = widget.update;

    return AlertDialog(
      title: const Text('发现新版本'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：${update.currentVersion}'),
              const SizedBox(height: 4),
              Text('最新版本：${update.latestVersion}'),
              const SizedBox(height: 14),
              Text(
                '更新内容',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                update.release.notes,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_state == _UpdateDialogState.downloading ||
                  _state == _UpdateDialogState.downloaded ||
                  _state == _UpdateDialogState.failed ||
                  _state == _UpdateDialogState.permissionRequired) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: _state == _UpdateDialogState.downloading
                      ? _progress
                      : null,
                ),
                const SizedBox(height: 8),
                Text(_statusText),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _state == _UpdateDialogState.downloading
              ? _cancelDownload
              : () => Navigator.of(context).pop(),
          child: Text(
            _state == _UpdateDialogState.downloading ? '取消下载' : '稍后更新',
          ),
        ),
        FilledButton(
          onPressed: _primaryAction,
          child: Text(_primaryButtonText),
        ),
      ],
    );
  }

  String get _statusText {
    switch (_state) {
      case _UpdateDialogState.idle:
        return '';
      case _UpdateDialogState.permissionRequired:
        return '请在系统设置中允许 WordSnap 安装未知应用，然后回到这里继续。';
      case _UpdateDialogState.downloading:
        return '正在下载 ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
      case _UpdateDialogState.downloaded:
        return '下载完成，请按系统提示完成安装。';
      case _UpdateDialogState.failed:
        return _message.isEmpty ? '下载失败，请稍后重试。' : _message;
    }
  }

  String get _primaryButtonText {
    switch (_state) {
      case _UpdateDialogState.permissionRequired:
        return '继续更新';
      case _UpdateDialogState.downloading:
        return '下载中...';
      case _UpdateDialogState.downloaded:
        return '继续安装';
      case _UpdateDialogState.failed:
        return '重新下载';
      case _UpdateDialogState.idle:
        return '立即更新';
    }
  }

  VoidCallback? get _primaryAction {
    switch (_state) {
      case _UpdateDialogState.downloading:
        return null;
      case _UpdateDialogState.permissionRequired:
        return () {
          _startDownload();
        };
      case _UpdateDialogState.downloaded:
        return () {
          _installDownloadedApk();
        };
      case _UpdateDialogState.failed:
      case _UpdateDialogState.idle:
        return () {
          _startDownload();
        };
    }
  }

  Future<void> _startDownload() async {
    final canInstall = await widget.installer.canInstallApk();
    if (!mounted) {
      return;
    }
    if (!canInstall) {
      setState(() {
        _state = _UpdateDialogState.permissionRequired;
      });
      await widget.installer.openInstallPermissionSettings();
      return;
    }

    setState(() {
      _state = _UpdateDialogState.downloading;
      _progress = 0;
      _message = '';
    });

    try {
      final apkFile = await widget.installer.downloadApk(
        update: widget.update,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = progress;
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadedApk = apkFile;
        _state = _UpdateDialogState.downloaded;
      });
      await _installDownloadedApk();
    } on UpdateInstallException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _UpdateDialogState.failed;
        _message = error.message;
      });
    }
  }

  Future<void> _installDownloadedApk() async {
    final apkFile = _downloadedApk;
    if (apkFile == null) {
      return;
    }
    try {
      await widget.installer.installApk(apkFile);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _UpdateDialogState.failed;
        _message = '无法打开系统安装器，请确认安装包完整后重试。';
      });
    }
  }

  void _cancelDownload() {
    widget.installer.cancelDownload();
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _UpdateDialogState.failed;
      _message = '下载已取消。';
    });
  }
}
