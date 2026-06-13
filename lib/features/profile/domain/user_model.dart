import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';

class UserProfile extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl; // Soporta Imágenes y GIFs
  final String? email; // Correo electrónico (opcional en Firestore)
  final String bannerUrl; // Imagen/GIF arriba del avatar
  final String backgroundUrl; // Imagen/GIF de fondo del perfil completo
  final String bio;
  final int reputation;
  final int level;
  final List<CommunityLabel> titles;
  final int followers;
  final int following;
  final int checkIns;
  final DateTime? lastCheckIn;
  final int checkInStreak;
  final String? avatarFrameUrl;
  final double bannerAlignmentY;
  final List<String> ownedFrames;
  final int coins;
  final String? status;
  final String? statusEmoji;
  final bool isOnline;
  final bool isProfileComplete;
  final DateTime? joinedAt;
  final int? themeColorValue;
  final List<String> socialLinks;
  final bool showFollows;
  final String globalRole; // 'user', 'moderator', 'admin'
  final String communityRole; // role within current community: 'member', 'leader', 'curator'
  final bool isBanned;
  final ChatBubbleStyle? chatBubbleStyle;
  final List<ChatBubbleStyle> ownedBubbleStyles;
  final String wallPrivacy; // 'everyone', 'members', 'nobody'
  final String chatInvitePrivacy; // 'everyone', 'members', 'nobody'
  final bool isBot;
  // Notification preferences
  final bool notifyMessages;
  final bool notifyLikes;
  final bool notifyFollowers;
  final bool notifyMentions;
  // Chat preferences
  final bool showReadReceipts;
  final bool showOnlineStatus;
  // Blocked users
  final List<String> blockedUserIds;
  final DateTime? birthday;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.email,
    required this.bannerUrl,
    required this.backgroundUrl,
    required this.bio,
    required this.reputation,
    required this.level,
    required this.titles,
    required this.followers,
    required this.following,
    required this.checkIns,
    this.lastCheckIn,
    this.checkInStreak = 0,
    this.avatarFrameUrl,
    this.bannerAlignmentY = 0.0,
    this.ownedFrames = const [],
    this.coins = 0,
    this.status,
    this.statusEmoji,
    this.isOnline = false,
    this.isProfileComplete = false,
    this.joinedAt,
    this.themeColorValue,
    this.socialLinks = const [],
    this.showFollows = true,
    this.globalRole = 'user',
    this.communityRole = 'member',
    this.isBanned = false,
    this.chatBubbleStyle,
    this.ownedBubbleStyles = const [],
    this.wallPrivacy = 'everyone',
    this.chatInvitePrivacy = 'everyone',
    this.isBot = false,
    this.notifyMessages = true,
    this.notifyLikes = true,
    this.notifyFollowers = true,
    this.notifyMentions = true,
    this.showReadReceipts = true,
    this.showOnlineStatus = true,
    this.blockedUserIds = const [],
    this.birthday,
  });

  @override
  List<Object?> get props => [
        id,
        username,
        displayName,
        avatarUrl,
        email,
        bannerUrl,
        backgroundUrl,
        bio,
        reputation,
        level,
        titles,
        followers,
        following,
        checkIns,
        lastCheckIn,
        checkInStreak,
        avatarFrameUrl,
        bannerAlignmentY,
        ownedFrames,
        coins,
        status,
        statusEmoji,
        isOnline,
        isProfileComplete,
        joinedAt,
        themeColorValue,
        socialLinks,
        showFollows,
        globalRole,
        communityRole,
        isBanned,
        chatBubbleStyle,
        ownedBubbleStyles,
        wallPrivacy,
        chatInvitePrivacy,
        notifyMessages,
        notifyLikes,
        notifyFollowers,
        notifyMentions,
        showReadReceipts,
        showOnlineStatus,
        blockedUserIds,
        birthday,
      ];

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? bannerUrl,
    String? backgroundUrl,
    String? bio,
    String? status,
    String? statusEmoji,
    int? reputation,
    int? level,
    int? checkIns,
    DateTime? lastCheckIn,
    int? checkInStreak,
    String? avatarFrameUrl,
    List<String>? ownedFrames,
    int? coins,
    List<CommunityLabel>? titles,
    bool? isOnline,
    bool? isProfileComplete,
    DateTime? joinedAt,
    int? themeColorValue,
    List<String>? socialLinks,
    bool? showFollows,
    String? globalRole,
    String? communityRole,
    bool? isBanned,
    ChatBubbleStyle? chatBubbleStyle,
    List<ChatBubbleStyle>? ownedBubbleStyles,
    String? wallPrivacy,
    String? chatInvitePrivacy,
    bool? isBot,
    bool? notifyMessages,
    bool? notifyLikes,
    bool? notifyFollowers,
    bool? notifyMentions,
    bool? showReadReceipts,
    bool? showOnlineStatus,
    double? bannerAlignmentY,
    List<String>? blockedUserIds,
    DateTime? birthday,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      bio: bio ?? this.bio,
      reputation: reputation ?? this.reputation,
      level: level ?? this.level,
      titles: titles ?? this.titles,
      followers: this.followers,
      following: this.following,
      checkIns: checkIns ?? this.checkIns,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      checkInStreak: checkInStreak ?? this.checkInStreak,
      avatarFrameUrl: avatarFrameUrl ?? this.avatarFrameUrl,
      ownedFrames: ownedFrames ?? this.ownedFrames,
      coins: coins ?? this.coins,
      status: status ?? this.status,
      statusEmoji: statusEmoji ?? this.statusEmoji,
      isOnline: isOnline ?? this.isOnline,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      joinedAt: joinedAt ?? this.joinedAt,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      socialLinks: socialLinks ?? this.socialLinks,
      showFollows: showFollows ?? this.showFollows,
      globalRole: globalRole ?? this.globalRole,
      communityRole: communityRole ?? this.communityRole,
      isBanned: isBanned ?? this.isBanned,
      chatBubbleStyle: chatBubbleStyle ?? this.chatBubbleStyle,
      ownedBubbleStyles: ownedBubbleStyles ?? this.ownedBubbleStyles,
      wallPrivacy: wallPrivacy ?? this.wallPrivacy,
      chatInvitePrivacy: chatInvitePrivacy ?? this.chatInvitePrivacy,
      isBot: isBot ?? this.isBot,
      notifyMessages: notifyMessages ?? this.notifyMessages,
      notifyLikes: notifyLikes ?? this.notifyLikes,
      notifyFollowers: notifyFollowers ?? this.notifyFollowers,
      notifyMentions: notifyMentions ?? this.notifyMentions,
      showReadReceipts: showReadReceipts ?? this.showReadReceipts,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      bannerAlignmentY: bannerAlignmentY ?? this.bannerAlignmentY,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      birthday: birthday ?? this.birthday,
    );
  }

  factory UserProfile.fromCommunityMember(CommunityMember member) {
    return UserProfile(
      id: member.userId,
      username: member.userId, // Default to ID if username not available
      displayName: member.displayName ?? 'Usuario',
      avatarUrl: member.avatarUrl ?? '',
      email: null,
      bannerUrl: member.bannerUrl ?? '',
      backgroundUrl: member.backgroundUrl ?? '',
      bio: member.bio ?? '',
      reputation: member.reputation,
      level: member.level,
      titles: member.titles,
      followers: 0,
      following: 0,
      checkIns: member.checkInCount,
      lastCheckIn: null,
      checkInStreak: 0,
      avatarFrameUrl: member.avatarFrameUrl, // NEW: Map from member profile
      bannerAlignmentY: member.bannerAlignmentY,

      ownedFrames: const [],
      coins: 0,
      status: member.status,
      statusEmoji: member.statusEmoji,
      isOnline: false,
      showOnlineStatus: member.showOnlineStatus,
      socialLinks: const [], 
      showFollows: member.showFollows,
      globalRole: 'user',
      wallPrivacy: 'everyone',
      chatInvitePrivacy: 'everyone',
      isBot: member.isBot,
    );
  }

  factory UserProfile.fromFirebase(User firebaseUser) {
    return UserProfile(
      id: firebaseUser.uid,
      username: firebaseUser.email?.split('@')[0] ?? 'usuario',
      displayName: firebaseUser.displayName ?? 'Usuario de Wumble',
      avatarUrl: firebaseUser.photoURL ?? '',
      email: firebaseUser.email,
      bannerUrl: '', 
      backgroundUrl: '', 
      bio: '¡Hola! Soy nuevo en la comunidad. ✨',
      reputation: 0,
      level: 1,
      titles: const [CommunityLabel(text: 'Nuevo')],
      followers: 0,
      following: 0,
      checkIns: 1,
      lastCheckIn: DateTime.now(),
      checkInStreak: 1,
      avatarFrameUrl: null,
      ownedFrames: const [],
      coins: 0,
      status: null,
      statusEmoji: null,
      isOnline: false,
      isProfileComplete: false,
      joinedAt: DateTime.now(),
      socialLinks: const [],
      showFollows: true,
      globalRole: 'user',
      wallPrivacy: 'everyone',
      chatInvitePrivacy: 'everyone',
      isBot: false,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, String id) {
    return UserProfile(
      id: id,
      username: data['username'] ?? 'usuario',
      displayName: data['displayName'] ?? 'Usuario de Wumble',
      avatarUrl: data['avatarUrl'] ?? '',
      email: data['email'],
      bannerUrl: data['bannerUrl'] ?? '',
      backgroundUrl: data['backgroundUrl'] ?? '',
      bio: data['bio'] ?? '',
      reputation: (data['reputation'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      titles: (data['titles'] as List<dynamic>?)?.map((t) => CommunityLabel.fromDynamic(t)).toList() ?? [],
      followers: (data['followers'] as num?)?.toInt() ?? 0,
      following: (data['following'] as num?)?.toInt() ?? 0,
      checkIns: (data['checkIns'] as num?)?.toInt() ?? 0,
      lastCheckIn: (data['lastCheckIn'] as Timestamp?)?.toDate(),
      checkInStreak: (data['checkInStreak'] as num?)?.toInt() ?? 0,
      avatarFrameUrl: data['avatarFrameUrl'],
      bannerAlignmentY: (data['bannerAlignmentY'] as num?)?.toDouble() ?? 0.0,
      ownedFrames: List<String>.from(data['ownedFrames'] ?? []),
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      status: data['status'],
      statusEmoji: data['statusEmoji'],
      isOnline: data['isOnline'] ?? false,
      isProfileComplete: data['isProfileComplete'] ?? false,
      joinedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      themeColorValue: data['themeColorValue'],
      socialLinks: List<String>.from(data['socialLinks'] ?? []),
      showFollows: data['showFollows'] ?? true,
      globalRole: data['globalRole'] ?? 'user',
      isBanned: data['isBanned'] ?? false,
      chatBubbleStyle: data['chatBubbleStyle'] != null ? ChatBubbleStyle.fromMap(data['chatBubbleStyle']) : null,
      ownedBubbleStyles: (data['ownedBubbleStyles'] as List<dynamic>?)
              ?.map((s) => ChatBubbleStyle.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      wallPrivacy: data['wallPrivacy'] ?? 'everyone',
      chatInvitePrivacy: data['chatInvitePrivacy'] ?? 'everyone',
      isBot: data['isBot'] ?? false,
      notifyMessages: data['notifyMessages'] ?? true,
      notifyLikes: data['notifyLikes'] ?? true,
      notifyFollowers: data['notifyFollowers'] ?? true,
      notifyMentions: data['notifyMentions'] ?? true,
      showReadReceipts: data['showReadReceipts'] ?? true,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      blockedUserIds: List<String>.from(data['blockedUserIds'] ?? []),
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
    );
  }
}

class WallReply {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String? senderAvatarFrame; // NEW
  final String text;
  final DateTime createdAt;

  WallReply({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.senderAvatarFrame, // NEW
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderAvatarFrame': senderAvatarFrame, // NEW
      'text': text,
      'createdAt': createdAt.toUtc(),
    };
  }

  factory WallReply.fromFirestore(Map<String, dynamic> data) {
    return WallReply(
      id: data['id'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Usuario',
      senderAvatar: data['senderAvatar'] ?? '',
      senderAvatarFrame: data['senderAvatarFrame'], // NEW
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class WallMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String? senderAvatarFrame; // NEW
  final String text;
  final String? imageUrl;
  final String? gifUrl;
  final String? stickerId;
  final DateTime createdAt;
  final List<String> likes; // User IDs
  final List<WallReply> replies;
  final String? communityId;

  WallMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.senderAvatarFrame, // NEW
    required this.text,
    this.imageUrl,
    this.gifUrl,
    this.stickerId,
    required this.createdAt,
    this.likes = const [],
    this.replies = const [],
    this.communityId,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderAvatarFrame': senderAvatarFrame, // NEW
      'text': text,
      'imageUrl': imageUrl,
      'gifUrl': gifUrl,
      'stickerId': stickerId,
      'createdAt': createdAt.toUtc(),
      'likes': likes,
      'replies': replies.map((r) => r.toFirestore()).toList(),
      'communityId': communityId,
    };
  }

  factory WallMessage.fromFirestore(String id, Map<String, dynamic> data) {
    return WallMessage(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Usuario',
      senderAvatar: data['senderAvatar'] ?? '',
      senderAvatarFrame: data['senderAvatarFrame'], // NEW
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      gifUrl: data['gifUrl'],
      stickerId: data['stickerId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
      replies: (data['replies'] as List<dynamic>?)
              ?.map((r) => WallReply.fromFirestore(r as Map<String, dynamic>))
              .toList() ??
          [],
      communityId: data['communityId'],
    );
  }
}

final UserProfile mockCurrentUser = const UserProfile(
  id: 'current_user',
  username: 'usuario_demo',
  displayName: 'Usuario Demo',
  avatarUrl: '', 
  bannerUrl: '', 
  backgroundUrl: '',
  bio: 'Perfil de demostración.',
  reputation: 0,
  level: 1,
  titles: [],
  followers: 0,
  following: 0,
  checkIns: 0,
  status: null,
  statusEmoji: null,
  isOnline: false,
  isBanned: false,
);

class PaginatedUsers {
  final List<UserProfile> users;
  final dynamic lastDoc;
  final bool hasMore;

  PaginatedUsers({
    required this.users,
    this.lastDoc,
    required this.hasMore,
  });
}
