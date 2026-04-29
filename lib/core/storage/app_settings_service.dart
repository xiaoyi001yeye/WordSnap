import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/study/study_models.dart';

enum OcrProvider {
  volcengine,
  deepseekV4,
}

extension OcrProviderX on OcrProvider {
  String get storageValue {
    switch (this) {
      case OcrProvider.volcengine:
        return 'volcengine';
      case OcrProvider.deepseekV4:
        return 'deepseek_v4';
    }
  }

  String get label {
    switch (this) {
      case OcrProvider.volcengine:
        return '火山引擎 OCR';
      case OcrProvider.deepseekV4:
        return 'DeepSeek V4';
    }
  }

  String get baseUrl {
    switch (this) {
      case OcrProvider.volcengine:
        return 'https://ark.cn-beijing.volces.com';
      case OcrProvider.deepseekV4:
        return 'https://api.deepseek.com';
    }
  }

  String get model {
    switch (this) {
      case OcrProvider.volcengine:
        return 'Doubao-1.5-vision-pro / Doubao-Seed-2.0-pro';
      case OcrProvider.deepseekV4:
        return 'deepseek-v4-flash';
    }
  }

  String get requestPath {
    switch (this) {
      case OcrProvider.volcengine:
        return '/api/coding/v3 或 /api/v3/chat/completions';
      case OcrProvider.deepseekV4:
        return '/chat/completions';
    }
  }

  String get apiKeyLabel {
    switch (this) {
      case OcrProvider.volcengine:
        return '火山引擎 API Key';
      case OcrProvider.deepseekV4:
        return 'DeepSeek API Key';
    }
  }

  bool get supportsBuiltInKey => this == OcrProvider.volcengine;
}

class AppSettingsService extends ChangeNotifier {
  static const String _darkModeKey = 'enable_dark_mode';
  static const String _onboardingKey = 'onboarding_completed';
  static const String _questionCountKey = 'study_question_count';
  static const String _optionCountKey = 'study_option_count';
  static const String _allowMultipleKey = 'study_allow_multiple';
  static const String _randomOrderKey = 'study_random_order';
  static const String _ocrProviderKey = 'ocr_provider';
  static const String _volcengineApiKeyKey = 'volcengine_api_key';
  static const String _deepseekApiKeyKey = 'deepseek_api_key';
  static const String _lastUpdateCheckTimeKey = 'last_update_check_time';
  static const String _builtInVolcengineApiKey =
      '348a9fb5-4514-4e80-8b6e-55ddc659d3a2';
  static const String _builtInVolcengineShortcut = '123456';

  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  bool get isDarkMode => _preferences.getBool(_darkModeKey) ?? false;

  bool get onboardingCompleted => _preferences.getBool(_onboardingKey) ?? false;

  OcrProvider get selectedOcrProvider {
    final stored = _preferences.getString(_ocrProviderKey)?.trim() ?? '';
    for (final provider in OcrProvider.values) {
      if (provider.storageValue == stored) {
        return provider;
      }
    }
    return OcrProvider.volcengine;
  }

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

  String get deepseekApiKey =>
      _preferences.getString(_deepseekApiKeyKey)?.trim() ?? '';

  bool get isUsingBuiltInVolcengineApiKey {
    final stored = _preferences.getString(_volcengineApiKeyKey)?.trim() ?? '';
    return stored.isEmpty ||
        stored == _builtInVolcengineShortcut ||
        stored == _builtInVolcengineApiKey;
  }

  String get selectedOcrApiKey {
    switch (selectedOcrProvider) {
      case OcrProvider.volcengine:
        return volcengineApiKey;
      case OcrProvider.deepseekV4:
        return deepseekApiKey;
    }
  }

  bool get hasSelectedOcrApiKey => selectedOcrApiKey.isNotEmpty;

  bool get isUsingBuiltInSelectedOcrApiKey {
    return selectedOcrProvider == OcrProvider.volcengine &&
        isUsingBuiltInVolcengineApiKey;
  }

  String get maskedSelectedOcrApiKey {
    final apiKey = selectedOcrApiKey;
    if (apiKey.isEmpty) {
      return '未配置';
    }
    if (apiKey.length <= 8) {
      return '${apiKey.substring(0, 2)}***${apiKey.substring(apiKey.length - 2)}';
    }
    return '${apiKey.substring(0, 4)}***${apiKey.substring(apiKey.length - 4)}';
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
      optionCount: _preferences.getInt(_optionCountKey) ?? 9,
      allowMultiple: _preferences.getBool(_allowMultipleKey) ?? false,
      randomOrder: _preferences.getBool(_randomOrderKey) ?? true,
    );
  }

  bool shouldCheckForUpdates(Duration interval) {
    final lastCheckedAt = _preferences.getInt(_lastUpdateCheckTimeKey);
    if (lastCheckedAt == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastCheckedAt),
    );
    return elapsed >= interval;
  }

  Future<void> markUpdateCheckedNow() async {
    await _preferences.setInt(
      _lastUpdateCheckTimeKey,
      DateTime.now().millisecondsSinceEpoch,
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

  Future<void> saveSelectedOcrProvider(OcrProvider provider) async {
    await _preferences.setString(_ocrProviderKey, provider.storageValue);
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

  Future<void> saveDeepseekApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      await _preferences.remove(_deepseekApiKeyKey);
    } else {
      await _preferences.setString(_deepseekApiKeyKey, normalized);
    }
    notifyListeners();
  }

  Future<void> saveSelectedOcrApiKey(String apiKey) {
    switch (selectedOcrProvider) {
      case OcrProvider.volcengine:
        return saveVolcengineApiKey(apiKey);
      case OcrProvider.deepseekV4:
        return saveDeepseekApiKey(apiKey);
    }
  }

  Future<void> saveStudyPreferences(StudyPreferences preferences) async {
    await _preferences.setInt(_questionCountKey, preferences.questionCount);
    await _preferences.setInt(_optionCountKey, preferences.optionCount);
    await _preferences.setBool(_allowMultipleKey, preferences.allowMultiple);
    await _preferences.setBool(_randomOrderKey, preferences.randomOrder);
    notifyListeners();
  }
}
