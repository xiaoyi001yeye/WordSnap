import 'package:flutter/widgets.dart';

import 'app/word_snap_app.dart';
import 'core/storage/app_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = AppSettingsService();
  await settingsService.initialize();

  runApp(WordSnapApp(settingsService: settingsService));
}
