import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/layout/responsive_helper.dart';
import '../../core/navigation/compatible_page_route.dart';
import '../../core/storage/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'paddle_ocr_service.dart';
import 'study_models.dart';
import 'word_snap_demo_service.dart';

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
  late RecognitionPreset _selectedPreset;
  final ImagePicker _imagePicker = ImagePicker();
  bool _fromGallery = false;
  bool _isPickingImage = false;
  bool _isRecognizing = false;
  String? _selectedImagePath;
  String? _pickErrorMessage;
  String? _recognitionErrorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.demoService.recognitionPresets.first;
    _restoreLostImage();
  }

  @override
  Widget build(BuildContext context) {
    final isLowQuality = _selectedPreset.isLowQuality;
    final hasSelectedImage = _selectedImagePath != null;
    final sourceLabel = hasSelectedImage
        ? (_fromGallery ? '已导入真实图片' : '已拍摄真实图片')
        : _selectedPreset.sourceLabel;
    final previewTitle =
        hasSelectedImage ? '当前采集图片' : _selectedPreset.previewTitle;
    final previewExcerpt = hasSelectedImage
        ? '图片已就绪，继续查看识别结果即可进入当前 MVP 识别流程。'
        : _selectedPreset.previewExcerpt;

    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: SafeArea(
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
                                onTap: _isPickingImage
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
                          _isPickingImage
                              ? '正在打开系统${_fromGallery ? '相册' : '相机'}...'
                              : '点击上方按钮即可直接拉起系统${_fromGallery ? '相册' : '相机'}。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F8FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            '应用会自动连接默认 PaddleOCR 服务，不需要手动填写地址。',
                            style: TextStyle(color: AppTheme.primaryBlue),
                          ),
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
                              style: const TextStyle(color: Color(0xFF9A5B00)),
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
                              style: const TextStyle(color: AppTheme.accentRed),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          '识别场景',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: widget.demoService.recognitionPresets.map((
                            preset,
                          ) {
                            final selected = preset.id == _selectedPreset.id;
                            return ChoiceChip(
                              label: Text(preset.title),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedPreset = preset;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasSelectedImage)
                        _SelectedImagePreview(imagePath: _selectedImagePath!),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isLowQuality
                                ? const [Color(0xFFEEE7D8), Color(0xFFD6CAB0)]
                                : const [Color(0xFFF6E8D1), Color(0xFFE8D4B0)],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    previewTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontSize: 24),
                                  ),
                                ),
                                _QualityBadge(
                                  score: _selectedPreset.qualityScore,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              previewExcerpt,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _selectedPreset.words.map((entry) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.38,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white.withValues(alpha: 0.68),
                                  ),
                                  child: Text(entry.word),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_fromGallery ? '相册导入' : '拍照识别'} · $sourceLabel',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasSelectedImage
                                  ? '真实图片已保存，点击下方按钮会直接开始 OCR 识别。'
                                  : _selectedPreset.suggestion,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (!hasSelectedImage) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F8FF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  '还没有采集图片，请先点击上方“拍照”或“相册导入”。',
                                  style: TextStyle(color: AppTheme.primaryBlue),
                                ),
                              ),
                            ],
                            if (isLowQuality) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  '检测到部分区域模糊，建议重拍或先裁切后再进入考试。',
                                  style: TextStyle(color: Color(0xFF9A5B00)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPreset =
                                widget.demoService.recognitionPresets.first;
                            _fromGallery = false;
                            _selectedImagePath = null;
                            _pickErrorMessage = null;
                            _recognitionErrorMessage = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentRed,
                          side: const BorderSide(color: AppTheme.accentRed),
                        ),
                        child: Text(hasSelectedImage ? '清除图片' : '重置场景'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: hasSelectedImage &&
                                !_isPickingImage &&
                                !_isRecognizing
                            ? _openResult
                            : null,
                        child: Text(
                          _isRecognizing
                              ? '正在识别...'
                              : (_fromGallery ? '识别导入图片' : '识别拍摄图片'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
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
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImagePath = pickedFile?.path;
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
      _pickErrorMessage = null;
      _recognitionErrorMessage = null;
    });

    RecognitionCapture capture;
    try {
      capture = await widget.demoService.createRecognitionCaptureFromPaddleOcr(
        imagePath: _selectedImagePath!,
        fromGallery: _fromGallery,
      );
    } on PaddleOcrException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recognitionErrorMessage = error.message;
        _isRecognizing = false;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recognitionErrorMessage = '识别失败，请稍后重试。';
        _isRecognizing = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecognizing = false;
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

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Image.file(imageFile, fit: BoxFit.cover),
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
      body: ListView(
        padding: ResponsiveHelper.screenPadding(context),
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
                    '共识别 ${words.length} 个单词',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryBlue,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.capture.sourceTypeLabel} · ${widget.capture.sourceLabel}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.capture.ocrEngineLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '识别引擎：${widget.capture.ocrEngineLabel} · ${widget.capture.recognizedLineCount} 行文本',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
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
          if (widget.capture.rawRecognizedText != null &&
              widget.capture.rawRecognizedText!.trim().isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '原始 OCR 文本',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(widget.capture.rawRecognizedText!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: words.map((entry) {
                  final selected = _selectedWords.contains(
                    entry.normalizedWord,
                  );
                  return FilterChip(
                    label: Text('${entry.word}  ${entry.meaning}'),
                    selected: selected,
                    onSelected: entry.hasResolvedMeaning
                        ? (value) {
                            setState(() {
                              if (value) {
                                _selectedWords.add(entry.normalizedWord);
                              } else {
                                _selectedWords.remove(entry.normalizedWord);
                              }
                            });
                          }
                        : null,
                    avatar: entry.hasResolvedMeaning
                        ? null
                        : const Icon(Icons.info_outline, size: 18),
                  );
                }).toList(),
              ),
            ),
          ),
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
                  child: const Text('生成考试'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        sourceLabel: widget.capture.sourceLabel,
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
    this.sourceLabel,
  });

  final WordSnapDemoService demoService;
  final AppSettingsService settingsService;
  final WordBook book;
  final ExamWordScope initialScope;
  final List<WordEntry>? initialWords;
  final String? sourceLabel;

  @override
  State<ExamSetupPage> createState() => _ExamSetupPageState();
}

