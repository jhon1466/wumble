import 'package:cloud_firestore/cloud_firestore.dart';

class Poll {
  final String id;
  final String creatorId;
  final String creatorName;
  final String creatorAvatarUrl;
  final String communityId;
  final String question;
  final List<PollOption> options;
  final int durationDays;
  final DateTime endsAt;
  final DateTime createdAt;
  final int totalVotes;
  final int likesCount;
  final int commentsCount;

  Poll({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.creatorAvatarUrl,
    required this.communityId,
    required this.question,
    required this.options,
    required this.durationDays,
    required this.endsAt,
    required this.createdAt,
    this.totalVotes = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  bool get isExpired => DateTime.now().isAfter(endsAt);

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorAvatarUrl': creatorAvatarUrl,
      'communityId': communityId,
      'question': question,
      'options': options.map((o) => o.toMap()).toList(),
      'durationDays': durationDays,
      'endsAt': Timestamp.fromDate(endsAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'totalVotes': totalVotes,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map, String documentId) {
    return Poll(
      id: documentId,
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? 'Usuario',
      creatorAvatarUrl: map['creatorAvatarUrl'] ?? '',
      communityId: map['communityId'] ?? '',
      question: map['question'] ?? '',
      options: (map['options'] as List? ?? [])
          .map((o) => PollOption.fromMap(o as Map<String, dynamic>))
          .toList(),
      durationDays: map['durationDays'] ?? 3,
      endsAt: (map['endsAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      totalVotes: map['totalVotes'] ?? 0,
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
    );
  }
}

class PollOption {
  final String id;
  final String text;
  final int voteCount;

  PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'voteCount': voteCount,
    };
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      voteCount: map['voteCount'] ?? 0,
    );
  }
}

class PollVote {
  final String userId;
  final String pollId;
  final String optionId;
  final DateTime votedAt;

  PollVote({
    required this.userId,
    required this.pollId,
    required this.optionId,
    required this.votedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'pollId': pollId,
      'optionId': optionId,
      'votedAt': Timestamp.fromDate(votedAt),
    };
  }

  factory PollVote.fromMap(Map<String, dynamic> map) {
    return PollVote(
      userId: map['userId'] ?? '',
      pollId: map['pollId'] ?? '',
      optionId: map['optionId'] ?? '',
      votedAt: (map['votedAt'] as Timestamp).toDate(),
    );
  }
}
