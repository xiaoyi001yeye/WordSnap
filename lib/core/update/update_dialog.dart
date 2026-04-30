import 'dart:io';

import 'package:flutter/material.dart';

import 'update_installer.dart';
import 'update_logger.dart';
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
                if (_state == _UpdateDialogState.downloading) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                ],
                Text(_statusText),
              ],
              _buildDiagnosticLogs(context),
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

  Widget _buildDiagnosticLogs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<UpdateLogEntry>>(
      valueListenable: UpdateLogger.entries,
      builder: (context, entries, child) {
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              '诊断日志',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  entries.map((entry) => entry.displayText).join('\n'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                ),
              ),
            ),
          ],
        );
      },
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
    UpdateLogger.info('Update dialog primary action started', {
      'state': _state.name,
      'latestVersion': widget.update.latestVersion,
      'assetName': widget.update.asset.name,
    });
    final canInstall = await widget.installer.canInstallApk();
    if (!mounted) {
      UpdateLogger.info('Update dialog primary action stopped', {
        'reason': 'unmounted_after_permission_check',
      });
      return;
    }
    if (!canInstall) {
      UpdateLogger.info('Install permission required before update download');
      setState(() {
        _state = _UpdateDialogState.permissionRequired;
      });
      await widget.installer.openInstallPermissionSettings();
      UpdateLogger.info('Install permission settings requested from dialog');
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
        UpdateLogger.info('Downloaded APK ignored', {
          'reason': 'dialog_unmounted',
          'apkPath': apkFile.path,
        });
        return;
      }
      UpdateLogger.info('Downloaded APK ready in dialog', {
        'apkPath': apkFile.path,
      });
      setState(() {
        _downloadedApk = apkFile;
        _state = _UpdateDialogState.downloaded;
      });
      await _installDownloadedApk();
    } on UpdateInstallException catch (error, stackTrace) {
      UpdateLogger.error('Update download failed in dialog', error, stackTrace);
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
      UpdateLogger.info('Install downloaded APK skipped', {
        'reason': 'no_downloaded_apk',
      });
      return;
    }
    try {
      UpdateLogger.info('Opening system installer from dialog', {
        'apkPath': apkFile.path,
      });
      await widget.installer.installApk(apkFile);
      UpdateLogger.info('System installer request completed from dialog', {
        'apkPath': apkFile.path,
      });
    } catch (error, stackTrace) {
      UpdateLogger.error(
        'Opening system installer failed in dialog',
        error,
        stackTrace,
        {'apkPath': apkFile.path},
      );
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
    UpdateLogger.info('Update download cancelled from dialog');
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
