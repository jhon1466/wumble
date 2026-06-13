import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';
import 'package:wumble/features/chat/domain/bubble_pack_model.dart';

abstract class ProfileRepository {
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? displayName,
    String? bio,
    String? avatarPath,
    String? bannerPath,
    String? backgroundPath,
    String? status,
    String? statusEmoji,
    bool? isOnline,
    bool? isProfileComplete,
    String? communityId,
    List<CommunityLabel>? titles,
    int? themeColorValue,
    List<String>? socialLinks,
    bool? showFollows,
    ChatBubbleStyle? chatBubbleStyle,
    String? wallPrivacy,
    String? chatInvitePrivacy,
    bool? isBot,
    DateTime? birthday,
    double? bannerAlignmentY,
    void Function(double progress)? onProgress,
  });

  Future<void> createProfile({required User user, String? username});
  Future<UserProfile?> getProfileByUsername(String username);
  
  Stream<UserProfile> getUserProfile(String userId);
  
  Future<List<UserProfile>> searchUsers(String query);
  
  // Perfiles por Comunidad
  Future<CommunityMember?> getMemberProfile(String communityId, String userId);
  Stream<CommunityMember?> getMemberProfileStream(String communityId, String userId);
  Future<void> updateMemberProfile(CommunityMember member);

  // Sistema de Follow
  Future<void> followUser(String currentUserId, String targetUserId);
  Future<void> unfollowUser(String currentUserId, String targetUserId);
  Stream<bool> isFollowing(String currentUserId, String targetUserId);
  Stream<List<UserProfile>> getFollowers(String userId);
  Stream<List<UserProfile>> getFollowing(String userId);
  Future<PaginatedUsers> getFollowersPaginated(String userId, {int limit = 20, dynamic lastDoc});
  Future<PaginatedUsers> getFollowingPaginated(String userId, {int limit = 20, dynamic lastDoc});

  // Notificaciones
  Future<void> syncFcmToken(String userId, String token);

  // Muro (Wall)
  Future<void> sendWallMessage(String targetUserId, WallMessage message, {String? communityId});
  Future<void> deleteWallMessage(String targetUserId, String messageId, {String? communityId});
  Stream<List<WallMessage>> getWallMessages(String userId, {String? communityId});
  Future<String> uploadWallImage(String userId, String path, {void Function(double progress)? onProgress});
  
  // Interacciones en el Muro
  Future<void> toggleWallMessageLike(String targetUserId, String messageId, String currentUserId, {String? communityId});
  Future<void> addWallMessageReply(String targetUserId, String messageId, WallReply reply, {String? communityId});

  // Bloqueo y Reporte
  Future<void> blockUser(String currentUserId, String targetUserId);
  Future<void> unblockUser(String currentUserId, String targetUserId);
  Stream<List<UserProfile>> getBlockedUsers(String userId);
  Future<void> reportUser({
    required String reporterId,
    required String targetUserId,
    required String reason,
    String? communityId,
  });

  // Settings
  Future<void> updateSettings(String userId, Map<String, dynamic> settings);
  
  Future<void> purchaseBubblePack(String userId, BubblePack pack);
  
  // Workshop
  Future<void> publishWorkshopPack(BubblePack pack);
  Stream<List<BubblePack>> getWorkshopPacks();

  // ──── Economy System ────
  Future<void> updateCoins(String userId, int amount);
  Future<void> donateCoins({
    required String senderId,
    required String receiverId,
    required int amount,
    String? postId,
    String? wikiId,
    String? communityId,
  });

  // Account Management
  Future<void> updateEmail(String newEmail, String password);
  Future<void> updatePassword(String oldPassword, String newPassword);
  Future<void> deleteAccount(String password);

  // ──── Daily Check-in & Frames ────
  Future<void> performCheckIn(String userId);
  Future<void> purchaseFrame(String userId, String frameUrl, int price);
  Future<void> purchasePack(String userId, String packId);
  Future<void> equipFrame(String userId, String? frameUrl);
}
