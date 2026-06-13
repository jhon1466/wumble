import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  final String id;
  final String userId;
  final String communityId;
  final String message;
  final DateTime requestedAt;

  JoinRequest({
    required this.id,
    required this.userId,
    required this.communityId,
    this.message = '',
    required this.requestedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'communityId': communityId,
      'message': message,
      'requestedAt': Timestamp.fromDate(requestedAt),
    };
  }

  factory JoinRequest.fromMap(Map<String, dynamic> map, String documentId) {
    return JoinRequest(
      id: documentId,
      userId: map['userId'] ?? '',
      communityId: map['communityId'] ?? '',
      message: map['message'] ?? '',
      requestedAt: (map['requestedAt'] as Timestamp).toDate(),
    );
  }
}