class _ExamSetupPageState extends State<ExamSetupPage> {
  late StudyPreferences _preferences;
  late ExamWordScope _scope;

  @override
  void initState() {
    super.initState();
    _preferences = widget.settingsService.studyPreferences;
    _scope = widget.initialScope;
  }

  @override
  Widget build(BuildContext context) {
    final recognizedWords =
        widget.initialWords ?? widget.demoService.loadRecognizedWords();
    final reviewQueueWords = widget.demoService.loadReviewQueueWords();
    final wordBookWords = widget.book.words;
    final availableWords = _wordsForScope(
      recognizedWords: recognizedWords,
      wordBookWords: wordBookWords,
      reviewQueueWords: reviewQueueWords,
    );
    final questionMax = math.max(2, availableWords.length);

    return Scaffold(
      appBar: AppBar(title: const Text('开始考试')),
      body: ListView(
        padding: ResponsiveHelper.screenPadding(context),
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
                    title: ExamWordScope.recognized.label,
                    subtitle: widget.sourceLabel ?? '根据本次识别结果出题',
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
                  _StepperRow(
                    label: '题目数量',
                    value: math.min(_preferences.questionCount, questionMax),
                    min: 2,
                    max: questionMax,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          questionCount: value,
                        );
                      });
                    },
                  ),
                  _StepperRow(
                    label: '每题选项',
                    value: math.min(
                      _preferences.optionCount,
                      math.max(2, availableWords.length),
                    ),
                    min: 2,
                    max: math.min(6, math.max(2, widget.book.words.length)),
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          optionCount: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('允许多选'),
                    subtitle: const Text('MVP 中暂按单词义项选择处理'),
                    value: _preferences.allowMultiple,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          allowMultiple: value,
                        );
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('随机顺序'),
                    value: _preferences.randomOrder,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          randomOrder: value,
                        );
                      });
                    },
                  ),
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

    final safeQuestionCount = math.min(
      _preferences.questionCount,
      sourceWords.length,
    );
    final safeOptionCount = math.min(
      _preferences.optionCount,
      math.max(2, book.words.length),
    );
    final safePreferences = _preferences.copyWith(
      questionCount: safeQuestionCount,
      optionCount: safeOptionCount,
    );

    await widget.settingsService.saveStudyPreferences(safePreferences);
    final session = widget.demoService.createExam(
      book: book,
      preferences: safePreferences,
      sourceWords: sourceWords,
      scope: _scope,
      sourceLabel: widget.sourceLabel ?? _scope.label,
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
  int _currentIndex = 0;

  ExamQuestion get _currentQuestion => widget.session.questions[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final allowMultiple = widget.session.preferences.allowMultiple;
    final isFavorite = widget.demoService.isFavorite(question.word);

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
      body: Padding(
        padding: ResponsiveHelper.screenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.session.questions.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 16),
            Text(
              widget.session.sourceLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text(
              question.word,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 8),
            Text(
              question.phonetic,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Text(
              '请选择正确的翻译${allowMultiple ? '（可多选）' : ''}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: question.options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemBuilder: (context, index) {
                  final selected = question.userSelections.contains(index);
                  return _OptionButton(
                    label: question.options[index],
                    selected: selected,
                    onTap: () {
                      setState(() {
                        if (allowMultiple) {
                          if (selected) {
                            question.userSelections.remove(index);
                          } else {
                            question.userSelections.add(index);
                          }
                        } else {
                          question.userSelections
                            ..clear()
                            ..add(index);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        question.userSelections.clear();
                      });
                      _goNext();
                    },
                    child: const Text('跳过'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _goNext,
                    child: Text(
                      _currentIndex == widget.session.questions.length - 1
                          ? '完成考试'
                          : '下一题',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goNext() async {
    if (_currentIndex < widget.session.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
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
}

class ExamResultPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final score = '${summary.correctCount} / ${summary.totalQuestions}';

    return Scaffold(
      appBar: AppBar(title: const Text('考试完成')),
      body: ListView(
        padding: ResponsiveHelper.screenPadding(context),
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
                        label: '未作答',
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
                    value: '${demoService.loadReviewQueueWords().length} 个待复习词',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    CompatibleNavigator.push<void>(
                      context,
                      MistakeReviewPage(
                        summary: summary,
                        demoService: demoService,
                      ),
                      transitionType: PageTransitionType.slide,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                    side: const BorderSide(color: AppTheme.accentRed),
                  ),
                  child: const Text('查看错题'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    CompatibleNavigator.push<void>(
                      context,
                      AnalysisPage(summary: summary, demoService: demoService),
                      transitionType: PageTransitionType.slide,
                    );
                  },
                  child: const Text('查看分析'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
                      _LegendRow(label: '不确定（跳过）', color: AppTheme.warning),
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
                    _buildRecommendation(summary, reviewCount),
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

  String _buildRecommendation(StudySummary summary, int reviewCount) {
    if (summary.wrongCount >= summary.correctCount) {
      return '这轮错误较多，建议先把错题加入复习队列，再用“复习队列”范围重新出一轮练习。当前待复习 $reviewCount 个单词。';
    }
    if (summary.skippedCount > 0) {
      return '你已经掌握了大部分内容，但仍有跳过题。可以优先复习不确定项，帮助记忆更稳定。';
    }
    return '当前掌握情况不错，可以继续从拍照识别导入新材料，扩大个人词本。';
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
                                ? '你的选择：未作答'
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

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final isLow = score < 0.75;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFFFFF4E5) : const Color(0xFFE9F8EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '识别度 ${(score * 100).round()}%',
        style: TextStyle(
          color: isLow ? const Color(0xFF9A5B00) : AppTheme.success,
          fontWeight: FontWeight.w700,
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

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: safeValue <= min ? null : () => onChanged(safeValue - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$safeValue'),
          IconButton(
            onPressed: safeValue >= max ? null : () => onChanged(safeValue + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFFE9F0FF) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFE4EAF5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? AppTheme.primaryBlue : null,
                  ),
            ),
          ),
        ),
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
