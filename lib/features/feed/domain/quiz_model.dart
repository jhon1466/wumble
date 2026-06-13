import 'package:cloud_firestore/cloud_firestore.dart';

class Quiz {
  final String id;
  final String creatorId;
  final String creatorName;
  final String creatorAvatarUrl;
  final String communityId;
  final String title;
  final String description;
  final String? imageUrl;
  final List<QuizQuestion> questions;
  final int playCount;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.creatorAvatarUrl,
    required this.communityId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.questions,
    this.playCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorAvatarUrl': creatorAvatarUrl,
      'communityId': communityId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'questions': questions.map((q) => q.toMap()).toList(),
      'playCount': playCount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Quiz.fromMap(Map<String, dynamic> map, String documentId) {
    return Quiz(
      id: documentId,
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? 'Usuario',
      creatorAvatarUrl: map['creatorAvatarUrl'] ?? '',
      communityId: map['communityId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      questions: (map['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
      playCount: map['playCount'] ?? 0,
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class QuizQuestion {
  final String text;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;
  final String? imageUrl;

  QuizQuestion({
    required this.text,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'imageUrl': imageUrl,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      text: map['text'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      explanation: map['explanation'],
      imageUrl: map['imageUrl'],
    );
  }
}

class QuizAttempt {
  final String id;
  final String quizId;
  final String userId;
  final String username;
  final String userAvatarUrl;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final bool isHardMode;
  final DateTime completedAt;

  QuizAttempt({
    required this.id,
    required this.quizId,
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.isHardMode,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'score': score,
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'isHardMode': isHardMode,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }

  factory QuizAttempt.fromMap(Map<String, dynamic> map, String documentId) {
    return QuizAttempt(
      id: documentId,
      quizId: map['quizId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Usuario',
      userAvatarUrl: map['userAvatarUrl'] ?? '',
      score: map['score'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      isHardMode: map['isHardMode'] ?? false,
      completedAt: (map['completedAt'] as Timestamp).toDate(),
    );
  }
}
