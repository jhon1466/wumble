import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String? authorAvatarFrameUrl; // NEW
  final String communityId;

  final String content;        // Legacy text
  final List<String> images;   // Legacy image grid
  final String? title;
  final String? backgroundImageUrl;
  final String? backgroundColor;
  final List<Map<String, dynamic>> blocks; // Rich text / Custom blocks [{ "type": "text", "value": "..." }]
  final List<String> likes;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final String type; // 'blog', 'image', 'video', 'status'
  final String? categoryId;
  final List<String> tags; // NEW
  final String? stickerUrl;
  final bool isFeatured;
  final DateTime? featuredAt;
  final bool isPinned;
  final DateTime? pinnedAt;

  // Integrated Poll Fields
  final List<String> pollOptions;
  final Map<String, int> pollVotes;
  final DateTime? pollEndsAt;
  final int pollTotalVotes;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    this.authorAvatarFrameUrl, // NEW
    required this.communityId,

    required this.content,
    this.images = const [],
    this.title,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.blocks = const [],
    this.likes = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.type = 'blog',
    this.categoryId,
    this.tags = const [], // NEW
    this.stickerUrl,
    this.isFeatured = false,
    this.featuredAt,
    this.isPinned = false,
    this.pinnedAt,
    this.pollOptions = const [],
    this.pollVotes = const {},
    this.pollEndsAt,
    this.pollTotalVotes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'authorAvatarFrameUrl': authorAvatarFrameUrl, // NEW
      'communityId': communityId,

      'content': content,
      'images': images,
      if (title != null) 'title': title,
      if (backgroundImageUrl != null) 'backgroundImageUrl': backgroundImageUrl,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      'blocks': blocks,
      'likes': likes,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type,
      if (categoryId != null) 'categoryId': categoryId,
      'tags': tags, // NEW
      if (stickerUrl != null) 'stickerUrl': stickerUrl,
      'isFeatured': isFeatured,
      if (featuredAt != null) 'featuredAt': Timestamp.fromDate(featuredAt!),
      'isPinned': isPinned,
      if (pinnedAt != null) 'pinnedAt': Timestamp.fromDate(pinnedAt!),
      'pollOptions': pollOptions,
      'pollVotes': pollVotes,
      if (pollEndsAt != null) 'pollEndsAt': Timestamp.fromDate(pollEndsAt!),
      'pollTotalVotes': pollTotalVotes,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map, String documentId) {
    return Post(
      id: documentId,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Usuario',
      authorAvatarUrl: map['authorAvatarUrl'] ?? '',
      authorAvatarFrameUrl: map['authorAvatarFrameUrl'] as String?, // NEW
      communityId: map['communityId'] ?? '',

      content: map['content'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      title: map['title'],
      backgroundImageUrl: map['backgroundImageUrl'],
      backgroundColor: map['backgroundColor'],
      blocks: map['blocks'] != null 
          ? List<Map<String, dynamic>>.from(map['blocks'].map((x) => Map<String, dynamic>.from(x)))
          : [],
      likes: List<String>.from(map['likes'] ?? []),
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      type: map['type'] ?? 'blog',
      categoryId: map['categoryId'],
      tags: List<String>.from(map['tags'] ?? []), // NEW
      stickerUrl: map['stickerUrl'],
      isFeatured: map['isFeatured'] == true,
      featuredAt: map['featuredAt'] != null 
          ? (map['featuredAt'] as Timestamp).toDate() 
          : null,
      isPinned: map['isPinned'] == true,
      pinnedAt: map['pinnedAt'] != null 
          ? (map['pinnedAt'] as Timestamp).toDate() 
          : null,
      pollOptions: List<String>.from(map['pollOptions'] ?? []),
      pollVotes: Map<String, int>.from(map['pollVotes'] ?? {}),
      pollEndsAt: map['pollEndsAt'] != null
          ? (map['pollEndsAt'] as Timestamp).toDate()
          : null,
      pollTotalVotes: map['pollTotalVotes'] ?? 0,
    );
  }
}

// Keep mockPosts for fallback/testing if needed, but updated
final List<Post> mockPosts = [];
