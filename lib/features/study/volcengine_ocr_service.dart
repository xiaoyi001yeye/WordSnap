import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/storage/app_settings_service.dart';

typedef VolcengineOcrLogCallback = void Function(String message);

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

  static const String _promptAssetPath = 'assets/prompts/word_book_ocr.prompt';
  static const String _arkEndpoint =
      'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  static const String _arkModel = 'Doubao-1.5-vision-pro';
  static const String _arkEngineLabel =
      'Volcengine Ark · Doubao-1.5-vision-pro';
  static const String _codingEndpoint =
      'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions';
  static const String _codingModel = 'Doubao-Seed-2.0-pro';
  static const String _codingEngineLabel =
      'Volcengine Ark Coding · Doubao-Seed-2.0-pro';
  static const String _deepseekEndpoint =
      'https://api.deepseek.com/chat/completions';
  static const String _deepseekModel = 'deepseek-v4-flash';
  static const String _deepseekEngineLabel = 'DeepSeek · deepseek-v4-flash';
  static const int _maxRecognitionAttempts = 2;
  static const int _maxOutputTokens = 4096;

  final http.Client _httpClient;
  static Future<_VolcengineOcrPrompts>? _promptLoadFuture;

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
    required OcrProvider provider,
    required bool useBuiltInVolcengineKey,
    VolcengineOcrLogCallback? onLog,
  }) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      onLog?.call('待识别图片不存在，无法继续。');
      throw const VolcengineOcrException('待识别图片不存在，请重新选择图片。');
    }
    if (apiKey.trim().isEmpty) {
      onLog?.call('未检测到 ${provider.apiKeyLabel}。');
      throw VolcengineOcrException('请先在设置中填写 ${provider.apiKeyLabel}。');
    }

    final totalStopwatch = Stopwatch()..start();
    final route = _resolveRoute(
      provider: provider,
      useBuiltInVolcengineKey: useBuiltInVolcengineKey,
    );
    final prompts = await _loadPrompts();
    onLog?.call('已选择 OCR 通道：${route.engineLabel}');
    onLog?.call('提示词资源：$_promptAssetPath');
    onLog?.call('系统提示词：\n${prompts.system.trim()}');
    onLog?.call('用户提示词：\n${prompts.user.trim()}');
    onLog?.call('开始读取待识别图片...');
    final imageBytes = await imageFile.readAsBytes();
    onLog?.call('图片读取完成，大小 ${_formatBytes(imageBytes.length)}。');
    final encodeStopwatch = Stopwatch()..start();
    final base64Image = base64Encode(imageBytes);
    encodeStopwatch.stop();
    onLog?.call('图片编码完成，用时 ${_formatDuration(encodeStopwatch.elapsed)}。');
    final dataUri = 'data:${_mimeTypeForPath(imagePath)};base64,$base64Image';

    _RetryableOcrResponseException? lastRetryableError;
    for (var attempt = 1; attempt <= _maxRecognitionAttempts; attempt += 1) {
      try {
        return await _recognizeImageAttempt(
          route: route,
          apiKey: apiKey,
          dataUri: dataUri,
          prompts: prompts,
          attempt: attempt,
          totalStopwatch: totalStopwatch,
          onLog: onLog,
        );
      } on _RetryableOcrResponseException catch (error) {
        lastRetryableError = error;
        if (attempt >= _maxRecognitionAttempts) {
          onLog?.call(
            '${route.provider.label} 已重试 ${attempt - 1} 次，返回内容仍无法解析。',
          );
          throw VolcengineOcrException(error.message);
        }
        onLog?.call(
          '${route.provider.label} 第 $attempt 次返回内容不可用：${error.message}',
        );
        onLog?.call('准备第 ${attempt + 1} 次重新识别图片。');
      }
    }

    throw VolcengineOcrException(
      lastRetryableError?.message ?? '${route.provider.label} 返回内容无法解析。',
    );
  }

  Future<VolcengineOcrRecognition> _recognizeImageAttempt({
    required _VolcengineOcrRoute route,
    required String apiKey,
    required String dataUri,
    required _VolcengineOcrPrompts prompts,
    required int attempt,
    required Stopwatch totalStopwatch,
    VolcengineOcrLogCallback? onLog,
  }) async {
    http.Response response;
    const requestTimeout = Duration(minutes: 3);
    const temperature = 0.1;
    final requestStopwatch = Stopwatch()..start();
    final attemptLabel = _attemptLabel(attempt);
    final userPrompt = _buildUserPromptForAttempt(
      prompts.user,
      attempt,
    );
    final requestBody = <String, Object?>{
      'model': route.model,
      'messages': <Object?>[
        <String, Object?>{
          'role': 'system',
          'content': prompts.system,
        },
        <String, Object?>{
          'role': 'user',
          'content': <Object?>[
            <String, Object?>{
              'type': 'text',
              'text': userPrompt,
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
      'temperature': temperature,
      'max_tokens': _maxOutputTokens,
    };
    onLog?.call('开始请求 ${route.provider.label}$attemptLabel，等待识别结果返回...');
    onLog?.call(
      '图片视觉识别请求参数：\n${_formatJsonForLog(<String, Object?>{
        'endpoint': route.endpoint,
        'model': route.model,
        'temperature': temperature,
        'max_tokens': _maxOutputTokens,
        'timeout_seconds': requestTimeout.inSeconds,
        'stream': false,
        'image_detail': 'high',
        'data_uri_chars': dataUri.length,
      })}',
    );
    try {
      response = await _httpClient
          .post(
            Uri.parse(route.endpoint),
            headers: <String, String>{
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(requestTimeout);
    } on SocketException {
      onLog?.call('网络连接失败，未能连上 ${route.provider.label}。');
      throw const VolcengineOcrException('网络连接失败，请检查网络后重试。');
    } on TimeoutException {
      onLog?.call('${route.provider.label} 请求超时，3 分钟内没有返回结果。');
      throw VolcengineOcrException('${route.provider.label} 识别超时，请稍后重试。');
    } on HttpException {
      onLog?.call('HTTP 请求异常，${route.provider.label} 接口调用失败。');
      throw VolcengineOcrException(
        '请求 ${route.provider.label} 失败，请稍后重试。',
      );
    } on FormatException {
      onLog?.call('图片编码阶段发生异常。');
      throw const VolcengineOcrException('图片编码失败，请重新选择图片。');
    }
    requestStopwatch.stop();
    onLog?.call(
      '收到 ${route.provider.label}$attemptLabel 响应，HTTP ${response.statusCode}，耗时 ${_formatDuration(requestStopwatch.elapsed)}。',
    );
    onLog?.call('${route.provider.label} 原始响应体：\n${_truncateForLog(response.body)}');

    final responseJson = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = _extractErrorMessage(
        responseJson,
        route: route,
      );
      onLog?.call(
        '${route.provider.label} 返回错误状态 ${response.statusCode}${errorMessage.isNotEmpty ? '：$errorMessage' : '。'}',
      );
      throw VolcengineOcrException(
        errorMessage.isNotEmpty
            ? errorMessage
            : '${route.provider.label} 请求失败（HTTP ${response.statusCode}）。',
      );
    }

    onLog?.call('开始解析 ${route.provider.label}$attemptLabel 返回内容...');
    final content = _extractMessageContent(responseJson);
    onLog?.call('模型返回的 message.content：\n${_truncateForLog(content)}');
    if (content.isEmpty) {
      onLog?.call('${route.provider.label} 返回内容为空。');
      throw _RetryableOcrResponseException('${route.provider.label} 返回了空结果。');
    }

    final payload = _extractPayload(content, onLog: onLog);
    final finishReason = _extractFinishReason(responseJson);
    if (_isLengthLimitedFinish(finishReason)) {
      throw _RetryableOcrResponseException(
        '${route.provider.label} 输出疑似被长度限制截断。',
      );
    }
    final entries = _parseEntries(payload['entries']);
    final lines = _buildLines(entries: entries);
    if (lines.isEmpty && entries.isEmpty) {
      onLog?.call('${route.provider.label} 已返回，但没有解析出可用文本。');
      throw VolcengineOcrException(
        '${route.provider.label} 已完成识别，但没有返回可用文本。',
      );
    }

    final words = _extractWords(lines, entries);
    const phonetics = <String>[];
    final averageScore = entries.isEmpty
        ? 0.45
        : entries
                .map((entry) => entry.score)
                .fold<double>(0.0, (sum, value) => sum + value) /
            entries.length;
    final fullText = lines.map((line) => line.text).join('\n');
    totalStopwatch.stop();
    onLog?.call('大模型输出词条明细：\n${_formatEntriesForLog(entries)}');
    onLog?.call(
      '识别结果解析完成：${entries.length} 个词条，${words.length} 个英文单词，总耗时 ${_formatDuration(totalStopwatch.elapsed)}。',
    );

    return VolcengineOcrRecognition(
      lines: lines,
      entries: entries,
      words: words,
      phonetics: phonetics,
      cjkLineCount: lines.where((line) => _cjkPattern.hasMatch(line.text)).length,
      averageScore: averageScore.clamp(0.0, 1.0).toDouble(),
      fullText: fullText,
      engineLabel: route.engineLabel,
    );
  }

  Future<_VolcengineOcrPrompts> _loadPrompts() {
    return _promptLoadFuture ??= _readPromptAsset();
  }

  Future<_VolcengineOcrPrompts> _readPromptAsset({
    String path = _promptAssetPath,
    void Function()? clearCacheOnError,
  }) async {
    try {
      final rawPrompt = await rootBundle.loadString(path);
      final decoded = jsonDecode(rawPrompt);
      if (decoded is! Map) {
        throw const FormatException('Prompt asset root must be a JSON object.');
      }
      final promptMap = Map<String, dynamic>.from(decoded);
      final system = promptMap['system']?.toString().trim() ?? '';
      final user = promptMap['user']?.toString().trim() ?? '';
      if (system.isEmpty || user.isEmpty) {
        throw const FormatException(
          'Prompt asset must include non-empty system and user fields.',
        );
      }
      return _VolcengineOcrPrompts(system: system, user: user);
    } catch (_) {
      if (clearCacheOnError != null) {
        clearCacheOnError();
      } else {
        _promptLoadFuture = null;
      }
      throw const VolcengineOcrException(
        'OCR 提示词资源读取失败，请检查应用资源是否完整。',
      );
    }
  }

  String _attemptLabel(int attempt) {
    if (attempt <= 1) {
      return '';
    }
    return '（第 $attempt 次重试）';
  }

  String _buildUserPromptForAttempt(String userPrompt, int attempt) {
    if (attempt <= 1) {
      return userPrompt;
    }
    return '$userPrompt\n\n上一次返回内容不是完整合法 JSON。'
        '请重新根据图片识别，只返回完整 JSON 对象，不要截断，不要输出解释，'
        '不要引用或修复上一次返回内容。';
  }

  _VolcengineOcrRoute _resolveRoute({
    required OcrProvider provider,
    required bool useBuiltInVolcengineKey,
  }) {
    switch (provider) {
      case OcrProvider.volcengine:
        if (useBuiltInVolcengineKey) {
          return const _VolcengineOcrRoute(
            provider: OcrProvider.volcengine,
            endpoint: _codingEndpoint,
            model: _codingModel,
            engineLabel: _codingEngineLabel,
            usesBuiltInVolcengineKey: true,
          );
        }
        return const _VolcengineOcrRoute(
          provider: OcrProvider.volcengine,
          endpoint: _arkEndpoint,
          model: _arkModel,
          engineLabel: _arkEngineLabel,
          usesBuiltInVolcengineKey: false,
        );
      case OcrProvider.deepseekV4:
        return const _VolcengineOcrRoute(
          provider: OcrProvider.deepseekV4,
          endpoint: _deepseekEndpoint,
          model: _deepseekModel,
          engineLabel: _deepseekEngineLabel,
          usesBuiltInVolcengineKey: false,
        );
    }
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

  String _extractErrorMessage(
    Map<String, dynamic> responseJson, {
    required _VolcengineOcrRoute route,
  }) {
    final error = responseJson['error'];
    if (error is Map) {
      final code = error['code']?.toString().trim() ?? '';
      final message = error['message']?.toString().trim() ?? '';
      if (route.provider == OcrProvider.volcengine) {
        if (code == 'ModelNotOpen') {
          return _appendRequestId(
            '当前账号还没有开通可用的火山引擎视觉模型。请先在方舟控制台开通模型服务，或改用可访问的 Endpoint ID。',
            message,
          );
        }
        if (code.startsWith('InvalidEndpointOrModel.')) {
          final prefix = route.usesBuiltInVolcengineKey
              ? '默认 OCR 通道暂时不可用，请稍后重试。'
              : '当前 API Key 无法访问默认视觉模型。请在设置中改用已开通权限的火山引擎 Key，或切回应用默认通道。';
          return _appendRequestId(prefix, message);
        }
      }
      if (message.isNotEmpty) {
        return _appendRequestId('${route.provider.label} 返回错误：$message', message);
      }
    }
    return '';
  }

  String _appendRequestId(String prefix, String rawMessage) {
    final match = RegExp(
      r'Request id:\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(rawMessage);
    final requestId = match?.group(1)?.trim() ?? '';
    if (requestId.isEmpty) {
      return prefix;
    }
    return '$prefix\n请求 ID：$requestId';
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

  String _extractFinishReason(Map<String, dynamic> responseJson) {
    final choices = responseJson['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      return '';
    }
    return firstChoice['finish_reason']?.toString().trim() ?? '';
  }

  bool _isLengthLimitedFinish(String finishReason) {
    final normalized = finishReason.toLowerCase();
    return normalized == 'length' ||
        normalized == 'max_tokens' ||
        normalized == 'content_filter_length';
  }

  Map<String, dynamic> _extractPayload(
    String content, {
    VolcengineOcrLogCallback? onLog,
  }) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (error) {
      onLog?.call('直接解析 message.content 为 JSON 失败：$error');
      final firstBrace = content.indexOf('{');
      final lastBrace = content.lastIndexOf('}');
      if (firstBrace >= 0 && lastBrace > firstBrace) {
        final jsonSlice = content.substring(firstBrace, lastBrace + 1);
        onLog?.call('尝试截取首尾花括号之间的 JSON 片段：\n${_truncateForLog(jsonSlice)}');
        try {
          final decoded = jsonDecode(jsonSlice);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (sliceError) {
          onLog?.call('截取 JSON 片段后仍解析失败：$sliceError');
          // Fall through to the unified parse error below.
        }
      }
    }
    onLog?.call('最终仍无法把返回内容解析成结构化 JSON。');
    throw const _RetryableOcrResponseException('返回内容无法解析为结构化 JSON。');
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
      final meaning = _formatPartOfSpeechMeanings(item);
      final sourceText = _composeSourceText(
        word: word,
        meaning: meaning,
      );
      final candidate = VolcengineOcrEntry(
        word: word,
        normalized: normalized,
        phonetic: '',
        meaning: meaning,
        score: _safeDouble(item['confidence']).clamp(0.0, 1.0).toDouble(),
        sourceText: sourceText,
      );

      final existing = bestByWord[normalized];
      if (existing == null || _isBetterEntryCandidate(candidate, existing)) {
        bestByWord[normalized] = candidate;
      }
    }

    return bestByWord.values.toList(growable: false);
  }

  List<VolcengineOcrLine> _buildLines({
    required List<VolcengineOcrEntry> entries,
  }) {
    final candidateLines = <String>[
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

    if (entries.isNotEmpty) {
      return bestByWord.values.toList(growable: false);
    }

    for (final line in lines) {
      if (!_looksLikeVocabularyLine(line.text)) {
        continue;
      }
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

  String _formatPartOfSpeechMeanings(Map<dynamic, dynamic> item) {
    final segments = <String>[];
    _addPartOfSpeechSegments(segments, item['part_of_speech']);

    if (segments.isEmpty) {
      final legacyPartOfSpeech =
          item['part_of_speech']?.toString().trim() ?? '';
      final legacyMeaning = item['meaning']?.toString().trim() ?? '';
      final segment = [legacyPartOfSpeech, legacyMeaning]
          .where((value) => value.isNotEmpty)
          .join(' ')
          .trim();
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }

    return segments.join('；').trim();
  }

  void _addPartOfSpeechSegments(List<String> segments, Object? value) {
    if (value is List) {
      for (final item in value) {
        _addPartOfSpeechSegments(segments, item);
      }
      return;
    }

    if (value is Map) {
      final rawPos = value['pos'] ??
          value['part_of_speech'] ??
          value['type'] ??
          value['speech'];
      final rawMeaning =
          value['meaning'] ?? value['translation'] ?? value['definition'];
      final pos = rawPos?.toString().trim() ?? '';
      final meaning = rawMeaning?.toString().trim() ?? '';
      final segment = [pos, meaning]
          .where((item) => item.isNotEmpty)
          .join(' ')
          .trim();
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }
  }

  bool _looksLikeVocabularyLine(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return false;
    }
    return _phoneticPattern.hasMatch(text) ||
        _partOfSpeechPattern.hasMatch(text) ||
        _cjkPattern.hasMatch(text);
  }

  double _scoreForLine(String line, List<VolcengineOcrEntry> entries) {
    for (final entry in entries) {
      if (entry.sourceText.isNotEmpty && line.contains(entry.sourceText)) {
        return entry.score;
      }
    }
    return entries.isEmpty ? 0.86 : 0.84;
  }

  String _composeSourceText({
    required String word,
    required String meaning,
  }) {
    return [
      word.trim(),
      meaning.trim(),
    ].where((segment) => segment.isNotEmpty).join(' ').trim();
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

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds >= 1) {
      return '${duration.inSeconds}.${(duration.inMilliseconds % 1000 ~/ 100)} 秒';
    }
    return '${duration.inMilliseconds} ms';
  }

  String _truncateForLog(String text, {int maxChars = 4000}) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return '(空)';
    }
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars)}\n...[日志展示已截断，原始内容共 ${normalized.length} 个字符]';
  }

  String _formatJsonForLog(Map<String, Object?> value) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  }

  String _formatEntriesForLog(List<VolcengineOcrEntry> entries) {
    if (entries.isEmpty) {
      return '(无词条)';
    }
    final buffer = StringBuffer();
    for (var index = 0; index < entries.length && index < 80; index += 1) {
      final entry = entries[index];
      buffer.writeln(
        '${index + 1}. ${entry.word}'
        '${entry.meaning.isEmpty ? ' | 释义缺失' : ' | ${entry.meaning}'}'
        ' | confidence=${entry.score.toStringAsFixed(2)}',
      );
    }
    if (entries.length > 80) {
      buffer.writeln('...[日志展示已截断，原始词条共 ${entries.length} 个]');
    }
    return buffer.toString().trimRight();
  }
}

class _VolcengineOcrRoute {
  const _VolcengineOcrRoute({
    required this.provider,
    required this.endpoint,
    required this.model,
    required this.engineLabel,
    required this.usesBuiltInVolcengineKey,
  });

  final OcrProvider provider;
  final String endpoint;
  final String model;
  final String engineLabel;
  final bool usesBuiltInVolcengineKey;
}

class _VolcengineOcrPrompts {
  const _VolcengineOcrPrompts({
    required this.system,
    required this.user,
  });

  final String system;
  final String user;
}

class _RetryableOcrResponseException implements Exception {
  const _RetryableOcrResponseException(this.message);

  final String message;
}
