import 'dart:io';

import 'package:flutter/services.dart';

class NativeOcrException implements Exception {
  const NativeOcrException(this.message);

  final String message;

  @override
  String toString() => 'NativeOcrException: $message';
}

class NativeOcrLine {
  const NativeOcrLine({
    required this.text,
    required this.score,
  });

  final String text;
  final double score;
}

class NativeOcrRecognition {
  const NativeOcrRecognition({
    required this.lines,
    required this.fullText,
    required this.engineLabel,
    required this.averageScore,
  });

  final List<NativeOcrLine> lines;
  final String fullText;
  final String engineLabel;
  final double averageScore;
}

class NativeOcrService {
  static const MethodChannel _channel = MethodChannel(
    'wordsnap/image_processing',
  );

  const NativeOcrService();

  Future<NativeOcrRecognition> recognizeText({
    required String imagePath,
  }) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw const NativeOcrException('当前平台不支持端侧 OCR。');
    }

    final result = await _channel.invokeMapMethod<String, Object?>(
      'recognizeText',
      <String, Object?>{
        'imagePath': imagePath,
      },
    );

    if (result == null) {
      throw const NativeOcrException('端侧 OCR 返回为空。');
    }

    final lines = <NativeOcrLine>[];
    final rawLines = result['lines'];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is! Map) {
          continue;
        }
        final text = item['text']?.toString().trim() ?? '';
        if (text.isEmpty) {
          continue;
        }
        lines.add(
          NativeOcrLine(
            text: text,
            score: _asDouble(item['score']),
          ),
        );
      }
    }
    final resultFullText = result['fullText']?.toString().trim() ?? '';
    final fullText = resultFullText.isNotEmpty
        ? resultFullText
        : lines.map((line) => line.text).join('\n');

    if (fullText.isEmpty) {
      throw const NativeOcrException('端侧 OCR 没有识别到可用文本。');
    }

    return NativeOcrRecognition(
      lines: lines,
      fullText: fullText,
      engineLabel: result['engineLabel']?.toString().trim().isNotEmpty == true
          ? result['engineLabel']!.toString().trim()
          : '端侧 OCR',
      averageScore:
          _asDouble(result['averageScore']).clamp(0.0, 1.0).toDouble(),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.85;
  }
}
