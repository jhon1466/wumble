import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ModerationReportStatus { pending, approved, rejected }
enum ModerationTargetType { post, comment, chat, profile }

class ModerationReport extends Equatable {
  final String id;
  final String communityId;
  final String reporterId; // Can be a botId or userId
  final String targetId;   // ID of the content (postId, commentId, etc.)
  final String targetUserId; // UID of the user who created the content
  final ModerationTargetType targetType;
  final String contentPreview;
  final String? mediaUrl;
  final String reason;
  final ModerationReportStatus status;
  final DateTime createdAt;
  final double confidenceScore;
  final Map<String, dynamic> metadata;

  const ModerationReport({
    required this.id,
    required this.communityId,
    required this.reporterId,
    required this.targetId,
    required this.targetUserId,
    required this.targetType,
    required this.contentPreview,
    this.mediaUrl,
    required this.reason,
    this.status = ModerationReportStatus.pending,
    required this.createdAt,
    this.confidenceScore = 0.0,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'communityId': communityId,
      'reporterId': reporterId,
      'targetId': targetId,
      'targetUserId': targetUserId,
      'targetType': targetType.name,
      'contentPreview': contentPreview,
      'mediaUrl': mediaUrl,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'confidenceScore': confidenceScore,
      'metadata': metadata,
    };
  }

  factory ModerationReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ModerationReport(
      id: doc.id,
      communityId: data['communityId'] ?? '',
      reporterId: data['reporterId'] ?? '',
      targetId: data['targetId'] ?? '',
      targetUserId: data['targetUserId'] ?? '',
      targetType: ModerationTargetType.values.firstWhere(
        (e) => e.name == data['targetType'],
        orElse: () => ModerationTargetType.post,
      ),
      contentPreview: data['contentPreview'] ?? '',
      mediaUrl: data['mediaUrl'],
      reason: data['reason'] ?? '',
      status: ModerationReportStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ModerationReportStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confidenceScore: (data['confidenceScore'] ?? 0.0).toDouble(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  ModerationReport copyWith({
    ModerationReportStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return ModerationReport(
      id: id,
      communityId: communityId,
      reporterId: reporterId,
      targetId: targetId,
      targetUserId: targetUserId,
      targetType: targetType,
      contentPreview: contentPreview,
      mediaUrl: mediaUrl,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      confidenceScore: confidenceScore,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    id, communityId, reporterId, targetId, targetUserId, 
    targetType, contentPreview, mediaUrl, reason, 
    status, createdAt, confidenceScore, metadata
  ];
}
