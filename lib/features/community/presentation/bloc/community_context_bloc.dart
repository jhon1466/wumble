import 'package:firebase_auth/firebase_auth.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/community_model.dart';
import '../../domain/community_member_model.dart';
import '../../domain/community_repository.dart'; // Add this import
import '../../../profile/domain/profile_repository.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/core/services/notification_service.dart';
import '../../domain/moderation_report_model.dart';

abstract class CommunityContextEvent {}

class EnterCommunity extends CommunityContextEvent {
  final Community community;
  EnterCommunity(this.community);
}

class ExitCommunity extends CommunityContextEvent {}

class CommunityMemberProfileUpdated extends CommunityContextEvent {
  final CommunityMember member;
  CommunityMemberProfileUpdated(this.member);
}

class ActiveCommunityUpdated extends CommunityContextEvent {
  final Community community;
  ActiveCommunityUpdated(this.community);
}

class JoinCommunityRequested extends CommunityContextEvent {
  final Community? community;
  JoinCommunityRequested({this.community});
}

class ClearJoinSuccess extends CommunityContextEvent {}

class LeaveCommunityRequested extends CommunityContextEvent {}

class CheckInRequested extends CommunityContextEvent {}

class CommunityContextState {
  final Community? activeCommunity;
  final CommunityMember? memberProfile;
  final bool isLoading;
  final bool hasPendingRequest;
  final int? lastCoinReward;
  final int checkInCompletedTrigger;
  final bool isNewlyJoined;

  CommunityContextState({
    this.activeCommunity,
    this.memberProfile,
    this.isLoading = true, // Default to true to prevent flicker
    this.hasPendingRequest = false,
    this.lastCoinReward,
    this.checkInCompletedTrigger = 0,
    this.isNewlyJoined = false,
  });

  CommunityContextState copyWith({
    Community? activeCommunity,
    CommunityMember? memberProfile,
    bool? isLoading,
    bool? hasPendingRequest,
    int? lastCoinReward,
    int? checkInCompletedTrigger,
    bool? isNewlyJoined,
    bool clearCommunity = false,
    bool clearMemberProfile = false,
  }) {
    return CommunityContextState(
      activeCommunity: clearCommunity ? null : (activeCommunity ?? this.activeCommunity),
      memberProfile: clearCommunity || clearMemberProfile ? null : (memberProfile ?? this.memberProfile),
      isLoading: isLoading ?? this.isLoading,
      hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
      lastCoinReward: lastCoinReward, // Nullable, usually reset on each emit unless passed
      checkInCompletedTrigger: checkInCompletedTrigger ?? (this.checkInCompletedTrigger ?? 0),
      isNewlyJoined: isNewlyJoined ?? (this.isNewlyJoined ?? false),
    );
  }
}

class CommunityContextBloc extends Bloc<CommunityContextEvent, CommunityContextState> {
  final ProfileRepository _profileRepository;
  final FirebaseAuth _auth;
  final CommunityRepository _communityRepository;
  StreamSubscription<CommunityMember?>? _memberSubscription;
  StreamSubscription<Community?>? _communitySubscription;
  StreamSubscription<QuerySnapshot>? _moderationSubscription;
  DateTime? _lastModerationAlertTime;

  CommunityContextBloc({
    required ProfileRepository profileRepository,
    required CommunityRepository communityRepository, // Add this
    required FirebaseAuth auth,
  })  : _profileRepository = profileRepository,
        _communityRepository = communityRepository, // Add this
        _auth = auth,
        super(CommunityContextState()) {
    on<EnterCommunity>(_onEnterCommunity);
    on<ExitCommunity>(_onExitCommunity);
    on<CommunityMemberProfileUpdated>(_onCommunityMemberProfileUpdated);
    on<JoinCommunityRequested>(_onJoinCommunityRequested);
    on<LeaveCommunityRequested>(_onLeaveCommunityRequested);
    on<CheckInRequested>(_onCheckInRequested);
    on<ActiveCommunityUpdated>(_onActiveCommunityUpdated);
    on<ClearJoinSuccess>((event, emit) => emit(state.copyWith(isNewlyJoined: false)));
  }

