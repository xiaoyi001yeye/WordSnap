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
    final book = widget.demoService.loadDefaultBook();
    final recognizedWords = widget.demoService.loadRecognizedWords();
    final recentUnits = widget.demoService.loadRecentUnits();
    final previewBuckets = widget.demoService.previewBucketCounts();

    final pages = [
      _HomeTab(
        book: book,
        recognizedWords: recognizedWords,
        recentUnits: recentUnits,
        onStartRecognition: _openRecognitionFlow,
      ),
      _StudyTab(
        book: book,
        recognizedWords: recognizedWords,
        preferences: widget.settingsService.studyPreferences,
        onOpenStudyFlow: _openRecognitionFlow,
        onOpenExamSetup: _openExamSetup,
      ),
      _WordBookTab(
        book: book,
        previewBuckets: previewBuckets,
      ),
      _StatsTab(
        previewBuckets: previewBuckets,
        recognizedCount: recognizedWords.length,
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
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: '学习'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '单词本'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: '统计'),
        ],
      ),
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

  Future<void> _openExamSetup() async {
    await CompatibleNavigator.push<void>(
      context,
      ExamSetupPage(
        demoService: widget.demoService,
        settingsService: widget.settingsService,
        book: widget.demoService.loadDefaultBook(),
      ),
      transitionType: PageTransitionType.slide,
    );
  }

  Future<void> _openPreviewAnalysis() async {
    final session = widget.demoService.createExam(
      book: widget.demoService.loadDefaultBook(),
      preferences: widget.settingsService.studyPreferences,
    );
    for (var index = 0; index < session.questions.length; index++) {
      final question = session.questions[index];
      if (index < 16) {
        question.userSelections.add(question.correctIndexes.first);
      } else if (index < 19) {
        question.userSelections.add(0);
      }
    }

    final summary = widget.demoService.summarizeExam(session);

    await CompatibleNavigator.push<void>(
      context,
      AnalysisPage(summary: summary),
      transitionType: PageTransitionType.slideUp,
    );
  }

  Future<void> _openSettings() async {
    await CompatibleNavigator.push<void>(
      context,
      SettingsPage(settingsService: widget.settingsService),
      transitionType: PageTransitionType.slideUp,
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.book,
    required this.recognizedWords,
    required this.recentUnits,
    required this.onStartRecognition,
  });

  final WordBook book;
  final List<WordEntry> recognizedWords;
  final List<RecentStudyUnit> recentUnits;
  final VoidCallback onStartRecognition;

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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '拍照或从相册选择图片，识别其中的单词并直接生成考试。',
                      style: TextStyle(
                        color: Color(0xFFDCE7FF),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onStartRecognition,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryBlue,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('开始识别'),
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
                      '${recognizedWords.length}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.primaryBlue,
                          ),
                    ),
                    const Text('今日新增'),
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
                    subtitle: Text('复习 ${unit.reviewCount} 词'),
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
    required this.book,
    required this.recognizedWords,
    required this.preferences,
    required this.onOpenStudyFlow,
    required this.onOpenExamSetup,
  });

  final WordBook book;
  final List<WordEntry> recognizedWords;
  final StudyPreferences preferences;
  final VoidCallback onOpenStudyFlow;
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
                      '共识别 ${recognizedWords.length} 个有效单词，可直接生成练习。',
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
                            onPressed: onOpenExamSetup,
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
                      '考试设置',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _ConfigRow(label: '单词范围', value: '全部单词 (${book.words.length})'),
                    _ConfigRow(label: '题目数量', value: '${preferences.questionCount} 题'),
                    _ConfigRow(label: '每题选项', value: '${preferences.optionCount} 个'),
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
          ],
        ),
      ),
    );
  }
}

class _WordBookTab extends StatelessWidget {
  const _WordBookTab({
    required this.book,
    required this.previewBuckets,
  });

  final WordBook book;
  final Map<MemoryBucket, int> previewBuckets;

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.screenPadding(context);
    final maxWidth = ResponsiveHelper.maxContentWidth(context);

    final taggedWords = <WordEntry>[
      ...book.words.take(5).map((entry) => entry.copyWith(bucket: MemoryBucket.mastered)),
      ...book.words.skip(5).take(3).map((entry) => entry.copyWith(bucket: MemoryBucket.fuzzy)),
      ...book.words.skip(8).take(2).map((entry) => entry.copyWith(bucket: MemoryBucket.uncertain)),
      ...book.words.skip(10),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: padding,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: previewBuckets.entries.map((entry) {
                    return Chip(
                      label: Text('${entry.key.label} ${entry.value}'),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...taggedWords.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    title: Text(entry.word),
                    subtitle: Text('${entry.phonetic}  ${entry.meaning}'),
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
    required this.onOpenAnalysis,
  });

  final Map<MemoryBucket, int> previewBuckets;
  final int recognizedCount;
  final VoidCallback onOpenAnalysis;

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
                    const Expanded(
                      child: _StatCard(
                        title: '正确率',
                        value: '80%',
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
                      final total = previewBuckets.values.fold<int>(0, (sum, value) => sum + value);
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
        color: accent.withOpacity(0.08),
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
  });

  final AppSettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsService,
      builder: (context, _) {
        final preferences = settingsService.studyPreferences;

        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: ResponsiveHelper.screenPadding(context),
            children: [
              Card(
                child: SwitchListTile(
                  value: settingsService.isDarkMode,
                  title: const Text('深色模式'),
                  subtitle: const Text('沿用 WordFlow 的统一主题配置思路'),
                  onChanged: settingsService.setDarkMode,
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
                        '当前考试偏好',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _ConfigRow(label: '题目数量', value: '${preferences.questionCount} 题'),
                      _ConfigRow(label: '每题选项', value: '${preferences.optionCount} 个'),
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
                        '本项目吸收的 WordFlow 能力',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text('1. AppInitializer 决定首屏'),
                      const Text('2. 服务层负责数据和偏好'),
                      const Text('3. core / features 分层承接未来扩展'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
