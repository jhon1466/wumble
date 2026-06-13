import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class LiveAudioService {
  // Injected at build time via --dart-define (see dart_defines.example.json).
  static const String appId =
      String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
  
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isSpeakerOn = false;

  bool get isSpeakerOn => _isSpeakerOn;

  final _volumeController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get onVolumeIndication => _volumeController.stream;

  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint('🎤 LiveAudioService: Initializing...');

    // Request permissions
    final status = await Permission.microphone.request();
    debugPrint('🎤 Microphone Permission Status: $status');
    if (!status.isGranted) {
      debugPrint('❌ Microphone permission denied');
      return;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: appId,
        // Usar Communication para llamadas 1:1 o grupos pequeños (mejor cancelación de eco)
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      await _engine!.enableAudio();
      
      // These are optional — wrap individually so they don't abort init
      try {
        await _engine!.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint('⚠️ setEnableSpeakerphone failed (non-fatal): $e');
      }
      
      try {
        await _engine!.enableInEarMonitoring(enabled: false, includeAudioFilters: EarMonitoringFilterType.earMonitoringFilterNone);
      } catch (e) {
        debugPrint('⚠️ enableInEarMonitoring failed (non-fatal): $e');
      }
      
      // 1. First register handler
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onError: (ErrorCodeType err, String msg) {
            debugPrint('❌ [AGORA ERROR] $err: $msg');
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('✅ [AGORA] Joined channel: ${connection.channelId} (uid: ${connection.localUid})');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('👤 [AGORA] User joined: $remoteUid');
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('👋 [AGORA] User offline: $remoteUid reason: $reason');
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('🔄 [AGORA] Connection State: $state (Reason: $reason)');
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint('👋 [AGORA] Left channel');
          },
          onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
            // Mapping 0 (local user) to their actual stable UID for global consistency
            // We use connection.localUid which contains our joined UID.
            final localUid = connection.localUid ?? 0;
            
            final speakingUids = speakers
                .where((s) => (s.volume ?? 0) > 1) 
                .map((s) => (s.uid == 0 || s.uid == localUid) ? localUid : s.uid!)
                .toList();

            if (speakingUids.isNotEmpty) {
              debugPrint('🔥 [AGORA VOL] Detected speakers: $speakingUids (local was $localUid)');
            }
            _volumeController.add(speakingUids);
          },
        ),
      );


      _isInitialized = true;
      debugPrint('✅ LiveAudioService: Initialized success');
    } catch (e) {
      debugPrint('❌ LiveAudioService Init Error: $e');
    }
  }

  Future<void> joinChannel(String channelId, String userId) async {
    if (!_isInitialized) await init();

    final uid = getStableUid(userId);
    debugPrint('🎤 Joining Channel: $channelId as UID: $uid');

    try {
      await _engine!.joinChannel(
        token: "", 
        channelId: channelId,
        uid: uid, 
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster, 
        ),
      );
      
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
      
      // CRITICAL: Enable volume indication AFTER joining channel
      await _engine!.enableAudioVolumeIndication(interval: 250, smooth: 3, reportVad: true);
      debugPrint('🎤 enableAudioVolumeIndication called AFTER join');
      
    } catch (e) {
      debugPrint('❌ LiveAudioService Join Error: $e');
    }
  }

  Future<void> toggleMic(bool isOn) async {
    if (_engine == null) return;
    debugPrint('🎤 Toggling Mic: $isOn');
    
    try {
      if (isOn) {
        await _engine!.muteLocalAudioStream(false);
        await _engine!.enableLocalAudio(true);
      } else {
        await _engine!.muteLocalAudioStream(true);
        await _engine!.enableLocalAudio(false);
      }
    } catch (e) {
      debugPrint('Error toggling mic: $e');
    }
  }

  Future<void> toggleSpeaker(bool speakerOn) async {
    if (_engine == null) return;
    debugPrint('🔊 Toggling Speaker: $speakerOn');
    try {
      await _engine!.setEnableSpeakerphone(speakerOn);
      _isSpeakerOn = speakerOn;
    } catch (e) {
      debugPrint('⚠️ toggleSpeaker error: $e');
    }
  }

  Future<void> leaveChannel() async {
    if (_engine != null) {
      debugPrint('🎤 Leaving Channel');
      await _engine!.leaveChannel();
    }
  }

  Future<void> dispose() async {
    if (_engine != null) {
      debugPrint('🎤 Disposing Engine');
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
    }
  }

  int getStableUid(String userId) {
    // Agora UIDs must be stable across devices for the same user
    int hash = 0;
    for (int i = 0; i < userId.length; i++) {
      hash = userId.codeUnitAt(i) + ((hash << 5) - hash);
    }
    // Ensure it fits in 32-bit unsigned and isn't 0
    final uid = (hash & 0x7FFFFFFF);
    return (uid == 0) ? 1 : uid;
  }

  void setEventHandler(RtcEngineEventHandler handler) {
    _engine?.registerEventHandler(handler);
  }
}
