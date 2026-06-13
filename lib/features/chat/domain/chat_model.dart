import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:wumble/core/domain/link_preview_data.dart';
import 'bot_framework.dart'; // Add import for BotButton

enum MessageType { text, sticker, voice, image, system }

class ChatMessage {
  final String id;
  final String senderId;
  final String? senderName; // Add sender name for notifications
  final String? senderAvatarUrl; // Add sender avatar for isolation
  final String? senderAvatarFrameUrl; // NEW
  final String? text;

  final String? stickerUrl;
  final String? imageUrl;
  final String? voiceUrl;
  final String? localPath;
  final MessageType type;
  final DateTime timestamp;
  final bool isEdited;
  final String? replyToId;
  final String? replyToUserId;
  final String? replyToText;
  final String? replyToSenderName;
  final String? replyToImageUrl;
  final MessageType? replyToType;
  final ChatBubbleStyle? bubbleStyle;
  final bool isBotEmbed;
  final String? embedTitle;
  final String? embedFooter;
  final int? embedColor;
  final List<BotButton> botButtons; 
  final BotConfig? botConfig; // NEW: Full config for mini-profile
  final Map<String, List<String>> reactions; // NEW: emoji/url -> [userIds]
  final LinkPreviewData? linkPreview; // NEW

  ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.senderAvatarFrameUrl, // NEW
    this.text,

    this.stickerUrl,
    this.imageUrl,
    this.voiceUrl,
    this.localPath,
    required this.type,
    required this.timestamp,
    this.isEdited = false,
    this.replyToId,
    this.replyToUserId,
    this.replyToText,
    this.replyToSenderName,
    this.replyToImageUrl,
    this.replyToType,
    this.bubbleStyle,
    this.isBotEmbed = false,
    this.embedTitle,
    this.embedFooter,
    this.embedColor,
    this.botButtons = const [],
    this.botConfig,
    this.reactions = const {},
    this.linkPreview,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'senderAvatarFrameUrl': senderAvatarFrameUrl, // NEW
      'text': text,

      'stickerUrl': stickerUrl,
      'imageUrl': imageUrl,
      'voiceUrl': voiceUrl,
      'type': type.name,
      'timestamp': FieldValue.serverTimestamp(),
      'isEdited': isEdited,
      'replyToId': replyToId,
      'replyToUserId': replyToUserId,
      'replyToText': replyToText,
      'replyToSenderName': replyToSenderName,
      'replyToImageUrl': replyToImageUrl,
      'replyToType': replyToType?.name,
      'bubbleStyle': bubbleStyle?.toMap(),
      'isBotEmbed': isBotEmbed,
      'embedTitle': embedTitle,
      'embedFooter': embedFooter,
      'embedColor': embedColor,
      'botButtons': botButtons.map((b) => b.toFirestore()).toList(),
      'botConfig': botConfig?.toFirestore(),
      'reactions': reactions,
      'linkPreview': linkPreview?.toMap(),
    };
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'],
      senderAvatarUrl: data['senderAvatarUrl'],
      senderAvatarFrameUrl: data['senderAvatarFrameUrl'], // NEW
      text: data['text'],

      stickerUrl: data['stickerUrl'],
      imageUrl: data['imageUrl'],
      voiceUrl: data['voiceUrl'],
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEdited: data['isEdited'] ?? false,
      replyToId: data['replyToId'],
      replyToUserId: data['replyToUserId'],
      replyToText: data['replyToText'],
      replyToSenderName: data['replyToSenderName'],
      replyToImageUrl: data['replyToImageUrl'],
      replyToType: data['replyToType'] != null ? MessageType.values.firstWhere((e) => e.name == data['replyToType'], orElse: () => MessageType.text) : null,
      bubbleStyle: data['bubbleStyle'] != null ? ChatBubbleStyle.fromMap(data['bubbleStyle']) : null,
      isBotEmbed: data['isBotEmbed'] ?? false,
      embedTitle: data['embedTitle'],
      embedFooter: data['embedFooter'],
      embedColor: data['embedColor'],
      botButtons: (data['botButtons'] as List<dynamic>?)
              ?.map((b) => BotButton.fromFirestore(b as Map<String, dynamic>))
              .toList() ??
          [],
      botConfig: data['botConfig'] != null ? BotConfig.fromMap(data['botConfig'] as Map<String, dynamic>) : null,
      reactions: (data['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List<dynamic>)),
          ) ??
          {},
      linkPreview: data['linkPreview'] != null ? LinkPreviewData.fromMap(data['linkPreview']) : null,
    );
  }
}

