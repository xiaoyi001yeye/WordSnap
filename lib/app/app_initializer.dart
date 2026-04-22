import 'package:flutter/material.dart';

import '../core/storage/app_settings_service.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/shell/word_snap_shell.dart';
import '../features/study/word_snap_demo_service.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({
    super.key,
    required this.settingsService,
    required this.demoService,
  });

  final AppSettingsService settingsService;
  final WordSnapDemoService demoService;

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late final Future<bool> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<bool> _bootstrap() async {
    return widget.settingsService.onboardingCompleted;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data!) {
          return WordSnapShell(
            settingsService: widget.settingsService,
            demoService: widget.demoService,
          );
        }

        return OnboardingPage(
          settingsService: widget.settingsService,
          demoService: widget.demoService,
        );
      },
    );
  }
}
