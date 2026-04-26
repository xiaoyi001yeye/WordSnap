import 'dart:io';

import 'package:flutter/services.dart';

class NativeImageProcessingException implements Exception {
  const NativeImageProcessingException(this.message);

  final String message;

  @override
  String toString() => 'NativeImageProcessingException: $message';
}

class ProcessedRecognitionImage {
  const ProcessedRecognitionImage({
    required this.path,
    required this.originalBytes,
    required this.outputBytes,
    required this.width,
    required this.height,
    required this.quality,
    required this.didCrop,
    required this.didResize,
  });

  final String path;
  final int originalBytes;
  final int outputBytes;
  final int width;
  final int height;
  final int quality;
  final bool didCrop;
  final bool didResize;
}

class NativeImageProcessingService {
  static const MethodChannel _channel = MethodChannel(
    'wordsnap/image_processing',
  );

  const NativeImageProcessingService();

  Future<ProcessedRecognitionImage> prepareRecognitionImage({
    required String imagePath,
    required double left,
    required double top,
    required double right,
    required double bottom,
    required int maxLongSide,
  }) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw const NativeImageProcessingException('当前平台不支持原生图片压缩。');
    }

    final result = await _channel.invokeMapMethod<String, Object?>(
      'prepareRecognitionImage',
      <String, Object?>{
        'imagePath': imagePath,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'maxLongSide': maxLongSide,
      },
    );

    if (result == null) {
      throw const NativeImageProcessingException('原生图片处理返回为空。');
    }

    final path = result['path']?.toString() ?? '';
    if (path.isEmpty) {
      throw const NativeImageProcessingException('原生图片处理没有返回有效文件。');
    }

    return ProcessedRecognitionImage(
      path: path,
      originalBytes: _asInt(result['originalBytes']),
      outputBytes: _asInt(result['outputBytes']),
      width: _asInt(result['width']),
      height: _asInt(result['height']),
      quality: _asInt(result['quality']),
      didCrop: result['didCrop'] == true,
      didResize: result['didResize'] == true,
    );
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