class BubbleLayer extends Equatable {
  final String id;
  final String type; // 'image', 'sticker', 'shape'
  final String url; // Could be local path or remote URL
  final double x; // Relative position 0.0 to 1.0 or absolute offset, let's use relative offset from center or top-left. Using -1.0 to 1.0 (Alignment) is good.
  final double y;
  final double scale; // 1.0 is original size
  final double rotation; // In radians
  final double opacity; // 0.0 to 1.0
  final int? colorValue; // For 'shape' or 'box' layers
  final int? secondaryColorValue;
  final double borderRadius;
  final double blur;

  const BubbleLayer({
    required this.id,
    required this.type,
    required this.url,
    this.x = 0.0,
    this.y = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.colorValue,
    this.secondaryColorValue,
    this.borderRadius = 0.0,
    this.blur = 0.0,
  });

  @override
  List<Object?> get props => [id, type, url, x, y, scale, rotation, opacity, colorValue, secondaryColorValue, borderRadius, blur];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
      'opacity': opacity,
      'colorValue': colorValue,
      'secondaryColorValue': secondaryColorValue,
      'borderRadius': borderRadius,
      'blur': blur,
    };
  }

  factory BubbleLayer.fromMap(Map<String, dynamic> map) {
    return BubbleLayer(
      id: map['id'] ?? '',
      type: map['type'] ?? 'image',
      url: map['url'] ?? '',
      x: (map['x'] ?? 0.0).toDouble(),
      y: (map['y'] ?? 0.0).toDouble(),
      scale: (map['scale'] ?? 1.0).toDouble(),
      rotation: (map['rotation'] ?? 0.0).toDouble(),
      opacity: (map['opacity'] ?? 1.0).toDouble(),
      colorValue: map['colorValue'],
      secondaryColorValue: map['secondaryColorValue'],
      borderRadius: (map['borderRadius'] ?? 0.0).toDouble(),
      blur: (map['blur'] ?? 0.0).toDouble(),
    );
  }

  BubbleLayer copyWith({
    String? id,
    String? type,
    String? url,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
    int? colorValue,
    int? secondaryColorValue,
    double? borderRadius,
    double? blur,
  }) {
    return BubbleLayer(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      colorValue: colorValue ?? this.colorValue,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      borderRadius: borderRadius ?? this.borderRadius,
      blur: blur ?? this.blur,
    );
  }
}

class AdvancedBubbleConfig extends Equatable {
  final List<BubbleLayer> layers;
  final double paddingTop;
  final double paddingBottom;
  final double paddingLeft;
  final double paddingRight;
  final double sliceTop; // 9-slice guide constraints
  final double sliceBottom;
  final double sliceLeft;
  final double sliceRight;
  final String? fontStyle; // Optional Google fonts specifier
  final int? shadowColorValue;
  final double shadowBlurRadius;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final bool clipLayers; // Toggle for overflow
  final List<Offset>? customPathPoints; // Relative points [0.0, 1.0]

