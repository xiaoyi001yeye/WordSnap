import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/study/study_models.dart';

class AppSettingsService extends ChangeNotifier {
  static const String _darkModeKey = 'enable_dark_mode';
  static const String _onboardingKey = 'onboarding_completed';
  static const String _questionCountKey = 'study_question_count';
  static const String _optionCountKey = 'study_option_count';
  static const String _allowMultipleKey = 'study_allow_multiple';
  static const String _randomOrderKey = 'study_random_order';
  static const String _volcengineApiKeyKey = 'volcengine_api_key';
  static const String _builtInVolcengineApiKey =
      '348a9fb5-4514-4e80-8b6e-55ddc659d3a2';
  static const String _builtInVolcengineShortcut = '123456';

  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  bool get isDarkMode => _preferences.getBool(_darkModeKey) ?? false;

  bool get onboardingCompleted => _preferences.getBool(_onboardingKey) ?? false;

  String get volcengineApiKey {
    final stored = _preferences.getString(_volcengineApiKeyKey)?.trim() ?? '';
    if (stored.isEmpty ||
        stored == _builtInVolcengineShortcut ||
        stored == _builtInVolcengineApiKey) {
      return _builtInVolcengineApiKey;
    }
    return stored;
  }

  bool get hasVolcengineApiKey => volcengineApiKey.isNotEmpty;

  bool get isUsingBuiltInVolcengineApiKey {
    final stored = _preferences.getString(_volcengineApiKeyKey)?.trim() ?? '';
    return stored.isEmpty ||
        stored == _builtInVolcengineShortcut ||
        stored == _builtInVolcengineApiKey;
  }

  String get maskedVolcengineApiKey {
    final apiKey = volcengineApiKey;
    if (apiKey.isEmpty) {
      return '未配置';
    }
    if (apiKey.length <= 8) {
      return '${apiKey.substring(0, 2)}***${apiKey.substring(apiKey.length - 2)}';
    }
    return '${apiKey.substring(0, 4)}***${apiKey.substring(apiKey.length - 4)}';
  }

  StudyPreferences get studyPreferences {
    return StudyPreferences(
      questionCount: _preferences.getInt(_questionCountKey) ?? 12,
      optionCount: _preferences.getInt(_optionCountKey) ?? 4,
      allowMultiple: _preferences.getBool(_allowMultipleKey) ?? false,
      randomOrder: _preferences.getBool(_randomOrderKey) ?? true,
    );
  }

  Future<void> setDarkMode(bool enabled) async {
    await _preferences.setBool(_darkModeKey, enabled);
    notifyListeners();
  }

  Future<void> markOnboardingCompleted() async {
    await _preferences.setBool(_onboardingKey, true);
    notifyListeners();
  }

  Future<void> saveVolcengineApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      await _preferences.remove(_volcengineApiKeyKey);
    } else if (normalized == _builtInVolcengineShortcut ||
        normalized == _builtInVolcengineApiKey) {
      await _preferences.setString(
        _volcengineApiKeyKey,
        _builtInVolcengineShortcut,
      );
    } else {
      await _preferences.setString(_volcengineApiKeyKey, normalized);
    }
    notifyListeners();
  }

  Future<void> saveStudyPreferences(StudyPreferences preferences) async {
    await _preferences.setInt(_questionCountKey, preferences.questionCount);
    await _preferences.setInt(_optionCountKey, preferences.optionCount);
    await _preferences.setBool(_allowMultipleKey, preferences.allowMultiple);
    await _preferences.setBool(_randomOrderKey, preferences.randomOrder);
    notifyListeners();
  }
}
