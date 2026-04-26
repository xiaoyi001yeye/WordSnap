import 'dart:io';

import 'package:flutter/services.dart';

class NativePronunciationException implements Exception {
  const NativePronunciationException(this.message);

  final String message;

  @override
  String toString() => 'NativePronunciationException: $message';
}

class NativePronunciationService {
  static const MethodChannel _channel = MethodChannel('wordsnap/pronunciation');

  const NativePronunciationService();

  Future<void> speakWord(String word) async {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) {
      throw const NativePronunciationException('当前单词为空，无法播放发音。');
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw const NativePronunciationException('当前平台不支持原生单词发音。');
    }

    await _channel.invokeMethod<void>('speakWord', <String, Object?>{
      'word': normalizedWord,
    });
  }
}
