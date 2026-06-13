import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';

class WikiComment {
  final String id;
  final String wikiId;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String content;
  final String? imageUrl;
  final String? stickerUrl;
  final DateTime createdAt;
  final int likesCount;
  final List<WikiComment> replies;
  final int authorLevel;
  final List<CommunityLabel> authorTitles;
  final String authorRole;
  final Map<String, List<String>> reactions;

  WikiComment({
    required this.id,
    required this.wikiId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.content,
    this.imageUrl,
    this.stickerUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.replies = const [],
    this.authorLevel = 1,
    this.authorTitles = const [],
    this.authorRole = 'member',
    this.reactions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'wikiId': wikiId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (stickerUrl != null) 'stickerUrl': stickerUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'replies': replies.map((r) => r.toMap()).toList(),
      'authorLevel': authorLevel,
      'authorTitles': authorTitles.map((t) => t.toFirestore()).toList(),
      'authorRole': authorRole,
      'reactions': reactions,
    };
  }

  factory WikiComment.fromMap(Map<String, dynamic> map, String documentId) {
    return WikiComment(
      id: documentId,
      wikiId: map['wikiId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Usuario',
      authorAvatarUrl: map['authorAvatarUrl'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      stickerUrl: map['stickerUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      replies: map['replies'] != null
          ? (map['replies'] as List<dynamic>)
              .map((r) => WikiComment.fromMap(r as Map<String, dynamic>, ''))
              .toList()
          : [],
      authorLevel: map['authorLevel'] ?? 1,
      authorTitles: CommunityLabel.fromDynamicList(map['authorTitles']),
      authorRole: map['authorRole'] ?? 'member',
      reactions: (map['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List<dynamic>)),
          ) ??
          {},
    );
  }
  WikiComment copyWith({
    String? id,
    String? wikiId,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? content,
    String? imageUrl,
    String? stickerUrl,
    DateTime? createdAt,
    int? likesCount,
    List<WikiComment>? replies,
    int? authorLevel,
    List<CommunityLabel>? authorTitles,
    String? authorRole,
    Map<String, List<String>>? reactions,
  }) {
    return WikiComment(
      id: id ?? this.id,
      wikiId: wikiId ?? this.wikiId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      stickerUrl: stickerUrl ?? this.stickerUrl,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      replies: replies ?? this.replies,
      authorLevel: authorLevel ?? this.authorLevel,
      authorTitles: authorTitles ?? this.authorTitles,
      authorRole: authorRole ?? this.authorRole,
      reactions: reactions ?? this.reactions,
    );
  }
}