  const AdvancedBubbleConfig({
    this.layers = const [],
    this.paddingTop = 10.0,
    this.paddingBottom = 10.0,
    this.paddingLeft = 14.0,
    this.paddingRight = 14.0,
    this.sliceTop = 0.0,
    this.sliceBottom = 0.0,
    this.sliceLeft = 0.0,
    this.sliceRight = 0.0,
    this.fontStyle,
    this.shadowColorValue,
    this.shadowBlurRadius = 0.0,
    this.shadowOffsetX = 0.0,
    this.shadowOffsetY = 0.0,
    this.clipLayers = true,
    this.customPathPoints,
  });

  @override
  List<Object?> get props => [
        layers, paddingTop, paddingBottom, paddingLeft, paddingRight,
        sliceTop, sliceBottom, sliceLeft, sliceRight,
        fontStyle, shadowColorValue, shadowBlurRadius, shadowOffsetX, shadowOffsetY,
        clipLayers, customPathPoints,
      ];

  Map<String, dynamic> toMap() {
    return {
      'layers': layers.map((e) => e.toMap()).toList(),
      'paddingTop': paddingTop,
      'paddingBottom': paddingBottom,
      'paddingLeft': paddingLeft,
      'paddingRight': paddingRight,
      'sliceTop': sliceTop,
      'sliceBottom': sliceBottom,
      'sliceLeft': sliceLeft,
      'sliceRight': sliceRight,
      'fontStyle': fontStyle,
      'shadowColorValue': shadowColorValue,
      'shadowBlurRadius': shadowBlurRadius,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'clipLayers': clipLayers,
      'customPathPoints': customPathPoints?.map((Offset e) => {'x': e.dx, 'y': e.dy}).toList(),
    };
  }

  factory AdvancedBubbleConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AdvancedBubbleConfig();
    return AdvancedBubbleConfig(
      layers: (map['layers'] as List<dynamic>?)?.map((e) => BubbleLayer.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      paddingTop: (map['paddingTop'] ?? 10.0).toDouble(),
      paddingBottom: (map['paddingBottom'] ?? 10.0).toDouble(),
      paddingLeft: (map['paddingLeft'] ?? 14.0).toDouble(),
      paddingRight: (map['paddingRight'] ?? 14.0).toDouble(),
      sliceTop: (map['sliceTop'] ?? 0.0).toDouble(),
      sliceBottom: (map['sliceBottom'] ?? 0.0).toDouble(),
      sliceLeft: (map['sliceLeft'] ?? 0.0).toDouble(),
      sliceRight: (map['sliceRight'] ?? 0.0).toDouble(),
      fontStyle: map['fontStyle'],
      shadowColorValue: map['shadowColorValue'],
      shadowBlurRadius: (map['shadowBlurRadius'] ?? 0.0).toDouble(),
      shadowOffsetX: (map['shadowOffsetX'] ?? 0.0).toDouble(),
      shadowOffsetY: (map['shadowOffsetY'] ?? 0.0).toDouble(),
      clipLayers: map['clipLayers'] ?? true,
      customPathPoints: (map['customPathPoints'] as List<dynamic>?)
          ?.map((e) => Offset((e['x'] ?? 0.0).toDouble(), (e['y'] ?? 0.0).toDouble()))
          .toList(),
    );
  }

  AdvancedBubbleConfig copyWith({
    List<BubbleLayer>? layers,
    double? paddingTop, double? paddingBottom, double? paddingLeft, double? paddingRight,
    double? sliceTop, double? sliceBottom, double? sliceLeft, double? sliceRight,
    String? fontStyle,
    int? shadowColorValue,
    double? shadowBlurRadius,
    double? shadowOffsetX,
    double? shadowOffsetY,
    bool? clipLayers,
    List<Offset>? customPathPoints,
  }) {
    return AdvancedBubbleConfig(
      layers: layers ?? this.layers,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      sliceTop: sliceTop ?? this.sliceTop,
      sliceBottom: sliceBottom ?? this.sliceBottom,
      sliceLeft: sliceLeft ?? this.sliceLeft,
      sliceRight: sliceRight ?? this.sliceRight,
      fontStyle: fontStyle ?? this.fontStyle,
      shadowColorValue: shadowColorValue ?? this.shadowColorValue,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      clipLayers: clipLayers ?? this.clipLayers,
      customPathPoints: customPathPoints ?? this.customPathPoints,
    );
  }
}

