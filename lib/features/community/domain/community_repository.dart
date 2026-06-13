import 'dart:io';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/chat/domain/bot_framework.dart';
import 'package:wumble/features/moderation/domain/moderation_models.dart';
import 'package:wumble/features/community/domain/navigation_tab_model.dart';

abstract class CommunityRepository {
  Future<Community> createCommunity(Community community, File? icon, File? banner, File? background);
  Future<Community?> getCommunity(String communityId);
  Future<Community?> getCommunityByHandle(String handle);
  Stream<Community?> getCommunityStream(String communityId);
  Future<List<Community>> getCommunities();
  Future<Map<String, dynamic>> getCommunitiesPaginated({String? category, dynamic lastDocument, int limit = 20});
  Future<List<Community>> searchCommunities(String query);
  Future<List<Community>> getCommunitiesByCategory(String category);
  Future<List<Community>> getTrendingCommunities();
  Future<List<Community>> getNewCommunities();
  Future<List<Community>> getFeaturedCommunities();
  Future<List<Community>> getUserCommunities(String userId);
  Future<void> joinCommunity(String communityId, String userId);
  Future<void> joinCommunityWithInvite(String inviteCode, String userId);
  Future<void> leaveCommunity(String communityId, String userId);
  Future<bool> isMember(String communityId, String userId);
  Future<List<CommunityMember>> getCommunityLeaderboard(String communityId, String type); // type: '24h', '7d', 'allTime'
  Future<void> updateMemberPresence(String communityId, String userId);
  Future<void> updateCommunity(String communityId, Map<String, dynamic> data, File? icon, File? banner, File? background);
  Future<List<CommunityMember>> getCommunityMembers(String communityId);
  Future<Map<String, dynamic>> getCommunityMembersPaginated(String communityId, {dynamic lastDocument, int limit = 20});
  Future<List<CommunityMember>> searchCommunityMembers(String communityId, String query);
  Future<void> updateMemberRole(String communityId, String userId, String newRole);
  Future<void> kickMember(String communityId, String userId);
  Future<void> warnMember(String communityId, String userId, String reason, String moderatorId);
  Future<void> banMember(String communityId, String userId, String moderatorId, {DateTime? expiresAt});
  Future<void> unbanMember(String communityId, String userId);
  Future<List<CommunityMember>> getBannedMembers(String communityId);
  Future<void> migrateMemberBanData(String communityId);
  Future<void> updateLevelTitles(String communityId, Map<String, String> titles);
  Future<void> updateMemberProfile(String communityId, String userId, Map<String, dynamic> data, File? avatar);
  Future<void> deleteCommunity(String communityId);
  Future<void> requestJoinCommunity(String communityId, String userId, {String message = ''});
  Future<List<dynamic>> getJoinRequests(String communityId); 
  Future<void> approveJoinRequest(String communityId, String userId);
  Future<void> denyJoinRequest(String communityId, String userId);
  Future<bool> hasPendingRequest(String communityId, String userId);
  Future<void> addReputation(String communityId, String userId, int amount);
  Future<void> updateMemberTitles(String communityId, String userId, List<dynamic> titles);
  Future<int> checkIn(String communityId, String userId);
  Future<CommunityMember?> getMemberProfile(String communityId, String userId);
  Future<void> toggleCommunityNotifications(String communityId, String userId, bool mute);
  
  // Sanctions history
  Stream<List<Sanction>> getMemberSanctions(String communityId, String userId);

  // ──── Bot Management ────
  Stream<List<BotConfig>> getCommunityBots(String communityId);
  Future<List<BotConfig>> getCommunityBotsFuture(String communityId);
  Future<void> createBot(String communityId, BotConfig bot);
  Future<void> updateBot(String communityId, BotConfig bot);
  Future<void> deleteBot(String communityId, String botId);
  Future<void> updateNavigationTabs(String communityId, List<CommunityNavigationTab> tabs);
}
