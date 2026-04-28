import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class NativePronunciationException implements Exception {
  const NativePronunciationException(this.message);

  final String message;

  @override
  String toString() => 'NativePronunciationException: $message';
}

enum WordPronunciationAccent {
  uk,
  us,
}

class WordPronunciationDetail {
  const WordPronunciationDetail({
    required this.word,
    required this.ukPhonetic,
    required this.usPhonetic,
    required this.ukSpeechUrl,
    required this.usSpeechUrl,
  });

  final String word;
  final String ukPhonetic;
  final String usPhonetic;
  final String ukSpeechUrl;
  final String usSpeechUrl;

  String phoneticFor(WordPronunciationAccent accent) {
    return switch (accent) {
      WordPronunciationAccent.uk => ukPhonetic,
      WordPronunciationAccent.us => usPhonetic,
    };
  }

  String speechUrlFor(WordPronunciationAccent accent) {
    final primary = switch (accent) {
      WordPronunciationAccent.uk => ukSpeechUrl,
      WordPronunciationAccent.us => usSpeechUrl,
    };
    if (primary.isNotEmpty) {
      return primary;
    }

    return switch (accent) {
      WordPronunciationAccent.uk => usSpeechUrl,
      WordPronunciationAccent.us => ukSpeechUrl,
    };
  }

  factory WordPronunciationDetail.fromJson(Map<String, Object?> json) {
    return WordPronunciationDetail(
      word: _stringValue(json['word']),
      ukPhonetic: _stringValue(json['ukphone']),
      usPhonetic: _stringValue(json['usphone']),
      ukSpeechUrl: _normalizeSpeechUrl(_stringValue(json['ukspeech'])),
      usSpeechUrl: _normalizeSpeechUrl(_stringValue(json['usspeech'])),
    );
  }

  static String _stringValue(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String _normalizeSpeechUrl(String value) {
    return value.replaceAll(r'\u0026', '&').trim();
  }
}

class NativePronunciationService {
  static const MethodChannel _channel = MethodChannel('wordsnap/pronunciation');
  static final Map<String, WordPronunciationDetail?> _detailCache =
      <String, WordPronunciationDetail?>{};
  static final Map<String, Future<WordPronunciationDetail?>> _pendingDetails =
      <String, Future<WordPronunciationDetail?>>{};

  const NativePronunciationService();

  Future<WordPronunciationDetail?> fetchWordDetail(String word) async {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) {
      return null;
    }

    final cacheKey = normalizedWord.toLowerCase();
    if (_detailCache.containsKey(cacheKey)) {
      return _detailCache[cacheKey];
    }

    final pending = _pendingDetails[cacheKey];
    if (pending != null) {
      return pending;
    }

    final request = _fetchWordDetail(normalizedWord).whenComplete(() {
      _pendingDetails.remove(cacheKey);
    });
    _pendingDetails[cacheKey] = request;
    final detail = await request;
    _detailCache[cacheKey] = detail;
    return detail;
  }

  Future<void> speakWord(
    String word, {
    WordPronunciationAccent accent = WordPronunciationAccent.us,
  }) async {
    await playWord(word, accent: accent);
  }

  Future<void> playWord(
    String word, {
    WordPronunciationAccent accent = WordPronunciationAccent.us,
  }) async {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) {
      throw const NativePronunciationException('当前单词为空，无法播放发音。');
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw const NativePronunciationException('当前平台不支持原生单词发音。');
    }

    final detail = await fetchWordDetail(normalizedWord);
    final resolvedWord = detail?.word.isNotEmpty == true
        ? detail!.word
        : normalizedWord;
    final directUrl = detail?.speechUrlFor(accent) ?? '';
    final fallbackUrl = buildYoudaoAudioUrl(resolvedWord, accent: accent);

    if (directUrl.isNotEmpty) {
      try {
        await _playAudioUrl(directUrl);
        return;
      } catch (_) {
        // Fall through to Youdao's stable word-based endpoint.
      }
    }

    await _playAudioUrl(fallbackUrl);
  }

  String buildYoudaoAudioUrl(
    String word, {
    WordPronunciationAccent accent = WordPronunciationAccent.us,
  }) {
    final type = accent == WordPronunciationAccent.uk ? 1 : 2;
    return Uri.https('dict.youdao.com', '/dictvoice', <String, String>{
      'audio': word.trim(),
      'type': type.toString(),
    }).toString();
  }

  Future<WordPronunciationDetail?> _fetchWordDetail(String word) async {
    final uri = Uri.https('v2.xxapi.cn', '/api/englishwords', <String, String>{
      'word': word,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        return null;
      }

      final data = decoded['data'];
      if (data is Map<String, Object?>) {
        return WordPronunciationDetail.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _playAudioUrl(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const NativePronunciationException('当前没有可播放的发音地址。');
    }

    await _channel.invokeMethod<void>('playAudioUrl', <String, Object?>{
      'url': normalizedUrl,
    });
  }
}
