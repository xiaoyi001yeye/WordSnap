import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class VolcengineOcrException implements Exception {
  const VolcengineOcrException(this.message);

  final String message;

  @override
  String toString() => 'VolcengineOcrException: $message';
}

class VolcengineOcrLine {
  const VolcengineOcrLine({
    required this.text,
    required this.score,
  });

  final String text;
  final double score;
}

class VolcengineOcrWord {
  const VolcengineOcrWord({
    required this.original,
    required this.normalized,
    required this.score,
  });

  final String original;
  final String normalized;
  final double score;
}

class VolcengineOcrEntry {
  const VolcengineOcrEntry({
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

class VolcengineOcrRecognition {
  const VolcengineOcrRecognition({
    required this.lines,
    required this.entries,
    required this.words,
    required this.phonetics,
    required this.cjkLineCount,
    required this.averageScore,
    required this.fullText,
    required this.engineLabel,
  });

  final List<VolcengineOcrLine> lines;
  final List<VolcengineOcrEntry> entries;
  final List<VolcengineOcrWord> words;
  final List<String> phonetics;
  final int cjkLineCount;
  final double averageScore;
  final String fullText;
  final String engineLabel;
}

class VolcengineOcrService {
  VolcengineOcrService({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static const String _endpoint =
      'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  static const String _model = 'Doubao-1.5-vision-pro';
  static const String _engineLabel = 'Volcengine Ark · Doubao-1.5-vision-pro';

  static const String _systemPrompt =
      '你是一个英语单词书 OCR 助手。请读取图片中的文本，优先识别词书条目。'
      '像 danger /ˈdeɪndʒə(r)/ n. 危险 这样即使中间间距较大，也要视为同一条词条。'
      '你必须只返回 JSON 对象，不要输出 Markdown。'
      'JSON 结构固定为 {"raw_text":"","entries":[{"word":"","phonetic":"","part_of_speech":"","meaning":"","source_text":"","confidence":0.0}]}.'
      '如果字段缺失，请填空字符串；不要编造图片中没有出现的单词或释义。';

  static const String _userPrompt =
      '请识别这张图片中的英文单词书/词典条目，保留原始换行到 raw_text，'
      '并把每个词条整理到 entries。entries 中的 meaning 只放中文释义正文，'
      'part_of_speech 单独填写如 n. / v. / adj.。';

  final http.Client _httpClient;

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

  Future<VolcengineOcrRecognition> recognizeImage({
    required String imagePath,
    required String apiKey,
  }) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw const VolcengineOcrException('待识别图片不存在，请重新选择图片。');
    }
    if (apiKey.trim().isEmpty) {
      throw const VolcengineOcrException('请先在设置中填写火山引擎 API Key。');
    }

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:${_mimeTypeForPath(imagePath)};base64,$base64Image';

    http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'model': _model,
              'messages': <Object?>[
                <String, Object?>{
                  'role': 'system',
                  'content': _systemPrompt,
                },
                <String, Object?>{
                  'role': 'user',
                  'content': <Object?>[
                    <String, Object?>{
                      'type': 'text',
                      'text': _userPrompt,
                    },
                    <String, Object?>{
                      'type': 'image_url',
                      'image_url': <String, Object?>{
                        'url': dataUri,
                        'detail': 'high',
                      },
                    },
                  ],
                },
              ],
              'temperature': 0.1,
              'max_tokens': 1800,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on SocketException {
      throw const VolcengineOcrException('网络连接失败，请检查网络后重试。');
    } on TimeoutException {
      throw const VolcengineOcrException('火山引擎识别超时，请稍后重试。');
    } on HttpException {
      throw const VolcengineOcrException('请求火山引擎 OCR 失败，请稍后重试。');
    } on FormatException {
      throw const VolcengineOcrException('图片编码失败，请重新选择图片。');
    }

    final responseJson = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = _extractErrorMessage(responseJson);
      throw VolcengineOcrException(
        errorMessage.isNotEmpty
            ? errorMessage
            : '火山引擎 OCR 请求失败（HTTP ${response.statusCode}）。',
      );
    }

    final content = _extractMessageContent(responseJson);
    if (content.isEmpty) {
      throw const VolcengineOcrException('火山引擎返回了空结果，请重试。');
    }

    final payload = _extractPayload(content);
    final rawText = payload['raw_text']?.toString().trim() ?? '';
    final entries = _parseEntries(payload['entries']);
    final lines = _buildLines(rawText: rawText, entries: entries);
    if (lines.isEmpty && entries.isEmpty) {
      throw const VolcengineOcrException('火山引擎已完成识别，但没有返回可用文本。');
    }

    final words = _extractWords(lines, entries);
    final phonetics = _extractPhonetics(lines, entries);
    final averageScore = entries.isEmpty
        ? 0.86
        : entries
                .map((entry) => entry.score)
                .fold<double>(0.0, (sum, value) => sum + value) /
            entries.length;
    final fullText = rawText.isNotEmpty
        ? rawText
        : lines.map((line) => line.text).join('\n');

    return VolcengineOcrRecognition(
      lines: lines,
      entries: entries,
      words: words,
      phonetics: phonetics,
      cjkLineCount: lines.where((line) => _cjkPattern.hasMatch(line.text)).length,
      averageScore: averageScore.clamp(0.0, 1.0).toDouble(),
      fullText: fullText,
      engineLabel: _engineLabel,
    );
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  String _extractErrorMessage(Map<String, dynamic> responseJson) {
    final error = responseJson['error'];
    if (error is Map) {
      final message = error['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) {
        return message;
      }
    }
    return '';
  }

  String _extractMessageContent(Map<String, dynamic> responseJson) {
    final choices = responseJson['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      return '';
    }
    final message = firstChoice['message'];
    if (message is! Map) {
      return '';
    }
    final content = message['content'];
    if (content is String) {
      return content.trim();
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map && item['type']?.toString() == 'text') {
          final text = item['text']?.toString() ?? '';
          buffer.write(text);
        } else if (item is String) {
          buffer.write(item);
        }
      }
      return buffer.toString().trim();
    }
    return '';
  }

  Map<String, dynamic> _extractPayload(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      final firstBrace = content.indexOf('{');
      final lastBrace = content.lastIndexOf('}');
      if (firstBrace >= 0 && lastBrace > firstBrace) {
        final jsonSlice = content.substring(firstBrace, lastBrace + 1);
        try {
          final decoded = jsonDecode(jsonSlice);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          // Fall through to the unified parse error below.
        }
      }
    }
    throw const VolcengineOcrException('火山引擎返回内容无法解析为结构化结果。');
  }

