import 'package:equatable/equatable.dart';
import '../../domain/moderation_models.dart';

abstract class ModerationState extends Equatable {
  const ModerationState();
  
  @override
  List<Object?> get props => [];
}

class ModerationInitial extends ModerationState {}

class ModerationLoading extends ModerationState {}

class ModerationLoaded extends ModerationState {
  final List<ModerationReport> pendingReports;
  final List<ModerationReport> handledReports;
  final List<Sanction>? activeSanctions;

  const ModerationLoaded({
    required this.pendingReports,
    required this.handledReports,
    this.activeSanctions,
  });

  @override
  List<Object?> get props => [pendingReports, handledReports, activeSanctions];
}

class ModerationError extends ModerationState {
  final String message;
  const ModerationError(this.message);

  @override
  List<Object?> get props => [message];
}

class ModerationSuccess extends ModerationState {
  final String message;
  const ModerationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
