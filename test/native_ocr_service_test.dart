import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordsnap/features/study/native_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.wordsnap/native_ocr');

  tearDown(() async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('recognizeImage extracts English words from native OCR response',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('native-ocr-test');
    final imageFile = File('${tempDir.path}/sample.jpg');
    await imageFile.writeAsBytes(<int>[1, 2, 3, 4]);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recognizeImage');
      expect(call.arguments, <String, dynamic>{'imagePath': imageFile.path});
      return <String, dynamic>{
        'engineLabel': 'Android ML Kit',
        'fullText': 'Natural disasters happen suddenly.\nWildfire damage.',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'text': 'Natural disasters happen suddenly.',
            'score': 0.96,
          },
          <String, dynamic>{
            'text': 'Wildfire damage.',
            'score': 0.83,
          },
        ],
      };
    });

    final service = NativeOcrService(methodChannel: channel);
    final result = await service.recognizeImage(imagePath: imageFile.path);

    expect(result.engineLabel, 'Android ML Kit');
    expect(result.lines, hasLength(2));
    expect(result.words.map((item) => item.normalized), contains('natural'));
    expect(result.words.map((item) => item.normalized), contains('wildfire'));
    expect(result.fullText, contains('Natural disasters happen suddenly.'));
    expect(result.averageScore, closeTo(0.895, 0.001));
  });

  test('recognizeImage surfaces platform exception messages', () async {
    final tempDir = await Directory.systemTemp.createTemp('native-ocr-error');
    final imageFile = File('${tempDir.path}/sample.jpg');
    await imageFile.writeAsBytes(<int>[1, 2, 3, 4]);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'ocr_failed',
        message: '系统 OCR 当前不可用。',
      );
    });

    final service = NativeOcrService(methodChannel: channel);

    await expectLater(
      () => service.recognizeImage(imagePath: imageFile.path),
      throwsA(
        isA<NativeOcrException>().having(
          (error) => error.message,
          'message',
          '系统 OCR 当前不可用。',
        ),
      ),
    );
  });
}