  List<VolcengineOcrEntry> _parseEntries(Object? rawEntries) {
    if (rawEntries is! List) {
      return const <VolcengineOcrEntry>[];
    }

    final bestByWord = <String, VolcengineOcrEntry>{};
    for (final item in rawEntries) {
      if (item is! Map) {
        continue;
      }

      final word = item['word']?.toString().trim() ?? '';
      if (!_looksLikeHeadword(word)) {
        continue;
      }

      final normalized = word.toLowerCase();
      final phonetic = _normalizePhonetic(item['phonetic']?.toString() ?? '');
      final partOfSpeech = item['part_of_speech']?.toString().trim() ?? '';
      final meaning = item['meaning']?.toString().trim() ?? '';
      final mergedMeaning = [partOfSpeech, meaning]
          .where((segment) => segment.isNotEmpty)
          .join(' ')
          .trim();
      final sourceText = item['source_text']?.toString().trim() ?? '';
      final candidate = VolcengineOcrEntry(
        word: word,
        normalized: normalized,
        phonetic: phonetic,
        meaning: mergedMeaning,
        score: _safeDouble(item['confidence']).clamp(0.0, 1.0).toDouble(),
        sourceText: sourceText,
      );

      final existing = bestByWord[normalized];
      if (existing == null || _isBetterEntryCandidate(candidate, existing)) {
        bestByWord[normalized] = candidate;
      }
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

  List<VolcengineOcrLine> _buildLines({
    required String rawText,
    required List<VolcengineOcrEntry> entries,
  }) {
    final normalizedText = rawText.replaceAll('\r\n', '\n').trim();
    final candidateLines = <String>[
      ...normalizedText
          .split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
      ...entries
          .map((entry) => entry.sourceText.trim())
          .where((item) => item.isNotEmpty),
    ];

    final unique = <String>{};
    final lines = <VolcengineOcrLine>[];
    for (final line in candidateLines) {
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty || !unique.add(normalized)) {
        continue;
      }
      lines.add(
        VolcengineOcrLine(
          text: normalized,
          score: _scoreForLine(normalized, entries),
        ),
      );
    }
    return List<VolcengineOcrLine>.unmodifiable(lines);
  }

  List<VolcengineOcrWord> _extractWords(
    List<VolcengineOcrLine> lines,
    List<VolcengineOcrEntry> entries,
  ) {
    final bestByWord = <String, VolcengineOcrWord>{};

    for (final entry in entries) {
      bestByWord[entry.normalized] = VolcengineOcrWord(
        original: entry.word,
        normalized: entry.normalized,
        score: entry.score,
      );
    }

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
        final candidate = VolcengineOcrWord(
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

  List<String> _extractPhonetics(
    List<VolcengineOcrLine> lines,
    List<VolcengineOcrEntry> entries,
  ) {
    final unique = <String>{};
    final phonetics = <String>[];

    for (final entry in entries) {
      if (entry.phonetic.isNotEmpty && unique.add(entry.phonetic)) {
        phonetics.add(entry.phonetic);
      }
    }

    for (final line in lines) {
      for (final match in _phoneticPattern.allMatches(line.text)) {
        final raw = _normalizePhonetic(match.group(0) ?? '');
        if (raw.isEmpty) {
          continue;
        }
        if (unique.add(raw)) {
          phonetics.add(raw);
        }
      }
    }

    return List<String>.unmodifiable(phonetics);
  }

  double _scoreForLine(String line, List<VolcengineOcrEntry> entries) {
    for (final entry in entries) {
      if (entry.sourceText.isNotEmpty && line.contains(entry.sourceText)) {
        return entry.score;
      }
    }
    return entries.isEmpty ? 0.86 : 0.84;
  }

  String _normalizePhonetic(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim();
  }

  String _mimeTypeForPath(String imagePath) {
    final normalized = imagePath.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    if (normalized.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }

  bool _looksLikeHeadword(String value) {
    if (value.isEmpty || value.length > 48) {
      return false;
    }
    if (_cjkPattern.hasMatch(value)) {
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

  bool _isBetterEntryCandidate(
    VolcengineOcrEntry candidate,
    VolcengineOcrEntry current,
  ) {
    final candidateCompleteness = _entryCompletenessScore(candidate);
    final currentCompleteness = _entryCompletenessScore(current);
    if (candidateCompleteness != currentCompleteness) {
      return candidateCompleteness > currentCompleteness;
    }
    return candidate.score >= current.score;
  }

  int _entryCompletenessScore(VolcengineOcrEntry entry) {
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
    return double.tryParse(value?.toString() ?? '') ?? 0.85;
  }
}
