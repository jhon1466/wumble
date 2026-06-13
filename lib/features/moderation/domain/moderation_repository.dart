import 'moderation_models.dart';

abstract class ModerationRepository {
  // Reports
  Future<void> submitReport(ModerationReport report);
  Stream<List<ModerationReport>> getPendingReports();
  Stream<List<ModerationReport>> getHandledReports();
  Future<void> updateReportStatus(String reportId, ReportStatus status, String adminId, {String? note});

  // Sanctions
  Future<void> applySanction(Sanction sanction);
  Future<void> revokeSanction(String sanctionId, String adminId, String reason);
  Stream<List<Sanction>> getUserSanctions(String userId);
  Future<bool> isUserBanned(String userId);

  // Tools
  Future<void> updateUserRole(String userId, String newRole);
}
