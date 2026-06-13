import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'post_like', 'comment', 'comment_like', 'reply'
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final String? postId;
  final String? wikiId;
  final String? roomId;
  final String? commentId;
  final String? communityId;
  final String? communityName;
  final String? communityAvatarUrl;
  final DateTime createdAt;
  final bool isRead;

  ActivityNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    this.postId,
    this.wikiId,
    this.roomId,
    this.commentId,
    this.communityId,
    this.communityName,
    this.communityAvatarUrl,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'postId': postId,
      'wikiId': wikiId,
      'roomId': roomId,
      'commentId': commentId,
      'communityId': communityId,
      'communityName': communityName,
      'communityAvatarUrl': communityAvatarUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory ActivityNotification.fromMap(Map<String, dynamic> map, String documentId) {
    return ActivityNotification(
      id: documentId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Usuario',
      senderAvatarUrl: map['senderAvatarUrl'] ?? '',
      postId: map['postId'],
      wikiId: map['wikiId'],
      roomId: map['roomId'],
      commentId: map['commentId'],
      communityId: map['communityId'],
      communityName: map['communityName'],
      communityAvatarUrl: map['communityAvatarUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}
