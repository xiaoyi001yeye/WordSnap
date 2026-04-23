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
  static const String _ocrServerUrlKey = 'ocr_server_url';

  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  bool get isDarkMode => _preferences.getBool(_darkModeKey) ?? false;

  bool get onboardingCompleted => _preferences.getBool(_onboardingKey) ?? false;

  String get ocrServerUrl {
    final saved = _preferences.getString(_ocrServerUrlKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return const String.fromEnvironment('PADDLE_OCR_ENDPOINT').trim();
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

  Future<void> saveStudyPreferences(StudyPreferences preferences) async {
    await _preferences.setInt(_questionCountKey, preferences.questionCount);
    await _preferences.setInt(_optionCountKey, preferences.optionCount);
    await _preferences.setBool(_allowMultipleKey, preferences.allowMultiple);
    await _preferences.setBool(_randomOrderKey, preferences.randomOrder);
    notifyListeners();
  }

  Future<void> saveOcrServerUrl(String url) async {
    await _preferences.setString(_ocrServerUrlKey, url.trim());
    notifyListeners();
  }
}
