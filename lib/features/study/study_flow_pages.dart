import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/responsive_helper.dart';
import '../../core/navigation/compatible_page_route.dart';
import '../../core/storage/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'study_models.dart';
import 'word_snap_demo_service.dart';

class RecognitionDemoPage extends StatelessWidget {
  const RecognitionDemoPage({
    super.key,
    required this.demoService,
    required this.settingsService,
  });

  final WordSnapDemoService demoService;
  final AppSettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final words = demoService.loadRecognizedWords();

    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照识别'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveHelper.maxContentWidth(context),
            ),
            child: Padding(
              padding: ResponsiveHelper.screenPadding(context),
              child: Column(
                children: [
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF7E9D3),
                                    Color(0xFFF1E0C6),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Natural Disasters',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontSize: 24),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: words.map((entry) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppTheme.primaryBlue,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                          child: Text(entry.word),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.black,
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    _CameraAction(icon: Icons.photo_library_outlined),
                                    _ShutterButton(),
                                    _CameraAction(icon: Icons.crop_free_outlined),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  '对准文字，保持清晰',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
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
                          onPressed: () {
                            CompatibleNavigator.push<void>(
                              context,
                              RecognitionResultPage(
                                demoService: demoService,
                                settingsService: settingsService,
                              ),
                              transitionType: PageTransitionType.slide,
                            );
                          },
                          child: const Text('查看识别结果'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecognitionResultPage extends StatelessWidget {
  const RecognitionResultPage({
    super.key,
    required this.demoService,
    required this.settingsService,
  });

  final WordSnapDemoService demoService;
  final AppSettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final words = demoService.loadRecognizedWords();

    return Scaffold(
      appBar: AppBar(title: const Text('识别结果')),
      body: ListView(
        padding: ResponsiveHelper.screenPadding(context),
        children: [
          Text(
            '共识别 ${words.length} 个单词',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryBlue,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: words.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4EAF5)),
                    ),
                    child: Text(entry.word),
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
                  onPressed: () {
                    CompatibleNavigator.push<void>(
                      context,
                      ExamSetupPage(
                        demoService: demoService,
                        settingsService: settingsService,
                        book: demoService.loadDefaultBook(),
                      ),
                      transitionType: PageTransitionType.slide,
                    );
                  },
                  child: const Text('生成考试'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ExamSetupPage extends StatefulWidget {
  const ExamSetupPage({
    super.key,
    required this.demoService,
    required this.settingsService,
    required this.book,
  });

  final WordSnapDemoService demoService;
  final AppSettingsService settingsService;
  final WordBook book;

  @override
  State<ExamSetupPage> createState() => _ExamSetupPageState();
}

class _ExamSetupPageState extends State<ExamSetupPage> {
  late StudyPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.settingsService.studyPreferences;
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    '考试设置',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _StepperRow(
                    label: '题目数量',
                    value: _preferences.questionCount,
                    min: 5,
                    max: widget.book.words.length,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(questionCount: value);
                      });
                    },
                  ),
                  _StepperRow(
                    label: '每题选项',
                    value: _preferences.optionCount,
                    min: 4,
                    max: 9,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(optionCount: value);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('允许多选'),
                    value: _preferences.allowMultiple,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(allowMultiple: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('随机顺序'),
                    value: _preferences.randomOrder,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(randomOrder: value);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startExam,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            child: const Text('开始考试'),
          ),
        ],
      ),
    );
  }

  Future<void> _startExam() async {
    await widget.settingsService.saveStudyPreferences(_preferences);
    final session = widget.demoService.createExam(
      book: widget.book,
      preferences: _preferences,
    );

    if (!mounted) {
      return;
    }

    await CompatibleNavigator.push<void>(
      context,
      ExamPage(
        session: session,
        demoService: widget.demoService,
      ),
      transitionType: PageTransitionType.slide,
    );
  }
}

class ExamPage extends StatefulWidget {
  const ExamPage({
    super.key,
    required this.session,
    required this.demoService,
  });

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

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1}/${widget.session.questions.length}'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(Icons.star_border_rounded),
                SizedBox(width: 4),
                Text('收藏'),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: ResponsiveHelper.screenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.word,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryBlue,
                  ),
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
            ElevatedButton(
              onPressed: _goNext,
              child: Text(
                _currentIndex == widget.session.questions.length - 1 ? '完成考试' : '下一题',
              ),
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
    await CompatibleNavigator.pushReplacement<void, void>(
      context,
      ExamResultPage(
        session: widget.session,
        summary: summary,
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
  });

  final ExamSession session;
  final StudySummary summary;

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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    CompatibleNavigator.push<void>(
                      context,
                      MistakeReviewPage(summary: summary),
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
                      AnalysisPage(summary: summary),
                      transitionType: PageTransitionType.slide,
                    );
                  },
                  child: const Text('查看分析'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '题目来源：${session.book.name}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
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
  });

  final StudySummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.bucketCounts.values.fold<int>(0, (sum, value) => sum + value);

    return Scaffold(
      appBar: AppBar(title: const Text('单词记忆分析')),
      body: ListView(
        padding: ResponsiveHelper.screenPadding(context),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  SizedBox(
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: const [
                        _LegendRow(label: '掌握（正确）', color: AppTheme.primaryBlue),
                        _LegendRow(label: '不熟悉（错误）', color: AppTheme.accentRed),
                        _LegendRow(label: '不确定（跳过）', color: AppTheme.warning),
                        _LegendRow(label: '没学过', color: Color(0xFF9CA3AF)),
                      ],
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
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '坚持复习，你会记得更牢。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
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
  });

  final StudySummary summary;

  @override
  Widget build(BuildContext context) {
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
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${item.word} 已加入复习队列')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: const Color(0xFFE9F0FF),
                          foregroundColor: AppTheme.primaryBlue,
                        ),
                        child: const Text('加入复习'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$value'),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
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
          color: selected ? const Color(0xFFE9F0FF) : Theme.of(context).cardColor,
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.color,
  });

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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      AppTheme.primaryBlue,
      AppTheme.accentRed,
      AppTheme.warning,
      Color(0xFF9CA3AF),
    ];

    final total = values.fold<int>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 20.0;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    if (total == 0) {
      return;
    }

    var startAngle = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = (values[index] / total) * math.pi * 2;
      if (sweep == 0) {
        continue;
      }

      final paint = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
