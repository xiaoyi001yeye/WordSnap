enum MemoryBucket { mastered, fuzzy, uncertain, unseen }

enum ExamWordScope { recognized, wordBook, reviewQueue }

enum ExamMode { singlePlayer, twoPlayer }

enum ExamPlayerSide { red, blue }

class WordEntry {
  static const String unresolvedMeaning = '待补充释义';
  static const String unresolvedPhonetic = '/-/';

  const WordEntry({
    required this.word,
    required this.meaning,
    required this.phonetic,
    this.confidence = 0.98,
    this.bucket = MemoryBucket.unseen,
    this.isFavorite = false,
    this.inReviewQueue = false,
    this.recognitionCount = 0,
    this.examCount = 0,
    this.lastSourceLabel,
  });

  final String word;
  final String meaning;
  final String phonetic;
  final double confidence;
  final MemoryBucket bucket;
  final bool isFavorite;
  final bool inReviewQueue;
  final int recognitionCount;
  final int examCount;
  final String? lastSourceLabel;

  String get normalizedWord => word.toLowerCase();
  bool get hasResolvedMeaning => meaning != unresolvedMeaning;

  WordEntry copyWith({
    String? word,
    String? meaning,
    String? phonetic,
    double? confidence,
    MemoryBucket? bucket,
    bool? isFavorite,
    bool? inReviewQueue,
    int? recognitionCount,
    int? examCount,
    String? lastSourceLabel,
  }) {
    return WordEntry(
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      phonetic: phonetic ?? this.phonetic,
      confidence: confidence ?? this.confidence,
      bucket: bucket ?? this.bucket,
      isFavorite: isFavorite ?? this.isFavorite,
      inReviewQueue: inReviewQueue ?? this.inReviewQueue,
      recognitionCount: recognitionCount ?? this.recognitionCount,
      examCount: examCount ?? this.examCount,
      lastSourceLabel: lastSourceLabel ?? this.lastSourceLabel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'meaning': meaning,
      'phonetic': phonetic,
      'confidence': confidence,
      'bucket': bucket.name,
      'isFavorite': isFavorite,
      'inReviewQueue': inReviewQueue,
      'recognitionCount': recognitionCount,
      'examCount': examCount,
      'lastSourceLabel': lastSourceLabel,
    };
  }

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    return WordEntry(
      word: json['word'] as String,
      meaning: json['meaning'] as String,
      phonetic: json['phonetic'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.98,
      bucket: _memoryBucketFromName(json['bucket'] as String?) ??
          MemoryBucket.unseen,
      isFavorite: json['isFavorite'] as bool? ?? false,
      inReviewQueue: json['inReviewQueue'] as bool? ?? false,
      recognitionCount: json['recognitionCount'] as int? ?? 0,
      examCount: json['examCount'] as int? ?? 0,
      lastSourceLabel: json['lastSourceLabel'] as String?,
    );
  }
}

class WordBook {
  const WordBook({
    required this.name,
    required this.totalWords,
    required this.lastStudiedLabel,
    required this.words,
  });

  final String name;
  final int totalWords;
  final String lastStudiedLabel;
  final List<WordEntry> words;
}

class RecentStudyUnit {
  const RecentStudyUnit({
    required this.title,
    required this.wordCount,
    required this.reviewCount,
    required this.dateLabel,
    required this.typeLabel,
  });

  final String title;
  final int wordCount;
  final int reviewCount;
  final String dateLabel;
  final String typeLabel;
}

class StudyPreferences {
  const StudyPreferences({
    required this.questionCount,
    required this.optionCount,
    required this.allowMultiple,
    required this.randomOrder,
    this.examMode = ExamMode.singlePlayer,
  });

  final int questionCount;
  final int optionCount;
  final bool allowMultiple;
  final bool randomOrder;
  final ExamMode examMode;

  StudyPreferences copyWith({
    int? questionCount,
    int? optionCount,
    bool? allowMultiple,
    bool? randomOrder,
    ExamMode? examMode,
  }) {
    return StudyPreferences(
      questionCount: questionCount ?? this.questionCount,
      optionCount: optionCount ?? this.optionCount,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      randomOrder: randomOrder ?? this.randomOrder,
      examMode: examMode ?? this.examMode,
    );
  }
}

class RecognitionPreset {
  const RecognitionPreset({
    required this.id,
    required this.title,
    required this.sourceLabel,
    required this.previewTitle,
    required this.previewExcerpt,
    required this.qualityScore,
    required this.suggestion,
    required this.words,
  });

