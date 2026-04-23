import 'package:flutter/material.dart';

import '../../core/layout/responsive_helper.dart';
import '../../core/navigation/compatible_page_route.dart';
import '../../core/storage/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../shell/word_snap_shell.dart';
import '../study/word_snap_demo_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.settingsService,
    required this.demoService,
  });

  final AppSettingsService settingsService;
  final WordSnapDemoService demoService;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingContent> _pages = [
    _OnboardingContent(
      title: '从真实材料开始学单词',
      subtitle: '拍照识词，把课本、试卷和读物直接变成练习',
      description: 'WordSnap 的核心不是先选词书，而是先采集你眼前的英文内容，再围绕这份材料完成学习闭环。',
      color: AppTheme.primaryBlue,
      icon: Icons.camera_alt_rounded,
    ),
    _OnboardingContent(
      title: '一次识别，直接出题',
      subtitle: '拍照识别 -> 生成考试 -> 结果分析 -> 错题巩固',
      description: '识别完成后，可以直接按本次结果出题，也可以把错误单词加入复习队列，继续强化。',
      color: AppTheme.warning,
      icon: Icons.quiz_rounded,
    ),
    _OnboardingContent(
      title: '积累个人词本与学习记录',
      subtitle: '每次识别、考试和复习都会沉淀为你的学习资产',
      description: '你可以随时查看单词本、记忆分布和复习队列，让碎片化学习逐步变成长期积累。',
      color: AppTheme.success,
      icon: Icons.insights_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.screenPadding(context);
    final maxWidth = ResponsiveHelper.maxContentWidth(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text('跳过'),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (value) {
                        setState(() {
                          _currentPage = value;
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = _pages[index];
                        return _OnboardingSlide(content: item);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final active = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: active ? 24 : 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: active
                              ? AppTheme.primaryBlue
                              : Theme.of(context).dividerColor,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isLastPage ? _finishOnboarding : _nextPage,
                    child: Text(isLastPage ? '开始体验 WordSnap' : '继续'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _nextPage() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    await widget.settingsService.markOnboardingCompleted();
    if (!mounted) {
      return;
    }

    await CompatibleNavigator.pushReplacement<void, void>(
      context,
      WordSnapShell(
        settingsService: widget.settingsService,
        demoService: widget.demoService,
      ),
      transitionType: PageTransitionType.fade,
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.content});

  final _OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: content.color.withValues(alpha: isDark ? 0.24 : 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            content.icon,
            size: 42,
            color: content.color,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          content.title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          content.subtitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: content.color,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          content.description,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开始前你会得到',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const _BulletLine(text: '拍照或导入图片，快速整理识别结果'),
                const _BulletLine(text: '按识别结果、词本或复习队列生成测试'),
                const _BulletLine(text: '把错题沉淀到复习队列，形成闭环'),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final IconData icon;
}