class ChatBubbleStyle extends Equatable {
  final String id;
  final String name;
  final int backgroundColorValue;
  final int? secondaryColorValue; // For gradients
  final int textColorValue;
  final String? topLeftOrnamentUrl;
  final String? topRightOrnamentUrl;
  final String? bottomLeftOrnamentUrl;
  final String? bottomRightOrnamentUrl;
  final String? backgroundImageUrl; // Texture
  final String? shapeId; // For custom bubble geometries (sharp, wavy, cloud, etc.)
  final bool hasGlow;
  final AdvancedBubbleConfig? advancedConfig; // Added for V2 editor

  const ChatBubbleStyle({
    required this.id,
    required this.name,
    required this.backgroundColorValue,
    this.secondaryColorValue,
    this.textColorValue = 0xFFFFFFFF,
    this.topLeftOrnamentUrl,
    this.topRightOrnamentUrl,
    this.bottomLeftOrnamentUrl,
    this.bottomRightOrnamentUrl,
    this.backgroundImageUrl,
    this.shapeId,
    this.hasGlow = false,
    this.advancedConfig,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        backgroundColorValue,
        secondaryColorValue,
        textColorValue,
        topLeftOrnamentUrl,
        topRightOrnamentUrl,
        bottomLeftOrnamentUrl,
        bottomRightOrnamentUrl,
        backgroundImageUrl,
        shapeId,
        hasGlow,
        advancedConfig,
      ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'backgroundColorValue': backgroundColorValue,
      'secondaryColorValue': secondaryColorValue,
      'textColorValue': textColorValue,
      'topLeftOrnamentUrl': topLeftOrnamentUrl,
      'topRightOrnamentUrl': topRightOrnamentUrl,
      'bottomLeftOrnamentUrl': bottomLeftOrnamentUrl,
      'bottomRightOrnamentUrl': bottomRightOrnamentUrl,
      'backgroundImageUrl': backgroundImageUrl,
      'shapeId': shapeId,
      'hasGlow': hasGlow,
      'advancedConfig': advancedConfig?.toMap(),
    };
  }

  ChatBubbleStyle copyWith({
    String? id,
    String? name,
    int? backgroundColorValue,
    int? secondaryColorValue,
    int? textColorValue,
    String? topLeftOrnamentUrl,
    String? topRightOrnamentUrl,
    String? bottomLeftOrnamentUrl,
    String? bottomRightOrnamentUrl,
    String? backgroundImageUrl,
    String? shapeId,
    bool? hasGlow,
    AdvancedBubbleConfig? advancedConfig,
  }) {
    return ChatBubbleStyle(
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      topLeftOrnamentUrl: topLeftOrnamentUrl ?? this.topLeftOrnamentUrl,
      topRightOrnamentUrl: topRightOrnamentUrl ?? this.topRightOrnamentUrl,
      bottomLeftOrnamentUrl: bottomLeftOrnamentUrl ?? this.bottomLeftOrnamentUrl,
      bottomRightOrnamentUrl: bottomRightOrnamentUrl ?? this.bottomRightOrnamentUrl,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      shapeId: shapeId ?? this.shapeId,
      hasGlow: hasGlow ?? this.hasGlow,
      advancedConfig: advancedConfig ?? this.advancedConfig,
    );
  }

