import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class WikiPage extends Equatable {
  final String id;
  final String communityId;
  final String authorId;
  final String authorName; // NEW
  final String authorAvatarUrl; // NEW
  final String? authorAvatarFrameUrl; // NEW
  final String title;
  final String content; // Legacy text or fallback
  final List<Map<String, dynamic>> blocks; // Rich text / Custom blocks [{ "type": "text", "value": "..." }]
  final String? iconUrl;
  final String? coverUrl;
  final Map<String, String> labels; // e.g., {'Rating': '5', 'Genre': 'Horror'}
  final int likesCount;
  final int commentsCount;
  final bool isApproved; // For "Golden" wikis in Catalog
  final bool isPendingReview; // Flag for submission flow
  final DateTime createdAt;

  const WikiPage({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.authorName, // NEW
    required this.authorAvatarUrl, // NEW
    this.authorAvatarFrameUrl, // NEW
    required this.title,
    required this.content,
    this.blocks = const [],
    this.iconUrl,
    this.coverUrl,
    this.labels = const {},
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isApproved = false,
    this.isPendingReview = false,
    required this.createdAt,
  });

  WikiPage copyWith({
    String? id,
    String? communityId,
    String? authorId,
    String? authorName, // NEW
    String? authorAvatarUrl, // NEW
    String? authorAvatarFrameUrl, // NEW
    String? title,
    String? content,
    List<Map<String, dynamic>>? blocks,
    String? iconUrl,
    String? coverUrl,
    Map<String, String>? labels,
    int? likesCount,
    int? commentsCount,
    bool? isApproved,
    bool? isPendingReview,
    DateTime? createdAt,
  }) {
    return WikiPage(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName, // NEW
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl, // NEW
      authorAvatarFrameUrl: authorAvatarFrameUrl ?? this.authorAvatarFrameUrl, // NEW
      title: title ?? this.title,
      content: content ?? this.content,
      blocks: blocks ?? this.blocks,
      iconUrl: iconUrl ?? this.iconUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      labels: labels ?? this.labels,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isApproved: isApproved ?? this.isApproved,
      isPendingReview: isPendingReview ?? this.isPendingReview,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'authorId': authorId,
      'authorName': authorName, // NEW
      'authorAvatarUrl': authorAvatarUrl, // NEW
      'authorAvatarFrameUrl': authorAvatarFrameUrl, // NEW
      'title': title,
      'content': content,
      'blocks': blocks,
      'iconUrl': iconUrl,
      'coverUrl': coverUrl,
      'labels': labels,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'isApproved': isApproved,
      'isPendingReview': isPendingReview,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WikiPage.fromMap(Map<String, dynamic> map, String id) {
    return WikiPage(
      id: id,
      communityId: map['communityId']?.toString() ?? '',
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ?? 'Usuario',
      authorAvatarUrl: map['authorAvatarUrl']?.toString() ?? '',
      authorAvatarFrameUrl: map['authorAvatarFrameUrl']?.toString(),
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      blocks: map['blocks'] != null 
          ? List<Map<String, dynamic>>.from(
              (map['blocks'] as List).map((x) => Map<String, dynamic>.from(x as Map))
            )
          : [],
      iconUrl: map['iconUrl']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      labels: (map['labels'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ?? {},
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      isApproved: map['isApproved'] ?? false,
      isPendingReview: map['isPendingReview'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        communityId,
        authorId,
        title,
        content,
        blocks,
        iconUrl,
        coverUrl,
        labels,
        likesCount,
        commentsCount,
        isApproved,
        isPendingReview,
        createdAt,
      ];
}
