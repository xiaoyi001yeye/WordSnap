import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/app_settings_service.dart';
import 'study_models.dart';
import 'volcengine_ocr_service.dart';

class WordSnapDemoService extends ChangeNotifier {
  WordSnapDemoService({
    required AppSettingsService settingsService,
    VolcengineOcrService? volcengineOcrService,
  })  : _random = Random(7),
        _settingsService = settingsService,
        _volcengineOcrService =
            volcengineOcrService ?? VolcengineOcrService();

  static const String _capturesKey = 'study_captures';
  static const String _historyKey = 'study_history';
  static const String _reviewQueueKey = 'study_review_queue';
  static const String _favoritesKey = 'study_favorites';

  final Random _random;
  final AppSettingsService _settingsService;
  final VolcengineOcrService _volcengineOcrService;

  late SharedPreferences _preferences;

  List<RecognitionCapture> _captures = <RecognitionCapture>[];
  List<StudyRecord> _history = <StudyRecord>[];
  Set<String> _reviewQueueWords = <String>{};
  Set<String> _favoriteWords = <String>{};

  static const List<WordEntry> _bookWords = [
    WordEntry(word: 'natural', meaning: '自然的', phonetic: '/ˈnætʃrəl/'),
    WordEntry(word: 'disaster', meaning: '灾难', phonetic: '/dɪˈzæstər/'),
    WordEntry(word: 'event', meaning: '事件', phonetic: '/ɪˈvent/'),
    WordEntry(word: 'cause', meaning: '导致', phonetic: '/kɔːz/'),
    WordEntry(word: 'force', meaning: '力量', phonetic: '/fɔːrs/'),
    WordEntry(word: 'Earth', meaning: '地球', phonetic: '/ɜːrθ/'),
    WordEntry(word: 'flood', meaning: '洪水', phonetic: '/flʌd/'),
    WordEntry(word: 'hurricane', meaning: '飓风', phonetic: '/ˈhʌrɪkeɪn/'),
    WordEntry(word: 'wildfire', meaning: '野火', phonetic: '/ˈwaɪldfaɪər/'),
    WordEntry(word: 'happen', meaning: '发生', phonetic: '/ˈhæpən/'),
    WordEntry(word: 'reduce', meaning: '减少', phonetic: '/rɪˈduːs/'),
    WordEntry(word: 'harm', meaning: '伤害', phonetic: '/hɑːrm/'),
    WordEntry(word: 'property', meaning: '财产', phonetic: '/ˈprɑːpərti/'),
    WordEntry(word: 'suddenly', meaning: '突然地', phonetic: '/ˈsʌdnli/'),
    WordEntry(word: 'damage', meaning: '损害', phonetic: '/ˈdæmɪdʒ/'),
    WordEntry(word: 'step', meaning: '步骤', phonetic: '/step/'),
    WordEntry(word: 'example', meaning: '例子', phonetic: '/ɪɡˈzæmpəl/'),
    WordEntry(word: 'recognize', meaning: '识别', phonetic: '/ˈrekəɡnaɪz/'),
    WordEntry(word: 'capture', meaning: '拍摄', phonetic: '/ˈkæptʃər/'),
    WordEntry(word: 'memory', meaning: '记忆', phonetic: '/ˈmeməri/'),
    WordEntry(word: 'tectonic', meaning: '地壳构造的', phonetic: '/tekˈtɑːnɪk/'),
    WordEntry(word: 'eruption', meaning: '喷发', phonetic: '/ɪˈrʌpʃən/'),
    WordEntry(word: 'evacuate', meaning: '疏散', phonetic: '/ɪˈvækjueɪt/'),
    WordEntry(word: 'shelter', meaning: '避难所', phonetic: '/ˈʃeltər/'),
  ];