  final String id;
  final String title;
  final String sourceLabel;
  final String previewTitle;
  final String previewExcerpt;
  final double qualityScore;
  final String suggestion;
  final List<WordEntry> words;

  bool get isLowQuality => qualityScore < 0.75;
}

class RecognitionCapture {
  const RecognitionCapture({
    required this.id,
    required this.title,
    required this.sourceTypeLabel,
    required this.sourceLabel,
    required this.previewTitle,
    required this.previewExcerpt,
    required this.qualityScore,
    required this.suggestion,
    required this.recognizedWords,
    required this.distractorPool,
    required this.createdAt,
    this.imagePath,
    this.ocrEngineLabel,
    this.rawRecognizedText,
    this.recognizedLineCount = 0,
    this.recognizedPhonetics = const <String>[],
    this.recognizedCjkLineCount = 0,
  });

  final String id;
  final String title;
  final String sourceTypeLabel;
  final String sourceLabel;
  final String previewTitle;
  final String previewExcerpt;
  final double qualityScore;
  final String suggestion;
  final List<WordEntry> recognizedWords;
  final List<String> distractorPool;
  final DateTime createdAt;
  final String? imagePath;
  final String? ocrEngineLabel;
  final String? rawRecognizedText;
  final int recognizedLineCount;
  final List<String> recognizedPhonetics;
  final int recognizedCjkLineCount;

