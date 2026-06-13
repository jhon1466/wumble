import 'package:equatable/equatable.dart';
import '../../domain/moderation_models.dart';

abstract class ModerationEvent extends Equatable {
  const ModerationEvent();

  @override
  List<Object?> get props => [];
}

class LoadModerationDashboard extends ModerationEvent {}

class FetchUserModerationHistory extends ModerationEvent {
  final String userId;
  const FetchUserModerationHistory(this.userId);

  @override
  List<Object?> get props => [userId];
}

class SubmitReportEvent extends ModerationEvent {
  final ModerationReport report;
  const SubmitReportEvent(this.report);

  @override
  List<Object?> get props => [report];
}

class ResolveReport extends ModerationEvent {
  final String reportId;
  final ReportStatus status;
  final String adminId;
  final String? note;

  const ResolveReport({
    required this.reportId,
    required this.status,
    required this.adminId,
    this.note,
  });

  @override
  List<Object?> get props => [reportId, status, adminId, note];
}

class ApplySanctionEvent extends ModerationEvent {
  final Sanction sanction;
  const ApplySanctionEvent(this.sanction);

  @override
  List<Object?> get props => [sanction];
}

class RevokeSanctionEvent extends ModerationEvent {
  final String sanctionId;
  final String adminId;
  final String reason;

  const RevokeSanctionEvent({
    required this.sanctionId,
    required this.adminId,
    required this.reason,
  });

  @override
  List<Object?> get props => [sanctionId, adminId, reason];
}
