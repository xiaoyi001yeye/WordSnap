import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class PaddleOcrException implements Exception {
  const PaddleOcrException(this.message);

  final String message;

  @override
  String toString() => 'PaddleOcrException: $message';
}

class PaddleOcrLine {
  const PaddleOcrLine({
    required this.text,
    required this.score,
  });

  final String text;
  final double score;
}

class PaddleOcrWord {
  const PaddleOcrWord({
    required this.original,
    required this.normalized,
    required this.score,
  });

  final String original;
  final String normalized;
  final double score;
}

class PaddleOcrRecognition {
  const PaddleOcrRecognition({
    required this.lines,
    required this.words,
    required this.averageScore,
    required this.fullText,
  });

  final List<PaddleOcrLine> lines;
  final List<PaddleOcrWord> words;
  final double averageScore;
  final String fullText;
}

class PaddleOcrService {
  PaddleOcrService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  static final RegExp _wordPattern = RegExp(
    r"[A-Za-z]+(?:[-'][A-Za-z]+)*",
  );

  Future<PaddleOcrRecognition> recognizeImage({
    required String imagePath,
    required Uri endpoint,
  }) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw const PaddleOcrException('待识别图片不存在，请重新选择图片。');
    }

    final imageBytes = await imageFile.readAsBytes();
    final response = await _client.post(
      endpoint,
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'file': base64Encode(imageBytes),
        'fileType': 1,
      }),
    );

    if (response.statusCode != 200) {
      throw PaddleOcrException(
        'PaddleOCR 服务返回 ${response.statusCode}，请检查服务地址和服务状态。',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final lines = _parseLines(payload);
    if (lines.isEmpty) {
      throw const PaddleOcrException(
        'PaddleOCR 已返回结果，但没有识别到可用文本。',
      );
    }

    final words = _extractWords(lines);
    final averageScore = lines
            .map((line) => line.score)
            .fold<double>(0, (sum, value) => sum + value) /
        lines.length;

    return PaddleOcrRecognition(
      lines: lines,
      words: words,
      averageScore: averageScore.clamp(0, 1),
      fullText: lines.map((line) => line.text).join('\n'),
    );
  }

  List<PaddleOcrLine> _parseLines(Map<String, dynamic> payload) {
    final result = payload['result'];
    if (result is! Map<String, dynamic>) {
      return const <PaddleOcrLine>[];
    }

    final rawResults = result['ocrResults'];
    if (rawResults is! List) {
      return const <PaddleOcrLine>[];
    }

    final lines = <PaddleOcrLine>[];
    for (final item in rawResults) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final prunedResult = item['prunedResult'];
      if (prunedResult is! Map<String, dynamic>) {
        continue;
      }

      final texts = prunedResult['rec_texts'];
      final scores = prunedResult['rec_scores'];
      if (texts is! List) {
        continue;
      }

      for (var index = 0; index < texts.length; index++) {
        final text = texts[index].toString().trim();
        if (text.isEmpty) {
          continue;
        }

        final score = scores is List && index < scores.length
            ? _safeDouble(scores[index])
            : 0.0;
        lines.add(PaddleOcrLine(text: text, score: score.clamp(0, 1)));
      }
    }

    return lines;
  }

  List<PaddleOcrWord> _extractWords(List<PaddleOcrLine> lines) {
    final bestByWord = <String, PaddleOcrWord>{};
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

        final candidate = PaddleOcrWord(
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
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
