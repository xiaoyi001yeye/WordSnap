import 'package:flutter/widgets.dart';

import 'app/word_snap_app.dart';
import 'core/storage/app_settings_service.dart';
import 'core/update/auto_update_service.dart';
import 'features/study/word_snap_demo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = AppSettingsService();
  await settingsService.initialize();
  final demoService = WordSnapDemoService(settingsService: settingsService);
  await demoService.initialize();
  final updateService = AutoUpdateService(settingsService: settingsService);

  runApp(
    WordSnapApp(
      settingsService: settingsService,
      demoService: demoService,
      updateService: updateService,
    ),
  );
}
