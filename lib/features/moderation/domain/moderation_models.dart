import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ReportStatus { pending, reviewed, resolved, dismissed }
enum ReportType { user, post, comment, chat }

class ModerationReport extends Equatable {
  final String id;
  final String reporterId;
  final String targetId; // ID of the user, post, or content being reported
  final ReportType type;
  final String reason;
  final String? details;
  final ReportStatus status;
  final DateTime createdAt;
  final String? handledBy; // Admin/Moderator ID
  final DateTime? handledAt;
  final String? adminNote;

  const ModerationReport({
    required this.id,
    required this.reporterId,
    required this.targetId,
    required this.type,
    required this.reason,
    this.details,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.handledBy,
    this.handledAt,
    this.adminNote,
  });

  @override
  List<Object?> get props => [
        id,
        reporterId,
        targetId,
        type,
        reason,
        details,
        status,
        createdAt,
        handledBy,
        handledAt,
        adminNote,
      ];

  factory ModerationReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ModerationReport(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      targetId: data['targetId'] ?? '',
      type: ReportType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'user'),
        orElse: () => ReportType.user,
      ),
      reason: data['reason'] ?? '',
      details: data['details'],
      status: ReportStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => ReportStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      handledBy: data['handledBy'],
      handledAt: (data['handledAt'] as Timestamp?)?.toDate(),
      adminNote: data['adminNote'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'targetId': targetId,
      'type': type.name,
      'reason': reason,
      'details': details,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'handledBy': handledBy,
      'handledAt': handledAt != null ? Timestamp.fromDate(handledAt!) : null,
      'adminNote': adminNote,
    };
  }
}

enum SanctionType { warning, strike, ban }

class Sanction extends Equatable {
  final String id;
  final String userId;
  final String adminId;
  final String? communityId;
  final SanctionType type;
  final String reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;

  const Sanction({
    required this.id,
    required this.userId,
    required this.adminId,
    this.communityId,
    required this.type,
    required this.reason,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, userId, adminId, communityId, type, reason, createdAt, expiresAt, isActive];

  factory Sanction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sanction(
      id: doc.id,
      userId: data['userId'] ?? '',
      adminId: data['adminId'] ?? '',
      communityId: data['communityId'],
      type: SanctionType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'warning'),
        orElse: () => SanctionType.warning,
      ),
      reason: data['reason'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'adminId': adminId,
      'communityId': communityId,
      'type': type.name,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
    };
  }
}
