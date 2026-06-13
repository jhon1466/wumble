import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import '../../chat/domain/chat_model.dart';

class CommunityLabel extends Equatable {
  final String text;
  final int? colorValue;

  const CommunityLabel({required this.text, this.colorValue});

  @override
  List<Object?> get props => [text, colorValue];

  Map<String, dynamic> toFirestore() => {
    'text': text,
    'colorValue': colorValue,
  };

  factory CommunityLabel.fromDynamic(dynamic data) {
    if (data is String) return CommunityLabel(text: data);
    if (data is Map) {
      final colorVal = data['colorValue'];
      return CommunityLabel(
        text: data['text'] ?? '',
        colorValue: colorVal is num ? colorVal.toInt() : null,
      );
    }
    return const CommunityLabel(text: '');
  }

  static List<CommunityLabel> fromDynamicList(dynamic list) {
    if (list is List) {
      return list.map((t) => CommunityLabel.fromDynamic(t)).toList();
    }
    return [];
  }
}

class CommunityMember {
  final String userId;
  final String communityId;
  final String? displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? backgroundUrl;
  final String? bio;
  final String? status;
  final String? statusEmoji;
  final List<CommunityLabel> titles;
  final String role; // 'leader', 'curator', 'member'
  final int level;
  final int reputation;
  final DateTime joinedAt;
  final DateTime? lastActive;
  final DateTime? lastCheckIn;
  final int checkInCount;
  final int onlineMinutes24h;
  final int onlineMinutes7d;
  final bool isBanned;
  final DateTime? banExpiresAt;
  final int? themeColorValue;
  final List<String> socialLinks;
  final bool showFollows;
  final ChatBubbleStyle? chatBubbleStyle;
  final bool isBot;
  final bool isMuted;
  final bool showOnlineStatus;
  final String? avatarFrameUrl; // NEW
  final double bannerAlignmentY;


  bool get isOnline {
    if (lastActive == null) return false;
    final now = DateTime.now();
    return now.difference(lastActive!).inMinutes < 10;
  }

  CommunityMember({
    required this.userId,
    required this.communityId,
    this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.backgroundUrl,
    this.bio,
    this.status,
    this.statusEmoji,
    this.titles = const [],
    this.role = 'member',
    this.level = 1,
    this.reputation = 0,
    required this.joinedAt,
    this.lastActive,
    this.lastCheckIn,
    this.checkInCount = 1,
    this.onlineMinutes24h = 0,
    this.onlineMinutes7d = 0,
    this.isBanned = false,
    this.banExpiresAt,
    this.themeColorValue,
    this.socialLinks = const [],
    this.showFollows = true,
    this.chatBubbleStyle,
    this.isBot = false,
    this.isMuted = false,
    this.showOnlineStatus = true,
    this.avatarFrameUrl, // NEW
    this.bannerAlignmentY = 0.0,
  });

