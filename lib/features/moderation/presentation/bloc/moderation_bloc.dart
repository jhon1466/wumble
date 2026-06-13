import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/moderation_models.dart';
import '../../domain/moderation_repository.dart';
import 'moderation_event.dart';
import 'moderation_state.dart';

class ModerationBloc extends Bloc<ModerationEvent, ModerationState> {
  final ModerationRepository _repository;
  StreamSubscription? _pendingSub;
  StreamSubscription? _handledSub;

  ModerationBloc({required ModerationRepository repository})
      : _repository = repository,
        super(ModerationInitial()) {
    on<LoadModerationDashboard>(_onLoadDashboard);
    on<ResolveReport>(_onResolveReport);
    on<ApplySanctionEvent>(_onApplySanction);
    on<RevokeSanctionEvent>(_onRevokeSanction);
    on<SubmitReportEvent>(_onSubmitReport);
  }

  Future<void> _onLoadDashboard(LoadModerationDashboard event, Emitter<ModerationState> emit) async {
    emit(ModerationLoading());
    
    await _pendingSub?.cancel();
    await _handledSub?.cancel();

    final pendingStream = _repository.getPendingReports();
    final handledStream = _repository.getHandledReports();

    // Simplified combined listener
    // In a real app we might want more granular handling
    _pendingSub = pendingStream.listen((reports) {
      final current = state;
      if (current is ModerationLoaded) {
        add(_UpdateLoadedState(pending: reports, handled: current.handledReports));
      } else {
        add(_UpdateLoadedState(pending: reports, handled: []));
      }
    });

    _handledSub = handledStream.listen((reports) {
      final current = state;
      if (current is ModerationLoaded) {
        add(_UpdateLoadedState(pending: current.pendingReports, handled: reports));
      } else {
        add(_UpdateLoadedState(pending: [], handled: reports));
      }
    });
    
    // Internal event to update state from streams
    on<_UpdateLoadedState>((event, emit) {
      emit(ModerationLoaded(pendingReports: event.pending, handledReports: event.handled));
    });
  }

  Future<void> _onResolveReport(ResolveReport event, Emitter<ModerationState> emit) async {
    try {
      await _repository.updateReportStatus(event.reportId, event.status, event.adminId, note: event.note);
      emit(const ModerationSuccess('Reporte actualizado correctamente'));
      // dashboard will auto-update via streams
    } catch (e) {
      emit(ModerationError('Error al actualizar reporte: $e'));
    }
  }

  Future<void> _onApplySanction(ApplySanctionEvent event, Emitter<ModerationState> emit) async {
    try {
      await _repository.applySanction(event.sanction);
      emit(const ModerationSuccess('Sanción aplicada correctamente'));
    } catch (e) {
      emit(ModerationError('Error al aplicar sanción: $e'));
    }
  }

  Future<void> _onRevokeSanction(RevokeSanctionEvent event, Emitter<ModerationState> emit) async {
    try {
      await _repository.revokeSanction(event.sanctionId, event.adminId, event.reason);
      emit(const ModerationSuccess('Sanción revocada correctamente'));
    } catch (e) {
      emit(ModerationError('Error al revocar sanción: $e'));
    }
  }

  Future<void> _onSubmitReport(SubmitReportEvent event, Emitter<ModerationState> emit) async {
    try {
      await _repository.submitReport(event.report);
      emit(const ModerationSuccess('Reporte enviado correctamente. El staff lo revisará pronto.'));
    } catch (e) {
      emit(ModerationError('Error al enviar reporte: $e'));
    }
  }

  @override
  Future<void> close() {
    _pendingSub?.cancel();
    _handledSub?.cancel();
    return super.close();
  }
}

class _UpdateLoadedState extends ModerationEvent {
  final List<ModerationReport> pending;
  final List<ModerationReport> handled;
  const _UpdateLoadedState({required this.pending, required this.handled});
}
