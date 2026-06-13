import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for local user ID check
import '../domain/chat_model.dart';
import '../domain/chat_repository.dart';
import '../../../core/services/live_audio_service.dart';

// ──── Events ────

abstract class LiveEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SubscribeToLiveSession extends LiveEvent {
  final String chatRoomId;
  SubscribeToLiveSession(this.chatRoomId);
  @override
  List<Object?> get props => [chatRoomId];
}

class StartLiveEvent extends LiveEvent {
  final String chatRoomId;
  final String hostId;
  final String hostName;
  final String hostAvatar;
  StartLiveEvent({
    required this.chatRoomId,
    required this.hostId,
    required this.hostName,
    required this.hostAvatar,
  });
  @override
  List<Object?> get props => [chatRoomId, hostId, hostName, hostAvatar];
}

class JoinLiveEvent extends LiveEvent {
  final String chatRoomId;
  final LiveParticipant participant;
  JoinLiveEvent({required this.chatRoomId, required this.participant});
  @override
  List<Object?> get props => [chatRoomId, participant];
}

class LeaveLiveEvent extends LiveEvent {
  final String chatRoomId;
  final String userId;
  LeaveLiveEvent({required this.chatRoomId, required this.userId});
  @override
  List<Object?> get props => [chatRoomId, userId];
}

class ToggleMicEvent extends LiveEvent {
  final String chatRoomId;
  final String userId;
  final bool isMicOn;
  ToggleMicEvent({required this.chatRoomId, required this.userId, required this.isMicOn});
  @override
  List<Object?> get props => [chatRoomId, userId, isMicOn];
}

class EndLiveEvent extends LiveEvent {
  final String chatRoomId;
  EndLiveEvent(this.chatRoomId);
  @override
  List<Object?> get props => [chatRoomId];
}

class UpdateSpeakingParticipants extends LiveEvent {
  final List<int> speakingUids;
  UpdateSpeakingParticipants(this.speakingUids);
  @override
  List<Object?> get props => [speakingUids];
}

// ──── States ────

abstract class LiveState extends Equatable {
  const LiveState();
  @override
  List<Object?> get props => [];
}

class LiveInitial extends LiveState {}

class LiveActive extends LiveState {
  final LiveSession session;
  const LiveActive(this.session);
  @override
  List<Object?> get props => [session];
}

class LiveInactive extends LiveState {}

class LiveError extends LiveState {
  final String message;
  const LiveError(this.message);
  @override
  List<Object?> get props => [message];
}

// ──── BLoC ────

class LiveBloc extends Bloc<LiveEvent, LiveState> {
  final ChatRepository _repository;
  final LiveAudioService _audioService;

  StreamSubscription? _volumeSubscription;
  List<int> _lastSpeakingUids = [];
  final Map<int, DateTime> _lastSpeakingTimestamps = {};

  LiveBloc({
    required ChatRepository repository,
    required LiveAudioService audioService,
  })  : _repository = repository,
        _audioService = audioService,
        super(LiveInitial()) {
    
    // Subscribe to volume stream
    _volumeSubscription = _audioService.onVolumeIndication.listen((speakingUids) {
      _lastSpeakingUids = speakingUids;
      add(UpdateSpeakingParticipants(speakingUids));
    });

    on<SubscribeToLiveSession>((event, emit) async {
      await emit.forEach(
        _repository.getLiveSession(event.chatRoomId),
        onData: (session) {
          if (session != null && session.isActive) {
            final now = DateTime.now();
            final mergedParticipants = session.participants.map((p) {
              final participantUid = _audioService.getStableUid(p.userId);
              
              // Use persistence logic for initial merge too
              final lastHeard = _lastSpeakingTimestamps[participantUid] ?? _lastSpeakingTimestamps[0];
              final isSpeaking = lastHeard != null && 
                               now.difference(lastHeard).inMilliseconds < 450;
                               
              return p.copyWith(isSpeaking: isSpeaking);
            }).toList();

            return LiveActive(session.copyWith(participants: mergedParticipants));
          } else {
            return LiveInactive();
          }
        },
        onError: (e, _) => LiveError(e.toString()),
      );
    });

    on<StartLiveEvent>((event, emit) async {
      try {
        await _repository.startLiveSession(
          chatRoomId: event.chatRoomId,
          hostId: event.hostId,
          hostName: event.hostName,
          hostAvatar: event.hostAvatar,
        );
        await _audioService.joinChannel(event.chatRoomId, event.hostId);
      } catch (e) {
        emit(LiveError(e.toString()));
      }
    });

    on<JoinLiveEvent>((event, emit) async {
      try {
        await _repository.joinLiveSession(event.chatRoomId, event.participant);
        await _audioService.joinChannel(event.chatRoomId, event.participant.userId);
      } catch (e) {
        emit(LiveError(e.toString()));
      }
    });

    on<LeaveLiveEvent>((event, emit) async {
      try {
        await _repository.leaveLiveSession(event.chatRoomId, event.userId);
        await _audioService.leaveChannel();
      } catch (e) {
        emit(LiveError(e.toString()));
      }
    });

    on<ToggleMicEvent>((event, emit) async {
      try {
        await _repository.updateParticipantStatus(
          event.chatRoomId,
          event.userId,
          isMicOn: event.isMicOn,
        );
        await _audioService.toggleMic(event.isMicOn);
      } catch (e) {
        emit(LiveError(e.toString()));
      }
    });

    on<EndLiveEvent>((event, emit) async {
      try {
        await _repository.endLiveSession(event.chatRoomId);
        await _audioService.leaveChannel();
      } catch (e) {
        emit(LiveError(e.toString()));
      }
    });

    on<UpdateSpeakingParticipants>((event, emit) {
      if (state is LiveActive) {
        final currentSession = (state as LiveActive).session;
        final currentUser = FirebaseAuth.instance.currentUser;
        final now = DateTime.now();

        // Update timestamps for currently speaking UIDs
        for (final uid in event.speakingUids) {
          _lastSpeakingTimestamps[uid] = now;
        }

        final updatedParticipants = currentSession.participants.map((p) {
          final participantUid = _audioService.getStableUid(p.userId);
          
          // Persistence: Still speaking if heard in the last 450ms
          final lastHeard = _lastSpeakingTimestamps[participantUid];
          bool isSpeaking = lastHeard != null && 
                           now.difference(lastHeard).inMilliseconds < 450;
          
          // Fallback for local user (reported as 0 or with their UID)
          if (currentUser != null && p.userId == currentUser.uid) {
            final localLastHeard = _lastSpeakingTimestamps[0];
            bool localIsSpeaking = localLastHeard != null && 
                                  now.difference(localLastHeard).inMilliseconds < 450;
            if (localIsSpeaking) isSpeaking = true;
          }
          
          if (isSpeaking) {
            debugPrint('🔥 [BLOC SPEAKING] ${p.username} | UID: $participantUid | local: ${p.userId == currentUser?.uid}');
          }
          
          return p.copyWith(isSpeaking: isSpeaking);
        }).toList();

        emit(LiveActive(currentSession.copyWith(participants: updatedParticipants)));
      }
    });
  }

  @override
  Future<void> close() {
    _volumeSubscription?.cancel();
    _audioService.dispose();
    return super.close();
  }
}
