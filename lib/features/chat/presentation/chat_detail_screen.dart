import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wumble/core/theme.dart';
import 'package:wumble/core/utils/media_helper.dart';
import 'package:wumble/core/services/storage_service.dart';
import 'package:wumble/core/services/notification_service.dart';
import 'package:wumble/core/utils/config.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/presentation/pages/create_public_chat_screen.dart';
import 'package:wumble/features/community/presentation/pages/community_info_screen.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';
import 'package:wumble/features/chat/domain/bot_framework.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/chat/domain/chat_repository.dart';
import 'package:wumble/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:wumble/features/chat/domain/moderation_service.dart';
import 'package:wumble/features/community/domain/moderation_report_model.dart';
import 'package:wumble/features/chat/presentation/widgets/sticker_selector.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/profile/domain/notification_repository.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'package:wumble/features/community/presentation/widgets/member_mini_profile.dart';
import 'chat_bloc.dart';
import 'live_bloc.dart';
import 'package:record/record.dart';
import '../../../../core/services/live_audio_service.dart';
import 'package:flutter/services.dart';
import 'widgets/live_overlay.dart';
import 'widgets/member_picker_sheet.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserName;
  final String otherUserAvatar;
  final String otherUserId;
  final String? communityId;

  ChatDetailScreen({
    super.key,
    required this.chatRoomId,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.otherUserId = '',
    this.communityId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final Map<String, CommunityMember> _memberMap = {};
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _liveScrollController = ScrollController();

  Map<String, String> _participantNames = {};
  Map<String, String> _participantAvatars = {};
  bool _isParticipant = false;

  bool _showStickers = false;
  ChatMessage? _replyToMessage;
  bool _isRecording = false;
  bool _isUploadingMedia = false;
  final List<ChatMessage> _optimisticMessages = [];
  late final ChatBloc _chatBloc;
  late final LiveBloc _liveBloc;
  final LiveAudioService _audioService = LiveAudioService();
  int _previousMessageCount = 0;
  String? _lastNewestId;
  bool _isOtherUserOnline = false;
  String? _backgroundImageUrl;
  late final ChatRepository _chatRepository;
  String _currentUserAvatar = '';
  String _currentUserName = 'Usuario';
  String? _currentUserAvatarFrame;           // <-- nuevo
  Map<String, String> _participantAvatarFrames = {};  // <-- nuevo
  ChatBubbleStyle? _currentUserBubbleStyle;
  bool _manuallyClosedLive = false;
  bool _isSpeakerOn = false;
  late String _otherUserName;
  late String _otherUserAvatar;
  Timer? _soloParticipantTimer;
  DateTime? _soloStartTime;
  StreamSubscription? _typingSubscription;
  List<TypingUser> _typingUsers = [];
  Timer? _typingTimer;
  Timer? _typingClearTimer; // auto-clears typing state after 5s of inactivity
  StreamSubscription? _chatRoomSubscription;
  StreamSubscription? _otherUserProfileSubscription;
  List<CommunityMember> _mentionableMembers = [];
  List<CommunityMember> _filteredMentions = [];
  bool _showMentions = false;
  String _currentMentionSearch = '';
  
  // Audio Recording Variables
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  bool _isProcessingVoice = false;
  String? _communityId;
  String? _creatorId;
  ModerationLevel _moderationLevel = ModerationLevel.medium;
  String? _guardianBotId;
  List<String> _curatorIds = [];
  List<String> _bannedUserIds = [];
  String? _privateChatKey;
  bool _isClosed = false;
  String? _invitationStatus;
  String? _inviterId;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  String? _description;
  String _otherUserBio = '';
  ChatRoom? _currentRoom;
  bool _showScrollToBottom = false;
  int _unreadCount = 0;


  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _otherUserAvatar = widget.otherUserId == 'BOT_Assistant' ? ModerationService.botAvatar : widget.otherUserAvatar;
    _otherUserName = widget.otherUserId == 'BOT_Assistant' ? ModerationService.botName : widget.otherUserName;
    _communityId = widget.communityId;
    _chatRepository = context.read<ChatRepository>();
    NotificationService.currentChatRoomId = widget.chatRoomId;
    debugPrint('ChatDetail: Initializing Live with roomId: ${widget.chatRoomId}');
    _chatBloc = ChatBloc(repository: _chatRepository)
      ..add(LoadMessages(widget.chatRoomId));
    
    _liveBloc = LiveBloc(
      repository: _chatRepository,
      audioService: _audioService,
    )..add(SubscribeToLiveSession(widget.chatRoomId));

    // Mark room notifications as read when entering
    di.sl<NotificationRepository>().markRoomNotificationsAsRead(_currentUserId, widget.chatRoomId);
    _chatRepository.markChatAsRead(widget.chatRoomId, _currentUserId);

    _listenToChatRoom();

    // --- IMMEDIATE INITIALIZATION (FAST FALLBACK) ---
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserAvatar = user.photoURL ?? '';
      _currentUserName = user.displayName ?? 'Usuario';
    }

    _loadCurrentUserAvatar();
    _listenToTypingStatus();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // In reversed list, 0 is bottom. Show button if offset > 200 OR unreadCount > 0
    final double offset = _scrollController.offset;
    final bool hasUnread = _unreadCount > 0;
    final bool show = offset > 200 || hasUnread;
    
    if (show != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = show;
      });
    }

    // Reset unread count if we are at the bottom
    if (offset < 50 && hasUnread) {
      if (mounted) setState(() => _unreadCount = 0);
    }
  }

  Future<void> _jumpToMessage(int index, String messageId) async {
    // 1. Mark as highlighted so the GlobalKey is assigned in itemBuilder
    setState(() { _highlightedMessageId = messageId; });

    // 2. Wait for the highlight state to be applied and widget rebuilt
    await Future.delayed(Duration(milliseconds: 50));

    final key = _messageKeys[messageId];
    
    // 3. Try perfect scroll (if widget was already in cache/built)
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // 4. Force scroll to an estimated position (Value derived from average bubble height)
      // In a REVERSED list, index 0 is the newest (bottom).
      // Index is proportional to distance from bottom.
      final estimatedOffset = index * 120.0;
      
      await _scrollController.animateTo(
        estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );

      // 5. Final try after forced scroll (the widget should be built now as it's in view)
      await Future.delayed(Duration(milliseconds: 100));
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
    
    // Clear highlight after 2 seconds
    _highlightTimer?.cancel();
    _highlightTimer = Timer(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _listenToTypingStatus() {
    _typingSubscription?.cancel();
    _typingSubscription = _chatRepository
        .getTypingUsers(widget.chatRoomId)
        .listen((users) {
      if (mounted) {
        setState(() {
          _typingUsers = users.where((u) => u.userId != _currentUserId).toList();
        });
      }
    });
  }

  void _updateTypingStatus(bool isTyping) {
    if (_currentUserId.isEmpty || _currentUserName == 'Usuario') return;

    if (!isTyping) {
      // Immediately clear typing (message sent, field cleared, etc.)
      _typingTimer?.cancel();
      _typingClearTimer?.cancel();
      _chatRepository.updateTypingStatus(
        widget.chatRoomId,
        _currentUserId,
        _currentUserName,
        false,
      );
      return;
    }

    // Debounce: write isTyping=true 500ms after the user starts typing
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        _chatRepository.updateTypingStatus(
          widget.chatRoomId,
          _currentUserId,
          _currentUserName,
          true,
        );
      }
    });

    // Auto-clear: if user hasn't typed for 5s, clear regardless (user paused mid-message)
    _typingClearTimer?.cancel();
    _typingClearTimer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        _typingTimer?.cancel();
        _chatRepository.updateTypingStatus(
          widget.chatRoomId,
          _currentUserId,
          _currentUserName,
          false,
        );
      }
    });
  }

  void _loadCurrentUserAvatar() async {
    final uid = _currentUserId;
    if (uid.isEmpty) return;

    debugPrint('ChatDetailScreen: Loading profile for $uid. Community: $_communityId');

    try {
      // 1. Get Global profile (base info)
      final globalDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (globalDoc.exists && mounted) {
        final globalData = globalDoc.data()!;
        final globalAvatar = globalData['avatarUrl'] ?? '';
        
        setState(() {
          // Use global as default
          if (_communityId == null) {
            _currentUserAvatar = globalAvatar;
            _currentUserName = globalData['displayName'] ?? globalData['username'] ?? 'Usuario';
          }
          _currentUserAvatarFrame = globalData['avatarFrameUrl'];
          _currentUserBubbleStyle = globalData['chatBubbleStyle'] != null 
              ? ChatBubbleStyle.fromMap(globalData['chatBubbleStyle']) 
              : null;
        });
      }

      // 2. Overwrite with Community profile if available
      if (_communityId != null) {
        final member = await di.sl<ProfileRepository>().getMemberProfile(_communityId!, uid);
        if (member != null && mounted) {
          debugPrint('ChatDetailScreen: Community member profile found: ${member.avatarUrl}');
          setState(() {
            _currentUserAvatar = (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) 
                ? member.avatarUrl! 
                : _currentUserAvatar;
            _currentUserName = (member.displayName != null && member.displayName!.isNotEmpty) 
                ? member.displayName! 
                : _currentUserName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user profile: $e');
    }
  }

  void _listenToOtherUserProfile() {
    if (widget.otherUserId.isEmpty) return;
    _otherUserProfileSubscription?.cancel();
    
    final uid = widget.otherUserId;
    
    // A. Global listener (for basic info/fallback)
    _otherUserProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _isOtherUserOnline = data['isOnline'] ?? false;
          // Only update name/avatar if we don't have a community context or it's currently empty
          if (_communityId == null || _otherUserName == 'Usuario') {
            _otherUserName = data['displayName'] ?? data['username'] ?? _otherUserName;
            _otherUserAvatar = data['avatarUrl'] ?? _otherUserAvatar;
          }
          _otherUserBio = data['bio'] ?? '';
        });
      }
    });

    // B. Community listener (if available)
    if (_communityId != null) {
      FirebaseFirestore.instance
          .collection('communities')
          .doc(_communityId)
          .collection('members')
          .doc(uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _otherUserName = data['displayName'] ?? _otherUserName;
            _otherUserAvatar = data['avatarUrl'] ?? _otherUserAvatar;
          });
        }
      });
    }
  }

  void _listenToChatRoom() {
    _chatRoomSubscription?.cancel();
    _chatRoomSubscription = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
        
        // Auto-reset unread count if we receive a message while in the chat
        if ((unreadCounts[_currentUserId] ?? 0) > 0) {
          _chatRepository.markChatAsRead(widget.chatRoomId, _currentUserId);
        }

        final otherId = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
        
        final names = Map<String, String>.from(data['participantNames'] ?? {});
        final avatars = Map<String, String>.from(data['participantAvatars'] ?? {});

        setState(() {
          final oldCommunityId = _communityId;
          _backgroundImageUrl = data['backgroundImageUrl'];
          
          final roomCommunityId = data['communityId'] as String?;
          if (roomCommunityId != null) {
            _communityId = roomCommunityId;
          }
          
          // Trigger profile reload if we just discovered the community context
          if (_communityId != null && _communityId != oldCommunityId) {
            _loadCurrentUserAvatar();
            _listenToOtherUserProfile();
          }
          _creatorId = data['creatorId'];
          _curatorIds = List<String>.from(data['curatorIds'] ?? []);
          _bannedUserIds = List<String>.from(data['bannedUserIds'] ?? []);
          _privateChatKey = data['privateChatKey'];
          _isClosed = data['isClosed'] ?? false;
          _invitationStatus = data['invitationStatus'];
          _inviterId = data['inviterId'];
          _participantNames = names;
          _participantAvatars = avatars;
          _isParticipant = participants.contains(_currentUserId);
          _currentRoom = ChatRoom.fromFirestore(doc); // Store the room object
          
          if (_privateChatKey != null && otherId.isNotEmpty) {
            // 1:1 Chat: Use participant data and RELAX moderation (low level)
            _otherUserName = names[otherId] ?? _otherUserName;
            _otherUserAvatar = avatars[otherId] ?? _otherUserAvatar;
            _moderationLevel = ModerationLevel.low; // Flexible for private chats
          } else {
            // Group Chat (Public or Private): Use room metadata
            _otherUserName = data['title'] ?? _otherUserName;
            _otherUserAvatar = data['imageUrl'] ?? _otherUserAvatar;
            _description = data['description'];
          }
          
          if (_communityId != null && _mentionableMembers.isEmpty) {
            _loadMentionableMembers();
          }
          // Load avatar frames from participant profile docs
          _loadParticipantFrames(participants);
        });
      }
    });
  }

  /// Fetches avatarFrameUrl from Firestore for every participant
  /// and updates [_participantAvatarFrames] so chat bubbles can render them.
  Future<void> _loadParticipantFrames(List<String> participantIds) async {
    final others = participantIds.where((id) => id != _currentUserId).toList();
    if (others.isEmpty) return;
    try {
      final futures = others.map((uid) =>
          FirebaseFirestore.instance.collection('users').doc(uid).get());
      final docs = await Future.wait(futures);
      if (!mounted) return;
      final Map<String, String> frames = {};
      for (int i = 0; i < others.length; i++) {
        final doc = docs[i];
        if (doc.exists) {
          final frameUrl = doc.data()?['avatarFrameUrl'] as String?;
          if (frameUrl != null && frameUrl.isNotEmpty) {
            frames[others[i]] = frameUrl;
          }
        }
      }
      setState(() {
        _participantAvatarFrames = {..._participantAvatarFrames, ...frames};
      });
    } catch (e) {
      debugPrint('Error loading participant frames: $e');
    }
  }

  Future<void> _loadMentionableMembers() async {
    if (_communityId == null) return;
    try {
      final members = await di.sl<CommunityRepository>().getCommunityMembers(_communityId!);
      
      // Explicitly load bots to ensure they are always mentionable (even old ones without isBanned: false)
      final botsQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(_communityId!)
          .collection('bots')
          .get();
          
      ModerationLevel communityLevel = ModerationLevel.medium;
      for (var doc in botsQuery.docs) {
        final bot = BotConfig.fromFirestore(doc);
          if (bot.isActive && bot.isGuardian) {
            _guardianBotId = bot.id;
            // Map 0.0-1.0 to Low, Medium, High
            if (bot.chatModerationSensitivity < 0.3) {
              _moderationLevel = ModerationLevel.low;
            } else if (bot.chatModerationSensitivity < 0.7) {
              _moderationLevel = ModerationLevel.medium;
            } else {
              _moderationLevel = ModerationLevel.high;
            }
            debugPrint('ChatDetail: Found Guardian bot "${bot.name}" with level: $_moderationLevel');
            break;
          }
        }

      final botsAsMembers = botsQuery.docs.map((doc) {
        final botConfig = BotConfig.fromFirestore(doc);
        return CommunityMember(
          userId: botConfig.id,
          communityId: _communityId!,
          displayName: botConfig.name,
          avatarUrl: botConfig.avatarUrl,
          joinedAt: DateTime.now(),
          isBot: true,
        );
      }).toList();

      if (mounted) {
        setState(() {
          final Map<String, CommunityMember> uniqueMembers = {};
          // Prioritize bots so they appear first
          for (var b in botsAsMembers) {
            uniqueMembers[b.userId] = b;
          }
          for (var m in members) {
            uniqueMembers[m.userId] = m;
          }
          _mentionableMembers = uniqueMembers.values.toList();
          // Also update _memberMap for rendering performance
          _memberMap.addAll(uniqueMembers);
        });
      }
    } catch (e) {
      debugPrint('Error loading mentionable members: $e');
    }
  }

  void _handleMentionSearch(String text) {
    if (text.isEmpty) {
      setState(() => _showMentions = false);
      return;
    }

    final lastAt = text.lastIndexOf('@');
    if (lastAt != -1 && (lastAt == 0 || text[lastAt - 1] == ' ')) {
      final query = text.substring(lastAt + 1).toLowerCase();
      // If there's a space after @ and some text, stop searching
      if (query.contains(' ')) {
        setState(() => _showMentions = false);
        return;
      }
      
      setState(() {
        if (query.isEmpty) {
          // If just '@', show top 5 members to avoid overwhelming the view
          _filteredMentions = _mentionableMembers.take(5).toList();
          _showMentions = _filteredMentions.isNotEmpty;
        } else {
          _filteredMentions = _mentionableMembers.where((m) {
            final name = (m.displayName ?? '').toLowerCase();
            return name.contains(query);
          }).toList();
          _showMentions = _filteredMentions.isNotEmpty;
        }
      });
    } else {
      setState(() => _showMentions = false);
    }
  }

  void _selectMention(CommunityMember member) {
    final text = _controller.text;
    final lastAt = text.lastIndexOf('@');
    if (lastAt != -1) {
      final newText = text.substring(0, lastAt) + '@${member.displayName ?? 'Usuario'} ';
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
      setState(() => _showMentions = false);
    }
  }

  void _checkSoloParticipant(LiveSession session) {
    final participantCount = session.participants.length;
    final isHost = session.hostId == _currentUserId;

    if (participantCount <= 1 && isHost) {
      if (_soloStartTime == null) {
        _soloStartTime = DateTime.now();
        debugPrint('ChatDetail: Solo participant detected. Starting 3-min countdown...');
        _soloParticipantTimer?.cancel();
        _soloParticipantTimer = Timer(Duration(minutes: 3), () {
          debugPrint('ChatDetail: Ending solo session due to inactivity (3 mins)');
          _liveBloc.add(EndLiveEvent(widget.chatRoomId));
        });
      }
    } else {
      if (_soloStartTime != null) {
        debugPrint('ChatDetail: Social activity detected. Cancelling solo countdown.');
        _soloStartTime = null;
        _soloParticipantTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    if (NotificationService.currentChatRoomId == widget.chatRoomId) {
      NotificationService.currentChatRoomId = null;
    }
    _soloParticipantTimer?.cancel();
    _typingTimer?.cancel();
    _typingClearTimer?.cancel();
    _chatRoomSubscription?.cancel();
    _otherUserProfileSubscription?.cancel();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _liveScrollController.dispose();
    _chatBloc.close();
    _liveBloc.close();
    _typingSubscription?.cancel();
    _recordingTimer?.cancel();
    _highlightTimer?.cancel();
    _updateTypingStatus(false);
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Reset unread count locally as we're sending a new message (we'll be at the bottom)
    if (_unreadCount > 0) {
      setState(() => _unreadCount = 0);
    }

    // --- Phase 10: AI Moderation Check ---
    final moderationResult = await ModerationService.analyzeText(text, level: _moderationLevel);
    if (moderationResult.isFlagged && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MENSAJE BLOQUEADO: ${moderationResult.reason}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    } else if (moderationResult.confidence > 0.4 && _guardianBotId != null && _communityId != null) {
      // Yellow Zone: Report but allow
      ModerationService.reportToModerators(
        communityId: _communityId!,
        reporterId: _guardianBotId!,
        targetId: 'pending_chat_msg', // Will be updated if we had real-time ID
        targetUserId: _currentUserId,
        targetType: ModerationTargetType.chat,
        contentPreview: text,
        reason: 'MENSAJE DE CHAT SOSPECHOSO: ${moderationResult.reason}',
        confidenceScore: moderationResult.confidence,
      );
    }

    final message = ChatMessage(
      id: '',
      senderId: _currentUserId,
      senderName: _currentUserName,
      senderAvatarUrl: _currentUserAvatar,
      text: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      replyToId: _replyToMessage?.id,
      replyToUserId: _replyToMessage?.senderId,
      replyToText: _replyToMessage?.text ?? (_replyToMessage?.type == MessageType.sticker ? 'Sticker' : _replyToMessage?.type == MessageType.image ? 'Foto' : _replyToMessage?.type == MessageType.voice ? 'Mensaje de voz' : ''),
      replyToSenderName: _replyToMessage?.senderName ?? (_replyToMessage != null ? _participantNames[_replyToMessage!.senderId] ?? 'Usuario' : null),
      replyToImageUrl: _replyToMessage?.imageUrl ?? _replyToMessage?.stickerUrl,
      replyToType: _replyToMessage?.type,
      bubbleStyle: _currentUserBubbleStyle,
      senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
    );

    _chatBloc.add(
      SendMessageEvent(chatRoomId: widget.chatRoomId, message: message),
    );
    _controller.clear();
    _updateTypingStatus(false);
    setState(() {
      _showStickers = false;
      _replyToMessage = null;
    });
    _scrollToBottom();
  }

  void _sendSticker(String url) async {
    // --- Phase 18: GIPHY/URL Moderation ---
    // Since this is a URL, we analyze it via URL
    final moderationResult = await ModerationService.analyzeImage(url, level: _moderationLevel);
    if (moderationResult.isFlagged && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('STICKER BLOQUEADO POR SYSTEM ASSISTANT: ${moderationResult.reason}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final message = ChatMessage(
      id: '',
      senderId: _currentUserId,
      senderName: _currentUserName,
      senderAvatarUrl: _currentUserAvatar,
      stickerUrl: url,
      type: MessageType.sticker,
      timestamp: DateTime.now(),
      replyToId: _replyToMessage?.id,
      replyToUserId: _replyToMessage?.senderId,
      replyToText: _replyToMessage?.text ?? (_replyToMessage?.type == MessageType.sticker ? 'Sticker' : _replyToMessage?.type == MessageType.image ? 'Foto' : _replyToMessage?.type == MessageType.voice ? 'Mensaje de voz' : ''),
      replyToSenderName: _replyToMessage?.senderName ?? (_replyToMessage != null ? _participantNames[_replyToMessage!.senderId] ?? 'Usuario' : null),
      replyToImageUrl: _replyToMessage?.imageUrl ?? _replyToMessage?.stickerUrl,
      replyToType: _replyToMessage?.type,
      bubbleStyle: _currentUserBubbleStyle,
      senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
    );

    _chatBloc.add(
      SendMessageEvent(chatRoomId: widget.chatRoomId, message: message),
    );
    setState(() {
      _showStickers = false;
      _replyToMessage = null;
    });
    _scrollToBottom();
  }

  Future<void> _sendCustomSticker(File file) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMsg = ChatMessage(
      id: tempId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      senderAvatarUrl: _currentUserAvatar,
      localPath: file.path,
      type: MessageType.sticker,
      timestamp: DateTime.now(),
      replyToId: _replyToMessage?.id,
      replyToUserId: _replyToMessage?.senderId,
      replyToText: _replyToMessage?.text ?? (_replyToMessage?.type == MessageType.sticker ? 'Sticker' : _replyToMessage?.type == MessageType.image ? 'Foto' : _replyToMessage?.type == MessageType.voice ? 'Mensaje de voz' : ''),
      replyToSenderName: _replyToMessage?.senderName ?? (_replyToMessage != null ? _participantNames[_replyToMessage!.senderId] ?? 'Usuario' : null),
      replyToImageUrl: _replyToMessage?.imageUrl ?? _replyToMessage?.stickerUrl,
      replyToType: _replyToMessage?.type,
      bubbleStyle: _currentUserBubbleStyle,
      senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
    );


    setState(() {
      _optimisticMessages.add(optimisticMsg);
      _showStickers = false;
      _replyToMessage = null;
    });
    _scrollToBottom();

    try {
      // --- Phase 12: Sticker Moderation ---
      final modResult = await ModerationService.analyzeImage(file, level: _moderationLevel);
      if (modResult.isFlagged && mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == tempId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('STICKER BLOQUEADO: ${modResult.reason}'), backgroundColor: Colors.redAccent),
        );
        return;
      }
      final stickerUrl = await _storageService.uploadChatImage(file);
      
      final finalMessage = ChatMessage(
        id: '',
        senderId: _currentUserId,
        senderName: _currentUserName,
        senderAvatarUrl: _currentUserAvatar,
        stickerUrl: stickerUrl,
        type: MessageType.sticker,
        timestamp: DateTime.now(),
        replyToId: optimisticMsg.replyToId,
        replyToUserId: optimisticMsg.replyToUserId,
        replyToText: optimisticMsg.replyToText,
        replyToSenderName: optimisticMsg.replyToSenderName,
        replyToImageUrl: optimisticMsg.replyToImageUrl,
        replyToType: optimisticMsg.replyToType,
        bubbleStyle: _currentUserBubbleStyle,
        senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
      );

      
      if (mounted) {
        _chatBloc.add(
          SendMessageEvent(chatRoomId: widget.chatRoomId, message: finalMessage),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al subir sticker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir sticker: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == tempId);
        });
      }
    }
  }

  final AudioRecorder _audioRecorder = AudioRecorder();
  final StorageService _storageService = StorageService();

  Future<void> _sendImage() async {
    final image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final optimisticMsg = ChatMessage(
        id: tempId,
        senderId: _currentUserId,
        senderName: _currentUserName,
        senderAvatarUrl: _currentUserAvatar,
        localPath: image.path,
        type: MessageType.image,
        timestamp: DateTime.now(),
        replyToId: _replyToMessage?.id,
        replyToUserId: _replyToMessage?.senderId,
        replyToText: _replyToMessage?.text ?? (_replyToMessage?.type == MessageType.sticker ? 'Sticker' : _replyToMessage?.type == MessageType.image ? 'Foto' : _replyToMessage?.type == MessageType.voice ? 'Mensaje de voz' : ''),
        replyToSenderName: _replyToMessage?.senderName ?? (_replyToMessage != null ? _participantNames[_replyToMessage!.senderId] ?? 'Usuario' : null),
        replyToImageUrl: _replyToMessage?.imageUrl ?? _replyToMessage?.stickerUrl,
        replyToType: _replyToMessage?.type,
        bubbleStyle: _currentUserBubbleStyle,
        senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
      );


    setState(() {
      _optimisticMessages.add(optimisticMsg);
      _replyToMessage = null;
    });
    _scrollToBottom();

      try {
        debugPrint('--- INICIANDO SUBIDA ---');
        debugPrint('Ruta local: ${image.path}');
        final file = File(image.path);
        
        // --- Phase 12: Image Moderation ---
        final modResult = await ModerationService.analyzeImage(file, level: _moderationLevel);
        if (modResult.isFlagged && mounted) {
           setState(() {
            _optimisticMessages.removeWhere((m) => m.id == tempId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('IMAGEN BLOQUEADA: ${modResult.reason}'), backgroundColor: Colors.redAccent),
          );
          return;
        }

        final imageUrl = await _storageService.uploadChatImage(file);
        debugPrint('Subida exitosa. URL: $imageUrl');
        
        final finalMessage = ChatMessage(
          id: '',
          senderId: _currentUserId,
          senderName: _currentUserName,
          senderAvatarUrl: _currentUserAvatar,
          imageUrl: imageUrl,
          type: MessageType.image,
          timestamp: DateTime.now(),
          replyToId: optimisticMsg.replyToId,
          replyToUserId: optimisticMsg.replyToUserId,
          replyToText: optimisticMsg.replyToText,
          replyToSenderName: optimisticMsg.replyToSenderName,
          replyToImageUrl: optimisticMsg.replyToImageUrl,
          replyToType: optimisticMsg.replyToType,
          bubbleStyle: _currentUserBubbleStyle,
          senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
        );

        
        if (mounted) {
          _chatBloc.add(
            SendMessageEvent(chatRoomId: widget.chatRoomId, message: finalMessage),
          );
          debugPrint('Evento SendMessageEvent enviado al Bloc');
        }
      } catch (e, stack) {
        debugPrint('❌ ERROR EN _sendImage: $e');
        debugPrint('Stacktrace: $stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir imagen: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _optimisticMessages.removeWhere((m) => m.id == tempId);
          });
        }
      }
    }
  }

  Future<void> _pickGiphy() async {
    try {
      final gif = await GiphyGet.getGif(
        context: context,
        apiKey: AppConfig.giphyApiKey,
        lang: GiphyLanguage.spanish,
        tabColor: Wumbleheme.secondaryColor,
      );

      if (gif != null && gif.images?.original?.url != null) {
        _sendSticker(gif.images!.original!.url!);
      }
    } catch (e) {
      debugPrint('Error en Giphy Chat Direct: $e');
    }
  }

  Future<void> _startRecording() async {
    debugPrint('🎤 _startRecording called');
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await Directory.systemTemp.createTemp();
        final path = '${directory.path}/voice_msg.m4a';
        await _audioRecorder.start(RecordConfig(), path: path);
        HapticFeedback.lightImpact(); // Add haptic feedback
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
        
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordingDuration++);
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopAndSendVoiceMessage() async {
    debugPrint('🛑 _stopAndSendVoiceMessage called');
    if (!_isRecording || _isProcessingVoice) return;
    
    setState(() => _isProcessingVoice = true);
    _recordingTimer?.cancel();
    
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
      
      if (path != null) {
        // ... (check validity or length later)
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        final optimisticMsg = ChatMessage(
          id: tempId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          senderAvatarUrl: _currentUserAvatar,
          localPath: path,
          type: MessageType.voice,
          timestamp: DateTime.now(),
          replyToId: _replyToMessage?.id,
          replyToUserId: _replyToMessage?.senderId,
          replyToText: _replyToMessage?.text ?? (_replyToMessage?.type == MessageType.sticker ? 'Sticker' : _replyToMessage?.type == MessageType.image ? 'Foto' : _replyToMessage?.type == MessageType.voice ? 'Mensaje de voz' : ''),
          replyToSenderName: _replyToMessage?.senderName ?? (_replyToMessage != null ? _participantNames[_replyToMessage!.senderId] ?? 'Usuario' : null),
          replyToImageUrl: _replyToMessage?.imageUrl ?? _replyToMessage?.stickerUrl,
          replyToType: _replyToMessage?.type,
          bubbleStyle: _currentUserBubbleStyle,
          senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
        );


        setState(() {
          _optimisticMessages.add(optimisticMsg);
          _replyToMessage = null;
        });
        _scrollToBottom();

        try {
          final voiceUrl = await _storageService.uploadChatVoice(File(path));
          
          final finalMessage = ChatMessage(
            id: '',
            senderId: _currentUserId,
            senderName: _currentUserName,
            senderAvatarUrl: _currentUserAvatar,
            voiceUrl: voiceUrl,
            type: MessageType.voice,
            timestamp: DateTime.now(),
            replyToId: optimisticMsg.replyToId,
            replyToUserId: optimisticMsg.replyToUserId,
            replyToText: optimisticMsg.replyToText,
            replyToSenderName: optimisticMsg.replyToSenderName,
            replyToImageUrl: optimisticMsg.replyToImageUrl,
            replyToType: optimisticMsg.replyToType,
            bubbleStyle: _currentUserBubbleStyle,
            senderAvatarFrameUrl: _currentUserAvatarFrame, // NEW
          );

          
          if (mounted) {
            _chatBloc.add(
              SendMessageEvent(chatRoomId: widget.chatRoomId, message: finalMessage),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al subir audio: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _optimisticMessages.removeWhere((m) => m.id == tempId);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() => _isRecording = false);
    } finally {
      if (mounted) setState(() => _isProcessingVoice = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          if (mounted) setState(() => _unreadCount = 0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _chatBloc),
        BlocProvider.value(value: _liveBloc),
      ],
        child: BlocListener<LiveBloc, LiveState>(
          listener: (context, state) {
            debugPrint('ChatDetail: LiveBloc State changed to: $state');
            if (state is LiveError) {
              debugPrint('ChatDetail: ❌ LiveError: ${state.message}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error Live: ${state.message}')),
                );
              }
            }
            if (state is LiveActive) {
              debugPrint('ChatDetail: Session is Active. Host: ${state.session.hostId} | Participants: ${state.session.participants.length}');
              
              _checkSoloParticipant(state.session);

              for (var p in state.session.participants) {
                debugPrint(' - [${p.role}] ${p.username} (${p.userId}) | Mic: ${p.isMicOn}');
              }
              
              // AUTO-JOIN REMOVED as per user request. 
              // We only join if user explicitly accepts invitation or clicks orange button.
            } else if (state is LiveInactive || state is LiveInitial) {
              // If session ends, we can reset the flag for the next session
              if (_manuallyClosedLive) {
                setState(() => _manuallyClosedLive = false);
              }
            }
          },
        child: BlocBuilder<LiveBloc, LiveState>(
          builder: (context, liveState) {
          final isLiveActive = liveState is LiveActive;
          
          return Scaffold(
        backgroundColor: Wumbleheme.backgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: GestureDetector(
            onTap: () {
              if (widget.otherUserId.isNotEmpty) {
                MemberMiniProfile.show(
                  context,
                  user: UserProfile(
                    id: widget.otherUserId,
                    username: '',
                    displayName: _otherUserName,
                    avatarUrl: _otherUserAvatar,
                    bannerUrl: '',
                    backgroundUrl: '',
                    bio: _otherUserBio,
                    reputation: 0,
                    level: 1,
                    titles: [],
                    followers: 0,
                    following: 0,
                    checkIns: 0,
                  ),
                  communityId: _communityId,
                );
              } else {
                _showChatMembersBottomSheet();
              }
            },
            child: Row(
              children: [
                UserAvatar(
                  key: ValueKey('header_${widget.otherUserId}_$_communityId'),
                  userId: widget.otherUserId,
                  avatarUrl: _otherUserAvatar,
                  displayName: _otherUserName, // Added
                  communityId: _communityId,
                  radius: 16,
                  isClickable: false, // Handled by outer GestureDetector
                  isOnline: widget.otherUserId.isNotEmpty && _isOtherUserOnline,
                  showOnlineIndicator: widget.otherUserId.isNotEmpty,
                  emptyIcon: widget.otherUserId.isEmpty ? Icons.group : Icons.person,
                ),
                SizedBox(width: 10),
               Expanded(
                 child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _otherUserName,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.otherUserId.isNotEmpty)
                            Text(
                              _isOtherUserOnline ? 'En línea' : 'Desconectado',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isOtherUserOnline ? Colors.greenAccent : Colors.white38,
                              ),
                            )
                          else 
                            Text(
                              '${_participantNames.length} miembros',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    if (_isClosed)
                      Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, color: Colors.redAccent, size: 12),
                              SizedBox(width: 4),
                              Text(
                                tr('CERRADO'),
                                style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
               ),
              ],
            ),
          ),
          actions: [
            if (!isLiveActive || (isLiveActive && !liveState.session.participants.any((p) => p.userId == _currentUserId)))
              GestureDetector(
                onTap: () {
                  if (_currentUserId.isEmpty || _currentUserName == 'Usuario') {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('Cargando datos de perfil...'))),
                      );
                    }
                    return;
                  }
                  
                  if (isLiveActive) {
                    // Manual JOIN
                    setState(() => _manuallyClosedLive = false);
                    _liveBloc.add(JoinLiveEvent(
                      chatRoomId: widget.chatRoomId,
                      participant: LiveParticipant(
                        userId: _currentUserId,
                        username: _currentUserName,
                        avatarUrl: _currentUserAvatar,
                        role: 'speaker',
                      ),
                    ));
                  } else {
                    // START Live
                    setState(() => _manuallyClosedLive = false);
                    _liveBloc.add(StartLiveEvent(
                      chatRoomId: widget.chatRoomId,
                      hostId: _currentUserId,
                      hostName: _currentUserName,
                      hostAvatar: _currentUserAvatar,
                    ));
                  }
                },
                child: BlocBuilder<CommunityContextBloc, CommunityContextState>(
                  builder: (context, state) {
                    final bool isModerator = state.memberProfile?.role == 'leader' || state.memberProfile?.role == 'curator';
                    final bool isMember = state.memberProfile != null;
                    final bool isGlobalOrDM = _communityId == null;
                    final bool canGoLive = (isMember || isGlobalOrDM) && _isParticipant && !(_isClosed && !isModerator);
                    
                    if (!canGoLive || !_isParticipant) return SizedBox.shrink();

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLiveActive ? Colors.orangeAccent : Colors.greenAccent.shade400,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLiveActive ? 'JOIN LIVE' : 'GO LIVE',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            isLiveActive ? Icons.headset : Icons.play_arrow,
                            color: Colors.black,
                            size: 14,
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            if (_isParticipant || widget.otherUserId.isNotEmpty || _creatorId == _currentUserId)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert),
                color: Wumbleheme.surfaceColor,
                onSelected: (value) {
                  switch (value) {
                    case 'background':
                      _changeChatBackground();
                      break;
                    case 'edit':
                      _showEditChatDialog();
                      break;
                    case 'clear':
                      _confirmClearChat();
                      break;
                    case 'delete':
                      _confirmDeleteChat();
                      break;
                    case 'leave':
                      _confirmLeaveChat();
                      break;
                    case 'lock':
                      _toggleChatLock();
                      break;
                  }
                },
                itemBuilder: (context) {
                  // Community Moderator Check
                  bool isCommunityModerator = false;
                  try {
                    final commState = context.read<CommunityContextBloc>().state;
                    isCommunityModerator = commState.memberProfile?.role == 'leader' || commState.memberProfile?.role == 'curator';
                  } catch (_) {}

                  final isCreator = _creatorId == _currentUserId || isCommunityModerator;
                  final isPrivate = _privateChatKey != null;
                  final canChangeBackground = isPrivate || isCreator;
                  
                  return [
                    if (canChangeBackground)
                      PopupMenuItem(
                        value: 'background',
                        child: Row(
                          children: [
                            Icon(Icons.wallpaper, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Text(tr('Cambiar fondo'), style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    if (isCreator && !isPrivate)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Text(tr('Editar chat'), style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    if (isCreator || isPrivate)
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep, color: Colors.orangeAccent, size: 20),
                            SizedBox(width: 12),
                            Text(tr('Vaciar chat'), style: TextStyle(color: Colors.orangeAccent)),
                          ],
                        ),
                      ),
                    if (isCreator || isPrivate)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Text(tr('Eliminar chat'), style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    if (isCreator && !isPrivate)
                      PopupMenuItem(
                        value: 'lock',
                        child: Row(
                          children: [
                            Icon(_isClosed ? Icons.lock_open : Icons.lock, color: Colors.blueAccent, size: 20),
                            SizedBox(width: 12),
                            Text(_isClosed ? 'Abrir chat' : 'Cerrar chat', style: TextStyle(color: Colors.blueAccent)),
                          ],
                        ),
                      ),
                    if (!isCreator && !isPrivate && _isParticipant)
                      PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Text(tr('Abandonar chat'), style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    if (isPrivate)
                      PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Text(tr('Abandonar chat'), style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                  ];
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            // 1. Fondo Global (Covers EVERYTHING including behind AppBar)
            Positioned.fill(
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    if (_backgroundImageUrl != null)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: _backgroundImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Wumbleheme.backgroundColor),
                          errorWidget: (context, url, error) => Container(color: Wumbleheme.backgroundColor),
                        ),
                      ),
                    if (_backgroundImageUrl != null)
                      Positioned.fill(
                        child: Container(color: Colors.black.withValues(alpha: 0.3)),
                      ),
                    if (_backgroundImageUrl != null) ...[
                      // Sombra superior para legibilidad de AppBar y Status Bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 150,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Sombra inferior para legibilidad del input y barra de navegación
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 150,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_backgroundImageUrl == null)
                      Positioned.fill(
                        child: Container(color: Wumbleheme.backgroundColor),
                      ),
                  ],
                ),
              ),
            ),
            
            // 2. Content (Messages + Input/Prompt)
            Column(
              children: [
                Expanded(
                  child: BlocConsumer<ChatBloc, ChatState>(
                    listener: (context, state) {
                      if (state is MessagesLoaded) {
                        for (var m in _mentionableMembers) {
                          _memberMap[m.userId] = m;
                        }
                        if (state.messages.isNotEmpty) {
                          final newestId = state.messages.first.id;
                          if (_previousMessageCount > 0 && _lastNewestId != null && newestId != _lastNewestId) {
                            final diff = state.messages.length - _previousMessageCount;
                            if (_scrollController.hasClients && _scrollController.offset > 50 && state.messages.first.senderId != _currentUserId) {
                              setState(() {
                                _unreadCount += diff;
                                _showScrollToBottom = true;
                              });
                            } else if (_scrollController.hasClients && _scrollController.offset <= 50) {
                              _scrollToBottom();
                            }
                          }
                          _lastNewestId = newestId;
                        }
                        _previousMessageCount = state.messages.length;
                      }
                    },
                    builder: (context, state) {
                      if (state is ChatLoading) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (state is MessagesLoaded) {
                        if (state.messages.isEmpty) {
                          return Center(child: Text(tr('¡Envía el primer mensaje! 👋'), style: TextStyle(color: Wumbleheme.textSecondary)));
                        }
                        final allMessages = [..._optimisticMessages, ...state.messages];
                        final showHeader = state.hasMore || state.isLoadingOlder;
                        final itemCount = allMessages.length + (showHeader ? 1 : 0);
                        return Stack(
                          children: [
                            NotificationListener<ScrollToMessageNotification>(
                              onNotification: (notif) {
                                final index = allMessages.indexWhere((m) => m.id == notif.messageId);
                                if (index != -1) _jumpToMessage(index, notif.messageId);
                                return true;
                              },
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification is ScrollEndNotification &&
                                      notification.metrics.pixels >= notification.metrics.maxScrollExtent - 80) {
                                    if (state.hasMore && !state.isLoadingOlder && allMessages.isNotEmpty) {
                                      context.read<ChatBloc>().add(LoadOlderMessages(
                                        chatRoomId: widget.chatRoomId,
                                        beforeTimestamp: allMessages.last.timestamp,
                                      ));
                                    }
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top + kToolbarHeight + 10, 0, 10),
                                  itemCount: itemCount,
                                  itemBuilder: (context, index) {
                                    if (showHeader && index == allMessages.length) {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Center(
                                          child: state.isLoadingOlder
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38))
                                              : Text(tr('— Inicio del chat —'), style: TextStyle(color: Colors.white24, fontSize: 11)),
                                        ),
                                      );
                                    }
                                    final msg = allMessages[index];
                                    final isOptimistic = _optimisticMessages.any((m) => m.id == msg.id);
                                    Widget? dateSeparator;
                                    if (index == allMessages.length - 1 || !_isSameDay(allMessages[index + 1].timestamp, msg.timestamp)) {
                                      dateSeparator = _buildDateSeparator(msg.timestamp);
                                    }
                                    return Column(
                                      children: [
                                        if (dateSeparator != null) dateSeparator,
                                        if (msg.type == MessageType.system)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 32.0),
                                            child: Center(
                                              child: Text(msg.text ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                                            ),
                                          )
                                        else
                                          GestureDetector(
                                            onLongPress: !isOptimistic ? () => _showMessageOptions(msg) : null,
                                            child: ChatBubble(
                                              key: msg.id == _highlightedMessageId ? _messageKeys.putIfAbsent(msg.id, () => GlobalKey()) : ValueKey('msg_${msg.id}'),
                                              message: _toChatBubbleMessage(msg),
                                              isHighlighted: msg.id == _highlightedMessageId,
                                              onBotButtonAction: _handleBotButtonAction,
                                              onReact: (reaction) => _reactToMessage(msg, reaction),
                                              onLongPress: !isOptimistic ? () => _showMessageOptions(msg) : null,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Scroll to bottom button (floating inside messages area)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: _buildScrollToBottomButton(),
                            ),
                          ],
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ),

                // Footer (Input / Indicators / Prompt)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_typingUsers.isNotEmpty) _buildTypingIndicator(),
                    if (_isRecording) _buildRecordingIndicator(),
                    if (_showMentions) _buildMentionsOverlay(),
                    BlocBuilder<CommunityContextBloc, CommunityContextState>(
                      builder: (context, state) {
                        final bool isMember = state.memberProfile != null;
                        // Robust access check for 1:1 and private chats
                        final bool isDirectMessage = widget.otherUserId.isNotEmpty || _privateChatKey != null;
                        final bool canDirectlyChat = isDirectMessage || _isParticipant || _creatorId == _currentUserId;
                        
                        if (canDirectlyChat) {
                          return _buildMessageInput();
                        }
                        
                        // If not a participant but in community context
                        if (_communityId != null) {
                          if (isMember) {
                            // Is member of community but not participant of this chat
                            return _buildChatJoinPrompt();
                          } else {
                            // Guest mode: Requires community membership first
                            return _buildGuestJoinPrompt();
                          }
                        }
                        
                        // Fallback if we belong to it but logic above missed something (e.g. 1:1 or already joined)
                        return _buildMessageInput();
                      },
                    ),
                    if (_showStickers)
                      StickerSelector(
                        onStickerSelected: _sendSticker,
                        onCustomStickerCreated: _sendCustomSticker,
                      ),
                  ],
                ),
              ],
            ),

            // 3. Calls and Overlays
            if (isLiveActive && !liveState.session.participants.any((p) => p.userId == _currentUserId))
              _buildCallInvitation(liveState.session),

            if (liveState is LiveActive && liveState.session.participants.any((p) => p.userId == _currentUserId) && !_manuallyClosedLive)
              LiveOverlay(
                session: liveState.session,
                currentUserId: _currentUserId,
                onLeave: () {
                  setState(() => _manuallyClosedLive = true);
                  if (liveState.session.hostId == _currentUserId) {
                    _liveBloc.add(EndLiveEvent(widget.chatRoomId));
                  } else {
                    _liveBloc.add(LeaveLiveEvent(chatRoomId: widget.chatRoomId, userId: _currentUserId));
                  }
                },
                onToggleMic: (isOn) => _liveBloc.add(ToggleMicEvent(chatRoomId: widget.chatRoomId, userId: _currentUserId, isMicOn: isOn)),
                isSpeakerOn: _isSpeakerOn,
                onToggleSpeaker: (s) {
                  _audioService.toggleSpeaker(s);
                  setState(() => _isSpeakerOn = s);
                },
                onSendMessage: (t) {
                  _chatBloc.add(SendMessageEvent(
                    chatRoomId: widget.chatRoomId,
                    message: ChatMessage(id: '', senderId: _currentUserId, senderName: _currentUserName, senderAvatarUrl: _currentUserAvatar, text: t, type: MessageType.text, timestamp: DateTime.now(), senderAvatarFrameUrl: _currentUserAvatarFrame),
                  ));
                },
                chatWidget: _buildLiveChatView(),
              ),
          ],
        ),
      );
    },
  ),
),
);
}

