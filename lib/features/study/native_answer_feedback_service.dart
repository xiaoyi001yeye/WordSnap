import 'dart:io';

import 'package:flutter/services.dart';

class NativeAnswerFeedbackService {
  static const MethodChannel _channel = MethodChannel('wordsnap/feedback');

  const NativeAnswerFeedbackService();

  Future<void> playSelectionCue() async {
    await HapticFeedback.selectionClick();
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    await _channel.invokeMethod<void>('playAnswerSelected');
  }
}