  static const List<RecognitionPreset> _presets = [
    RecognitionPreset(
      id: 'textbook',
      title: '英语课本页',
      sourceLabel: '八年级课本 Unit 1',
      previewTitle: 'Natural Disasters',
      previewExcerpt: 'Natural disasters happen suddenly and cause harm.',
      qualityScore: 0.95,
      suggestion: '识别质量很好，可以直接生成考试。',
      words: [
        WordEntry(word: 'natural', meaning: '自然的', phonetic: '/ˈnætʃrəl/'),
        WordEntry(word: 'disaster', meaning: '灾难', phonetic: '/dɪˈzæstər/'),
        WordEntry(word: 'event', meaning: '事件', phonetic: '/ɪˈvent/'),
        WordEntry(word: 'cause', meaning: '导致', phonetic: '/kɔːz/'),
        WordEntry(word: 'force', meaning: '力量', phonetic: '/fɔːrs/'),
        WordEntry(word: 'Earth', meaning: '地球', phonetic: '/ɜːrθ/'),
        WordEntry(word: 'flood', meaning: '洪水', phonetic: '/flʌd/'),
        WordEntry(word: 'hurricane', meaning: '飓风', phonetic: '/ˈhʌrɪkeɪn/'),
        WordEntry(word: 'wildfire', meaning: '野火', phonetic: '/ˈwaɪldfaɪər/'),
        WordEntry(word: 'happen', meaning: '发生', phonetic: '/ˈhæpən/'),
        WordEntry(word: 'reduce', meaning: '减少', phonetic: '/rɪˈduːs/'),
        WordEntry(word: 'harm', meaning: '伤害', phonetic: '/hɑːrm/'),
        WordEntry(word: 'property', meaning: '财产', phonetic: '/ˈprɑːpərti/'),
        WordEntry(word: 'suddenly', meaning: '突然地', phonetic: '/ˈsʌdnli/'),
        WordEntry(word: 'damage', meaning: '损害', phonetic: '/ˈdæmɪdʒ/'),
        WordEntry(word: 'step', meaning: '步骤', phonetic: '/step/'),
      ],
    ),
    RecognitionPreset(
      id: 'worksheet',
      title: '试卷阅读材料',
      sourceLabel: '周测阅读理解',
      previewTitle: 'Volcano Evacuation Drill',
      previewExcerpt:
          'Students learn how to evacuate and find shelter quickly.',
      qualityScore: 0.88,
      suggestion: '可直接使用，建议把不需要的词先取消勾选。',
      words: [
        WordEntry(word: 'example', meaning: '例子', phonetic: '/ɪɡˈzæmpəl/'),
        WordEntry(word: 'recognize', meaning: '识别', phonetic: '/ˈrekəɡnaɪz/'),
        WordEntry(word: 'capture', meaning: '拍摄', phonetic: '/ˈkæptʃər/'),
        WordEntry(word: 'memory', meaning: '记忆', phonetic: '/ˈmeməri/'),
        WordEntry(word: 'tectonic', meaning: '地壳构造的', phonetic: '/tekˈtɑːnɪk/'),
        WordEntry(word: 'eruption', meaning: '喷发', phonetic: '/ɪˈrʌpʃən/'),
        WordEntry(word: 'evacuate', meaning: '疏散', phonetic: '/ɪˈvækjueɪt/'),
        WordEntry(word: 'shelter', meaning: '避难所', phonetic: '/ˈʃeltər/'),
        WordEntry(word: 'reduce', meaning: '减少', phonetic: '/rɪˈduːs/'),
        WordEntry(word: 'damage', meaning: '损害', phonetic: '/ˈdæmɪdʒ/'),
      ],
    ),
    RecognitionPreset(
      id: 'gallery-blur',
      title: '相册旧照片',
      sourceLabel: '课后笔记截图',
      previewTitle: 'Emergency Notes',
      previewExcerpt:
          'The text is slightly blurred near the lower right corner.',
      qualityScore: 0.68,
      suggestion: '图片稍模糊，建议重拍或先裁切后再生成考试。',
      words: [
        WordEntry(word: 'natural', meaning: '自然的', phonetic: '/ˈnætʃrəl/'),
        WordEntry(word: 'disaster', meaning: '灾难', phonetic: '/dɪˈzæstər/'),
        WordEntry(word: 'force', meaning: '力量', phonetic: '/fɔːrs/'),
        WordEntry(word: 'damage', meaning: '损害', phonetic: '/ˈdæmɪdʒ/'),
        WordEntry(word: 'evacuate', meaning: '疏散', phonetic: '/ɪˈvækjueɪt/'),
        WordEntry(word: 'shelter', meaning: '避难所', phonetic: '/ˈʃeltər/'),
      ],
    ),
  ];

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _captures = _readCaptureList();
    _history = _readHistoryList();
    _reviewQueueWords =
        _preferences.getStringList(_reviewQueueKey)?.toSet() ?? <String>{};
    _favoriteWords =
        _preferences.getStringList(_favoritesKey)?.toSet() ?? <String>{};