  Future<void> _onEnterCommunity(EnterCommunity event, Emitter<CommunityContextState> emit) async {
    debugPrint('CommunityContextBloc: Entering community ${event.community.id}');
    final bool isSameCommunity = state.activeCommunity?.id == event.community.id;
    emit(state.copyWith(
      activeCommunity: event.community, 
      isLoading: true, 
      clearMemberProfile: !isSameCommunity,
      isNewlyJoined: false, // Ensure this isn't stuck from a previous community
      checkInCompletedTrigger: 0, // Reset trigger when entering new community context
    ));
    
    final userId = _auth.currentUser?.uid;
    
    try {
      // 1. Fetch FULL community details immediately (ensures tabs and metadata are correct for guests)
      final fullCommunity = await _communityRepository.getCommunity(event.community.id);
      final activeCommunity = fullCommunity ?? event.community;

      if (userId == null) {
        // Guest mode - Emitting full community immediately
        emit(state.copyWith(activeCommunity: activeCommunity, isLoading: false, clearMemberProfile: true));
        return;
      }

      // 2. Fetch Member Profile
      final member = await _profileRepository.getMemberProfile(event.community.id, userId);
      
      if (member == null) {
        // Fallback: If we just joined, we might have the member profile already in state
        // even if replication lag makes the fetch return null.
        if (state.memberProfile != null && state.activeCommunity?.id == event.community.id) {
          emit(state.copyWith(activeCommunity: activeCommunity, memberProfile: state.memberProfile, isLoading: false));
          return;
        }

        // Not a member: Check for pending request
        bool pending = false;
        try {
          pending = await _communityRepository.hasPendingRequest(event.community.id, userId);
        } catch (_) {}
        
        emit(state.copyWith(activeCommunity: activeCommunity, isLoading: false, hasPendingRequest: pending, clearMemberProfile: true));
      } else {
        // Is a member
        debugPrint('CommunityContextBloc: User IS a member. Level: ${member.level}');
        CommunityMember currentMember = member;

        // Auto-unban check
        if (currentMember.isBanned && 
            currentMember.banExpiresAt != null && 
            currentMember.banExpiresAt!.isBefore(DateTime.now())) {
          try {
            await _communityRepository.unbanMember(event.community.id, userId);
            currentMember = currentMember.copyWith(isBanned: false, banExpiresAt: null);
          } catch (e) {
            print('Error auto-unbanning member: $e');
          }
        }

        emit(state.copyWith(activeCommunity: activeCommunity, memberProfile: currentMember, isLoading: false));
        
        // Setup subscriptions
        _memberSubscription?.cancel();
        _memberSubscription = _profileRepository
            .getMemberProfileStream(event.community.id, userId)
            .listen((updatedMember) {
              if (updatedMember != null) add(CommunityMemberProfileUpdated(updatedMember));
            });
        
        _setupModerationListener(event.community.id, currentMember);
      }

      // 3. Setup real-time community stream (metadata monitoring: membersCount, name, etc.)
      _communitySubscription?.cancel();
      _communitySubscription = _communityRepository
          .getCommunityStream(event.community.id)
          .listen((updatedCommunity) {
            if (updatedCommunity != null) add(ActiveCommunityUpdated(updatedCommunity));
          });

    } catch (e) {
      debugPrint('CommunityContextBloc: Error entering community: $e');
      emit(state.copyWith(isLoading: false, clearMemberProfile: true, hasPendingRequest: false)); 
    }
  }

  void _onExitCommunity(ExitCommunity event, Emitter<CommunityContextState> emit) {
    _memberSubscription?.cancel();
    _memberSubscription = null;
    _communitySubscription?.cancel();
    _communitySubscription = null;
    _moderationSubscription?.cancel();
    _moderationSubscription = null;
    emit(state.copyWith(clearCommunity: true));
  }

  void _onActiveCommunityUpdated(ActiveCommunityUpdated event, Emitter<CommunityContextState> emit) {
    if (state.activeCommunity?.id == event.community.id) {
       // Keep the isNewlyJoined flag if we are just updating the object
       emit(state.copyWith(activeCommunity: event.community));
    }
  }

  void _onCommunityMemberProfileUpdated(CommunityMemberProfileUpdated event, Emitter<CommunityContextState> emit) {
    if (state.activeCommunity?.id == event.member.communityId) {
      debugPrint('CommunityContextBloc: Profile updated for current community');
      final oldRole = state.memberProfile?.role;
      emit(state.copyWith(memberProfile: event.member));
      
      // Si el rol cambió a staff, iniciar listener
      if (oldRole != event.member.role) {
        _setupModerationListener(event.member.communityId, event.member);
      }
    }
  }

