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
      title: '把 WordFlow 的架构学过来',
      subtitle: '启动初始化、主题、设置、服务层和导航能力已经抽离',
      description: '当前项目不再从单页原型起步，而是直接拥有可扩展的 Flutter 应用骨架。',
      color: AppTheme.primaryBlue,
      icon: Icons.layers_rounded,
    ),
    _OnboardingContent(
      title: '围绕 WordSnap 业务重新组织',
      subtitle: '拍照识词 -> 生成考试 -> 结果分析 -> 错题巩固',
      description: '把 WordFlow 里成熟的工程能力，迁移成适配图片识词和练习闭环的新流程。',
      color: AppTheme.warning,
      icon: Icons.camera_alt_rounded,
    ),
    _OnboardingContent(
      title: '从这里继续扩展真实能力',
      subtitle: '下一步只需要替换演示数据服务',
      description: 'OCR、真实词本、云同步、学习记录持久化，都可以在现有架构上平滑接入。',
      color: AppTheme.success,
      icon: Icons.rocket_launch_rounded,
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
            color: content.color.withOpacity(isDark ? 0.24 : 0.12),
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
                  '迁移重点',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const _BulletLine(text: '应用启动先读本地状态，再决定首屏'),
                const _BulletLine(text: '通用能力沉淀到 core，业务放到 features'),
                const _BulletLine(text: '用服务层替代页面里的临时逻辑'),
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
