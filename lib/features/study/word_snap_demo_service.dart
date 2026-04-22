import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'study_models.dart';

class WordSnapDemoService extends ChangeNotifier {
  WordSnapDemoService() : _random = Random(7);

  static const String _capturesKey = 'study_captures';
  static const String _historyKey = 'study_history';
  static const String _reviewQueueKey = 'study_review_queue';
  static const String _favoritesKey = 'study_favorites';

  final Random _random;

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
      previewExcerpt: 'Students learn how to evacuate and find shelter quickly.',
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
      previewExcerpt: 'The text is slightly blurred near the lower right corner.',
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
    _reviewQueueWords = _preferences.getStringList(_reviewQueueKey)?.toSet() ??
        <String>{};
    _favoriteWords = _preferences.getStringList(_favoritesKey)?.toSet() ??
        <String>{};

    if (_captures.isEmpty) {
      final defaultCapture = _buildCapture(
        preset: recognitionPresets.first,
        sourceTypeLabel: '拍照识别',
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

  List<WordEntry> loadRecognizedWords({
    RecognitionCapture? capture,
  }) {
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

    final latestBuckets = latestRecord?.summary.bucketCounts ?? previewBucketCounts();
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
  }) async {
    final capture = _buildCapture(
      preset: preset,
      sourceTypeLabel: fromGallery ? '相册导入' : '拍照识别',
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
      preferences.questionCount.clamp(1, pool.length) as int,
      pool.length,
    );
    final selected = pool.take(questionCount).toList(growable: false);

    final questions = selected.map((entry) {
      final distractors = List<WordEntry>.from(book.words)
        ..removeWhere((candidate) => candidate.normalizedWord == entry.normalizedWord)
        ..shuffle(_random);

      final maxOptions = min(
        preferences.optionCount.clamp(2, book.words.length) as int,
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

    final unseenCount =
        max(0, session.book.words.length - session.questions.length);

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
      MemoryBucket.unseen: max(0, recognizedCount - mastered - fuzzy - uncertain),
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

  RecognitionCapture _buildCapture({
    required RecognitionPreset preset,
    required String sourceTypeLabel,
  }) {
    return RecognitionCapture(
      id: '${preset.id}-${DateTime.now().microsecondsSinceEpoch}',
      title: preset.title,
      sourceTypeLabel: sourceTypeLabel,
      sourceLabel: preset.sourceLabel,
      previewTitle: preset.previewTitle,
      previewExcerpt: preset.previewExcerpt,
      qualityScore: preset.qualityScore,
      suggestion: preset.suggestion,
      recognizedWords: _decorateWords(preset.words),
      createdAt: DateTime.now(),
    );
  }

  List<RecognitionCapture> _readCaptureList() {
    final rawList = _preferences.getStringList(_capturesKey) ?? <String>[];
    return rawList
        .map((item) => RecognitionCapture.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  List<StudyRecord> _readHistoryList() {
    final rawList = _preferences.getStringList(_historyKey) ?? <String>[];
    return rawList
        .map((item) => StudyRecord.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ))
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
      _history
          .map((item) => jsonEncode(item.toJson()))
          .toList(growable: false),
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
