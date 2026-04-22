import 'dart:math';

import 'study_models.dart';

class WordSnapDemoService {
  WordSnapDemoService() : _random = Random(7);

  final Random _random;

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
  ];

  WordBook loadDefaultBook() {
    return const WordBook(
      name: '默认单词本',
      totalWords: 218,
      lastStudiedLabel: '今天',
      words: _bookWords,
    );
  }

  List<RecentStudyUnit> loadRecentUnits() {
    return const [
      RecentStudyUnit(
        title: 'Unit 1 自然灾害',
        wordCount: 56,
        reviewCount: 18,
        dateLabel: '05-20',
      ),
      RecentStudyUnit(
        title: '英语课本 P3',
        wordCount: 72,
        reviewCount: 66,
        dateLabel: '05-18',
      ),
      RecentStudyUnit(
        title: '拍照识别新增',
        wordCount: 32,
        reviewCount: 14,
        dateLabel: '今天',
      ),
    ];
  }

  List<WordEntry> loadRecognizedWords() {
    const recognizedWords = [
      'natural',
      'disaster',
      'event',
      'cause',
      'force',
      'Earth',
      'flood',
      'hurricane',
      'wildfire',
      'happen',
      'reduce',
      'harm',
      'property',
      'suddenly',
      'damage',
      'step',
    ];

    return _bookWords
        .where((entry) => recognizedWords.contains(entry.word))
        .toList(growable: false);
  }

  StudyPreferences defaultPreferences() {
    return const StudyPreferences(
      questionCount: 20,
      optionCount: 6,
      allowMultiple: true,
      randomOrder: true,
    );
  }

  ExamSession createExam({
    required WordBook book,
    required StudyPreferences preferences,
  }) {
    final pool = List<WordEntry>.from(book.words);
    if (preferences.randomOrder) {
      pool.shuffle(_random);
    }

    final questionCount =
        preferences.questionCount.clamp(1, book.words.length) as int;
    final optionCount =
        preferences.optionCount.clamp(3, book.words.length - 1) as int;
    final selected = pool.take(questionCount).toList();
    final questions = selected.map((entry) {
      final distractors = List<WordEntry>.from(book.words)
        ..removeWhere((candidate) => candidate.word == entry.word)
        ..shuffle(_random);

      final optionWords = <String>[entry.meaning];
      optionWords.addAll(
        distractors
            .take(optionCount - 1)
            .map((item) => item.meaning),
      );
      optionWords.shuffle(_random);

      final correctIndexes = <int>{optionWords.indexOf(entry.meaning)};

      return ExamQuestion(
        word: entry.word,
        phonetic: entry.phonetic,
        options: optionWords,
        correctIndexes: correctIndexes,
      );
    }).toList(growable: false);

    return ExamSession(
      book: book,
      preferences: preferences,
      questions: questions,
      generatedAt: DateTime.now(),
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
          correctMeaning: question.options[question.correctIndexes.first],
          selectedMeanings: question.userSelections
              .map((index) => question.options[index])
              .toList(growable: false),
        ),
      );
    }

    final bucketCounts = <MemoryBucket, int>{
      MemoryBucket.mastered: correctCount,
      MemoryBucket.fuzzy: wrongCount,
      MemoryBucket.uncertain: skippedCount,
      MemoryBucket.unseen:
          (session.book.words.length - session.questions.length)
              .clamp(0, session.book.words.length) as int,
    };

    return StudySummary(
      totalQuestions: session.questions.length,
      correctCount: correctCount,
      wrongCount: wrongCount,
      skippedCount: skippedCount,
      bucketCounts: bucketCounts,
      mistakes: mistakes,
    );
  }

  Map<MemoryBucket, int> previewBucketCounts() {
    return const {
      MemoryBucket.mastered: 20,
      MemoryBucket.fuzzy: 6,
      MemoryBucket.uncertain: 3,
      MemoryBucket.unseen: 3,
    };
  }
}