  factory ChatBubbleStyle.fromMap(Map<String, dynamic> map) {
    return ChatBubbleStyle(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      backgroundColorValue: map['backgroundColorValue'] ?? 0xFF2B2D31,
      secondaryColorValue: map['secondaryColorValue'],
      textColorValue: map['textColorValue'] ?? 0xFFFFFFFF,
      topLeftOrnamentUrl: map['topLeftOrnamentUrl'],
      topRightOrnamentUrl: map['topRightOrnamentUrl'] ?? map['ornamentUrl'], // Legacy fallback
      bottomLeftOrnamentUrl: map['bottomLeftOrnamentUrl'],
      bottomRightOrnamentUrl: map['bottomRightOrnamentUrl'],
      backgroundImageUrl: map['backgroundImageUrl'],
      shapeId: map['shapeId'],
      hasGlow: map['hasGlow'] ?? false,
      advancedConfig: map['advancedConfig'] != null ? AdvancedBubbleConfig.fromMap(map['advancedConfig']) : null,
    );
  }
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantAvatars;
  final Map<String, String> participantAvatarFrames; // NEW
  final String lastMessage;

  final DateTime lastMessageTime;
  final String lastSenderId;
  final String? backgroundImageUrl;
  final String? bannerUrl; // NEW: Specific for list/card display
  final String? privateChatKey; // Added for optimized 1:1 lookups
  
  // Public Chat Fields
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? communityId;
  final bool isPublic;
  final String? creatorId;
  final List<String> curatorIds;
  final List<String> bannedUserIds;
  final bool isClosed; // Added
  
  // 1:1 Chat Invitation Fields
  final String? invitationStatus; // 'pending', 'accepted', 'rejected'
  final String? inviterId;

  final Map<String, int> unreadCounts; // userId -> count
  final Map<String, DateTime> lastReadTimes; // userId -> timestamp
  final Map<String, Map<String, bool>> participantPrivacy; // userId -> {setting: value}

  ChatRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantAvatars,
    this.participantAvatarFrames = const {}, // NEW
    required this.lastMessage,

    required this.lastMessageTime,
    required this.lastSenderId,
    this.backgroundImageUrl,
    this.bannerUrl, // NEW
    this.privateChatKey,
    this.title,
    this.description,
    this.imageUrl,
    this.communityId,
    this.isPublic = false,
    this.creatorId,
    this.curatorIds = const [],
    this.bannedUserIds = const [],
    this.isClosed = false,
    this.invitationStatus,
    this.inviterId,
    this.unreadCounts = const {},
    this.lastReadTimes = const {},
    this.participantPrivacy = const {},
  });

  /// Get the other user's ID for 1:1 chats
  String getOtherUserId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId, orElse: () => '');
  }

  /// Get the other user's name for 1:1 chats
  String getOtherUserName(String currentUserId) {
    final otherId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    return participantNames[otherId] ?? 'Usuario';
  }

  /// Get the other user's avatar for 1:1 chats
  String getOtherUserAvatar(String currentUserId) {
    final otherId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    return participantAvatars[otherId] ?? '';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'participantAvatarFrames': participantAvatarFrames, // NEW
      'lastMessage': lastMessage,

      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': lastSenderId,
      'privateChatKey': privateChatKey,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'communityId': communityId,
      'isPublic': isPublic,
      'creatorId': creatorId,
      'curatorIds': curatorIds,
      'bannedUserIds': bannedUserIds,
      'backgroundImageUrl': backgroundImageUrl,
      'bannerUrl': bannerUrl, // NEW
      'isClosed': isClosed,
      'invitationStatus': invitationStatus,
      'inviterId': inviterId,
      'unreadCounts': unreadCounts,
      'lastReadTimes': lastReadTimes.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      'participantPrivacy': participantPrivacy,
    };
  }

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Process participantPrivacy to ensure correct types
    final rawPrivacy = data['participantPrivacy'] as Map<String, dynamic>? ?? {};
    final Map<String, Map<String, bool>> privacySet = {};
    rawPrivacy.forEach((userId, settings) {
      if (settings is Map) {
        privacySet[userId] = Map<String, bool>.from(settings);
      }
    });

    return ChatRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantAvatars: Map<String, String>.from(data['participantAvatars'] ?? {}),
      participantAvatarFrames: Map<String, String>.from(data['participantAvatarFrames'] ?? {}), // NEW
      lastMessage: data['lastMessage'] ?? '',

      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: data['lastSenderId'] ?? '',
      backgroundImageUrl: data['backgroundImageUrl'],
      bannerUrl: data['bannerUrl'], // NEW
      privateChatKey: data['privateChatKey'],
      title: data['title'],
      description: data['description'],
      imageUrl: data['imageUrl'],
      communityId: data['communityId'],
      isPublic: data['isPublic'] ?? false,
      creatorId: data['creatorId'],
      curatorIds: List<String>.from(data['curatorIds'] ?? []),
      bannedUserIds: List<String>.from(data['bannedUserIds'] ?? []),
      isClosed: data['isClosed'] ?? false,
      invitationStatus: data['invitationStatus'],
      inviterId: data['inviterId'],
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      lastReadTimes: (data['lastReadTimes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as Timestamp?)?.toDate() ?? DateTime.now()),
          ) ??
          {},
      participantPrivacy: privacySet,
    );
  }
}

