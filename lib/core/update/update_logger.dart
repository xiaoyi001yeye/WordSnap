import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class UpdateLogger {
  const UpdateLogger._();

  static const String _name = 'WordSnapUpdate';
  static const int _maxEntries = 80;

  static final ValueNotifier<List<UpdateLogEntry>> entries =
      ValueNotifier<List<UpdateLogEntry>>(const <UpdateLogEntry>[]);

  static void clear() {
    entries.value = const <UpdateLogEntry>[];
  }

  static void info(String message, [Map<String, Object?> data = const {}]) {
    final formatted = _format(message, data);
    _append('INFO', formatted);
    debugPrint('[$_name] $formatted');
    developer.log(formatted, name: _name);
  }

  static void error(
    String message,
    Object error,
    StackTrace stackTrace, [
    Map<String, Object?> data = const {},
  ]) {
    final formatted = _format(message, data);
    _append('ERROR', '$formatted error=$error');
    debugPrint('[$_name] ERROR $formatted error=$error');
    developer.log(
      formatted,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _format(String message, Map<String, Object?> data) {
    if (data.isEmpty) {
      return message;
    }
    final fields = data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    return '$message $fields';
  }

  static void _append(String level, String message) {
    final nextEntries = <UpdateLogEntry>[
      ...entries.value,
      UpdateLogEntry(
        time: DateTime.now(),
        level: level,
        message: message,
      ),
    ];
    entries.value = nextEntries.length <= _maxEntries
        ? nextEntries
        : nextEntries.sublist(nextEntries.length - _maxEntries);
  }
}

class UpdateLogEntry {
  const UpdateLogEntry({
    required this.time,
    required this.level,
    required this.message,
  });

  final DateTime time;
  final String level;
  final String message;

  String get displayText {
    final hour = _twoDigits(time.hour);
    final minute = _twoDigits(time.minute);
    final second = _twoDigits(time.second);
    return '[$hour:$minute:$second] [$level] $message';
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
