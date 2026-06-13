import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/moderation_models.dart';
import '../domain/moderation_repository.dart';

class ModerationRepositoryImpl implements ModerationRepository {
  final FirebaseFirestore _firestore;

  ModerationRepositoryImpl(this._firestore);

  @override
  Future<void> submitReport(ModerationReport report) async {
    await _firestore.collection('reports').add(report.toFirestore());
  }

  @override
  Stream<List<ModerationReport>> getPendingReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: ReportStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ModerationReport.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<ModerationReport>> getHandledReports() {
    return _firestore
        .collection('reports')
        .where('status', isNotEqualTo: ReportStatus.pending.name)
        .orderBy('status') // Firestore requirement: inequity filter field must be first in orderBy
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ModerationReport.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> updateReportStatus(String reportId, ReportStatus status, String adminId, {String? note}) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': status.name,
      'handledBy': adminId,
      'handledAt': FieldValue.serverTimestamp(),
      'adminNote': note,
    });
  }

  @override
  Future<void> applySanction(Sanction sanction) async {
    await _firestore.collection('sanctions').add(sanction.toFirestore());
    
    // If it's a ban, we might want to update the user document for quick checks
    if (sanction.type == SanctionType.ban) {
      await _firestore.collection('users').doc(sanction.userId).update({
        'isBanned': true,
      });
    }
  }

  @override
  Future<void> revokeSanction(String sanctionId, String adminId, String reason) async {
    final doc = await _firestore.collection('sanctions').doc(sanctionId).get();
    if (!doc.exists) return;
    
    final sanction = Sanction.fromFirestore(doc);
    
    await _firestore.collection('sanctions').doc(sanctionId).update({
      'isActive': false,
      'revokedBy': adminId,
      'revokedAt': FieldValue.serverTimestamp(),
      'revocationReason': reason,
    });

    if (sanction.type == SanctionType.ban) {
      // Check if there are other active bans
      final activeBans = await _firestore
          .collection('sanctions')
          .where('userId', isEqualTo: sanction.userId)
          .where('type', isEqualTo: SanctionType.ban.name)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (activeBans.docs.isEmpty) {
        await _firestore.collection('users').doc(sanction.userId).update({
          'isBanned': false,
        });
      }
    }
  }

  @override
  Stream<List<Sanction>> getUserSanctions(String userId) {
    return _firestore
        .collection('sanctions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Sanction.fromFirestore(doc))
            .toList());
  }

  @override
  Future<bool> isUserBanned(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    return doc.data()?['isBanned'] ?? false;
  }

  @override
  Future<void> updateUserRole(String userId, String newRole) async {
    await _firestore.collection('users').doc(userId).update({
      'globalRole': newRole,
    });
  }
}
