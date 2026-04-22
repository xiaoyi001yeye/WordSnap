import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/storage/app_settings_service.dart';
import '../core/theme/app_theme.dart';
import '../features/study/word_snap_demo_service.dart';
import 'app_initializer.dart';

class WordSnapApp extends StatelessWidget {
  const WordSnapApp({
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
        final isDarkMode = settingsService.isDarkMode;
        _configureSystemUi(isDarkMode);

        return MaterialApp(
          title: 'WordSnap',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppInitializer(
            settingsService: settingsService,
            demoService: demoService,
          ),
        );
      },
    );
  }

  void _configureSystemUi(bool isDarkMode) {
    if (isDarkMode) {
      AppTheme.setDarkSystemUi();
    } else {
      AppTheme.setLightSystemUi();
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