  bool get isLowQuality => qualityScore < 0.75;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sourceTypeLabel': sourceTypeLabel,
      'sourceLabel': sourceLabel,
      'previewTitle': previewTitle,
      'previewExcerpt': previewExcerpt,
      'qualityScore': qualityScore,
      'suggestion': suggestion,
      'recognizedWords': recognizedWords.map((item) => item.toJson()).toList(),
      'distractorPool': distractorPool,
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
      'ocrEngineLabel': ocrEngineLabel,
      'rawRecognizedText': rawRecognizedText,
      'recognizedLineCount': recognizedLineCount,
      'recognizedPhonetics': recognizedPhonetics,
      'recognizedCjkLineCount': recognizedCjkLineCount,
    };
  }

  factory RecognitionCapture.fromJson(Map<String, dynamic> json) {
    return RecognitionCapture(
      id: json['id'] as String,
      title: json['title'] as String,
      sourceTypeLabel: json['sourceTypeLabel'] as String,
      sourceLabel: json['sourceLabel'] as String,
      previewTitle: json['previewTitle'] as String,
      previewExcerpt: json['previewExcerpt'] as String,
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.8,
      suggestion: json['suggestion'] as String? ?? '',
      recognizedWords: (json['recognizedWords'] as List<dynamic>? ?? [])
          .map((item) => WordEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      distractorPool: (json['distractorPool'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(growable: false),
      createdAt: DateTime.parse(json['createdAt'] as String),
      imagePath: json['imagePath'] as String?,
      ocrEngineLabel: json['ocrEngineLabel'] as String?,
      rawRecognizedText: json['rawRecognizedText'] as String?,
      recognizedLineCount: json['recognizedLineCount'] as int? ?? 0,
      recognizedPhonetics: (json['recognizedPhonetics'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(growable: false),
      recognizedCjkLineCount: json['recognizedCjkLineCount'] as int? ?? 0,
    );
  }
}

class ExamQuestion {
  ExamQuestion({
    required this.word,
    required this.meaning,
    required this.phonetic,
    required this.options,
    required this.correctIndexes,
  }) : userSelections = <int>{};

  final String word;
  final String meaning;
  final String phonetic;
  final List<String> options;
  final Set<int> correctIndexes;
  final Set<int> userSelections;
  final Map<ExamPlayerSide, int> playerSelections =
      <ExamPlayerSide, int>{};
  ExamPlayerSide? multiplayerWinner;

  bool get isSkipped => userSelections.isEmpty;

  bool get isMultiplayerResolved {
    return multiplayerWinner != null ||
        playerSelections.length == ExamPlayerSide.values.length;
  }

  bool isPlayerCorrect(ExamPlayerSide side) {
    final selectedIndex = playerSelections[side];
    return selectedIndex != null && correctIndexes.contains(selectedIndex);
  }

  bool get isCorrect {
    if (userSelections.length != correctIndexes.length) {
      return false;
    }

    for (final index in userSelections) {
      if (!correctIndexes.contains(index)) {
        return false;
      }
    }

    return true;
  }
}

class ExamSession {
  ExamSession({
    required this.book,
    required this.preferences,
    required this.questions,
    required this.generatedAt,
    required this.scope,
    required this.sourceLabel,
  });

  final WordBook book;
  final StudyPreferences preferences;
  final List<ExamQuestion> questions;
  final DateTime generatedAt;
  final ExamWordScope scope;
  final String sourceLabel;
}

class MistakeReviewItem {
  const MistakeReviewItem({
    required this.word,
    required this.phonetic,
    required this.correctMeaning,
    required this.selectedMeanings,
  });

  final String word;
  final String phonetic;
  final String correctMeaning;
  final List<String> selectedMeanings;

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'phonetic': phonetic,
      'correctMeaning': correctMeaning,
      'selectedMeanings': selectedMeanings,
    };
  }

  factory MistakeReviewItem.fromJson(Map<String, dynamic> json) {
    return MistakeReviewItem(
      word: json['word'] as String,
      phonetic: json['phonetic'] as String? ?? '',
      correctMeaning: json['correctMeaning'] as String,
      selectedMeanings: (json['selectedMeanings'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(growable: false),
    );
  }
}

class StudySummary {
  const StudySummary({
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
    required this.bucketCounts,
    required this.mistakes,
  });

  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final Map<MemoryBucket, int> bucketCounts;
  final List<MistakeReviewItem> mistakes;

  double get accuracy =>
      totalQuestions == 0 ? 0 : correctCount / totalQuestions;

  Map<String, dynamic> toJson() {
    return {
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'skippedCount': skippedCount,
      'bucketCounts': bucketCounts.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'mistakes': mistakes.map((item) => item.toJson()).toList(),
    };
  }

  factory StudySummary.fromJson(Map<String, dynamic> json) {
    return StudySummary(
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      wrongCount: json['wrongCount'] as int? ?? 0,
      skippedCount: json['skippedCount'] as int? ?? 0,
      bucketCounts: (json['bucketCounts'] as Map<String, dynamic>? ?? {})
          .map<MemoryBucket, int>((key, value) {
        return MapEntry(
          _memoryBucketFromName(key) ?? MemoryBucket.unseen,
          value as int? ?? 0,
        );
      }),
      mistakes: (json['mistakes'] as List<dynamic>? ?? [])
          .map(
            (item) => MistakeReviewItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

class StudyRecord {
  const StudyRecord({
    required this.id,
    required this.title,
    required this.sourceLabel,
    required this.studiedAt,
    required this.summary,
  });

  final String id;
  final String title;
  final String sourceLabel;
  final DateTime studiedAt;
  final StudySummary summary;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sourceLabel': sourceLabel,
      'studiedAt': studiedAt.toIso8601String(),
      'summary': summary.toJson(),
    };
  }

  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    return StudyRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      sourceLabel: json['sourceLabel'] as String,
      studiedAt: DateTime.parse(json['studiedAt'] as String),
      summary: StudySummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

extension MemoryBucketCopy on MemoryBucket {
  String get label {
    switch (this) {
      case MemoryBucket.mastered:
        return '掌握';
      case MemoryBucket.fuzzy:
        return '不熟悉';
      case MemoryBucket.uncertain:
        return '不确定';
      case MemoryBucket.unseen:
        return '没学过';
    }
  }
}

extension ExamWordScopeCopy on ExamWordScope {
  String get label {
    switch (this) {
      case ExamWordScope.recognized:
        return '本次识别';
      case ExamWordScope.wordBook:
        return '默认词本';
      case ExamWordScope.reviewQueue:
        return '复习队列';
    }
  }
}

extension ExamModeCopy on ExamMode {
  String get label {
    switch (this) {
      case ExamMode.singlePlayer:
        return '单人模式';
      case ExamMode.twoPlayer:
        return '双人模式';
    }
  }

  int get optionCount {
    switch (this) {
      case ExamMode.singlePlayer:
        return 9;
      case ExamMode.twoPlayer:
        return 4;
    }
  }
}

extension ExamPlayerSideCopy on ExamPlayerSide {
  String get label {
    switch (this) {
      case ExamPlayerSide.red:
        return '红方';
      case ExamPlayerSide.blue:
        return '蓝方';
    }
  }
}

MemoryBucket? _memoryBucketFromName(String? name) {
  for (final bucket in MemoryBucket.values) {
    if (bucket.name == name) {
      return bucket;
    }
  }
  return null;
}

ExamMode examModeFromName(String? name) {
  for (final mode in ExamMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return ExamMode.singlePlayer;
}
