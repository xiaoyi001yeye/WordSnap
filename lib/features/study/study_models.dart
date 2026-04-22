enum MemoryBucket {
  mastered,
  fuzzy,
  uncertain,
  unseen,
}

class WordEntry {
  const WordEntry({
    required this.word,
    required this.meaning,
    required this.phonetic,
    this.confidence = 0.98,
    this.bucket = MemoryBucket.unseen,
  });

  final String word;
  final String meaning;
  final String phonetic;
  final double confidence;
  final MemoryBucket bucket;

  WordEntry copyWith({
    String? word,
    String? meaning,
    String? phonetic,
    double? confidence,
    MemoryBucket? bucket,
  }) {
    return WordEntry(
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      phonetic: phonetic ?? this.phonetic,
      confidence: confidence ?? this.confidence,
      bucket: bucket ?? this.bucket,
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
  });

  final String title;
  final int wordCount;
  final int reviewCount;
  final String dateLabel;
}

class StudyPreferences {
  const StudyPreferences({
    required this.questionCount,
    required this.optionCount,
    required this.allowMultiple,
    required this.randomOrder,
  });

  final int questionCount;
  final int optionCount;
  final bool allowMultiple;
  final bool randomOrder;

  StudyPreferences copyWith({
    int? questionCount,
    int? optionCount,
    bool? allowMultiple,
    bool? randomOrder,
  }) {
    return StudyPreferences(
      questionCount: questionCount ?? this.questionCount,
      optionCount: optionCount ?? this.optionCount,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      randomOrder: randomOrder ?? this.randomOrder,
    );
  }
}

class ExamQuestion {
  ExamQuestion({
    required this.word,
    required this.phonetic,
    required this.options,
    required this.correctIndexes,
  }) : userSelections = <int>{};

  final String word;
  final String phonetic;
  final List<String> options;
  final Set<int> correctIndexes;
  final Set<int> userSelections;

  bool get isSkipped => userSelections.isEmpty;

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
  });

  final WordBook book;
  final StudyPreferences preferences;
  final List<ExamQuestion> questions;
  final DateTime generatedAt;
}

class MistakeReviewItem {
  const MistakeReviewItem({
    required this.word,
    required this.correctMeaning,
    required this.selectedMeanings,
  });

  final String word;
  final String correctMeaning;
  final List<String> selectedMeanings;
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
