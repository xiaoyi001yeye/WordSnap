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

class NativeOcrWord {
  const NativeOcrWord({
    required this.original,
    required this.normalized,
    required this.score,
  });

  final String original;
  final String normalized;
  final double score;
}

class NativeOcrRecognition {
  const NativeOcrRecognition({
    required this.lines,
    required this.words,
    required this.averageScore,
    required this.fullText,
    required this.engineLabel,
  });

  final List<NativeOcrLine> lines;
  final List<NativeOcrWord> words;
  final double averageScore;
  final String fullText;
  final String engineLabel;
}

class NativeOcrService {
  NativeOcrService({
    MethodChannel? methodChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.example.wordsnap/native_ocr';

  final MethodChannel _methodChannel;

  static final RegExp _wordPattern = RegExp(
    r"[A-Za-z]+(?:[-'][A-Za-z]+)*",
  );

  Future<NativeOcrRecognition> recognizeImage({
    required String imagePath,
  }) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw const NativeOcrException('待识别图片不存在，请重新选择图片。');
    }

    Map<Object?, Object?> payload;
    try {
      final rawPayload =
          await _methodChannel.invokeMethod<Object?>('recognizeImage', {
        'imagePath': imagePath,
      });
      if (rawPayload is! Map) {
        throw const NativeOcrException('系统 OCR 返回了无法解析的结果。');
      }
      payload = Map<Object?, Object?>.from(rawPayload);
    } on PlatformException catch (error) {
      throw NativeOcrException(
        error.message ?? '系统 OCR 识别失败，请稍后重试。',
      );
    }

    final lines = _parseLines(payload);
    if (lines.isEmpty) {
      throw const NativeOcrException('系统 OCR 已完成识别，但没有识别到可用文本。');
    }

    final words = _extractWords(lines);
    final averageScore = lines
            .map((line) => line.score)
            .fold<double>(0, (sum, value) => sum + value) /
        lines.length;

    final fullText = payload['fullText']?.toString().trim();
    final engineLabel = payload['engineLabel']?.toString().trim();

    return NativeOcrRecognition(
      lines: lines,
      words: words,
      averageScore: averageScore.clamp(0, 1),
      fullText: fullText?.isNotEmpty == true
          ? fullText!
          : lines.map((line) => line.text).join('\n'),
      engineLabel: engineLabel?.isNotEmpty == true
          ? engineLabel!
          : _defaultEngineLabel(),
    );
  }

  List<NativeOcrLine> _parseLines(Map<Object?, Object?> payload) {
    final rawLines = payload['lines'];
    if (rawLines is! List) {
      return const <NativeOcrLine>[];
    }

    final lines = <NativeOcrLine>[];
    for (final item in rawLines) {
      if (item is! Map) {
        continue;
      }

      final text = item['text']?.toString().trim() ?? '';
      if (text.isEmpty) {
        continue;
      }

      final score = _safeDouble(item['score']).clamp(0, 1);
      lines.add(NativeOcrLine(text: text, score: score));
    }

    return lines;
  }

  List<NativeOcrWord> _extractWords(List<NativeOcrLine> lines) {
    final bestByWord = <String, NativeOcrWord>{};
    for (final line in lines) {
      for (final match in _wordPattern.allMatches(line.text)) {
        final rawWord = match.group(0);
        if (rawWord == null) {
          continue;
        }

        final normalized = rawWord.toLowerCase();
        if (normalized.length < 2) {
          continue;
        }

        final candidate = NativeOcrWord(
          original: rawWord,
          normalized: normalized,
          score: line.score,
        );
        final existing = bestByWord[normalized];
        if (existing == null || candidate.score >= existing.score) {
          bestByWord[normalized] = candidate;
        }
      }
    }

    final words = bestByWord.values.toList(growable: false);
    words.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return left.normalized.compareTo(right.normalized);
    });
    return words;
  }

  double _safeDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.9;
  }

  String _defaultEngineLabel() {
    if (Platform.isIOS) {
      return 'iOS Vision';
    }
    if (Platform.isAndroid) {
      return 'Android ML Kit';
    }
    return '系统 OCR';
  }
}