class TypingUser extends Equatable {
  final String userId;
  final String username;
  final DateTime timestamp;

  const TypingUser({
    required this.userId,
    required this.username,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [userId, username, timestamp];

  factory TypingUser.fromFirestore(Map<String, dynamic> data, String id) {
    return TypingUser(
      userId: id,
      username: data['username'] ?? 'Usuario',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class LiveParticipant extends Equatable {
  final String userId;
  final String username;
  final String avatarUrl;
  final String role; // 'host', 'cohost', 'speaker', 'listener'
  final bool isMicOn;
  final bool isSpeaking;

  LiveParticipant({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.role,
    this.isMicOn = true, // Default to true (mic open)
    this.isSpeaking = false,
  });

  LiveParticipant copyWith({
    String? userId,
    String? username,
    String? avatarUrl,
    String? role,
    bool? isMicOn,
    bool? isSpeaking,
  }) {
    return LiveParticipant(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isMicOn: isMicOn ?? this.isMicOn,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  @override
  List<Object?> get props => [userId, username, avatarUrl, role, isMicOn, isSpeaking];

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'role': role,
      'isMicOn': isMicOn,
      'isSpeaking': isSpeaking,
    };
  }

  factory LiveParticipant.fromMap(Map<String, dynamic> map) {
    return LiveParticipant(
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      role: map['role'] ?? 'listener',
      isMicOn: map['isMicOn'] ?? true, // Default to true
      isSpeaking: map['isSpeaking'] ?? false,
    );
  }
}

class LiveSession extends Equatable {
  final String chatRoomId;
  final bool isActive;
  final String hostId;
  final String? announcement;
  final List<LiveParticipant> participants;
  final DateTime? startedAt;

  LiveSession({
    required this.chatRoomId,
    required this.isActive,
    required this.hostId,
    this.announcement,
    required this.participants,
    this.startedAt,
  });

  LiveSession copyWith({
    String? chatRoomId,
    bool? isActive,
    String? hostId,
    String? announcement,
    List<LiveParticipant>? participants,
    DateTime? startedAt,
  }) {
    return LiveSession(
      chatRoomId: chatRoomId ?? this.chatRoomId,
      isActive: isActive ?? this.isActive,
      hostId: hostId ?? this.hostId,
      announcement: announcement ?? this.announcement,
      participants: participants ?? this.participants,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  List<Object?> get props => [chatRoomId, isActive, hostId, announcement, participants, startedAt];

  Map<String, dynamic> toFirestore() {
    return {
      'isActive': isActive,
      'hostId': hostId,
      'announcement': announcement,
      'participants': participants.map((p) => p.toMap()).toList(),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory LiveSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveSession(
      chatRoomId: doc.id,
      isActive: data['isActive'] ?? false,
      hostId: data['hostId'] ?? '',
      announcement: data['announcement'],
      participants: (data['participants'] as List<dynamic>?)
              ?.map((p) => LiveParticipant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
    );
  }
}
