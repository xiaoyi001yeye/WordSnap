import 'package:flutter/material.dart';

import '../../core/layout/responsive_helper.dart';
import '../../core/navigation/compatible_page_route.dart';
import '../../core/storage/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../study/study_flow_pages.dart';
import '../study/study_models.dart';
import '../study/word_snap_demo_service.dart';

class WordSnapShell extends StatefulWidget {
  const WordSnapShell({
    super.key,
    required this.settingsService,
    required this.demoService,
  });

  final AppSettingsService settingsService;
  final WordSnapDemoService demoService;

  @override
  State<WordSnapShell> createState() => _WordSnapShellState();
}

class _WordSnapShellState extends State<WordSnapShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final titles = ['首页', '学习', '单词本', '统计'];

    return AnimatedBuilder(
      animation: widget.demoService,
      builder: (context, _) {
        final book = widget.demoService.loadDefaultBook();
        final capture = widget.demoService.latestCapture;
        final recognizedWords = widget.demoService.loadRecognizedWords();
        final recentUnits = widget.demoService.loadRecentUnits();
        final previewBuckets = widget.demoService.previewBucketCounts();
        final reviewQueueWords = widget.demoService.loadReviewQueueWords();
        final latestRecord = widget.demoService.latestRecord;

        final pages = [
          _HomeTab(
            book: book,
            capture: capture,
            recentUnits: recentUnits,
            onStartRecognition: _openRecognitionFlow,
            onOpenExamSetup: _openRecognizedExam,
          ),
          _StudyTab(
            capture: capture,
            recognizedWords: recognizedWords,
            reviewQueueWords: reviewQueueWords,
            preferences: widget.settingsService.studyPreferences,
            onOpenStudyFlow: _openRecognitionFlow,
            onOpenRecognizedExam: _openRecognizedExam,
            onOpenReviewExam: _openReviewExam,
          ),
          _WordBookTab(book: book),
          _StatsTab(
            previewBuckets: previewBuckets,
            recognizedCount: recognizedWords.length,
            latestRecord: latestRecord,
            onOpenAnalysis: _openPreviewAnalysis,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_currentIndex]),
            actions: [
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (value) {
              setState(() {
                _currentIndex = value;
              });
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: '首页'),
              NavigationDestination(
                  icon: Icon(Icons.school_outlined), label: '学习'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined), label: '单词本'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined), label: '统计'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRecognitionFlow() async {
    await CompatibleNavigator.push<void>(
      context,
      RecognitionDemoPage(
        demoService: widget.demoService,
        settingsService: widget.settingsService,
      ),
      transitionType: PageTransitionType.slide,
    );
  }

  Future<void> _openRecognizedExam() async {
    await CompatibleNavigator.push<void>(
      context,
      ExamSetupPage(
        demoService: widget.demoService,
        settingsService: widget.settingsService,
        book: widget.demoService.loadDefaultBook(),
        initialScope: ExamWordScope.recognized,
        initialWords: widget.demoService.loadRecognizedWords(),
        sourceLabel: widget.demoService.latestCapture.sourceLabel,
      ),
      transitionType: PageTransitionType.slide,
    );
  }

  Future<void> _openReviewExam() async {
    await CompatibleNavigator.push<void>(
      context,
      ExamSetupPage(
        demoService: widget.demoService,
        settingsService: widget.settingsService,
        book: widget.demoService.loadDefaultBook(),
        initialScope: ExamWordScope.reviewQueue,
        sourceLabel: '复习队列',
      ),
      transitionType: PageTransitionType.slide,
    );
  }

  Future<void> _openPreviewAnalysis() async {
    final latestRecord = widget.demoService.latestRecord;
    if (latestRecord != null) {
      await CompatibleNavigator.push<void>(
        context,
        AnalysisPage(
          summary: latestRecord.summary,
          demoService: widget.demoService,
        ),
        transitionType: PageTransitionType.slideUp,
      );
      return;
    }

    final session = widget.demoService.createExam(
      book: widget.demoService.loadDefaultBook(),
      preferences: widget.settingsService.studyPreferences,
      sourceWords: widget.demoService.loadRecognizedWords(),
      scope: ExamWordScope.recognized,
      sourceLabel: widget.demoService.latestCapture.sourceLabel,
    );
    for (var index = 0; index < session.questions.length; index++) {
      final question = session.questions[index];
      if (index < session.questions.length - 2) {
        question.userSelections.add(question.correctIndexes.first);
      } else if (question.options.length > 1) {
        question.userSelections.add(0);
      }
    }

    final summary = widget.demoService.summarizeExam(session);

    await CompatibleNavigator.push<void>(
      context,
      AnalysisPage(
        summary: summary,
        demoService: widget.demoService,
      ),
      transitionType: PageTransitionType.slideUp,
    );
  }

  Future<void> _openSettings() async {
    await CompatibleNavigator.push<void>(
      context,
      SettingsPage(
        settingsService: widget.settingsService,
        demoService: widget.demoService,
      ),
      transitionType: PageTransitionType.slideUp,
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.book,
    required this.capture,
    required this.recentUnits,
    required this.onStartRecognition,
    required this.onOpenExamSetup,
  });

  final WordBook book;
  final RecognitionCapture capture;
  final List<RecentStudyUnit> recentUnits;
  final VoidCallback onStartRecognition;
  final VoidCallback onOpenExamSetup;

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.screenPadding(context);
    final maxWidth = ResponsiveHelper.maxContentWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: padding,
          children: [
            Card(
              color: AppTheme.primaryBlue,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '拍照识别单词',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '最近材料：${capture.sourceLabel}\n识别出 ${capture.recognizedWords.length} 个单词，可直接生成考试。',
                      style: const TextStyle(
                        color: Color(0xFFDCE7FF),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onStartRecognition,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryBlue,
                              minimumSize: const Size.fromHeight(56),
                            ),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('开始识别'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onOpenExamSetup,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            child: const Text('直接出题'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '我的单词本',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                title: Text(
                  book.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '单词数量 ${book.totalWords}\n上次学习：${book.lastStudiedLabel}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${capture.recognizedWords.length}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.primaryBlue,
                              ),
                    ),
                    const Text('本次识别'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '最近学习',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (recentUnits.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '还没有学习记录，先拍照识别一组单词开始吧。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ...recentUnits.map((unit) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    title: Text(unit.title),
                    subtitle:
                        Text('${unit.typeLabel} · 复习 ${unit.reviewCount} 词'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${unit.wordCount}词'),
                        Text(
                          unit.dateLabel,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StudyTab extends StatelessWidget {
  const _StudyTab({
    required this.capture,
    required this.recognizedWords,
    required this.reviewQueueWords,
    required this.preferences,
    required this.onOpenStudyFlow,
    required this.onOpenRecognizedExam,
    required this.onOpenReviewExam,
  });

  final RecognitionCapture capture;
  final List<WordEntry> recognizedWords;
  final List<WordEntry> reviewQueueWords;
  final StudyPreferences preferences;
  final VoidCallback onOpenStudyFlow;
  final VoidCallback onOpenRecognizedExam;
  final VoidCallback onOpenReviewExam;

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.screenPadding(context);
    final maxWidth = ResponsiveHelper.maxContentWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: padding,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前识别结果',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${capture.sourceLabel} · 共识别 ${recognizedWords.length} 个有效单词，可直接生成练习。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: recognizedWords.take(10).map((entry) {
                        return Chip(label: Text(entry.word));
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onOpenStudyFlow,
                            child: const Text('查看识别流程'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onOpenRecognizedExam,
                            child: const Text('生成考试'),
                          ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '复习入口',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _ConfigRow(
                        label: '待复习单词', value: '${reviewQueueWords.length} 个'),
                    _ConfigRow(
                        label: '题目数量', value: '${preferences.questionCount} 题'),
                    _ConfigRow(
                        label: '每题选项', value: '${preferences.optionCount} 个'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: reviewQueueWords.length >= 2
                          ? onOpenReviewExam
                          : null,
                      child: const Text('练习复习队列'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordBookTab extends StatelessWidget {
  const _WordBookTab({required this.book});

  final WordBook book;

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.screenPadding(context);
    final maxWidth = ResponsiveHelper.maxContentWidth(context);
    final favorites = book.words.where((entry) => entry.isFavorite).length;
    final reviewQueue = book.words.where((entry) => entry.inReviewQueue).length;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: padding,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: '收藏词',
                        value: '$favorites',
                        accent: AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: '复习队列',
                        value: '$reviewQueue',
                        accent: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...book.words.take(18).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    title: Text(entry.word),
                    subtitle: Text(
                      '${entry.phonetic}  ${entry.meaning}'
                      '${entry.lastSourceLabel == null ? '' : '\n来源：${entry.lastSourceLabel}'}',
                    ),
                    trailing: _MemoryBadge(bucket: entry.bucket),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.previewBuckets,
    required this.recognizedCount,
    required this.latestRecord,
    required this.onOpenAnalysis,
  });

  final Map<MemoryBucket, int> previewBuckets;
  final int recognizedCount;
  final StudyRecord? latestRecord;
  final VoidCallback onOpenAnalysis;

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.screenPadding(context);
    final maxWidth = ResponsiveHelper.maxContentWidth(context);
    final accuracy = latestRecord == null
        ? 0
        : (latestRecord!.summary.accuracy * 100).round();
    final total =
        previewBuckets.values.fold<int>(0, (sum, value) => sum + value);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: padding,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: '本次识别',
                        value: '$recognizedCount',
                        accent: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: '正确率',
                        value: latestRecord == null ? '--' : '$accuracy%',
                        accent: AppTheme.success,
                      ),
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
                      '记忆程度分布',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ...previewBuckets.entries.map((entry) {
                      final percent = total == 0 ? 0.0 : entry.value / total;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onOpenAnalysis,
              child: const Text('查看分析页'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.label,
    required this.value,
  });

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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mutedInk,
                ),
          ),
        ],
      ),
    );
  }
}

class _MemoryBadge extends StatelessWidget {
  const _MemoryBadge({required this.bucket});

  final MemoryBucket bucket;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;

    switch (bucket) {
      case MemoryBucket.mastered:
        background = const Color(0xFFE9F8EF);
        foreground = AppTheme.success;
      case MemoryBucket.fuzzy:
        background = const Color(0xFFFFF2E2);
        foreground = AppTheme.warning;
      case MemoryBucket.uncertain:
        background = const Color(0xFFE9EEF6);
        foreground = AppTheme.mutedInk;
      case MemoryBucket.unseen:
        background = const Color(0xFFF1F5F9);
        foreground = AppTheme.mutedInk;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        bucket.label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: accent,
                ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settingsService,
    required this.demoService,
  });

  final AppSettingsService settingsService;
  final WordSnapDemoService demoService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsService,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: demoService,
          builder: (context, _) {
            final preferences = settingsService.studyPreferences;
            final favoriteCount = demoService
                .loadDefaultBook()
                .words
                .where((entry) => entry.isFavorite)
                .length;
            final reviewCount = demoService.loadReviewQueueWords().length;
            final captureCount = demoService.captures.length;

            return Scaffold(
              appBar: AppBar(title: const Text('设置')),
              body: ListView(
                padding: ResponsiveHelper.screenPadding(context),
                children: [
                  Card(
                    child: SwitchListTile(
                      value: settingsService.isDarkMode,
                      title: const Text('深色模式'),
                      subtitle: const Text('统一控制应用主题和系统栏样式'),
                      onChanged: (value) async {
                        await settingsService.setDarkMode(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OcrServerSettingsCard(settingsService: settingsService),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前考试偏好',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _ConfigRow(
                              label: '题目数量',
                              value: '${preferences.questionCount} 题'),
                          _ConfigRow(
                              label: '每题选项',
                              value: '${preferences.optionCount} 个'),
                          _ConfigRow(
                            label: '允许多选',
                            value: preferences.allowMultiple ? '开启' : '关闭',
                          ),
                          _ConfigRow(
                            label: '随机顺序',
                            value: preferences.randomOrder ? '开启' : '关闭',
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
                            '本地学习数据',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _ConfigRow(label: '识别记录', value: '$captureCount 组'),
                          _ConfigRow(label: '收藏单词', value: '$favoriteCount 个'),
                          _ConfigRow(label: '复习队列', value: '$reviewCount 个'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OcrServerSettingsCard extends StatefulWidget {
  const _OcrServerSettingsCard({
    required this.settingsService,
  });

  final AppSettingsService settingsService;

  @override
  State<_OcrServerSettingsCard> createState() => _OcrServerSettingsCardState();
}

class _OcrServerSettingsCardState extends State<_OcrServerSettingsCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.settingsService.ocrServerUrl,
    );
  }

  @override
  void didUpdateWidget(covariant _OcrServerSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latestUrl = widget.settingsService.ocrServerUrl;
    if (_controller.text != latestUrl) {
      _controller.text = latestUrl;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.settingsService.ocrServerUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PaddleOCR 服务', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              '填写可访问的 PaddleOCR /ocr 地址。真机调试时不要写 localhost，应该填写电脑的局域网 IP，例如 http://192.168.1.10:8080/ocr 。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'OCR 服务地址',
                hintText: 'http://192.168.1.10:8080/ocr',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('保存地址'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    _controller.clear();
                    await widget.settingsService.saveOcrServerUrl('');
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(content: Text('已清空 OCR 服务地址')),
                    );
                  },
                  child: const Text('清空'),
                ),
              ],
            ),
            if (currentUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '当前生效地址：$currentUrl',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final normalized = _normalizedUrl(_controller.text);
    if (normalized == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('请输入完整地址，例如 http://192.168.1.10:8080/ocr'),
        ),
      );
      return;
    }

    _controller.text = normalized;
    await widget.settingsService.saveOcrServerUrl(normalized);
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('PaddleOCR 服务地址已保存')),
    );
  }

  String? _normalizedUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }

    final normalized = (parsed.path.isEmpty || parsed.path == '/')
        ? parsed.replace(path: '/ocr')
        : parsed;
    return normalized.toString();
  }
}
