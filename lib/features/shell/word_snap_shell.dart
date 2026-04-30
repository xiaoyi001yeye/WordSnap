import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_version.dart';
import '../../core/layout/responsive_helper.dart';
import '../../core/navigation/compatible_page_route.dart';
import '../../core/storage/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/update/auto_update_service.dart';
import '../study/study_flow_pages.dart';
import '../study/study_models.dart';
import '../study/word_snap_demo_service.dart';

class WordSnapShell extends StatefulWidget {
  const WordSnapShell({
    super.key,
    required this.settingsService,
    required this.demoService,
    required this.updateService,
  });

  final AppSettingsService settingsService;
  final WordSnapDemoService demoService;
  final AutoUpdateService updateService;

  @override
  State<WordSnapShell> createState() => _WordSnapShellState();
}

class _WordSnapShellState extends State<WordSnapShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.updateService.checkAutomatically(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      widget.updateService.checkAutomatically(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['首页', '单词本', '统计'];
    final pageIndex = _currentIndex >= titles.length
        ? titles.length - 1
        : _currentIndex;

    return AnimatedBuilder(
      animation: widget.demoService,
      builder: (context, _) {
        final book = widget.demoService.loadDefaultBook();
        final capture = widget.demoService.latestCapture;
        final recognizedWords = widget.demoService.loadRecognizedWords();
        final recentUnits = widget.demoService.loadRecentUnits();
        final previewBuckets = widget.demoService.previewBucketCounts();
        final latestRecord = widget.demoService.latestRecord;

        final pages = [
          _HomeTab(
            book: book,
            capture: capture,
            recentUnits: recentUnits,
            onStartRecognition: _openRecognitionFlow,
            onOpenExamSetup: _openRecognizedExam,
          ),
          _WordBookTab(
            book: book,
            onDeleteWord: _deleteWordFromBook,
          ),
          _StatsTab(
            previewBuckets: previewBuckets,
            recognizedCount: recognizedWords.length,
            latestRecord: latestRecord,
            onOpenAnalysis: _openPreviewAnalysis,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: pageIndex == 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(titles[pageIndex]),
                      const SizedBox(width: 10),
                      const _VersionBadge(),
                    ],
                  )
                : Text(titles[pageIndex]),
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
              index: pageIndex,
              children: pages,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: pageIndex,
            onDestinationSelected: (value) {
              setState(() {
                _currentIndex = value;
              });
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: '首页'),
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
        capture: widget.demoService.latestCapture,
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
      distractorPool: widget.demoService.latestCapture.distractorPool,
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
        updateService: widget.updateService,
      ),
      transitionType: PageTransitionType.slideUp,
    );
  }

  Future<void> _deleteWordFromBook(WordEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除单词'),
          content: Text('确定从单词本删除 ${entry.word} 吗？删除后不会再用于默认词本出题。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    await widget.demoService.deleteWordFromBook(entry.word);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entry.word} 已从单词本删除')),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppVersion.display,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
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

class _WordBookTab extends StatelessWidget {
  const _WordBookTab({
    required this.book,
    required this.onDeleteWord,
  });

  final WordBook book;
  final ValueChanged<WordEntry> onDeleteWord;

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
                        title: '总单词',
                        value: '${book.totalWords}',
                        accent: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
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
            if (book.words.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '单词本里暂时没有单词。',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ...book.words.asMap().entries.map((indexedEntry) {
              final displayIndex = indexedEntry.key + 1;
              final entry = indexedEntry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WordBookEntryCard(
                  index: displayIndex,
                  entry: entry,
                  onDelete: () => onDeleteWord(entry),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WordBookEntryCard extends StatelessWidget {
  const _WordBookEntryCard({
    required this.index,
    required this.entry,
    required this.onDelete,
  });

  final int index;
  final WordEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '$index.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.word,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${entry.phonetic}  ${entry.meaning}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (entry.lastSourceLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '来源：${entry.lastSourceLabel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedInk,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ExamCountBadge(count: entry.examCount),
                      _MemoryBadge(bucket: entry.bucket),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '删除单词',
              onPressed: onDelete,
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
                side: BorderSide(
                  color: AppTheme.accentRed.withValues(alpha: 0.5),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCountBadge extends StatelessWidget {
  const _ExamCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final hasAttempts = count > 0;
    final foreground = hasAttempts ? AppTheme.success : AppTheme.mutedInk;
    final background =
        hasAttempts ? const Color(0xFFE9F8EF) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Text(
        '已考 $count 次',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settingsService,
    required this.demoService,
    required this.updateService,
  });

  final AppSettingsService settingsService;
  final WordSnapDemoService demoService;
  final AutoUpdateService updateService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiKeyController;
  bool _obscureApiKey = true;
  bool _isSavingApiKey = false;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: _apiKeyInputValue);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsService,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: widget.demoService,
          builder: (context, _) {
            final preferences = widget.settingsService.studyPreferences;
            final selectedProvider = widget.settingsService.selectedOcrProvider;
            final favoriteCount = widget.demoService
                .loadDefaultBook()
                .words
                .where((entry) => entry.isFavorite)
                .length;
            final reviewCount = widget.demoService.loadReviewQueueWords().length;
            final captureCount = widget.demoService.captures.length;

            return Scaffold(
              appBar: AppBar(title: const Text('设置')),
              body: ListView(
                padding: ResponsiveHelper.screenPadding(context),
                children: [
                  Card(
                    child: SwitchListTile(
                      value: widget.settingsService.isDarkMode,
                      title: const Text('深色模式'),
                      subtitle: const Text('统一控制应用主题和系统栏样式'),
                      onChanged: (value) async {
                        await widget.settingsService.setDarkMode(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.system_update_alt_rounded),
                      title: const Text('应用更新'),
                      subtitle: const Text(
                        '当前版本 ${AppVersion.display} · 检查 WordSnap 是否有新版安装包',
                      ),
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _isCheckingUpdate ? null : _checkForUpdates,
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
                            '大模型配置',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<OcrProvider>(
                            value: selectedProvider,
                            decoration: const InputDecoration(
                              labelText: '识别模型',
                              border: OutlineInputBorder(),
                            ),
                            items: OcrProvider.values
                                .map(
                                  (provider) => DropdownMenuItem<OcrProvider>(
                                    value: provider,
                                    child: Text(provider.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _isSavingApiKey ? null : _changeOcrProvider,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _apiKeyController,
                            obscureText: _obscureApiKey,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: selectedProvider.apiKeyLabel,
                              hintText: _apiKeyHintText,
                              border: const OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: '粘贴 Key',
                                    onPressed: _isSavingApiKey
                                        ? null
                                        : _pasteSelectedOcrApiKey,
                                    icon: const Icon(Icons.content_paste_rounded),
                                  ),
                                  IconButton(
                                    tooltip: _obscureApiKey ? '显示 Key' : '隐藏 Key',
                                    onPressed: () {
                                      setState(() {
                                        _obscureApiKey = !_obscureApiKey;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureApiKey
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 96,
                                minHeight: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSavingApiKey
                                      ? null
                                      : _clearSelectedOcrApiKey,
                                  child: const Text('清空 Key'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSavingApiKey
                                      ? null
                                      : _saveSelectedOcrApiKey,
                                  child: Text(
                                    _isSavingApiKey ? '保存中...' : '保存 Key',
                                  ),
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
                            '当前考试偏好',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _ConfigRow(
                              label: '题目数量',
                              value: '${preferences.questionCount} 题'),
                          _ConfigRow(label: '答题布局', value: '九宫格（固定）'),
                          _ConfigRow(
                            label: '作答模式',
                            value: '单选（固定）',
                          ),
                          _ConfigRow(
                            label: '题目顺序',
                            value: '随机（固定）',
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

  String get _apiKeyInputValue {
    if (widget.settingsService.isUsingBuiltInSelectedOcrApiKey) {
      return '123456';
    }
    return widget.settingsService.selectedOcrApiKey;
  }

  String get _apiKeyHintText {
    switch (widget.settingsService.selectedOcrProvider) {
      case OcrProvider.volcengine:
        return '输入 123456 可直接应用内置 Key';
      case OcrProvider.deepseekV4:
        return '填写你自己的 DeepSeek API Key';
    }
  }

  Future<void> _changeOcrProvider(OcrProvider? provider) async {
    if (provider == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    await widget.settingsService.saveSelectedOcrProvider(provider);
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyController.text = _apiKeyInputValue;
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
    });
    await widget.updateService.checkManually(context);
    if (!mounted) {
      return;
    }
    setState(() {
      _isCheckingUpdate = false;
    });
  }

  Future<void> _pasteSelectedOcrApiKey() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final pastedText = clipboardData?.text?.trim() ?? '';
    if (pastedText.isEmpty) {
      return;
    }
    setState(() {
      _apiKeyController.value = TextEditingValue(
        text: pastedText,
        selection: TextSelection.collapsed(offset: pastedText.length),
      );
    });
  }

  Future<void> _saveSelectedOcrApiKey() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSavingApiKey = true;
    });
    await widget.settingsService.saveSelectedOcrApiKey(_apiKeyController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingApiKey = false;
      _apiKeyController.text = _apiKeyInputValue;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.settingsService.isUsingBuiltInSelectedOcrApiKey
              ? '已应用程序内置的火山引擎 API Key'
              : '${widget.settingsService.selectedOcrProvider.apiKeyLabel} 已保存',
        ),
      ),
    );
  }

  Future<void> _clearSelectedOcrApiKey() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSavingApiKey = true;
    });
    _apiKeyController.clear();
    await widget.settingsService.saveSelectedOcrApiKey('');
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingApiKey = false;
      _apiKeyController.text = _apiKeyInputValue;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.settingsService.selectedOcrProvider == OcrProvider.volcengine
              ? '已恢复程序内置的火山引擎 API Key'
              : '已清空 DeepSeek API Key',
        ),
      ),
    );
  }
}
