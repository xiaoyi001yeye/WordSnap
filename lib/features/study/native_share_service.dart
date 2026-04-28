import 'package:flutter/services.dart';

class NativeShareService {
  const NativeShareService();

  static const MethodChannel _channel = MethodChannel('wordsnap/share');

  Future<void> shareImage({
    required String imagePath,
    required String text,
  }) async {
    await _channel.invokeMethod<void>('shareImage', {
      'imagePath': imagePath,
      'text': text,
    });
  }
}
