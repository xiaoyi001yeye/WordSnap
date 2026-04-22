import 'package:flutter/widgets.dart';

import 'app/word_snap_app.dart';
import 'core/storage/app_settings_service.dart';
import 'features/study/word_snap_demo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = AppSettingsService();
  await settingsService.initialize();
  final demoService = WordSnapDemoService();
  await demoService.initialize();

  runApp(
    WordSnapApp(
      settingsService: settingsService,
      demoService: demoService,
    ),
  );
}
