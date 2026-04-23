import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsnap/app/word_snap_app.dart';
import 'package:wordsnap/core/storage/app_settings_service.dart';
import 'package:wordsnap/features/study/word_snap_demo_service.dart';

void main() {
  testWidgets('shows onboarding on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settingsService = AppSettingsService();
    await settingsService.initialize();

    final demoService = WordSnapDemoService();
    await demoService.initialize();

    await tester.pumpWidget(
      WordSnapApp(
        settingsService: settingsService,
        demoService: demoService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('从真实材料开始学单词'), findsOneWidget);
    expect(find.text('开始体验 WordSnap'), findsNothing);
  });
}
