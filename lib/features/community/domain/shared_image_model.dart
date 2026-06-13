import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SharedImage extends Equatable {
  final String id;
  final String communityId;
  final String authorId;
  final String imageUrl;
  final String? title;
  final String? categoryId; // Opcional para organizar en álbumes/categorías
  final int likesCount;
  final DateTime createdAt;

  const SharedImage({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.imageUrl,
    this.title,
    this.categoryId,
    this.likesCount = 0,
    required this.createdAt,
  });

  SharedImage copyWith({
    String? id,
    String? communityId,
    String? authorId,
    String? imageUrl,
    String? title,
    String? categoryId,
    int? likesCount,
    DateTime? createdAt,
  }) {
    return SharedImage(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      authorId: authorId ?? this.authorId,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'authorId': authorId,
      'imageUrl': imageUrl,
      'title': title,
      'categoryId': categoryId,
      'likesCount': likesCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SharedImage.fromMap(Map<String, dynamic> map, String id) {
    return SharedImage(
      id: id,
      communityId: map['communityId'] ?? '',
      authorId: map['authorId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      title: map['title'],
      categoryId: map['categoryId'],
      likesCount: map['likesCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        communityId,
        authorId,
        imageUrl,
        title,
        categoryId,
        likesCount,
        createdAt,
      ];
}

class SharedFolderCategory extends Equatable {
  final String id;
  final String communityId;
  final String name;
  final int order;

  const SharedFolderCategory({
    required this.id,
    required this.communityId,
    required this.name,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'name': name,
      'order': order,
    };
  }

  factory SharedFolderCategory.fromMap(Map<String, dynamic> map, String id) {
    return SharedFolderCategory(
      id: id,
      communityId: map['communityId'] ?? '',
      name: map['name'] ?? '',
      order: map['order'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, communityId, name, order];
}