Widget _buildLiveChatView() {
  // A simplified version of the message list for the overlay
  return BlocBuilder<ChatBloc, ChatState>(
    builder: (context, state) {
      if (state is MessagesLoaded) {
        final messages = [...state.messages, ..._optimisticMessages];
        // Sort DESCENDING for reverse: true
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        return ListView.builder(
          controller: _liveScrollController,
          reverse: true, // Also reverse in overlay
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          itemCount: messages.length,
          cacheExtent: 1000,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            final msg = messages[index];
            return ChatBubble(
              message: _toChatBubbleMessage(msg),
              onReact: (reaction) => _reactToMessage(msg, reaction),
              onLongPress: () => _showMessageOptions(msg),
            );
          },
        );
      }
      return SizedBox.shrink();
    },
  );
}

Widget _buildCallInvitation(LiveSession session) {
  final hostName = session.participants.firstWhere((p) => p.userId == session.hostId, orElse: () => LiveParticipant(userId: '', username: 'Alguien', avatarUrl: '', role: 'host')).username;
  final hostAvatar = session.participants.firstWhere((p) => p.userId == session.hostId, orElse: () => LiveParticipant(userId: '', username: '', avatarUrl: '', role: 'host')).avatarUrl;

  return Positioned(
    top: 10,
    left: 10,
    right: 10,
    child: Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          UserAvatar(
            userId: session.hostId,
            avatarUrl: hostAvatar,
            displayName: hostName,
            communityId: _communityId,
            radius: 20,
            avatarFrameUrl: _participantAvatarFrames[session.hostId],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$hostName quiere hablar contigo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  tr('Llamada de voz en curso'),
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() => _manuallyClosedLive = false);
              _liveBloc.add(JoinLiveEvent(
                chatRoomId: widget.chatRoomId,
                participant: LiveParticipant(
                  userId: _currentUserId,
                  username: _currentUserName,
                  avatarUrl: _currentUserAvatar,
                  role: 'speaker',
                  isMicOn: true,
                ),
              ));
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(tr('ENTRAR'), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    ),
  );
}

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Hoy, ${DateFormat('h:mm a').format(date)}';
    } else if (_isSameDay(date, now.subtract(Duration(days: 1)))) {
      label = 'Ayer, ${DateFormat('h:mm a').format(date)}';
    } else {
      label = DateFormat("d MMM yyyy, h:mm", 'es').format(date);
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  ChatBubbleMessage _toChatBubbleMessage(ChatMessage msg) {
    String senderName = 'Usuario';
    String senderAvatar = '';
    int? senderLevel;
    String? senderRole;
    
    // Determine if it's a 1:1 chat or a group/public chat
    bool isOneOnOne = _privateChatKey != null;

    if (msg.senderId == _currentUserId) {
      senderName = 'Yo';
      senderAvatar = msg.senderAvatarUrl ?? _currentUserAvatar;
      if (senderAvatar.contains('profiles/')) {
        debugPrint('WARNING: ChatDetailScreen is using a GLOBAL avatar URL ($senderAvatar) for message ${msg.id}');
      }
      // Get own level/role if available
      final member = _memberMap[_currentUserId];
      if (member != null) {
        senderLevel = member.level;
        senderRole = member.role;
      }
    } else {
      final member = _memberMap[msg.senderId];
      if (member != null) {
        senderName = member.displayName ?? 'Usuario';
        senderAvatar = member.avatarUrl ?? '';
        senderLevel = member.level;
        senderRole = member.role;
      } else {
        senderName = msg.senderName ?? _participantNames[msg.senderId] ?? (isOneOnOne ? _otherUserName : 'Usuario');
        senderAvatar = msg.senderAvatarUrl ?? _participantAvatars[msg.senderId] ?? (isOneOnOne ? _otherUserAvatar : '');
      }
    }

    // Role override for Bots
    if (msg.senderId.startsWith('BOT_') || msg.botConfig != null) {
      senderRole = 'bot';
    }

    // Resolve sender avatar frame
    String? senderAvatarFrame;
    if (msg.senderId == _currentUserId) {
      senderAvatarFrame = _currentUserAvatarFrame;
    } else {
      senderAvatarFrame = _participantAvatarFrames[msg.senderId];
    }

    final bool isOwn = msg.senderId == _currentUserId;
    final bool isOptimistic = msg.id.startsWith('temp_');

    // Read Receipts Logic
    bool isSeen = false;
    bool showReadReceipts = true;

    if (_currentRoom != null && isOwn && !isOptimistic) {
      // Check if ANY other participant has read this message
      // In 1:1, it's the other person. In groups, we'll consider it "seen" if anyone else read it
      // or we can be more strict. For now, let's treat 1:1 and small groups the same.
      final otherParticipants = _currentRoom!.participants.where((id) => id != _currentUserId);
      
      bool seenByOthers = false;
      bool allShowReceipts = (_currentRoom!.participantPrivacy[_currentUserId]?['showReadReceipts'] ?? true);
      
      for (final otherId in otherParticipants) {
        final lastRead = _currentRoom!.lastReadTimes[otherId];
        if (lastRead != null && lastRead.isAfter(msg.timestamp)) {
          seenByOthers = true;
        }
        // If anyone involved has receipts OFF, we don't show the blue checks
        if (!(_currentRoom!.participantPrivacy[otherId]?['showReadReceipts'] ?? true)) {
          allShowReceipts = false;
        }
      }
      
      isSeen = seenByOthers;
      showReadReceipts = allShowReceipts;
    }

    return ChatBubbleMessage(
      id: msg.id,
      senderId: msg.senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatar,
      senderAvatarFrameUrl: senderAvatarFrame,
      senderLevel: senderLevel,
      senderRole: senderRole,
      isOneOnOne: isOneOnOne,
      text: msg.text,
      stickerUrl: msg.stickerUrl,
      imageUrl: msg.imageUrl,
      voiceUrl: msg.voiceUrl,
      localPath: msg.localPath,
      type: msg.type,
      timestamp: msg.timestamp,
      isMe: isOwn,
      isEdited: msg.isEdited,
      replyToId: msg.replyToId,
      replyToText: msg.replyToText,
      replyToSenderName: msg.replyToSenderName,
      replyToImageUrl: msg.replyToImageUrl,
      replyToType: msg.replyToType,
      communityId: _communityId,
      bubbleStyle: msg.bubbleStyle,
      isBotEmbed: msg.isBotEmbed,
      embedTitle: msg.embedTitle,
      embedFooter: msg.embedFooter,
      embedColor: msg.embedColor,
      botButtons: msg.botButtons,
      reactions: msg.reactions,
      isSeen: isSeen,
      showReadReceipts: showReadReceipts,
      linkPreview: msg.linkPreview,
    );
  }


  void _handleBotButtonAction(BotButton button) async {
    if (button.isUrl) {
      final uri = Uri.tryParse(button.trigger);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('No se pudo abrir el enlace'))),
          );
        }
      }
    } else {
      // Trigger as command
      _controller.text = button.trigger;
      _sendMessage();
    }
  }

  void _banUserFromChat(String userId) {
    _chatRepository.banUserFromChat(widget.chatRoomId, userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Usuario expulsado del chat'))),
      );
    }
  }

  void _showMessageOptions(ChatMessage msg) {
    final bool isMe = msg.senderId == _currentUserId;
    
    // Community Moderator Check
    bool isCommunityModerator = false;
    try {
      if (mounted) {
        final state = context.read<CommunityContextBloc>().state;
        isCommunityModerator = state.memberProfile?.role == 'leader' || state.memberProfile?.role == 'curator';
      }
    } catch (_) {}

    final bool isOwner = _creatorId == _currentUserId || isCommunityModerator;
    final bool isCurator = _curatorIds.contains(_currentUserId);
    final bool canModerate = isOwner || isCurator;
    final bool targetIsOwner = msg.senderId == _creatorId;
    final bool targetIsCurator = _curatorIds.contains(msg.senderId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Wumbleheme.surfaceColor.withOpacity(0.9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white10),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 8,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Message Preview (Premium touch)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Column(
                      children: [
                        Text(
                          tr('MENSÁJE'),
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 12),
                        Transform.scale(
                          scale: 0.95,
                          child: ChatBubble(
                            message: _toChatBubbleMessage(msg),
                            isHighlighted: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10, height: 1),

                  // Reactions Bar
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ...['❤️', '😂', '😮', '😢', '👍', '🔥', '🎉', '😡', '🤔'].map((emoji) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _reactToMessage(msg, emoji);
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 24)),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showFullEmojiReactionPicker(msg);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Wumbleheme.primaryColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, size: 24, color: Wumbleheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // Menu Options
                  _buildMenuTile(
                    icon: Icons.add_reaction_outlined,
                    title: tr('Reaccionar con Sticker'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showStickerReactionPicker(msg);
                    },
                  ),
                  if (msg.type == MessageType.text && msg.text != null)
                    _buildMenuTile(
                      icon: Icons.copy_rounded,
                      title: tr('Copiar texto'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: msg.text!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('Texto copiado al portapapeles')),
                            backgroundColor: Wumbleheme.primaryColor,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  _buildMenuTile(
                    icon: Icons.reply_rounded,
                    title: tr('Responder'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _replyToMessage = msg;
                      });
                    },
                  ),
                  if (isMe && msg.type == MessageType.text)
                    _buildMenuTile(
                      icon: Icons.edit_rounded,
                      title: tr('Editar mensaje'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEditDialog(msg);
                      },
                    ),
                  if (isMe || canModerate)
                    _buildMenuTile(
                      icon: Icons.delete_outline_rounded,
                      title: tr('Eliminar mensaje'),
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmDelete(msg);
                      },
                    ),
                  if (canModerate && !isMe && !targetIsOwner && (!targetIsCurator || isOwner))
                    _buildMenuTile(
                      icon: Icons.gavel_rounded,
                      title: tr('Expulsar del chat'),
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmBan(msg);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(icon, color: color.withOpacity(0.8), size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }


  void _confirmBan(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Expulsar del chat'), style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que quieres expulsar a ${msg.senderName ?? 'este usuario'}? No podrá volver a unirse.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () {
              _banUserFromChat(msg.senderId);
              Navigator.pop(ctx);
            },
            child: Text(tr('EXPULSAR'), style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Eliminar mensaje'), style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que deseas eliminar este mensaje? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(msg);
            },
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    // Si es imagen o audio, eliminar del Storage primero
    if (msg.imageUrl != null) {
      await _storageService.deleteFileByUrl(msg.imageUrl!);
    }
    if (msg.voiceUrl != null) {
      await _storageService.deleteFileByUrl(msg.voiceUrl!);
    }
    
    if (mounted) {
      _chatBloc.add(
        DeleteMessageEvent(chatRoomId: widget.chatRoomId, messageId: msg.id),
      );
    }
  }

  void _reactToMessage(ChatMessage msg, String reaction) {
    if (_currentUserId.isEmpty) return;
    
    if (!_isParticipant && _creatorId != _currentUserId && _privateChatKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Únete al chat para reaccionar'))),
      );
      return;
    }

    _chatRepository.reactToMessage(widget.chatRoomId, msg.id, _currentUserId, reaction);
  }

  void _showStickerReactionPicker(ChatMessage msg) {
    if (!_isParticipant && _creatorId != _currentUserId && _privateChatKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Únete al chat para usar stickers'))),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                tr('Reaccionar con Sticker'),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Expanded(
              child: StickerSelector(
                onStickerSelected: (url) {
                  Navigator.pop(ctx);
                  _reactToMessage(msg, url);
                },
                // We don't support custom stickers creating reactions for now to keep it simple
                onCustomStickerCreated: (file) async {
                  // If they upload a custom sticker, we'd need to upload it first
                  // For now let's just use regular stickers
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ChatMessage msg) {
    final controller = TextEditingController(text: msg.text);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Editar mensaje'), style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          maxLines: null,
          decoration: InputDecoration(
            hintText: tr('Escribe tu mensaje...'),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Wumbleheme.primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != msg.text) {
                _chatBloc.add(
                  EditMessageEvent(
                    chatRoomId: widget.chatRoomId,
                    messageId: msg.id,
                    newText: newText,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(tr('Guardar')),
          ),
        ],
      ),
    );
  }

  Future<void> _changeChatBackground() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.white70),
                title: Text(tr('Elegir imagen'), style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final xfile = await MediaHelper.pickImageWithOptimization(context);
                  if (xfile == null || !mounted) return;
                  
                  try {
                    debugPrint('ChatDetail: Subiendo imagen de fondo...');
                    final url = await _storageService.uploadChatImage(File(xfile.path));
                    debugPrint('ChatDetail: Fondo subido: $url');
                    
                    if (mounted) {
                      _chatBloc.add(UpdateChatBackgroundEvent(
                        chatRoomId: widget.chatRoomId,
                        imageUrl: url,
                      ));
                    }
                  } catch (e) {
                    debugPrint('ChatDetail: ❌ Error al subir fondo: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al subir imagen: $e')),
                      );
                    }
                  }
                },
              ),
              if (_backgroundImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  title: Text(tr('Quitar fondo'), style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _chatBloc.add(UpdateChatBackgroundEvent(
                      chatRoomId: widget.chatRoomId,
                      imageUrl: null,
                    ));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Vaciar chat'), style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas eliminar todos los mensajes? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _chatBloc.add(ClearChatEvent(chatRoomId: widget.chatRoomId));
            },
            child: Text(tr('Vaciar'), style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Eliminar chat'), style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este chat? Se perderán todos los datos y participantes. Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _chatBloc.add(DeleteChatRoomEvent(widget.chatRoomId));
              Navigator.pop(context); // Go back to previous screen
            },
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Abandonar chat'), style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas abandonar este chat público? Dejarás de recibir notificaciones.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _chatBloc.add(LeaveChatEvent(
                chatRoomId: widget.chatRoomId,
                userId: _currentUserId,
                username: _currentUserName,
              ));
              Navigator.pop(context); // Go back to previous screen
            },
            child: Text(tr('Abandonar'), style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleChatLock() async {
    final newStatus = !_isClosed;
    try {
      await context.read<ChatRepository>().toggleChatRoomLock(widget.chatRoomId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Chat cerrado correctamente.' : 'Chat abierto correctamente.'),
            backgroundColor: Wumbleheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showEditChatDialog() async {
    final doc = await FirebaseFirestore.instance.collection('chatRooms').doc(widget.chatRoomId).get();
    if (!doc.exists) return;
    
    final room = ChatRoom.fromFirestore(doc);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePublicChatScreen(
            communityId: _communityId ?? '',
            themeColor: Wumbleheme.primaryColor,
            existingChat: room,
          ),
        ),
      );
    }
  }

  void _showMemberManagementOptions(String userId, String name, bool isCurator) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Gestionar a $name',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: Icon(isCurator ? Icons.shield_outlined : Icons.shield, color: Colors.cyanAccent),
                title: Text(isCurator ? 'Quitar rol de Curador' : 'Hacer Curador del chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isCurator) {
                    _removeCurator(userId);
                  } else {
                    _appointCurator(userId);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.gavel, color: Colors.redAccent),
                title: Text(tr('Expulsar del chat'), style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBanFromList(userId, name);
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _appointCurator(String userId) {
    context.read<ChatRepository>().appointCurator(widget.chatRoomId, userId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Usuario nombrado Curador'))),
    );
  }

  void _removeCurator(String userId) {
    context.read<ChatRepository>().removeCurator(widget.chatRoomId, userId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Rol de Curador revocado'))),
    );
  }

  void _confirmBanFromList(String userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Expulsar del chat'), style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que quieres expulsar a $name? No podrá volver a unirse.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () {
              _banUserFromChat(userId);
              Navigator.pop(ctx);
            },
            child: Text(tr('EXPULSAR'), style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showChatMembersBottomSheet() {
    final participantIds = _participantNames.keys.toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, controller) {
            return Column(
              children: [
                SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  tr('Miembros del Chat'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (_description != null && _description!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('DESCRIPCIÓN'),
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            _description!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 12),
                if (_communityId != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final selected = await MemberPickerSheet.show(
                          context,
                          communityId: _communityId!,
                          excludedIds: participantIds,
                        );
                        if (selected != null && mounted) {
                          try {
                            await _chatRepository.inviteMemberToChat(
                              widget.chatRoomId,
                              UserProfile(
                                id: selected.userId,
                                username: '',
                                displayName: selected.displayName ?? 'Usuario',
                                avatarUrl: selected.avatarUrl ?? '',
                                bannerUrl: '',
                                backgroundUrl: '',
                                bio: '',
                                reputation: 0,
                                level: 1,
                                titles: const [],
                                followers: 0,
                                following: 0,
                                checkIns: 0,
                              ),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Invitado: ${selected.displayName}')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al invitar: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        }
                      },
                      icon: Icon(Icons.person_add, size: 18),
                      label: Text(tr('INVITAR MIEMBRO')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Wumbleheme.primaryColor,
                        foregroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: participantIds.length,
                    itemBuilder: (ctx, i) {
                      final uid = participantIds[i];
                      
                      String name = 'Usuario';
                      String avatar = '';
                      CommunityMember? knownMember;

                      try {
                        knownMember = _mentionableMembers.firstWhere((m) => m.userId == uid);
                      } catch (_) {}

                      if (uid == _currentUserId) {
                        name = knownMember?.displayName ?? _currentUserName;
                        avatar = knownMember?.avatarUrl ?? _currentUserAvatar;
                      } else {
                        name = knownMember?.displayName ?? _participantNames[uid] ?? 'Usuario';
                        avatar = knownMember?.avatarUrl ?? _participantAvatars[uid] ?? '';
                      }
                      
                      final level = knownMember?.level ?? 1;
                      
                      return ListTile(
                        leading: UserAvatar(
                          userId: uid,
                          avatarUrl: avatar,
                          displayName: name,
                          communityId: _communityId,
                          radius: 20,
                          avatarFrameUrl: uid == _currentUserId ? _currentUserAvatarFrame : _participantAvatarFrames[uid],
                          skipFirestoreSync: true,
                          isAnimated: false,
                        ),
                        title: Row(
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white)),
                            if (uid == _creatorId)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.star, color: Colors.amber, size: 14),
                              ),
                            if (_curatorIds.contains(uid))
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.shield, color: Colors.cyanAccent, size: 14),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          uid == _creatorId 
                              ? 'Anfitrión' 
                              : (_curatorIds.contains(uid) ? 'Curador' : (knownMember != null && knownMember.role.toLowerCase() != 'member'
                                  ? CommunityMember.getRoleTitle(knownMember.role)
                                  : (knownMember != null && knownMember.titles.isNotEmpty 
                                      ? knownMember.titles.first.text 
                                      : 'Miembro'))),
                          style: TextStyle(
                            color: (uid == _creatorId || _curatorIds.contains(uid)) ? Wumbleheme.primaryColor : Colors.white54, 
                            fontSize: 11,
                            fontWeight: (uid == _creatorId || _curatorIds.contains(uid)) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: () {
                          // Community Moderator Check
                          bool isCommunityModerator = false;
                          try {
                            final commState = context.read<CommunityContextBloc>().state;
                            isCommunityModerator = commState.memberProfile?.role == 'leader' || commState.memberProfile?.role == 'curator';
                          } catch (_) {}

                          final bool canManage = _currentUserId == _creatorId || isCommunityModerator;
                          
                          if (uid != _currentUserId && canManage) {
                            return IconButton(
                              icon: const Icon(Icons.more_horiz, color: Colors.white54),
                              onPressed: () => _showMemberManagementOptions(uid, name, _curatorIds.contains(uid)),
                            );
                          }
                          return null;
                        }(),
                        onTap: () {
                          Navigator.pop(ctx);
                          MemberMiniProfile.show(
                            context,
                            user: UserProfile(
                              id: uid,
                              username: '',
                              displayName: name,
                              avatarUrl: '', // Will load from repo
                              bannerUrl: '',
                              backgroundUrl: '',
                              bio: '',
                              reputation: 0,
                              level: 1,
                              titles: [],
                              followers: 0,
                              following: 0,
                              checkIns: 0,
                            ),
                            communityId: _communityId,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMentionsOverlay() {
    return Container(
      constraints: BoxConstraints(maxHeight: 200),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredMentions.length,
        itemBuilder: (context, index) {
          final member = _filteredMentions[index];
          return ListTile(
            leading: UserAvatar(
              userId: member.userId,
              avatarUrl: member.avatarUrl ?? '',
              displayName: member.displayName ?? 'Usuario',
              communityId: _communityId,
              radius: 14,
              skipFirestoreSync: true,
              isAnimated: false,
            ),
            title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  member.displayName ?? 'Usuario', 
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (member.isBot) ...[
                SizedBox(width: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    border: Border.all(color: Colors.blueAccent, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tr('BOT'),
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
            onTap: () => _selectMention(member),
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          _TypingDots(color: Wumbleheme.primaryColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _typingUsers.length == 1
                  ? '${_typingUsers[0].username} está escribiendo...'
                  : '${_typingUsers.length} personas están escribiendo...',
              style: TextStyle(
                color: Wumbleheme.primaryColor.withValues(alpha: 0.8),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    final minutes = (_recordingDuration / 60).floor().toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.red.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.mic, color: Colors.red, size: 16),
          SizedBox(width: 8),
          Text(
            'Grabando audio... $minutes:$seconds',
            style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.image_rounded,
                    color: Colors.blueAccent,
                    label: tr('Fotos'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendImage();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.sticky_note_2,
                    color: Colors.purpleAccent,
                    label: tr('Stickers'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _showStickers = true);
                    },
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatJoinPrompt() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, 16, 20, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.public_rounded, size: 20, color: Colors.orangeAccent),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('Conversación Pública'),
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        tr('Únete a este chat para empezar a escribir.'),
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (_currentUserId.isNotEmpty && _currentUserName != 'Usuario') {
                      _chatBloc.add(JoinPublicChatEvent(
                        chatRoomId: widget.chatRoomId,
                        userId: _currentUserId,
                        username: _currentUserName,
                        userAvatar: _currentUserAvatar,
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('Cargando datos de usuario...'))),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    minimumSize: Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(tr('UNIRME'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestJoinPrompt() {
    return BlocBuilder<CommunityContextBloc, CommunityContextState>(
      builder: (context, state) {
        // Guest mode: Requires membership to chat
        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 16, 20, 30), // Increased bottom padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.forum_rounded, size: 20, color: Colors.white),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr('Conversación Restringida'),
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            tr('Únete a la comunidad para participar.'),
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (state.activeCommunity != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityInfoScreen(community: state.activeCommunity!),
                            ),
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Wumbleheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        minimumSize: Size(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(tr('UNIRME'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return BlocBuilder<CommunityContextBloc, CommunityContextState>(
      builder: (context, state) {
        final bool isModerator = state.memberProfile?.role == 'leader' || state.memberProfile?.role == 'curator';
        final bool isClosedForMe = _isClosed && !isModerator && _creatorId != _currentUserId;

        if (isClosedForMe) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              border: Border(top: BorderSide(color: Colors.redAccent, width: 0.5)),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.redAccent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    tr('Este chat ha sido cerrado.'),
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }


        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToMessage != null) _buildReplyInputPreview(),
            Container(
              padding: EdgeInsets.fromLTRB(8, 4, 12, 10), // Increased bottom padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Plus Button (Consolidated Menu)
                    IconButton(
                      icon: Icon(Icons.add_circle, size: 28),
                      color: Colors.white54,
                      onPressed: _isUploadingMedia ? null : _showAttachmentMenu,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    SizedBox(width: 8),
                    
                    // Main Input Field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                maxLines: 5,
                                minLines: 1,
                                style: TextStyle(color: Colors.white, fontSize: 15),
                                onChanged: (val) {
                                  _updateTypingStatus(val.isNotEmpty);
                                  _handleMentionSearch(val);
                                  setState(() {});
                                },
                                onTap: () {
                                  if (_showStickers) setState(() => _showStickers = false);
                                },
                                decoration: InputDecoration(
                                  hintText: tr('Escribe un mensaje...'),
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  filled: false,
                                ),
                              ),
                            ),
                            // Emoji Button inside the TextField
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: IconButton(
                                icon: Icon(
                                  _showStickers ? Icons.keyboard : Icons.sticky_note_2,
                                  color: Colors.white54,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _isUploadingMedia ? null : () {
                                  setState(() {
                                    _showStickers = !_showStickers;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Send or Record Button
                    _controller.text.isNotEmpty
                        ? CircleAvatar(
                            backgroundColor: Wumbleheme.primaryColor,
                            radius: 20,
                            child: IconButton(
                              icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                              onPressed: _isUploadingMedia ? null : _sendMessage,
                            ),
                          )
                        : IgnorePointer(
                            ignoring: _isUploadingMedia,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isUploadingMedia ? 0.5 : 1.0,
                              child: InkWell(
                                onTap: () {
                                  if (_isRecording) {
                                    _stopAndSendVoiceMessage();
                                  } else {
                                    _startRecording();
                                  }
                                },
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  padding: EdgeInsets.all(_isRecording ? 12 : 10),
                                  decoration: BoxDecoration(
                                    color: _isRecording ? Colors.redAccent : Wumbleheme.secondaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: _isRecording 
                                        ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)] 
                                        : null,
                                  ),
                                  child: Icon(
                                    _isRecording ? Icons.stop : Icons.mic, 
                                    color: Colors.white,
                                    size: _isRecording ? 24 : 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReplyInputPreview() {
    final senderName = _replyToMessage?.senderName ?? _participantNames[_replyToMessage!.senderId] ?? 'Usuario';
    final text = _replyToMessage?.text ?? (_replyToMessage?.type == MessageType.sticker ? 'Sticker' : _replyToMessage?.type == MessageType.image ? 'Imagen' : _replyToMessage?.type == MessageType.voice ? 'Audio' : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: Wumbleheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Respondiendo a $senderName',
                  style: const TextStyle(
                    color: Wumbleheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white54),
            onPressed: () => setState(() => _replyToMessage = null),
          ),
        ],
      ),
    );
  }


  Widget _buildPendingReceiverPrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Text(
              '$_otherUserName quiere hablar contigo',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _chatBloc.add(RejectChatRequestEvent(chatRoomId: widget.chatRoomId, userId: _currentUserId));
                      Navigator.pop(context); // Close chat if rejected
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr('Rechazar')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _chatBloc.add(AcceptChatRequestEvent(chatRoomId: widget.chatRoomId, userId: _currentUserId, username: _currentUserName));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Wumbleheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr('Aceptar'), style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showFullEmojiReactionPicker(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Wumbleheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            Navigator.pop(ctx);
            _reactToMessage(msg, emoji.emoji);
          },
          config: Config(
            height: 350,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: Wumbleheme.backgroundColor,
              columns: 7,
              buttonMode: ButtonMode.MATERIAL,
              emojiSizeMax: 28,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: Wumbleheme.backgroundColor,
              indicatorColor: Wumbleheme.primaryColor,
              iconColorSelected: Wumbleheme.primaryColor,
              iconColor: Wumbleheme.textSecondary,
              dividerColor: Colors.white10,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Wumbleheme.backgroundColor,
              buttonIconColor: Colors.white,
              hintTextStyle: const TextStyle(color: Wumbleheme.textSecondary, fontSize: 14),
              inputTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 12,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showScrollToBottom ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_showScrollToBottom,
          child: GestureDetector(
            onTap: _scrollToBottom,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Wumbleheme.secondaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Wumbleheme.secondaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none, // Allow badge to overflow circle
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black,
                    size: 28,
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          _unreadCount > 99 ? '99+' : '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Discord-like dots: they go up and down (scale/offset) with a delay
            final double delay = i * 0.2;
            double value = (_controller.value - delay);
            if (value < 0) value += 1.0;
            
            // Create a wave effect
            final double wave = (1.0 + (0.5 * (1.0 - (2.0 * (value - 0.5)).abs()))).clamp(0.8, 1.2);
            final double opacity = (0.4 + (0.6 * (1.0 - (2.0 * (value - 0.5)).abs()))).clamp(0.4, 1.0);

            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              transform: Matrix4.translationValues(0, -3.0 * (wave - 1.0), 0),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
