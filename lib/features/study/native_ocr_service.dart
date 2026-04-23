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

class NativeOcrEntry {
  const NativeOcrEntry({
    required this.word,
    required this.normalized,
    required this.phonetic,
    required this.meaning,
    required this.score,
    required this.sourceText,
  });

  final String word;
  final String normalized;
  final String phonetic;
  final String meaning;
  final double score;
  final String sourceText;
}

class NativeOcrRecognition {
  const NativeOcrRecognition({
    required this.lines,
    required this.entries,
    required this.words,
    required this.phonetics,
    required this.cjkLineCount,
    required this.averageScore,
    required this.fullText,
    required this.engineLabel,
  });

  final List<NativeOcrLine> lines;
  final List<NativeOcrEntry> entries;
  final List<NativeOcrWord> words;
  final List<String> phonetics;
  final int cjkLineCount;
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
  static final RegExp _phoneticPattern = RegExp(
    r'(?:/|\[)\s*[^\s/\[\]\d][^/\[\]\n]{0,48}?\s*(?:/|\])',
  );
  static final RegExp _cjkPattern = RegExp(
    r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
  );
  static final RegExp _partOfSpeechPattern = RegExp(
    r'\b(?:n|v|vi|vt|adj|adv|prep|pron|conj|art|num|int|aux|det|phr)\.',
    caseSensitive: false,
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

    final entries = _extractEntries(lines);
    final words = _extractWords(lines);
    final phonetics = _extractPhonetics(lines);
    final averageScore = lines
            .map((line) => line.score)
            .fold<double>(0, (sum, value) => sum + value) /
        lines.length;

    final fullText = payload['fullText']?.toString().trim();
    final engineLabel = payload['engineLabel']?.toString().trim();

    return NativeOcrRecognition(
      lines: lines,
      entries: entries,
      words: words,
      phonetics: phonetics,
      cjkLineCount: lines.where((line) => _cjkPattern.hasMatch(line.text)).length,
      averageScore: averageScore.clamp(0.0, 1.0).toDouble(),
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

      final score = _safeDouble(item['score']).clamp(0.0, 1.0).toDouble();
      lines.add(NativeOcrLine(text: text, score: score));
    }

    return lines;
  }

  List<NativeOcrEntry> _extractEntries(List<NativeOcrLine> lines) {
    final bestByWord = <String, NativeOcrEntry>{};
    var index = 0;

    while (index < lines.length) {
      NativeOcrEntry? matchedEntry;
      var consumedLineCount = 0;

      for (var windowSize = 3; windowSize >= 1; windowSize--) {
        if (index + windowSize > lines.length) {
          continue;
        }

        final window = lines.sublist(index, index + windowSize);
        final combinedText = window
            .map((line) => line.text)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final averageScore = window
                .map((line) => line.score)
                .fold<double>(0, (sum, value) => sum + value) /
            window.length;

        final candidate = _tryParseEntry(
          combinedText,
          averageScore.clamp(0.0, 1.0).toDouble(),
        );
        if (candidate == null) {
          continue;
        }

        matchedEntry = candidate;
        consumedLineCount = windowSize;
        break;
      }

      if (matchedEntry != null) {
        final existing = bestByWord[matchedEntry.normalized];
        if (existing == null || _isBetterEntryCandidate(matchedEntry, existing)) {
          bestByWord[matchedEntry.normalized] = matchedEntry;
        }
        index += consumedLineCount;
        continue;
      }

      index++;
    }

    final entries = bestByWord.values.toList(growable: false);
    entries.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return left.normalized.compareTo(right.normalized);
    });
    return entries;
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

  List<String> _extractPhonetics(List<NativeOcrLine> lines) {
    final unique = <String>{};
    final phonetics = <String>[];

    for (final line in lines) {
      for (final match in _phoneticPattern.allMatches(line.text)) {
        final raw = match.group(0)?.trim();
        if (raw == null || raw.length < 3) {
          continue;
        }
        if (unique.add(raw)) {
          phonetics.add(raw);
        }
      }
    }

    return List<String>.unmodifiable(phonetics);
  }

  NativeOcrEntry? _tryParseEntry(String rawText, double score) {
    final text = rawText
        .replaceAll('／', '/')
        .replaceAll('【', '[')
        .replaceAll('】', ']')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) {
      return null;
    }

    final phoneticMatch = _phoneticPattern.firstMatch(text);
    final partOfSpeechMatch = _partOfSpeechPattern.firstMatch(text);
    final cjkMatch = _cjkPattern.firstMatch(text);

    var wordBoundary = text.length;
    if (phoneticMatch != null && phoneticMatch.start < wordBoundary) {
      wordBoundary = phoneticMatch.start;
    }
    if (partOfSpeechMatch != null && partOfSpeechMatch.start < wordBoundary) {
      wordBoundary = partOfSpeechMatch.start;
    }
    if (cjkMatch != null && cjkMatch.start < wordBoundary) {
      wordBoundary = cjkMatch.start;
    }

    final headword = text
        .substring(0, wordBoundary)
        .replaceAll(RegExp(r"^[^A-Za-z]+|[^A-Za-z'\-\s]+$"), '')
        .trim();
    if (!_looksLikeHeadword(headword)) {
      return null;
    }

    final phonetic = phoneticMatch?.group(0)?.replaceAll(RegExp(r'\s+'), '') ?? '';
    final meaningStart = partOfSpeechMatch?.start ?? cjkMatch?.start ?? -1;
    final meaning = meaningStart >= 0 ? text.substring(meaningStart).trim() : '';

    if (phonetic.isEmpty && meaning.isEmpty) {
      return null;
    }

    return NativeOcrEntry(
      word: headword,
      normalized: headword.toLowerCase(),
      phonetic: phonetic,
      meaning: meaning,
      score: score,
      sourceText: text,
    );
  }

  bool _looksLikeHeadword(String value) {
    if (value.isEmpty || value.length > 48) {
      return false;
    }
    if (value.contains(_cjkPattern)) {
      return false;
    }
    if (!RegExp(r"^[A-Za-z][A-Za-z'\-\s]*$").hasMatch(value)) {
      return false;
    }

    final tokens = value
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return tokens.isNotEmpty && tokens.length <= 4;
  }

  bool _isBetterEntryCandidate(NativeOcrEntry candidate, NativeOcrEntry current) {
    final candidateCompleteness = _entryCompletenessScore(candidate);
    final currentCompleteness = _entryCompletenessScore(current);
    if (candidateCompleteness != currentCompleteness) {
      return candidateCompleteness > currentCompleteness;
    }
    return candidate.score >= current.score;
  }

  int _entryCompletenessScore(NativeOcrEntry entry) {
    var score = 0;
    if (entry.phonetic.isNotEmpty) {
      score += 2;
    }
    if (entry.meaning.isNotEmpty) {
      score += 2;
    }
    if (_cjkPattern.hasMatch(entry.meaning)) {
      score += 1;
    }
    if (_partOfSpeechPattern.hasMatch(entry.meaning)) {
      score += 1;
    }
    return score;
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
