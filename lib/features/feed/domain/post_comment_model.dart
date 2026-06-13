import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/core/domain/link_preview_data.dart';

class PostComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String? authorAvatarFrameUrl; // NEW
  final String content;

  final String? imageUrl;
  final String? gifUrl;
  final String? stickerUrl;
  final DateTime createdAt;
  final int likesCount;
  final List<PostComment> replies;
  final int authorLevel;
  final List<CommunityLabel> authorTitles;
  final String authorRole;
  final Map<String, List<String>> reactions; // NEW
  final LinkPreviewData? linkPreview; // NEW

  PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    this.authorAvatarFrameUrl, // NEW
    required this.content,

    this.imageUrl,
    this.gifUrl,
    this.stickerUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.replies = const [],
    this.authorLevel = 1,
    this.authorTitles = const [],
    this.authorRole = 'member',
    this.reactions = const {},
    this.linkPreview,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'authorAvatarFrameUrl': authorAvatarFrameUrl, // NEW
      'content': content,

      if (imageUrl != null) 'imageUrl': imageUrl,
      if (gifUrl != null) 'gifUrl': gifUrl,
      if (stickerUrl != null) 'stickerUrl': stickerUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'replies': replies.map((r) => r.toMap()).toList(),
      'authorLevel': authorLevel,
      'authorTitles': authorTitles.map((t) => t.toFirestore()).toList(),
      'authorRole': authorRole,
      'reactions': reactions,
      'linkPreview': linkPreview?.toMap(),
    };
  }

  factory PostComment.fromMap(Map<String, dynamic> map, String documentId) {
    return PostComment(
      id: documentId,
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Usuario',
      authorAvatarUrl: map['authorAvatarUrl'] ?? '',
      authorAvatarFrameUrl: map['authorAvatarFrameUrl'] as String?, // NEW
      content: map['content'] ?? '',

      imageUrl: map['imageUrl'],
      gifUrl: map['gifUrl'],
      stickerUrl: map['stickerUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      replies: map['replies'] != null
          ? (map['replies'] as List<dynamic>)
              .map((r) => PostComment.fromMap(r as Map<String, dynamic>, ''))
              .toList()
          : [],
      authorLevel: map['authorLevel'] ?? 1,
      authorTitles: CommunityLabel.fromDynamicList(map['authorTitles']),
      authorRole: map['authorRole'] ?? 'member',
      reactions: (map['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List<dynamic>)),
          ) ??
          {},
      linkPreview: map['linkPreview'] != null ? LinkPreviewData.fromMap(map['linkPreview']) : null,
    );
  }
}
