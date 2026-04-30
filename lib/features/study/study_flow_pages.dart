import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/layout/responsive_helper.dart';
import '../../core/navigation/compatible_page_route.dart';
import '../../core/storage/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'native_answer_feedback_service.dart';
import 'native_image_processing_service.dart';
import 'native_pronunciation_service.dart';
import 'native_share_service.dart';
import 'study_models.dart';
import 'volcengine_ocr_service.dart';
import 'word_snap_demo_service.dart';

double _clampDouble(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

class RecognitionDemoPage extends StatefulWidget {
  const RecognitionDemoPage({
    super.key,
    required this.demoService,
    required this.settingsService,
  });

  final WordSnapDemoService demoService;
  final AppSettingsService settingsService;

  @override
  State<RecognitionDemoPage> createState() => _RecognitionDemoPageState();
}

class _RecognitionDemoPageState extends State<RecognitionDemoPage> {
  static const int _maxRecognitionLongSide = 2200;
  static const int _directUploadSizeThresholdBytes = 3 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();
  final NativeImageProcessingService _nativeImageProcessingService =
      const NativeImageProcessingService();
  final ScrollController _recognitionLogScrollController = ScrollController();
  bool _fromGallery = false;
  bool _isPickingImage = false;
  bool _isRecognizing = false;
  bool _showRecognitionOverlay = false;
  Rect _recognitionSelection = const Rect.fromLTWH(0.14, 0.12, 0.72, 0.76);
  String? _selectedImagePath;
  String? _pickErrorMessage;
  String? _recognitionErrorMessage;
  final List<_RecognitionLogItem> _recognitionLogs = <_RecognitionLogItem>[];

  @override
  void initState() {
    super.initState();
    _fromGallery = !_supportsDirectCameraCapture;
    _restoreLostImage();
  }

  @override
  void dispose() {
    _recognitionLogScrollController.dispose();
    super.dispose();
  }

  bool get _supportsDirectCameraCapture => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final hasSelectedImage = _selectedImagePath != null;
    final supportsDirectCameraCapture = _supportsDirectCameraCapture;
    final hasOcrApiKey = widget.settingsService.hasSelectedOcrApiKey;

    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveHelper.maxContentWidth(context),
                ),
                child: ListView(
                  padding: ResponsiveHelper.screenPadding(context),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '采集方式',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SegmentButton(
                                    label: '拍照',
                                    icon: Icons.photo_camera_outlined,
                                    selected: !_fromGallery,
                                    onTap: _isPickingImage ||
                                            !supportsDirectCameraCapture
                                        ? null
                                        : () => _pickImage(ImageSource.camera),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SegmentButton(
                                    label: '相册导入',
                                    icon: Icons.photo_library_outlined,
                                    selected: _fromGallery,
                                    onTap: _isPickingImage
                                        ? null
                                        : () => _pickImage(ImageSource.gallery),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              !supportsDirectCameraCapture
                                  ? '当前设备建议使用“相册导入”，桌面版暂不支持直接拉起系统相机。'
                                  : _isPickingImage
                                  ? '正在打开系统${_fromGallery ? '相册' : '相机'}...'
                                  : '点击上方按钮即可直接拉起系统${_fromGallery ? '相册' : '相机'}。',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_pickErrorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _pickErrorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF9A5B00),
                                  ),
                                ),
                              ),
                            ],
                            if (_recognitionErrorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE7E7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _recognitionErrorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.accentRed,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (hasSelectedImage) ...[
                      _RecognitionImageSelector(
                        imagePath: _selectedImagePath!,
                        selection: _recognitionSelection,
                        onSelectionChanged: (selection) {
                          setState(() {
                            _recognitionSelection = selection;
                          });
                        },
                        onOpenFullscreen: () {
                          CompatibleNavigator.push<void>(
                            context,
                            _FullImagePreviewPage(imagePath: _selectedImagePath!),
                            transitionType: PageTransitionType.slideUp,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: hasSelectedImage
                                ? () {
                                    setState(() {
                                      _fromGallery = !supportsDirectCameraCapture;
                                      _selectedImagePath = null;
                                      _recognitionSelection =
                                          const Rect.fromLTWH(
                                            0.14,
                                            0.12,
                                            0.72,
                                            0.76,
                                          );
                                      _pickErrorMessage = null;
                                      _recognitionErrorMessage = null;
                                    });
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentRed,
                              side: const BorderSide(color: AppTheme.accentRed),
                            ),
                            child: const Text('清除图片'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: hasSelectedImage &&
                                    hasOcrApiKey &&
                                    !_isPickingImage &&
                                    !_isRecognizing
                                ? _openResult
                                : null,
                            child: Text(_isRecognizing ? '正在识别...' : '开始识别'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showRecognitionOverlay)
            _RecognitionProgressOverlay(
              isRecognizing: _isRecognizing,
              logs: _recognitionLogs,
              scrollController: _recognitionLogScrollController,
              onClose: _isRecognizing
                  ? null
                  : () {
                      setState(() {
                        _showRecognitionOverlay = false;
                      });
                    },
            ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && !_supportsDirectCameraCapture) {
      setState(() {
        _fromGallery = true;
        _isPickingImage = false;
        _pickErrorMessage = '桌面版暂不支持直接拍照，请改用“相册导入”选择图片。';
        _recognitionErrorMessage = null;
      });
      return;
    }

    setState(() {
      _fromGallery = source == ImageSource.gallery;
      _isPickingImage = true;
      _pickErrorMessage = null;
      _recognitionErrorMessage = null;
    });

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 2400,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImagePath = pickedFile?.path;
        _recognitionSelection = const Rect.fromLTWH(0.14, 0.12, 0.72, 0.76);
        if (pickedFile == null) {
          _pickErrorMessage = '你这次没有选择图片，重新点一次即可继续。';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pickErrorMessage =
            '系统${source == ImageSource.gallery ? '相册' : '相机'}没有成功打开，请检查权限后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _restoreLostImage() async {
    final lostData = await _imagePicker.retrieveLostData();
    if (!mounted || lostData.isEmpty) {
      return;
    }

    final recoveredFiles = lostData.files;
    if (recoveredFiles != null && recoveredFiles.isNotEmpty) {
      setState(() {
        _selectedImagePath = recoveredFiles.first.path;
        _recognitionSelection = const Rect.fromLTWH(0.14, 0.12, 0.72, 0.76);
        _pickErrorMessage = null;
      });
      return;
    }

    setState(() {
      _pickErrorMessage = '已尝试恢复上次未完成的图片选择，但没有拿到可用图片，请重试。';
    });
  }

  Future<void> _openResult() async {
    if (_selectedImagePath == null) {
      setState(() {
        _pickErrorMessage = '请先拍一张照片，或从相册里选一张图片。';
      });
      return;
    }

    setState(() {
      _isRecognizing = true;
      _showRecognitionOverlay = true;
      _pickErrorMessage = null;
      _recognitionErrorMessage = null;
      _recognitionLogs.clear();
    });
    _appendRecognitionLog('开始准备识别流程。');

    if (!widget.settingsService.hasSelectedOcrApiKey) {
      _appendRecognitionLog(
        '识别已中止：未配置 ${widget.settingsService.selectedOcrProvider.apiKeyLabel}。',
      );
      setState(() {
        _isRecognizing = false;
        _recognitionErrorMessage =
            '请先到设置页填写 ${widget.settingsService.selectedOcrProvider.apiKeyLabel}。';
      });
      return;
    }

    RecognitionCapture capture;
    try {
      final recognitionImagePath = await _prepareImageForRecognition();
      _appendRecognitionLog('图片预处理完成，准备进入 OCR。');
      capture = await widget.demoService.createRecognitionCaptureFromVolcengineOcr(
        imagePath: recognitionImagePath,
        fromGallery: _fromGallery,
        onLog: _appendRecognitionLog,
      );
    } on VolcengineOcrException catch (error) {
      if (!mounted) {
        return;
      }
      _appendRecognitionLog('识别失败：${error.message}');
      setState(() {
        _recognitionErrorMessage = error.message;
        _isRecognizing = false;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      _appendRecognitionLog('识别失败：发生未预期错误。');
      setState(() {
        _recognitionErrorMessage =
            '${widget.settingsService.selectedOcrProvider.label} 识别失败，请稍后重试。';
        _isRecognizing = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecognizing = false;
      _showRecognitionOverlay = false;
    });

    await CompatibleNavigator.push<void>(
      context,
      RecognitionResultPage(
        demoService: widget.demoService,
        settingsService: widget.settingsService,
        capture: capture,
      ),
      transitionType: PageTransitionType.slide,
    );
  }

  Future<String> _prepareImageForRecognition() async {
    final imagePath = _selectedImagePath;
    if (imagePath == null) {
      throw const VolcengineOcrException('请先拍一张照片，或从相册里选一张图片。');
    }

    final sourceFile = File(imagePath);
    final originalSize = await sourceFile.length();
    _appendRecognitionLog('原图大小 ${_formatBytes(originalSize)}，开始检查是否需要裁切或缩放。');
    final selection = _normalizeSelection(_recognitionSelection);
    final isFullSelection = _isFullImageSelection(selection);
    if (isFullSelection && originalSize <= _directUploadSizeThresholdBytes) {
      _appendRecognitionLog('当前使用整张图片，且体积不大，直接上传原图。');
      return imagePath;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return _prepareImageForRecognitionOnDevice(
        imagePath: imagePath,
        originalSize: originalSize,
        selection: selection,
        isFullSelection: isFullSelection,
      );
    }

    return _prepareImageForRecognitionFallback(
      imagePath: imagePath,
      originalSize: originalSize,
      selection: selection,
      isFullSelection: isFullSelection,
    );
  }

  Future<String> _prepareImageForRecognitionOnDevice({
    required String imagePath,
    required int originalSize,
    required Rect selection,
    required bool isFullSelection,
  }) async {
    _appendRecognitionLog('检测到移动端，交给原生图片引擎执行裁切压缩。');

    try {
      final result = await _nativeImageProcessingService.prepareRecognitionImage(
        imagePath: imagePath,
        left: selection.left,
        top: selection.top,
        right: selection.right,
        bottom: selection.bottom,
        maxLongSide: _maxRecognitionLongSide,
      );
      final savedBytes = originalSize - result.outputBytes;
      final savedRatio = originalSize <= 0
          ? 0.0
          : savedBytes / originalSize * 100;
      _appendRecognitionLog(
        '原生处理完成：输出 ${result.width}x${result.height}，JPEG 质量 ${result.quality}，'
        '文件从 ${_formatBytes(result.originalBytes)} 降到 ${_formatBytes(result.outputBytes)}，缩小 ${savedRatio.toStringAsFixed(1)}%。',
      );
      if (result.didCrop) {
        _appendRecognitionLog('已按当前选区裁切图片。');
      }
      if (result.didResize) {
        _appendRecognitionLog('图片已额外缩放，降低上传与识别耗时。');
      }
      return result.path;
    } on NativeImageProcessingException catch (error) {
      _appendRecognitionLog('原生压缩失败，回退到 Dart 图片处理：${error.message}');
    } on PlatformException catch (error) {
      _appendRecognitionLog(
        '原生压缩失败，回退到 Dart 图片处理：${error.message ?? error.code}',
      );
    }

    return _prepareImageForRecognitionFallback(
      imagePath: imagePath,
      originalSize: originalSize,
      selection: selection,
      isFullSelection: isFullSelection,
    );
  }

  Future<String> _prepareImageForRecognitionFallback({
    required String imagePath,
    required int originalSize,
    required Rect selection,
    required bool isFullSelection,
  }) async {
    final sourceFile = File(imagePath);
    final sourceBytes = await sourceFile.readAsBytes();
    _appendRecognitionLog('开始解码图片，用于${isFullSelection ? '缩放' : '裁切与缩放'}。');
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;
    final cropRect = isFullSelection
        ? Rect.fromLTWH(
            0,
            0,
            sourceImage.width.toDouble(),
            sourceImage.height.toDouble(),
          )
        : Rect.fromLTRB(
            selection.left * sourceImage.width,
            selection.top * sourceImage.height,
            selection.right * sourceImage.width,
            selection.bottom * sourceImage.height,
          );
    final cropWidth =
        cropRect.width.round().clamp(8, sourceImage.width).toInt();
    final cropHeight =
        cropRect.height.round().clamp(8, sourceImage.height).toInt();
    final longestSide = math.max(cropWidth, cropHeight);
    final scaleFactor = longestSide > _maxRecognitionLongSide
        ? _maxRecognitionLongSide / longestSide
        : 1.0;
    final targetWidth = math.max(8, (cropWidth * scaleFactor).round());
    final targetHeight = math.max(8, (cropHeight * scaleFactor).round());

    if (!isFullSelection) {
      _appendRecognitionLog('已按选区裁切，区域尺寸 ${cropWidth}x$cropHeight。');
    }
    if (scaleFactor < 0.999) {
      _appendRecognitionLog(
        '检测到图片较大，按 ${targetWidth}x$targetHeight 输出，减少上传体积。',
      );
    } else {
      _appendRecognitionLog('当前分辨率在阈值内，不额外缩放。');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      sourceImage,
      cropRect,
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(targetWidth, targetHeight);
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    sourceImage.dispose();
    croppedImage.dispose();
    picture.dispose();

    if (byteData == null) {
      _appendRecognitionLog('图片处理结果为空，回退到原图上传。');
      return imagePath;
    }

    final processedBytes = byteData.buffer.asUint8List();
    final processedSize = processedBytes.length;
    if (isFullSelection && processedSize >= originalSize) {
      _appendRecognitionLog(
        '缩放后的 PNG 仍不比原图更小，继续使用原图上传。',
      );
      return imagePath;
    }

    final cropFile = File(
      '${Directory.systemTemp.path}/wordsnap-selection-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await cropFile.writeAsBytes(processedBytes);
    _appendRecognitionLog(
      '已生成上传图片 ${_formatBytes(processedSize)}，${isFullSelection ? '替换原图上传' : '将按选区结果上传'}。',
    );
    return cropFile.path;
  }

  Rect _normalizeSelection(Rect selection) {
    return Rect.fromLTRB(
      _clampDouble(selection.left, 0.0, 1.0),
      _clampDouble(selection.top, 0.0, 1.0),
      _clampDouble(selection.right, 0.0, 1.0),
      _clampDouble(selection.bottom, 0.0, 1.0),
    );
  }

  bool _isFullImageSelection(Rect selection) {
    return selection.left <= 0.01 &&
        selection.top <= 0.01 &&
        selection.right >= 0.99 &&
        selection.bottom >= 0.99;
  }

  void _appendRecognitionLog(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _recognitionLogs.add(
        _RecognitionLogItem(
          timeLabel: _formatCurrentTime(),
          message: message,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_recognitionLogScrollController.hasClients) {
        return;
      }
      _recognitionLogScrollController.animateTo(
        _recognitionLogScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _RecognitionLogItem {
  const _RecognitionLogItem({
    required this.timeLabel,
    required this.message,
  });

  final String timeLabel;
  final String message;
}

class _RecognitionProgressOverlay extends StatelessWidget {
  const _RecognitionProgressOverlay({
    required this.isRecognizing,
    required this.logs,
    required this.scrollController,
    required this.onClose,
  });

  final bool isRecognizing;
  final List<_RecognitionLogItem> logs;
  final ScrollController scrollController;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x9909101F),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxDialogHeight = math.max(0.0, constraints.maxHeight - 40);
              final maxLogHeight = math.max(
                120.0,
                math.min(320.0, constraints.maxHeight * 0.46),
              );

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: maxDialogHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Material(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isRecognizing) ...[
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    isRecognizing ? '正在识别图片' : '识别日志',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                if (!isRecognizing)
                                  IconButton(
                                    onPressed: onClose,
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: '关闭日志',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              logs.isEmpty
                                  ? '正在准备识别环境...'
                                  : logs.last.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  minHeight: math.min(180.0, maxLogHeight),
                                  maxHeight: maxLogHeight,
                                ),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F8FC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE4EAF5),
                                  ),
                                ),
                                child: logs.isEmpty
                                    ? Center(
                                        child: Text(
                                          '日志准备中...',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      )
                                    : ListView.separated(
                                        controller: scrollController,
                                        itemCount: logs.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final item = logs[index];
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.timeLabel,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  color: AppTheme.primaryBlue,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  item.message,
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: AppTheme.ink,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ),
                            if (!isRecognizing) ...[
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: onClose,
                                  child: const Text('关闭'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecognitionImageSelector extends StatelessWidget {
  const _RecognitionImageSelector({
    required this.imagePath,
    required this.selection,
    required this.onSelectionChanged,
    required this.onOpenFullscreen,
  });

  final String imagePath;
  final Rect selection;
  final ValueChanged<Rect> onSelectionChanged;
  final VoidCallback onOpenFullscreen;

  static const double _minSelectionSize = 0.16;
  static const double _handleSize = 22;
  static final Map<String, Future<Size>> _sizeFutures =
      <String, Future<Size>>{};

  @override
  Widget build(BuildContext context) {
    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      return Container(
        height: 300,
        color: const Color(0xFFF7F7F7),
        alignment: Alignment.center,
        child: const Text('图片文件已不存在，请重新拍照或重新导入。'),
      );
    }

    return FutureBuilder<Size>(
      future: _sizeFutures.putIfAbsent(
        imagePath,
        () => _loadImageSize(imageFile),
      ),
      builder: (context, snapshot) {
        final imageSize = snapshot.data;

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewWidth = constraints.maxWidth;
              final previewHeight =
                  _clampDouble(previewWidth * 0.68, 280.0, 420.0);
              final previewSize = Size(previewWidth, previewHeight);
              final imageRect = imageSize == null
                  ? Offset.zero & previewSize
                  : _containedImageRect(imageSize, previewSize);
              final selectionRect = _selectionToPreviewRect(
                selection,
                imageRect,
              );

              return SizedBox(
                height: previewHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF6F8FC),
                        ),
                        child: Image.file(imageFile, fit: BoxFit.contain),
                      ),
                    ),
                    if (imageSize != null) ...[
                      Positioned.fromRect(
                        rect: imageRect,
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SelectionScrimPainter(
                              selectionRect: Rect.fromLTWH(
                                selection.left * imageRect.width,
                                selection.top * imageRect.height,
                                selection.width * imageRect.width,
                                selection.height * imageRect.height,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: selectionRect,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            onSelectionChanged(
                              _moveSelection(
                                details.delta,
                                imageRect,
                              ),
                            );
                          },
                          child: CustomPaint(
                            painter: _SelectionBorderPainter(),
                          ),
                        ),
                      ),
                      _buildHandle(
                        rect: selectionRect,
                        alignment: Alignment.topLeft,
                        imageRect: imageRect,
                      ),
                      _buildHandle(
                        rect: selectionRect,
                        alignment: Alignment.topRight,
                        imageRect: imageRect,
                      ),
                      _buildHandle(
                        rect: selectionRect,
                        alignment: Alignment.bottomLeft,
                        imageRect: imageRect,
                      ),
                      _buildHandle(
                        rect: selectionRect,
                        alignment: Alignment.bottomRight,
                        imageRect: imageRect,
                      ),
                    ],
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: IconButton(
                          tooltip: '查看大图',
                          onPressed: onOpenFullscreen,
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHandle({
    required Rect rect,
    required Alignment alignment,
    required Rect imageRect,
  }) {
    final center = Offset(
      rect.left + (alignment.x + 1) * rect.width / 2,
      rect.top + (alignment.y + 1) * rect.height / 2,
    );

    return Positioned(
      left: center.dx - _handleSize / 2,
      top: center.dy - _handleSize / 2,
      width: _handleSize,
      height: _handleSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          onSelectionChanged(
            _resizeSelection(details.delta, imageRect, alignment),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryBlue, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Rect _moveSelection(Offset delta, Rect imageRect) {
    final dx = delta.dx / imageRect.width;
    final dy = delta.dy / imageRect.height;
    final left = _clampDouble(
      selection.left + dx,
      0.0,
      1.0 - selection.width,
    );
    final top = _clampDouble(
      selection.top + dy,
      0.0,
      1.0 - selection.height,
    );

    return Rect.fromLTWH(left, top, selection.width, selection.height);
  }

  Rect _resizeSelection(
    Offset delta,
    Rect imageRect,
    Alignment alignment,
  ) {
    final dx = delta.dx / imageRect.width;
    final dy = delta.dy / imageRect.height;
    var left = selection.left;
    var top = selection.top;
    var right = selection.right;
    var bottom = selection.bottom;

    if (alignment.x < 0) {
      left = _clampDouble(left + dx, 0.0, right - _minSelectionSize);
    } else {
      right = _clampDouble(right + dx, left + _minSelectionSize, 1.0);
    }

    if (alignment.y < 0) {
      top = _clampDouble(top + dy, 0.0, bottom - _minSelectionSize);
    } else {
      bottom = _clampDouble(bottom + dy, top + _minSelectionSize, 1.0);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _selectionToPreviewRect(Rect selection, Rect imageRect) {
    return Rect.fromLTWH(
      imageRect.left + selection.left * imageRect.width,
      imageRect.top + selection.top * imageRect.height,
      selection.width * imageRect.width,
      selection.height * imageRect.height,
    );
  }

  Rect _containedImageRect(Size imageSize, Size previewSize) {
    final fittedSizes = applyBoxFit(BoxFit.contain, imageSize, previewSize);
    final destination = fittedSizes.destination;
    return Rect.fromLTWH(
      (previewSize.width - destination.width) / 2,
      (previewSize.height - destination.height) / 2,
      destination.width,
      destination.height,
    );
  }

  Future<Size> _loadImageSize(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    return size;
  }
}

class _SelectionScrimPainter extends CustomPainter {
  const _SelectionScrimPainter({required this.selectionRect});

  final Rect selectionRect;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.16);
    final fullPath = Path()..addRect(Offset.zero & size);
    final selectionPath = Path()..addRect(selectionRect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, selectionPath),
      scrim,
    );
  }

  @override
  bool shouldRepaint(_SelectionScrimPainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}

class _SelectionBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final rect = Offset.zero & size;
    const dash = 10.0;
    const gap = 6.0;

    _drawDashedLine(canvas, paint, rect.topLeft, rect.topRight, dash, gap);
    _drawDashedLine(canvas, paint, rect.topRight, rect.bottomRight, dash, gap);
    _drawDashedLine(canvas, paint, rect.bottomRight, rect.bottomLeft, dash, gap);
    _drawDashedLine(canvas, paint, rect.bottomLeft, rect.topLeft, dash, gap);
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dash,
    double gap,
  ) {
    final delta = end - start;
    final distance = delta.distance;
    final direction = delta / distance;
    var progress = 0.0;

    while (progress < distance) {
      final segmentEnd = math.min(progress + dash, distance);
      canvas.drawLine(
        start + direction * progress,
        start + direction * segmentEnd,
        paint,
      );
      progress += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_SelectionBorderPainter oldDelegate) => false;
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      return Container(
        height: 220,
        color: const Color(0xFFF7F7F7),
        alignment: Alignment.center,
        child: const Text('图片文件已不存在，请重新拍照或重新导入。'),
      );
    }

    return InkWell(
      onTap: () {
        CompatibleNavigator.push<void>(
          context,
          _FullImagePreviewPage(imagePath: imagePath),
          transitionType: PageTransitionType.slideUp,
        );
      },
      child: Stack(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Image.file(imageFile, fit: BoxFit.cover),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullImagePreviewPage extends StatelessWidget {
  const _FullImagePreviewPage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final imageFile = File(imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('图片预览'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: imageFile.existsSync()
              ? InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                  ),
                )
              : const Text(
                  '图片文件已不存在，请重新拍照或重新导入。',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}

class RecognitionResultPage extends StatefulWidget {
  const RecognitionResultPage({
    super.key,
    required this.demoService,
    required this.settingsService,
    required this.capture,
  });

  final WordSnapDemoService demoService;
  final AppSettingsService settingsService;
  final RecognitionCapture capture;

  @override
  State<RecognitionResultPage> createState() => _RecognitionResultPageState();
}

class _RecognitionResultPageState extends State<RecognitionResultPage> {
  late final Set<String> _selectedWords;

  @override
  void initState() {
    super.initState();
    _selectedWords = widget.capture.recognizedWords
        .where((entry) => entry.hasResolvedMeaning)
        .map((entry) => entry.normalizedWord)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.demoService.loadRecognizedWords(
      capture: widget.capture,
    );
    final unresolvedCount =
        words.where((entry) => !entry.hasResolvedMeaning).length;
    final selectedCount = words
        .where((entry) => _selectedWords.contains(entry.normalizedWord))
        .length;
    final selectableCount = words
        .where(
          (entry) =>
              _selectedWords.contains(entry.normalizedWord) &&
              entry.hasResolvedMeaning,
        )
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('识别结果')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: ResponsiveHelper.screenPadding(
            context,
          ).add(const EdgeInsets.only(bottom: 12)),
          children: [
            if (widget.capture.imagePath != null) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: _SelectedImagePreview(
                  imagePath: widget.capture.imagePath!,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '共抽取 ${words.length} 个英文单词',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.primaryBlue,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${widget.capture.sourceTypeLabel} · ${widget.capture.sourceLabel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: widget.capture.qualityScore,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.capture.isLowQuality
                            ? AppTheme.warning
                            : AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.capture.suggestion),
                    const SizedBox(height: 12),
                    Text(
                      '已选择 $selectedCount 个单词，其中 $selectableCount 个可用于出题',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (words.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '当前还没有抽取到可用于出题的英文单词，请重拍或调整图片后再试。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (unresolvedCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '有 $unresolvedCount 个单词暂未匹配本地词义，会保留在结果中，但当前不会参与考试。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildWordSelectionCard(context, words),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentRed,
                      side: const BorderSide(color: AppTheme.accentRed),
                    ),
                    child: const Text('重拍'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectableCount >= 2 ? _openExamSetup : null,
                    child: const Text('开始考试'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordSelectionCard(
    BuildContext context,
    List<WordEntry> words,
  ) {
    final selectedCount = words
        .where((entry) => _selectedWords.contains(entry.normalizedWord))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('单词确认表', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '已勾选 $selectedCount / ${words.length} 个单词，勾选项会保存并用于本次考试。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (words.isEmpty)
              Text(
                '当前没有可展示的英文单词，请重拍或调整图片后再试。',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = math.max(constraints.maxWidth, 560.0);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Table(
                        border: TableBorder.all(
                          color: const Color(0xFFD7E3FF),
                        ),
                        columnWidths: const {
                          0: FixedColumnWidth(48),
                          1: FlexColumnWidth(1.1),
                          2: FlexColumnWidth(1.35),
                          3: FlexColumnWidth(2.25),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          _buildWordHeaderRow(context),
                          ...words.map(
                            (entry) => _buildWordTableRow(context, entry),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  TableRow _buildWordHeaderRow(BuildContext context) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFEFF5FF)),
      children: [
        _buildWordTableCell(context, '选择', isHeader: true),
        _buildWordTableCell(context, '单词', isHeader: true),
        _buildWordTableCell(context, '音标', isHeader: true),
        _buildWordTableCell(context, '释义', isHeader: true),
      ],
    );
  }

  TableRow _buildWordTableRow(BuildContext context, WordEntry entry) {
    final selected = _selectedWords.contains(entry.normalizedWord);
    final canSelect = entry.hasResolvedMeaning;
    final phonetic = entry.phonetic == WordEntry.unresolvedPhonetic
        ? '待补充'
        : entry.phonetic;

    return TableRow(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF5F9FF) : Colors.white,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: Checkbox(
              value: selected,
              onChanged: canSelect
                  ? (value) {
                      _toggleSelectedWord(entry, value ?? false);
                    }
                  : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        _buildWordTableCell(context, entry.word),
        _buildWordTableCell(context, phonetic),
        _buildWordTableCell(context, entry.meaning),
      ],
    );
  }

  Widget _buildWordTableCell(
    BuildContext context,
    String text, {
    bool isHeader = false,
  }) {
    final style = isHeader
        ? Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryBlue,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: style,
        softWrap: true,
      ),
    );
  }

  void _toggleSelectedWord(WordEntry entry, bool selected) {
    setState(() {
      if (selected) {
        _selectedWords.add(entry.normalizedWord);
      } else {
        _selectedWords.remove(entry.normalizedWord);
      }
    });
  }

  Future<void> _openExamSetup() async {
    final selectedWords = widget.capture.recognizedWords
        .where(
          (entry) =>
              _selectedWords.contains(entry.normalizedWord) &&
              entry.hasResolvedMeaning,
        )
        .toList(growable: false);

    await CompatibleNavigator.push<void>(
      context,
      ExamSetupPage(
        demoService: widget.demoService,
        settingsService: widget.settingsService,
        book: widget.demoService.loadDefaultBook(),
        initialScope: ExamWordScope.recognized,
        initialWords: selectedWords,
        capture: widget.capture,
      ),
      transitionType: PageTransitionType.slide,
    );
  }
}

class ExamSetupPage extends StatefulWidget {
  const ExamSetupPage({
    super.key,
    required this.demoService,
    required this.settingsService,
    required this.book,
    this.initialScope = ExamWordScope.wordBook,
    this.initialWords,
    this.capture,
  });

  final WordSnapDemoService demoService;
  final AppSettingsService settingsService;
  final WordBook book;
  final ExamWordScope initialScope;
  final List<WordEntry>? initialWords;
  final RecognitionCapture? capture;

  @override
  State<ExamSetupPage> createState() => _ExamSetupPageState();
}

class _ExamSetupPageState extends State<ExamSetupPage> {
  late StudyPreferences _preferences;
  late ExamWordScope _scope;
  late ExamMode _examMode;

  @override
  void initState() {
    super.initState();
    _preferences = widget.settingsService.studyPreferences;
    _scope = widget.initialScope;
    _examMode = _preferences.examMode;
  }

  @override
  Widget build(BuildContext context) {
    final recognizedWords =
        widget.initialWords ?? widget.demoService.loadRecognizedWords();
    final reviewQueueWords = widget.demoService.loadReviewQueueWords();
    final wordBookWords = widget.book.words;
    final recognizedScopeTitle =
        widget.capture?.sourceLabel ??
        widget.demoService.latestCapture.sourceLabel;
    final availableWords = _wordsForScope(
      recognizedWords: recognizedWords,
      wordBookWords: wordBookWords,
      reviewQueueWords: reviewQueueWords,
    );
    final questionCount = availableWords.length;

    return Scaffold(
      appBar: AppBar(title: const Text('开始考试')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: ResponsiveHelper.screenPadding(
            context,
          ).add(const EdgeInsets.only(bottom: 12)),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('出题范围', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _ScopeOption(
                      title: recognizedScopeTitle,
                      subtitle: '根据这次单词快照中的全部单词出题',
                      count: recognizedWords.length,
                      selected: _scope == ExamWordScope.recognized,
                      onTap: recognizedWords.length >= 2
                          ? () {
                              setState(() {
                                _scope = ExamWordScope.recognized;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _ScopeOption(
                      title: ExamWordScope.wordBook.label,
                      subtitle: '使用默认词本中的全部单词',
                      count: wordBookWords.length,
                      selected: _scope == ExamWordScope.wordBook,
                      onTap: () {
                        setState(() {
                          _scope = ExamWordScope.wordBook;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _ScopeOption(
                      title: ExamWordScope.reviewQueue.label,
                      subtitle: '优先巩固错题和待复习单词',
                      count: reviewQueueWords.length,
                      selected: _scope == ExamWordScope.reviewQueue,
                      onTap: reviewQueueWords.length >= 2
                          ? () {
                              setState(() {
                                _scope = ExamWordScope.reviewQueue;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('考试设置', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final singleButton = _SegmentButton(
                          label: ExamMode.singlePlayer.label,
                          icon: Icons.person_rounded,
                          selected: _examMode == ExamMode.singlePlayer,
                          onTap: () {
                            setState(() {
                              _examMode = ExamMode.singlePlayer;
                            });
                          },
                        );
                        final twoPlayerButton = _SegmentButton(
                          label: ExamMode.twoPlayer.label,
                          icon: Icons.groups_2_rounded,
                          selected: _examMode == ExamMode.twoPlayer,
                          onTap: () {
                            setState(() {
                              _examMode = ExamMode.twoPlayer;
                            });
                          },
                        );

                        if (constraints.maxWidth < 420) {
                          return Column(
                            children: [
                              singleButton,
                              const SizedBox(height: 12),
                              twoPlayerButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: singleButton),
                            const SizedBox(width: 12),
                            Expanded(child: twoPlayerButton),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _ConfigRow(label: '题目数量', value: '$questionCount 题'),
                    _ConfigRow(label: '答案数量', value: '${_examMode.optionCount} 个'),
                    _ConfigRow(label: '考试模式', value: _examMode.label),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: availableWords.length >= 2 ? _startExam : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              child: Text(
                availableWords.length >= 2 ? '开始考试' : '至少需要 2 个单词才能生成考试',
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<WordEntry> _wordsForScope({
    required List<WordEntry> recognizedWords,
    required List<WordEntry> wordBookWords,
    required List<WordEntry> reviewQueueWords,
  }) {
    switch (_scope) {
      case ExamWordScope.recognized:
        return recognizedWords;
      case ExamWordScope.wordBook:
        return wordBookWords;
      case ExamWordScope.reviewQueue:
        return reviewQueueWords;
    }
  }

  Future<void> _startExam() async {
    final book = widget.demoService.loadDefaultBook();
    final sourceWords = _scope == ExamWordScope.wordBook
        ? book.words
        : _wordsForScope(
            recognizedWords:
                widget.initialWords ?? widget.demoService.loadRecognizedWords(),
            wordBookWords: book.words,
            reviewQueueWords: widget.demoService.loadReviewQueueWords(),
          );

    final safeQuestionCount = sourceWords.length;
    final safePreferences = _preferences.copyWith(
      questionCount: safeQuestionCount,
      optionCount: _examMode.optionCount,
      allowMultiple: false,
      randomOrder: true,
      examMode: _examMode,
    );

    await widget.settingsService.saveStudyPreferences(safePreferences);
    if (_scope == ExamWordScope.recognized) {
      await widget.demoService.addWordsToDefaultBook(sourceWords);
    }
    final session = widget.demoService.createExam(
      book: book,
      preferences: safePreferences,
      sourceWords: sourceWords,
      distractorPool: _scope == ExamWordScope.recognized
          ? widget.capture?.distractorPool
          : null,
      scope: _scope,
      sourceLabel: _scope == ExamWordScope.recognized
          ? (widget.capture?.sourceLabel ??
                widget.demoService.latestCapture.sourceLabel)
          : _scope.label,
    );

    if (!mounted) {
      return;
    }

    await CompatibleNavigator.push<void>(
      context,
      ExamPage(session: session, demoService: widget.demoService),
      transitionType: PageTransitionType.slide,
    );
  }
}

class ExamPage extends StatefulWidget {
  const ExamPage({super.key, required this.session, required this.demoService});

  final ExamSession session;
  final WordSnapDemoService demoService;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final NativePronunciationService _pronunciationService =
      const NativePronunciationService();
  final NativeAnswerFeedbackService _answerFeedbackService =
      const NativeAnswerFeedbackService();
  final Map<String, WordPronunciationDetail?> _pronunciationDetails =
      <String, WordPronunciationDetail?>{};
  final Set<String> _loadingPronunciationDetails = <String>{};
  int _currentIndex = 0;
  bool _isAdvancing = false;

  ExamQuestion get _currentQuestion => widget.session.questions[_currentIndex];

  @override
  void initState() {
    super.initState();
    _loadPronunciationDetail(_currentQuestion.word);
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final isFavorite = widget.demoService.isFavorite(question.word);
    final pronunciationKey = _pronunciationCacheKey(question.word);
    final pronunciationDetail = _pronunciationDetails[pronunciationKey];
    final isLoadingPronunciation =
        _loadingPronunciationDetails.contains(pronunciationKey);

    final isTwoPlayer =
        widget.session.preferences.examMode == ExamMode.twoPlayer;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1}/${widget.session.questions.length}'),
        actions: [
          IconButton(
            onPressed: () async {
              await widget.demoService.toggleFavoriteWord(question.word);
              if (mounted) {
                setState(() {});
              }
            },
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFavorite ? AppTheme.warning : null,
            ),
            tooltip: '收藏当前单词',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: ResponsiveHelper.screenPadding(context),
          child: isTwoPlayer
              ? _buildTwoPlayerExam(
                  context: context,
                  question: question,
                  pronunciationDetail: pronunciationDetail,
                  isLoadingPronunciation: isLoadingPronunciation,
                )
              : _buildSinglePlayerExam(
                  context: context,
                  question: question,
                  pronunciationDetail: pronunciationDetail,
                  isLoadingPronunciation: isLoadingPronunciation,
                ),
        ),
      ),
    );
  }

  Widget _buildSinglePlayerExam({
    required BuildContext context,
    required ExamQuestion question,
    required WordPronunciationDetail? pronunciationDetail,
    required bool isLoadingPronunciation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionHeader(
          progress: (_currentIndex + 1) / widget.session.questions.length,
          sourceLabel: widget.session.sourceLabel,
          word: question.word,
          phonetic: question.phonetic,
          pronunciationDetail: pronunciationDetail,
          isLoadingPronunciation: isLoadingPronunciation,
          onPlay: (accent) => _speakWord(question.word, accent),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 24) / 3;
              final tileHeight = math.max(138.0, tileWidth * 1.12);

              return GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: question.options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, index) {
                  final selected = question.userSelections.contains(index);
                  return _OptionButton(
                    label: question.options[index],
                    selected: selected,
                    onTap: () => _handleAnswerTap(index),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTwoPlayerExam({
    required BuildContext context,
    required ExamQuestion question,
    required WordPronunciationDetail? pronunciationDetail,
    required bool isLoadingPronunciation,
  }) {
    final redScore = _playerScore(ExamPlayerSide.red);
    final blueScore = _playerScore(ExamPlayerSide.blue);
    final selectedEntry = question.playerSelections.entries.isEmpty
        ? null
        : question.playerSelections.entries.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionHeader(
          progress: (_currentIndex + 1) / widget.session.questions.length,
          sourceLabel: widget.session.sourceLabel,
          word: question.word,
          phonetic: question.phonetic,
          pronunciationDetail: pronunciationDetail,
          isLoadingPronunciation: isLoadingPronunciation,
          onPlay: (accent) => _speakWord(question.word, accent),
        ),
        const SizedBox(height: 14),
        _VersusScoreboard(redScore: redScore, blueScore: blueScore),
        const SizedBox(height: 14),
        Expanded(
          child: _TwoPlayerSharedAnswerGrid(
            question: question,
            selectedSide: selectedEntry?.key,
            selectedIndex: selectedEntry?.value,
            onOptionTap: (side, index) => _handleMultiplayerAnswerTap(
              side: side,
              index: index,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAnswerTap(int index) async {
    if (_isAdvancing) {
      return;
    }

    final question = _currentQuestion;
    if (question.userSelections.contains(index)) {
      _isAdvancing = true;
      await _playAnswerSelectionCue();
      await _goNext();
      return;
    }

    setState(() {
      question.userSelections
        ..clear()
        ..add(index);
    });

    await _playAnswerSelectionCue();
  }

  Future<void> _handleMultiplayerAnswerTap({
    required ExamPlayerSide side,
    required int index,
  }) async {
    if (_isAdvancing) {
      return;
    }

    final question = _currentQuestion;
    if (question.isMultiplayerResolved || question.playerSelections.isNotEmpty) {
      return;
    }

    final isCorrect = question.correctIndexes.contains(index);
    setState(() {
      question.playerSelections[side] = index;
      if (isCorrect) {
        question.multiplayerWinner = side;
      }
    });

    _isAdvancing = true;
    await _playAnswerSelectionCue();
    await Future<void>.delayed(
      Duration(milliseconds: isCorrect ? 650 : 900),
    );
    if (!mounted || !identical(question, _currentQuestion)) {
      return;
    }
    await _goNext();
  }

  int _playerScore(ExamPlayerSide side) {
    return widget.session.questions
        .where((question) => question.multiplayerWinner == side)
        .length;
  }

  Future<void> _playAnswerSelectionCue() async {
    try {
      await _answerFeedbackService.playSelectionCue();
    } catch (_) {
      // Haptics already ran before the native sound request; keep failures quiet.
    }
  }

  Future<void> _loadPronunciationDetail(String word) async {
    final cacheKey = _pronunciationCacheKey(word);
    if (cacheKey.isEmpty ||
        _pronunciationDetails.containsKey(cacheKey) ||
        _loadingPronunciationDetails.contains(cacheKey)) {
      return;
    }

    setState(() {
      _loadingPronunciationDetails.add(cacheKey);
    });

    final detail = await _pronunciationService.fetchWordDetail(word);
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingPronunciationDetails.remove(cacheKey);
      _pronunciationDetails[cacheKey] = detail;
    });
  }

  Future<void> _speakWord(
    String word,
    WordPronunciationAccent accent,
  ) async {
    try {
      await _pronunciationService.playWord(word, accent: accent);
    } on PlatformException catch (error) {
      _showPronunciationError(error.message ?? '系统发音服务暂时不可用。');
    } on NativePronunciationException catch (error) {
      _showPronunciationError(error.message);
    } catch (_) {
      _showPronunciationError('当前无法播放单词发音，请稍后重试。');
    }
  }

  void _showPronunciationError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _goNext() async {
    if (_currentIndex < widget.session.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAdvancing = false;
      });
      _loadPronunciationDetail(_currentQuestion.word);
      return;
    }

    final summary = widget.demoService.summarizeExam(widget.session);
    await widget.demoService.saveStudyRecord(
      session: widget.session,
      summary: summary,
    );

    if (!mounted) {
      return;
    }

    await CompatibleNavigator.pushReplacement<void, void>(
      context,
      ExamResultPage(
        session: widget.session,
        summary: summary,
        demoService: widget.demoService,
      ),
      transitionType: PageTransitionType.slide,
    );
  }

  String _pronunciationCacheKey(String word) => word.trim().toLowerCase();
}

class ExamResultPage extends StatefulWidget {
  const ExamResultPage({
    super.key,
    required this.session,
    required this.summary,
    required this.demoService,
  });

  final ExamSession session;
  final StudySummary summary;
  final WordSnapDemoService demoService;

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  static const int _mistakePreviewLimit = 3;

  final GlobalKey _shareBoundaryKey = GlobalKey();
  final NativeShareService _shareService = const NativeShareService();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.session.preferences.examMode == ExamMode.twoPlayer) {
      return _buildTwoPlayerResult(context);
    }

    final session = widget.session;
    final summary = widget.summary;
    final demoService = widget.demoService;
    final score = '${summary.correctCount} / ${summary.totalQuestions}';
    final total = summary.bucketCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final reviewCount = demoService.loadReviewQueueWords().length;
    final mistakePreview = summary.mistakes
        .take(_mistakePreviewLimit)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('考试完成'),
        actions: [
          IconButton(
            onPressed: _isSharing ? null : _shareResultImage,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: '一键分享',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: ResponsiveHelper.screenPadding(
              context,
            ).add(const EdgeInsets.only(bottom: 12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RepaintBoundary(
                  key: _shareBoundaryKey,
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in_rounded,
                      size: 92,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '太棒了，你完成了本次考试',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      score,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppTheme.primaryBlue,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '正确率 ${(summary.accuracy * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryBlue,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResultMetric(
                          label: '正确',
                          value: '${summary.correctCount}',
                          color: AppTheme.success,
                        ),
                        _ResultMetric(
                          label: '错误',
                          value: '${summary.wrongCount}',
                          color: AppTheme.accentRed,
                        ),
                        _ResultMetric(
                          label: '待巩固',
                          value: '${summary.skippedCount}',
                          color: AppTheme.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _ConfigRow(label: '题目来源', value: session.sourceLabel),
                    _ConfigRow(label: '出题范围', value: session.scope.label),
                    _ConfigRow(
                      label: '复习队列',
                      value: '$reviewCount 个待复习词',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '错题回顾',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (summary.mistakes.isNotEmpty)
                          Text(
                            '已自动加入复习',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.primaryBlue),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (summary.mistakes.isEmpty)
                      Text(
                        '这一轮没有错题，状态很好。',
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    else ...[
                      ...mistakePreview.asMap().entries.map((entry) {
                        return _CompactMistakeReviewTile(
                          index: entry.key,
                          item: entry.value,
                          isLast: entry.key == mistakePreview.length - 1 &&
                              summary.mistakes.length <= _mistakePreviewLimit,
                        );
                      }),
                      if (summary.mistakes.length > _mistakePreviewLimit)
                        Text(
                          '还有 ${summary.mistakes.length - _mistakePreviewLimit} 个词已收进复习队列，之后可直接用“复习队列”出题。',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.mutedInk),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 540;
                    final chart = SizedBox(
                      width: 160,
                      height: 160,
                      child: CustomPaint(
                        painter: _DonutChartPainter(
                          values: [
                            summary.bucketCounts[MemoryBucket.mastered] ?? 0,
                            summary.bucketCounts[MemoryBucket.fuzzy] ?? 0,
                            summary.bucketCounts[MemoryBucket.uncertain] ?? 0,
                            summary.bucketCounts[MemoryBucket.unseen] ?? 0,
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const Text('总单词'),
                            ],
                          ),
                        ),
                      ),
                    );
                    const legend = Column(
                      children: [
                        _LegendRow(label: '掌握（正确）', color: AppTheme.primaryBlue),
                        _LegendRow(label: '不熟悉（错误）', color: AppTheme.accentRed),
                        _LegendRow(label: '待巩固（不确定）', color: AppTheme.warning),
                        _LegendRow(label: '没学过', color: Color(0xFF9CA3AF)),
                      ],
                    );

                    if (isCompact) {
                      return Column(
                        children: [chart, const SizedBox(height: 16), legend],
                      );
                    }

                    return Row(
                      children: [
                        chart,
                        const SizedBox(width: 16),
                        const Expanded(child: legend),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: summary.bucketCounts.entries.map((entry) {
                    final value = entry.value;
                    final percent = total == 0 ? 0.0 : value / total;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${entry.key.label} ${entry.value}'),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('学习建议', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(
                      _buildStudyRecommendation(summary, reviewCount),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSharing ? null : _shareResultImage,
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(_isSharing ? '正在生成图片' : '一键分享'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('返回首页'),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoPlayerResult(BuildContext context) {
    final session = widget.session;
    final summary = widget.summary;
    final redScore = _playerScore(ExamPlayerSide.red);
    final blueScore = _playerScore(ExamPlayerSide.blue);
    final noPointCount = math.max(
      0,
      session.questions.length - redScore - blueScore,
    );
    final winnerLabel = redScore == blueScore
        ? '平局'
        : redScore > blueScore
            ? '红方获胜'
            : '蓝方获胜';
    final winnerColor = redScore == blueScore
        ? AppTheme.warning
        : redScore > blueScore
            ? AppTheme.accentRed
            : AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('双人结算'),
        actions: [
          IconButton(
            onPressed: _isSharing ? null : _shareResultImage,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: '一键分享',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: ResponsiveHelper.screenPadding(
              context,
            ).add(const EdgeInsets.only(bottom: 12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RepaintBoundary(
                  key: _shareBoundaryKey,
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.emoji_events_rounded,
                                  size: 88,
                                  color: winnerColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  winnerLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                _TwoPlayerFinalScore(
                                  redScore: redScore,
                                  blueScore: blueScore,
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _ResultMetric(
                                      label: '红方',
                                      value: '$redScore',
                                      color: AppTheme.accentRed,
                                    ),
                                    _ResultMetric(
                                      label: '蓝方',
                                      value: '$blueScore',
                                      color: AppTheme.primaryBlue,
                                    ),
                                    _ResultMetric(
                                      label: '未得分',
                                      value: '$noPointCount',
                                      color: AppTheme.warning,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _ConfigRow(
                                  label: '考试模式',
                                  value: session.preferences.examMode.label,
                                ),
                                _ConfigRow(
                                  label: '题目来源',
                                  value: session.sourceLabel,
                                ),
                                _ConfigRow(
                                  label: '题目数量',
                                  value: '${summary.totalQuestions} 题',
                                ),
                                _ConfigRow(
                                  label: '答案数量',
                                  value: '${session.preferences.optionCount} 个',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '得分回顾',
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                ...session.questions
                                    .asMap()
                                    .entries
                                    .take(6)
                                    .map((entry) {
                                  return _TwoPlayerRoundTile(
                                    index: entry.key,
                                    question: entry.value,
                                  );
                                }),
                                if (session.questions.length > 6)
                                  Text(
                                    '还有 ${session.questions.length - 6} 题已计入最终比分。',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.mutedInk,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareResultImage,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: Text(_isSharing ? '正在生成图片' : '一键分享'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('返回首页'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _playerScore(ExamPlayerSide side) {
    return widget.session.questions
        .where((question) => question.multiplayerWinner == side)
        .length;
  }

  Future<void> _shareResultImage() async {
    if (_isSharing) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject =
          _shareBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('result image is not ready');
      }

      final pixelRatio = math.min(MediaQuery.of(context).devicePixelRatio, 3.0);
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('unable to encode result image');
      }

      final bytes = Uint8List.view(
        byteData.buffer,
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/wordsnap-result-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      final summary = widget.summary;
      final shareText = widget.session.preferences.examMode == ExamMode.twoPlayer
          ? 'WordSnap 双人对战：红方 ${_playerScore(ExamPlayerSide.red)} 分，蓝方 ${_playerScore(ExamPlayerSide.blue)} 分。'
          : 'WordSnap 背单词成绩：${summary.correctCount}/${summary.totalQuestions}，正确率 ${(summary.accuracy * 100).round()}%。';
      await _shareService.shareImage(
        imagePath: file.path,
        text: shareText,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享图片生成失败，请稍后重试。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }
}

class _CompactMistakeReviewTile extends StatelessWidget {
  const _CompactMistakeReviewTile({
    required this.index,
    required this.item,
    required this.isLast,
  });

  final int index;
  final MistakeReviewItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4EAF5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.word,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '正确：${item.correctMeaning}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.selectedMeanings.isEmpty
                        ? '选择：未选择'
                        : '选择：${item.selectedMeanings.join('、')}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppTheme.mutedInk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _buildStudyRecommendation(StudySummary summary, int reviewCount) {
  if (summary.wrongCount >= summary.correctCount) {
    return '这轮错题已自动加入复习队列，可以直接用“复习队列”范围重新出一轮练习。当前待复习 $reviewCount 个单词。';
  }
  if (summary.skippedCount > 0) {
    return '你已经掌握了大部分内容，待巩固词已自动收进复习队列，下一轮优先强化这些不确定项。';
  }
  return '当前掌握情况不错，可以继续从拍照识别导入新材料，扩大个人词本。';
}

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({
    super.key,
    required this.summary,
    required this.demoService,
  });

  final StudySummary summary;
  final WordSnapDemoService demoService;

  @override
  Widget build(BuildContext context) {
    final total = summary.bucketCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final reviewCount = demoService.loadReviewQueueWords().length;

    return Scaffold(
      appBar: AppBar(title: const Text('单词记忆分析')),
      body: ListView(
        padding: ResponsiveHelper.screenPadding(context),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 540;
                  final chart = SizedBox(
                    width: 160,
                    height: 160,
                    child: CustomPaint(
                      painter: _DonutChartPainter(
                        values: [
                          summary.bucketCounts[MemoryBucket.mastered] ?? 0,
                          summary.bucketCounts[MemoryBucket.fuzzy] ?? 0,
                          summary.bucketCounts[MemoryBucket.uncertain] ?? 0,
                          summary.bucketCounts[MemoryBucket.unseen] ?? 0,
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const Text('总单词'),
                          ],
                        ),
                      ),
                    ),
                  );
                  const legend = Column(
                    children: [
                      _LegendRow(label: '掌握（正确）', color: AppTheme.primaryBlue),
                      _LegendRow(label: '不熟悉（错误）', color: AppTheme.accentRed),
                      _LegendRow(label: '待巩固（不确定）', color: AppTheme.warning),
                      _LegendRow(label: '没学过', color: Color(0xFF9CA3AF)),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      children: [chart, const SizedBox(height: 16), legend],
                    );
                  }

                  return Row(
                    children: [
                      chart,
                      const SizedBox(width: 16),
                      const Expanded(child: legend),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: summary.bucketCounts.entries.map((entry) {
                  final value = entry.value;
                  final percent = total == 0 ? 0.0 : value / total;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.key.label} ${entry.value}'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('学习建议', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    _buildStudyRecommendation(summary, reviewCount),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class MistakeReviewPage extends StatelessWidget {
  const MistakeReviewPage({
    super.key,
    required this.summary,
    required this.demoService,
  });

  final StudySummary summary;
  final WordSnapDemoService demoService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: demoService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('错题详情')),
          body: ListView(
            padding: ResponsiveHelper.screenPadding(context),
            children: [
              if (summary.mistakes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '这一轮没有错题，状态很好。',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ...summary.mistakes.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final inReview = demoService.isInReviewQueue(item.word);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${item.word}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(item.phonetic),
                          const SizedBox(height: 10),
                          Text('正确答案：${item.correctMeaning}'),
                          const SizedBox(height: 8),
                          Text(
                            item.selectedMeanings.isEmpty
                                ? '你的选择：未选择'
                                : '你的选择：${item.selectedMeanings.join('、')}',
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (inReview) {
                                await demoService.removeWordFromReview(
                                  item.word,
                                );
                              } else {
                                await demoService.addWordToReview(item.word);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      inReview
                                          ? '${item.word} 已移出复习队列'
                                          : '${item.word} 已加入复习队列',
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              backgroundColor: inReview
                                  ? const Color(0xFFFDECEC)
                                  : const Color(0xFFE9F0FF),
                              foregroundColor: inReview
                                  ? AppTheme.accentRed
                                  : AppTheme.primaryBlue,
                            ),
                            child: Text(inReview ? '移出复习' : '加入复习'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE9F0FF)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.primaryBlue : const Color(0xFFE4EAF5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? AppTheme.primaryBlue : null),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected ? AppTheme.primaryBlue : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFE4EAF5),
            width: selected ? 2 : 1,
          ),
          color:
              selected ? const Color(0xFFE9F0FF) : Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count 词',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onTap == null
                        ? AppTheme.mutedInk
                        : AppTheme.primaryBlue,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({
    required this.progress,
    required this.sourceLabel,
    required this.word,
    required this.phonetic,
    required this.pronunciationDetail,
    required this.isLoadingPronunciation,
    required this.onPlay,
  });

  final double progress;
  final String sourceLabel;
  final String word;
  final String phonetic;
  final WordPronunciationDetail? pronunciationDetail;
  final bool isLoadingPronunciation;
  final ValueChanged<WordPronunciationAccent> onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
        ),
        const SizedBox(height: 16),
        Text(
          sourceLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                word,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(color: AppTheme.primaryBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PronunciationPanel(
          detail: pronunciationDetail,
          fallbackPhonetic: phonetic,
          isLoading: isLoadingPronunciation,
          onPlay: onPlay,
        ),
      ],
    );
  }
}

class _VersusScoreboard extends StatelessWidget {
  const _VersusScoreboard({required this.redScore, required this.blueScore});

  final int redScore;
  final int blueScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EAF5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlayerScoreBadge(
              score: redScore,
              color: AppTheme.accentRed,
              alignment: Alignment.centerLeft,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '比分',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: _PlayerScoreBadge(
              score: blueScore,
              color: AppTheme.primaryBlue,
              alignment: Alignment.centerRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerScoreBadge extends StatelessWidget {
  const _PlayerScoreBadge({
    required this.score,
    required this.color,
    required this.alignment,
  });

  final int score;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$score',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

class _TwoPlayerSharedAnswerGrid extends StatelessWidget {
  const _TwoPlayerSharedAnswerGrid({
    required this.question,
    required this.selectedSide,
    required this.selectedIndex,
    required this.onOptionTap,
  });

  final ExamQuestion question;
  final ExamPlayerSide? selectedSide;
  final int? selectedIndex;
  final void Function(ExamPlayerSide side, int index) onOptionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = question.isMultiplayerResolved;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  resolved
                      ? question.multiplayerWinner == null
                          ? '本题未得分'
                          : '本题已计分'
                      : '每题只能选择一侧',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!resolved)
                Text(
                  '点一次即锁定',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mutedInk,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileHeight = math.max(
                  88.0,
                  math.min(126.0, (constraints.maxHeight - 12) / 2),
                );

                return GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: question.options.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: tileHeight,
                  ),
                  itemBuilder: (context, index) {
                    final optionSelected = selectedIndex == index;
                    final optionSelectedSide = optionSelected ? selectedSide : null;
                    return _TwoPlayerSharedOptionButton(
                      label: question.options[index],
                      selectedSide: optionSelectedSide,
                      disabled: resolved,
                      onSideTap: (side) => onOptionTap(side, index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoPlayerSharedOptionButton extends StatelessWidget {
  const _TwoPlayerSharedOptionButton({
    required this.label,
    required this.selectedSide,
    required this.disabled,
    required this.onSideTap,
  });

  final String label;
  final ExamPlayerSide? selectedSide;
  final bool disabled;
  final ValueChanged<ExamPlayerSide> onSideTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = selectedSide == ExamPlayerSide.red
        ? AppTheme.accentRed
        : selectedSide == ExamPlayerSide.blue
            ? AppTheme.primaryBlue
            : null;
    final borderColor = selectedColor?.withValues(alpha: 0.42) ??
        const Color(0xFFDCE4F0);
    final labelColor = disabled && selectedSide == null
        ? AppTheme.mutedInk.withValues(alpha: 0.78)
        : const Color(0xFF2B3447);
    final boxShadow = selectedColor == null
        ? <BoxShadow>[
            const BoxShadow(
              color: Color(0x110F172A),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: selectedColor.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ];

    return Opacity(
      opacity: disabled && selectedSide == null ? 0.72 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: selectedSide != null ? 1.8 : 1,
            ),
            boxShadow: boxShadow,
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TwoPlayerOptionHalf(
                      side: ExamPlayerSide.red,
                      selected: selectedSide == ExamPlayerSide.red,
                      hasSelection: selectedSide != null,
                      disabled: disabled,
                      onTap: disabled
                          ? null
                          : () => onSideTap(ExamPlayerSide.red),
                    ),
                  ),
                  Container(
                    width: 1,
                    color: const Color(0xFFD9E3F2),
                  ),
                  Expanded(
                    child: _TwoPlayerOptionHalf(
                      side: ExamPlayerSide.blue,
                      selected: selectedSide == ExamPlayerSide.blue,
                      hasSelection: selectedSide != null,
                      disabled: disabled,
                      onTap: disabled
                          ? null
                          : () => onSideTap(ExamPlayerSide.blue),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoPlayerOptionHalf extends StatelessWidget {
  const _TwoPlayerOptionHalf({
    required this.side,
    required this.selected,
    required this.hasSelection,
    required this.disabled,
    required this.onTap,
  });

  final ExamPlayerSide side;
  final bool selected;
  final bool hasSelection;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = side == ExamPlayerSide.red
        ? AppTheme.accentRed
        : AppTheme.primaryBlue;
    final inactiveBecausePeerSelected = hasSelection && !selected;
    final backgroundColor = selected
        ? accentColor.withValues(alpha: 0.22)
        : inactiveBecausePeerSelected
            ? const Color(0xFFF8FAFF)
            : accentColor.withValues(alpha: 0.08);
    final foregroundColor = inactiveBecausePeerSelected
        ? AppTheme.mutedInk.withValues(alpha: 0.58)
        : accentColor;
    final Widget marker;
    if (selected) {
      marker = Container(
        key: ValueKey<String>('${side.name}-selected'),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 14,
          color: Colors.white,
        ),
      );
    } else {
      marker = Text(
        side == ExamPlayerSide.red ? '红' : '蓝',
        key: ValueKey<String>('${side.name}-idle'),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Align(
              alignment: side == ExamPlayerSide.red
                  ? Alignment.topLeft
                  : Alignment.topRight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: marker,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.03 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE6F0FF)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    selected ? AppTheme.primaryBlue : const Color(0xFFE4EAF5),
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              children: [
                if (selected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            height: 1.35,
                            color: selected ? AppTheme.primaryBlue : null,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PronunciationPanel extends StatelessWidget {
  const _PronunciationPanel({
    required this.detail,
    required this.fallbackPhonetic,
    required this.isLoading,
    required this.onPlay,
  });

  final WordPronunciationDetail? detail;
  final String fallbackPhonetic;
  final bool isLoading;
  final ValueChanged<WordPronunciationAccent> onPlay;

  @override
  Widget build(BuildContext context) {
    final normalizedFallback = fallbackPhonetic.trim();
    final ukPhonetic = detail?.ukPhonetic.isNotEmpty == true
        ? detail!.ukPhonetic
        : normalizedFallback;
    final usPhonetic = detail?.usPhonetic.isNotEmpty == true
        ? detail!.usPhonetic
        : normalizedFallback;

    return Row(
      children: [
        Expanded(
          child: _AccentPronunciationButton(
            label: '英音',
            phonetic: ukPhonetic,
            isLoading: isLoading,
            color: AppTheme.primaryBlue,
            onTap: () => onPlay(WordPronunciationAccent.uk),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AccentPronunciationButton(
            label: '美音',
            phonetic: usPhonetic,
            isLoading: isLoading,
            color: AppTheme.success,
            onTap: () => onPlay(WordPronunciationAccent.us),
          ),
        ),
      ],
    );
  }
}

class _AccentPronunciationButton extends StatelessWidget {
  const _AccentPronunciationButton({
    required this.label,
    required this.phonetic,
    required this.isLoading,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String phonetic;
  final bool isLoading;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.titleMedium?.color;
    final surfaceBase = theme.cardColor;
    final borderColor = Color.alphaBlend(color.withOpacity(0.28), surfaceBase);
    final surfaceColor = Color.alphaBlend(color.withOpacity(0.08), surfaceBase);
    final mutedColor = theme.textTheme.bodyMedium?.color ?? AppTheme.mutedInk;
    final trimmedPhonetic = phonetic.trim();
    final subtitle = trimmedPhonetic.isNotEmpty
        ? trimmedPhonetic
        : (isLoading ? '加载中' : label);

    return Semantics(
      button: true,
      label: '播放$label发音',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.4),
            ),
            child: Row(
              children: [
                Icon(Icons.volume_up_rounded, color: color, size: 25),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: mutedColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoPlayerFinalScore extends StatelessWidget {
  const _TwoPlayerFinalScore({
    required this.redScore,
    required this.blueScore,
  });

  final int redScore;
  final int blueScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FinalScoreSide(
            label: ExamPlayerSide.red.label,
            score: redScore,
            color: AppTheme.accentRed,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            ':',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.mutedInk,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
          ),
        ),
        Expanded(
          child: _FinalScoreSide(
            label: ExamPlayerSide.blue.label,
            score: blueScore,
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }
}

class _FinalScoreSide extends StatelessWidget {
  const _FinalScoreSide({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: color,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

class _TwoPlayerRoundTile extends StatelessWidget {
  const _TwoPlayerRoundTile({
    required this.index,
    required this.question,
  });

  final int index;
  final ExamQuestion question;

  @override
  Widget build(BuildContext context) {
    final winner = question.multiplayerWinner;
    final color = winner == ExamPlayerSide.red
        ? AppTheme.accentRed
        : winner == ExamPlayerSide.blue
            ? AppTheme.primaryBlue
            : AppTheme.warning;
    final label = winner == null ? '未得分' : '${winner.label} +1';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAF5)),
      ),
      child: Row(
        children: [
          Text(
            '${index + 1}.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.word,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '答案：${question.meaning}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedInk,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedInk),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      return;
    }

    const colors = [
      AppTheme.primaryBlue,
      AppTheme.accentRed,
      AppTheme.warning,
      Color(0xFF9CA3AF),
    ];

    final strokeWidth = size.width * 0.16;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    var startAngle = -math.pi / 2;

    for (var index = 0; index < values.length; index++) {
      final sweepAngle = (values[index] / total) * math.pi * 2;
      paint.color = colors[index];
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