  void _setupModerationListener(String communityId, CommunityMember member) {
    _moderationSubscription?.cancel();
    _moderationSubscription = null;

    if (member.role == 'leader' || member.role == 'curator') {
      debugPrint('ModerationListener: Starting for Staff in $communityId');
      _moderationSubscription = FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('moderation_reports')
          .where('status', isEqualTo: ModerationReportStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final report = ModerationReport.fromFirestore(doc);
          
          // Solo notificar si es nuevo (creado hace menos de 30 segundos)
          // Y si no hemos notificado este mismo reporte recientemente
          final now = DateTime.now();
          if (report.createdAt.isAfter(now.subtract(const Duration(seconds: 30)))) {
             if (_lastModerationAlertTime == null || report.createdAt.isAfter(_lastModerationAlertTime!)) {
                _lastModerationAlertTime = report.createdAt;
                
                NotificationService.showLocalNotification(
                  id: report.id.hashCode,
                  title: tr('🛡️ ALERTA DE MODERACIÓN'),
                  body: 'La IA ha detectado contenido sospechoso en la comunidad.',
                  data: {
                    'type': 'moderation_report',
                    'communityId': communityId,
                    'reportId': report.id,
                  },
                );
             }
          }
        }
      });
    }
  }

  Future<void> _onJoinCommunityRequested(JoinCommunityRequested event, Emitter<CommunityContextState> emit) async {
    final userId = _auth.currentUser?.uid;
    final targetCommunity = event.community ?? state.activeCommunity;
    
    if (userId == null || targetCommunity == null) return;
    
    emit(state.copyWith(isLoading: true, activeCommunity: targetCommunity, isNewlyJoined: false));
    try {
      if (targetCommunity.privacy == 'approval') {
        // Enviar solicitud en lugar de unirse directamente
        await _communityRepository.requestJoinCommunity(targetCommunity.id, userId);
        emit(state.copyWith(isLoading: false, hasPendingRequest: true));
        return;
      } else if (targetCommunity.privacy == 'private') {
        // Privada: rechazar la acción
        emit(state.copyWith(isLoading: false));
        return;
      }

      await _communityRepository.joinCommunity(targetCommunity.id, userId);
      // Refresh member profile
      final member = await _profileRepository.getMemberProfile(targetCommunity.id, userId);
      
      // Update community member count optimistically
      final updatedCommunity = targetCommunity.copyWith(
        membersCount: targetCommunity.membersCount + 1
      );
      
      emit(state.copyWith(
        memberProfile: member, 
        activeCommunity: updatedCommunity,
        isLoading: false,
        hasPendingRequest: false,
        isNewlyJoined: true,
      ));
    } catch (e) {
      debugPrint('Error joining community: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onLeaveCommunityRequested(LeaveCommunityRequested event, Emitter<CommunityContextState> emit) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || state.activeCommunity == null) return;

    emit(state.copyWith(isLoading: true));
    try {
      await _communityRepository.leaveCommunity(state.activeCommunity!.id, userId);
      
      // Update community member count optimistically
      final updatedCommunity = state.activeCommunity!.copyWith(
        membersCount: (state.activeCommunity!.membersCount - 1).clamp(0, 999999999)
      );

      emit(CommunityContextState(
        activeCommunity: updatedCommunity,
        memberProfile: null,
        isLoading: false,
        hasPendingRequest: false,
      ));
    } catch (e) {
      print('Error leaving community: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCheckInRequested(CheckInRequested event, Emitter<CommunityContextState> emit) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || state.activeCommunity == null) return;

    try {
      // 1. Community-specific check-in (Awards 15 rep + Random 1-100 Coins)
      final int coinReward = await _communityRepository.checkIn(state.activeCommunity!.id, userId);

      // 2. Also award global metadata (streak + 10 global rep) if not already done today
      try {
        await _profileRepository.performCheckIn(userId);
      } catch (_) {
        // Already checked in globally today — that's fine, ignore the error
      }

      // 3. Refresh member profile to reflect updated rep
      final member = await _profileRepository.getMemberProfile(state.activeCommunity!.id, userId);
      emit(state.copyWith(
        memberProfile: member, 
        lastCoinReward: coinReward,
        checkInCompletedTrigger: state.checkInCompletedTrigger + 1,
      ));
    } catch (e) {
      print('Error checking in: $e');
    }
  }

  @override
  Future<void> close() {
    _memberSubscription?.cancel();
    _communitySubscription?.cancel();
    _moderationSubscription?.cancel();
    return super.close();
  }
}