  factory CommunityMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityMember(
      userId: doc.id, // Siempre garantizado
      communityId: data['communityId'] ?? '',
      displayName: data['displayName'],
      avatarUrl: data['avatarUrl'],
      bannerUrl: data['bannerUrl'],
      backgroundUrl: data['backgroundUrl'],
      bio: data['bio'],
      status: data['status'],
      statusEmoji: data['statusEmoji'],
      titles: (data['titles'] as List<dynamic>?)?.map((t) => CommunityLabel.fromDynamic(t)).toList() ?? [],
      role: data['role'] ?? 'member',
      level: (data['level'] as num?)?.toInt() ?? 1,
      reputation: (data['reputation'] as num?)?.toInt() ?? 0,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      lastCheckIn: (data['lastCheckIn'] as Timestamp?)?.toDate(),
      checkInCount: (data['checkInCount'] as num?)?.toInt() ?? 1,
      onlineMinutes24h: (data['onlineMinutes24h'] as num?)?.toInt() ?? 0,
      onlineMinutes7d: (data['onlineMinutes7d'] as num?)?.toInt() ?? 0,
      isBanned: data['isBanned'] ?? false,
      banExpiresAt: (data['banExpiresAt'] as Timestamp?)?.toDate(),
      themeColorValue: (data['themeColorValue'] as num?)?.toInt(),
      socialLinks: List<String>.from(data['socialLinks'] ?? []),
      showFollows: data['showFollows'] ?? true,
      chatBubbleStyle: data['chatBubbleStyle'] != null ? ChatBubbleStyle.fromMap(data['chatBubbleStyle']) : null,
      isBot: data['isBot'] ?? false,
      isMuted: data['isMuted'] ?? false,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      avatarFrameUrl: data['avatarFrameUrl'] as String?, // NEW
      bannerAlignmentY: (data['bannerAlignmentY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'communityId': communityId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'backgroundUrl': backgroundUrl,
      'bio': bio,
      'status': status,
      'statusEmoji': statusEmoji,
      'titles': titles.map((t) => t.toFirestore()).toList(),
      'role': role,
      'level': level,
      'reputation': reputation,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : FieldValue.serverTimestamp(),
      'lastCheckIn': lastCheckIn != null ? Timestamp.fromDate(lastCheckIn!) : null,
      'checkInCount': checkInCount,
      'onlineMinutes24h': onlineMinutes24h,
      'onlineMinutes7d': onlineMinutes7d,
      'isBanned': isBanned,
      'banExpiresAt': banExpiresAt != null ? Timestamp.fromDate(banExpiresAt!) : null,
      'themeColorValue': themeColorValue,
      'socialLinks': socialLinks,
      'showFollows': showFollows,
      'chatBubbleStyle': chatBubbleStyle?.toMap(),
      'isBot': isBot,
      'isMuted': isMuted,
      'showOnlineStatus': showOnlineStatus,
      'avatarFrameUrl': avatarFrameUrl, // NEW
      'bannerAlignmentY': bannerAlignmentY,
    };
  }

  static String getRoleTitle(String role) {
    switch (role.toLowerCase()) {
      case 'leader':
        return 'Líder';
      case 'curator':
        return 'Curador';
      default:
        return 'Miembro';
    }
  }

  static Color getRoleColor(String role, Color defaultColor) {
    switch (role.toLowerCase()) {
      case 'leader':
        return const Color(0xFFFFC107); // Amber
      case 'curator':
        return const Color(0xFF00BFA5); // Teal/Curator
      default:
        return defaultColor;
    }
  }
  CommunityMember copyWith({
    String? displayName,
    String? avatarUrl,
    String? bannerUrl,
    String? backgroundUrl,
    String? bio,
    String? status,
    String? statusEmoji,
    List<CommunityLabel>? titles,
    String? role,
    int? level,
    int? reputation,
    DateTime? lastActive,
    DateTime? lastCheckIn,
    int? checkInCount,
    int? onlineMinutes24h,
    int? onlineMinutes7d,
    bool? isBanned,
    DateTime? banExpiresAt,
    int? themeColorValue,
    List<String>? socialLinks,
    bool? showFollows,
    ChatBubbleStyle? chatBubbleStyle,
    bool? isBot,
    bool? isMuted,
    bool? showOnlineStatus,
    String? avatarFrameUrl, // NEW
    double? bannerAlignmentY,
  }) {
    return CommunityMember(
      userId: userId,
      communityId: communityId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      statusEmoji: statusEmoji ?? this.statusEmoji,
      titles: titles ?? this.titles,
      role: role ?? this.role,
      level: level ?? this.level,
      reputation: reputation ?? this.reputation,
      joinedAt: joinedAt,
      lastActive: lastActive ?? this.lastActive,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      checkInCount: checkInCount ?? this.checkInCount,
      onlineMinutes24h: onlineMinutes24h ?? this.onlineMinutes24h,
      onlineMinutes7d: onlineMinutes7d ?? this.onlineMinutes7d,
      isBanned: isBanned ?? this.isBanned,
      banExpiresAt: banExpiresAt ?? this.banExpiresAt,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      socialLinks: socialLinks ?? this.socialLinks,
      showFollows: showFollows ?? this.showFollows,
      chatBubbleStyle: chatBubbleStyle ?? this.chatBubbleStyle,
      isBot: isBot ?? this.isBot,
      isMuted: isMuted ?? this.isMuted,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      avatarFrameUrl: avatarFrameUrl ?? this.avatarFrameUrl, // NEW
      bannerAlignmentY: bannerAlignmentY ?? this.bannerAlignmentY,
    );
  }
}