    if (_captures.isEmpty) {
      final defaultCapture = _buildCapture(
        preset: recognitionPresets.first,
        sourceTypeLabel: '拍照识别',
        sourceLabel: recognitionPresets.first.sourceLabel,
        previewTitle: recognitionPresets.first.previewTitle,
        previewExcerpt: recognitionPresets.first.previewExcerpt,
      );
      _captures = [defaultCapture];
      await _persistCaptures();
    }
  }

  List<RecognitionPreset> get recognitionPresets =>
      List<RecognitionPreset>.unmodifiable(_presets);

  List<RecognitionCapture> get captures =>
      List<RecognitionCapture>.unmodifiable(_captures);

  List<StudyRecord> get studyHistory =>
      List<StudyRecord>.unmodifiable(_history);

  RecognitionCapture get latestCapture => _captures.first;

  StudyRecord? get latestRecord => _history.isEmpty ? null : _history.first;

  List<WordEntry> loadRecognizedWords({RecognitionCapture? capture}) {
    return _decorateWords((capture ?? latestCapture).recognizedWords);
  }

  List<WordEntry> loadReviewQueueWords() {
    return loadDefaultBook()
        .words
        .where((entry) => entry.inReviewQueue)
        .toList(growable: false);
  }

  WordBook loadDefaultBook() {
    final seedMap = <String, WordEntry>{
      for (final entry in _bookWords) entry.normalizedWord: entry,
    };
    final recognitionCountMap = <String, int>{};
    final lastSourceMap = <String, String>{};

    for (final capture in _captures) {
      for (final word in capture.recognizedWords) {
        final key = word.normalizedWord;
        seedMap[key] = word;
        recognitionCountMap[key] = (recognitionCountMap[key] ?? 0) + 1;
        lastSourceMap[key] = capture.sourceLabel;
      }
    }

    final latestBuckets =
        latestRecord?.summary.bucketCounts ?? previewBucketCounts();
    final words = seedMap.values.map((entry) {
      final key = entry.normalizedWord;
      return entry.copyWith(
        recognitionCount: recognitionCountMap[key] ?? 0,
        lastSourceLabel: lastSourceMap[key],
        isFavorite: _favoriteWords.contains(key),
        inReviewQueue: _reviewQueueWords.contains(key),
        bucket: _guessBucketForWord(entry, latestBuckets),
      );
    }).toList()
      ..sort((left, right) => left.word.compareTo(right.word));

    final lastStudiedLabel = latestRecord == null
        ? '未开始'
        : formatRelativeDate(latestRecord!.studiedAt);

    return WordBook(
      name: '默认单词本',
      totalWords: words.length,
      lastStudiedLabel: lastStudiedLabel,
      words: words,
    );
  }

  List<RecentStudyUnit> loadRecentUnits() {
    final items = <RecentStudyUnit>[];

    for (final record in _history.take(3)) {
      items.add(
        RecentStudyUnit(
          title: record.title,
          wordCount: record.summary.totalQuestions,
          reviewCount: record.summary.wrongCount,
          dateLabel: formatRelativeDate(record.studiedAt),
          typeLabel: '考试',
        ),
      );
    }

    for (final capture in _captures.take(3)) {
      items.add(
        RecentStudyUnit(
          title: capture.title,
          wordCount: capture.recognizedWords.length,
          reviewCount: capture.isLowQuality ? 1 : 0,
          dateLabel: formatRelativeDate(capture.createdAt),
          typeLabel: capture.sourceTypeLabel,
        ),
      );
    }

    return items.take(4).toList(growable: false);
  }

  StudyPreferences defaultPreferences() {
    return const StudyPreferences(
      questionCount: 12,
      optionCount: 4,
      allowMultiple: false,
      randomOrder: true,
    );
  }

  Future<RecognitionCapture> createRecognitionCapture({
    required RecognitionPreset preset,
    required bool fromGallery,
    String? pickedImagePath,
  }) async {
    final storedImagePath = await _persistCaptureImage(pickedImagePath);
    final capture = _buildCapture(
      preset: preset,
      sourceTypeLabel: fromGallery ? '相册导入' : '拍照识别',
      sourceLabel: _resolveSourceLabel(
        preset: preset,
        fromGallery: fromGallery,
        imagePath: storedImagePath,
      ),
      previewTitle: _resolvePreviewTitle(
        preset: preset,
        fromGallery: fromGallery,
        hasImage: storedImagePath != null,
      ),
      previewExcerpt: _resolvePreviewExcerpt(
        preset: preset,
        fromGallery: fromGallery,
        imagePath: storedImagePath,
      ),
      imagePath: storedImagePath,
    );

    _captures = [
      capture,
      ..._captures.where((item) => item.id != capture.id),
    ].take(8).toList(growable: false);
    await _persistCaptures();
    notifyListeners();
    return capture;
  }

  Future<RecognitionCapture> createRecognitionCaptureFromVolcengineOcr({
    required String imagePath,
    required bool fromGallery,
  }) async {
    final storedImagePath = await _persistCaptureImage(imagePath);
    final targetImagePath = storedImagePath ?? imagePath;
    final recognition = await _volcengineOcrService.recognizeImage(
      imagePath: targetImagePath,
      apiKey: _settingsService.volcengineApiKey,
      useBuiltInCodingKey: _settingsService.isUsingBuiltInVolcengineApiKey,
    );
    final recognizedWords = _buildWordsFromOcr(recognition);

    final previewTitle = recognition.lines.first.text;
    final previewExcerpt =
        recognition.lines.skip(1).take(2).map((line) => line.text).join(' ');

    final capture = RecognitionCapture(
      id: 'arkocr-${DateTime.now().microsecondsSinceEpoch}',
      title: '火山引擎 OCR 识别结果',
      sourceTypeLabel: fromGallery ? '相册导入' : '拍照识别',
      sourceLabel: _resolveOcrSourceLabel(
        fromGallery: fromGallery,
        imagePath: targetImagePath,
      ),
      previewTitle: _ellipsize(previewTitle, 42),
      previewExcerpt: _ellipsize(
        previewExcerpt.isEmpty ? recognition.fullText : previewExcerpt,
        72,
      ),
      qualityScore: recognition.averageScore,
      suggestion: _buildOcrSuggestion(
        recognition: recognition,
        recognizedWords: recognizedWords,
      ),
      recognizedWords: recognizedWords,
      createdAt: DateTime.now(),
      imagePath: storedImagePath,
      ocrEngineLabel: recognition.engineLabel,
      rawRecognizedText: recognition.fullText,
      recognizedLineCount: recognition.lines.length,
      recognizedPhonetics: recognition.phonetics,
      recognizedCjkLineCount: recognition.cjkLineCount,
    );

    _captures = [
      capture,
      ..._captures.where((item) => item.id != capture.id),
    ].take(8).toList(growable: false);
    await _persistCaptures();
    notifyListeners();
    return capture;
  }

  ExamSession createExam({
    required WordBook book,
    required StudyPreferences preferences,
    List<WordEntry>? sourceWords,
    ExamWordScope scope = ExamWordScope.wordBook,
    String? sourceLabel,
  }) {
    final rawPool = List<WordEntry>.from(sourceWords ?? book.words);
    var pool = _removeDuplicateWords(rawPool);
    if (pool.isEmpty) {
      pool = _removeDuplicateWords(book.words);
    }

    if (preferences.randomOrder) {
      pool.shuffle(_random);
    }

    final questionCount = min(
      preferences.questionCount.clamp(1, pool.length),
      pool.length,
    );
    final selected = pool.take(questionCount).toList(growable: false);

    final questions = selected.map((entry) {
      final distractors = List<WordEntry>.from(book.words)
        ..removeWhere(
          (candidate) => candidate.normalizedWord == entry.normalizedWord,
        )
        ..shuffle(_random);

      final maxOptions = min(
        preferences.optionCount.clamp(2, book.words.length),
        distractors.length + 1,
      );

      final optionWords = <String>[entry.meaning];
      optionWords.addAll(
        distractors.take(maxOptions - 1).map((item) => item.meaning),
      );
      optionWords.shuffle(_random);

      return ExamQuestion(
        word: entry.word,
        meaning: entry.meaning,
        phonetic: entry.phonetic,
        options: optionWords,
        correctIndexes: {optionWords.indexOf(entry.meaning)},
      );
    }).toList(growable: false);

    return ExamSession(
      book: book,
      preferences: preferences,
      questions: questions,
      generatedAt: DateTime.now(),
      scope: scope,
      sourceLabel: sourceLabel ?? scope.label,
    );
  }

  StudySummary summarizeExam(ExamSession session) {
    var correctCount = 0;
    var wrongCount = 0;
    var skippedCount = 0;
    final mistakes = <MistakeReviewItem>[];

    for (final question in session.questions) {
      if (question.isSkipped) {
        skippedCount++;
        continue;
      }

      if (question.isCorrect) {
        correctCount++;
        continue;
      }

      wrongCount++;
      mistakes.add(
        MistakeReviewItem(
          word: question.word,
          phonetic: question.phonetic,
          correctMeaning: question.meaning,
          selectedMeanings: question.userSelections
              .map((index) => question.options[index])
              .toList(growable: false),
        ),
      );
    }

    final unseenCount = max(
      0,
      session.book.words.length - session.questions.length,
    );

    return StudySummary(
      totalQuestions: session.questions.length,
      correctCount: correctCount,
      wrongCount: wrongCount,
      skippedCount: skippedCount,
      bucketCounts: {
        MemoryBucket.mastered: correctCount,
        MemoryBucket.fuzzy: wrongCount,
        MemoryBucket.uncertain: skippedCount,
        MemoryBucket.unseen: unseenCount,
      },
      mistakes: mistakes,
    );
  }

  Future<void> saveStudyRecord({
    required ExamSession session,
    required StudySummary summary,
  }) async {
    final record = StudyRecord(
      id: '${session.generatedAt.microsecondsSinceEpoch}',
      title: '${session.sourceLabel} 测试',
      sourceLabel: session.sourceLabel,
      studiedAt: DateTime.now(),
      summary: summary,
    );

    _history = [record, ..._history].take(20).toList(growable: false);
    await _persistHistory();
    notifyListeners();
  }

  Map<MemoryBucket, int> previewBucketCounts() {
    if (latestRecord != null) {
      return latestRecord!.summary.bucketCounts;
    }

    final recognizedCount = latestCapture.recognizedWords.length;
    final mastered = min(4, recognizedCount);
    final fuzzy = min(2, max(0, recognizedCount - mastered));
    final uncertain = min(1, max(0, recognizedCount - mastered - fuzzy));

    return {
      MemoryBucket.mastered: mastered,
      MemoryBucket.fuzzy: fuzzy,
      MemoryBucket.uncertain: uncertain,
      MemoryBucket.unseen: max(
        0,
        recognizedCount - mastered - fuzzy - uncertain,
      ),
    };
  }

  Future<void> toggleFavoriteWord(String word) async {
    final key = word.toLowerCase();
    if (_favoriteWords.contains(key)) {
      _favoriteWords.remove(key);
    } else {
      _favoriteWords.add(key);
    }
    await _preferences.setStringList(
      _favoritesKey,
      _favoriteWords.toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> addWordToReview(String word) async {
    _reviewQueueWords.add(word.toLowerCase());
    await _preferences.setStringList(
      _reviewQueueKey,
      _reviewQueueWords.toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> removeWordFromReview(String word) async {
    _reviewQueueWords.remove(word.toLowerCase());
    await _preferences.setStringList(
      _reviewQueueKey,
      _reviewQueueWords.toList(growable: false),
    );
    notifyListeners();
  }

  bool isFavorite(String word) => _favoriteWords.contains(word.toLowerCase());

  bool isInReviewQueue(String word) =>
      _reviewQueueWords.contains(word.toLowerCase());

  String formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(target).inDays;

    if (difference <= 0) {
      return '今天';
    }
    if (difference == 1) {
      return '昨天';
    }
    return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  MemoryBucket _guessBucketForWord(
    WordEntry entry,
    Map<MemoryBucket, int> latestBuckets,
  ) {
    if (_reviewQueueWords.contains(entry.normalizedWord)) {
      return MemoryBucket.fuzzy;
    }
    if (_favoriteWords.contains(entry.normalizedWord)) {
      return MemoryBucket.mastered;
    }
    if (entry.recognitionCount > 0) {
      return latestBuckets[MemoryBucket.uncertain] == 0
          ? MemoryBucket.mastered
          : MemoryBucket.uncertain;
    }
    return MemoryBucket.unseen;
  }

  List<WordEntry> _buildWordsFromOcr(VolcengineOcrRecognition recognition) {
    final seedMap = <String, WordEntry>{
      for (final entry in _bookWords) entry.normalizedWord: entry,
    };
    final resolvedByWord = <String, WordEntry>{};

    for (final candidate in recognition.entries) {
      final existing = seedMap[candidate.normalized];
      final resolved = WordEntry(
        word: candidate.word,
        meaning: candidate.meaning.isNotEmpty
            ? candidate.meaning
            : existing?.meaning ?? WordEntry.unresolvedMeaning,
        phonetic: candidate.phonetic.isNotEmpty
            ? candidate.phonetic
            : existing?.phonetic ?? WordEntry.unresolvedPhonetic,
        confidence: candidate.score,
      );
      resolvedByWord[candidate.normalized] = resolved;
    }

    for (final candidate in recognition.words) {
      if (resolvedByWord.containsKey(candidate.normalized)) {
        continue;
      }
      final existing = seedMap[candidate.normalized];
      if (existing != null) {
        resolvedByWord[candidate.normalized] = existing.copyWith(
          word: candidate.original,
          confidence: candidate.score,
        );
        continue;
      }

      resolvedByWord[candidate.normalized] = WordEntry(
        word: candidate.original,
        meaning: WordEntry.unresolvedMeaning,
        phonetic: WordEntry.unresolvedPhonetic,
        confidence: candidate.score,
      );
    }

    return _decorateWords(
      _removeDuplicateWords(resolvedByWord.values.toList(growable: false)),
    );
  }

  String _resolveOcrSourceLabel({
    required bool fromGallery,
    required String imagePath,
  }) {
    if (fromGallery) {
      return path.basename(imagePath);
    }

    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '现场拍摄 $hour:$minute';
  }

  String _buildOcrSuggestion({
    required VolcengineOcrRecognition recognition,
    required List<WordEntry> recognizedWords,
  }) {
    final unresolvedCount =
        recognizedWords.where((entry) => !entry.hasResolvedMeaning).length;
    final score = recognition.averageScore;
    final phoneticCount = recognition.phonetics.length;
    final cjkLineCount = recognition.cjkLineCount;

    if (recognizedWords.isEmpty) {
      if (cjkLineCount > 0 || phoneticCount > 0) {
        return '已保留 ${recognition.lines.length} 行 OCR 文本，其中 $cjkLineCount 行包含中文，识别到 $phoneticCount 条音标；但当前还没有抽取出可用于出题的英文单词。';
      }
      return '火山引擎 OCR 已完成识别，但当前还没有抽取出可用于出题的英文单词，建议重拍、裁切重点区域，或提高图片清晰度后重试。';
    }

    if (recognizedWords.length < 3) {
      return '当前只抽取到 ${recognizedWords.length} 个英文单词，另识别到 $phoneticCount 条音标、$cjkLineCount 行中文文本；建议优先拍清英文和音标区域。';
    }

    if (unresolvedCount > 0) {
      return '已识别 ${recognizedWords.length} 个英文单词、$phoneticCount 条音标，其中 $unresolvedCount 个词暂未匹配本地词义，当前不会参与出题。';
    }

    if (phoneticCount == 0) {
      return '已识别 ${recognizedWords.length} 个英文单词，但没有稳定提取到音标，建议让音标区域更靠近镜头并避免反光。';
    }

    if (score >= 0.9) {
      return '识别质量很好，已同时保留中文原文和音标，可以直接查看结果并生成考试。';
    }

    if (score >= 0.75) {
      return '识别质量可用，建议先检查英文、中文和音标结果后再生成考试。';
    }

    return '已完成识别，但置信度偏低，建议先确认中英文和音标区域是否清晰，必要时重新拍摄。';
  }

  String _ellipsize(String text, int maxLength) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 1)}…';
  }

  RecognitionCapture _buildCapture({
    required RecognitionPreset preset,
    required String sourceTypeLabel,
    required String sourceLabel,
    required String previewTitle,
    required String previewExcerpt,
    String? imagePath,
  }) {
    return RecognitionCapture(
      id: '${preset.id}-${DateTime.now().microsecondsSinceEpoch}',
      title: preset.title,
      sourceTypeLabel: sourceTypeLabel,
      sourceLabel: sourceLabel,
      previewTitle: previewTitle,
      previewExcerpt: previewExcerpt,
      qualityScore: preset.qualityScore,
      suggestion: preset.suggestion,
      recognizedWords: _decorateWords(preset.words),
      createdAt: DateTime.now(),
      imagePath: imagePath,
    );
  }

  Future<String?> _persistCaptureImage(String? pickedImagePath) async {
    if (pickedImagePath == null || pickedImagePath.isEmpty) {
      return null;
    }

    final sourceFile = File(pickedImagePath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final capturesDirectory = Directory(
      path.join(appDirectory.path, 'captures'),
    );
    if (!await capturesDirectory.exists()) {
      await capturesDirectory.create(recursive: true);
    }

    final extension = path.extension(sourceFile.path);
    final targetPath = path.join(
      capturesDirectory.path,
      'capture-${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}',
    );

    final savedFile = await sourceFile.copy(targetPath);
    return savedFile.path;
  }

  String _resolveSourceLabel({
    required RecognitionPreset preset,
    required bool fromGallery,
    required String? imagePath,
  }) {
    if (imagePath == null) {
      return preset.sourceLabel;
    }

    if (fromGallery) {
      return path.basename(imagePath);
    }

    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '现场拍摄 $hour:$minute';
  }

  String _resolvePreviewTitle({
    required RecognitionPreset preset,
    required bool fromGallery,
    required bool hasImage,
  }) {
    if (!hasImage) {
      return preset.previewTitle;
    }

    return fromGallery ? '已导入图片' : '最新拍摄图片';
  }

  String _resolvePreviewExcerpt({
    required RecognitionPreset preset,
    required bool fromGallery,
    required String? imagePath,
  }) {
    if (imagePath == null) {
      return preset.previewExcerpt;
    }

    final name = path.basename(imagePath);
    return fromGallery
        ? '已从相册导入 $name，可继续进入当前识别流程。'
        : '已拍摄新图片 $name，可继续进入当前识别流程。';
  }

  List<RecognitionCapture> _readCaptureList() {
    final rawList = _preferences.getStringList(_capturesKey) ?? <String>[];
    return rawList
        .map(
          (item) => RecognitionCapture.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  List<StudyRecord> _readHistoryList() {
    final rawList = _preferences.getStringList(_historyKey) ?? <String>[];
    return rawList
        .map(
          (item) =>
              StudyRecord.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> _persistCaptures() async {
    await _preferences.setStringList(
      _capturesKey,
      _captures
          .map((item) => jsonEncode(item.toJson()))
          .toList(growable: false),
    );
  }

  Future<void> _persistHistory() async {
    await _preferences.setStringList(
      _historyKey,
      _history.map((item) => jsonEncode(item.toJson())).toList(growable: false),
    );
  }

  List<WordEntry> _decorateWords(List<WordEntry> words) {
    return words.map((entry) {
      final key = entry.normalizedWord;
      return entry.copyWith(
        isFavorite: _favoriteWords.contains(key),
        inReviewQueue: _reviewQueueWords.contains(key),
      );
    }).toList(growable: false);
  }

  List<WordEntry> _removeDuplicateWords(List<WordEntry> words) {
    final unique = <String, WordEntry>{};
    for (final entry in words) {
      unique[entry.normalizedWord] = entry;
    }
    return unique.values.toList(growable: false);
  }
}
