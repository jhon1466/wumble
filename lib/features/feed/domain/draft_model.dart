import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDraft {
  final String id;
  final String? title;
  final String? communityId;
  final String? backgroundColor;
  final String? backgroundImageUrl;
  final List<Map<String, dynamic>> blocks;
  final String? categoryId;
  final File? backgroundImageFile; // Added
  final DateTime createdAt;
  final DateTime updatedAt;

  PostDraft({
    required this.id,
    this.title,
    this.communityId,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.blocks = const [],
    this.categoryId,
    this.backgroundImageFile, // Added
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'communityId': communityId,
      'backgroundColor': backgroundColor,
      'backgroundImageUrl': backgroundImageUrl,
      'blocks': blocks,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PostDraft.fromMap(Map<String, dynamic> map, String documentId) {
    return PostDraft(
      id: documentId,
      title: map['title'],
      communityId: map['communityId'],
      backgroundColor: map['backgroundColor'],
      backgroundImageUrl: map['backgroundImageUrl'],
      blocks: map['blocks'] != null 
          ? List<Map<String, dynamic>>.from(map['blocks'].map((x) => Map<String, dynamic>.from(x)))
          : [],
      categoryId: map['categoryId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
