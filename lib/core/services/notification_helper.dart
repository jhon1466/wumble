import 'package:flutter/material.dart';
import '../../features/chat/presentation/chat_detail_screen.dart';
import '../../features/feed/presentation/pages/post_detail_screen.dart';
import '../../features/community/presentation/pages/wiki_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/community/presentation/pages/moderation_center_screen.dart';
import '../../features/community/presentation/community_screen.dart'; // Added
import '../../features/community/domain/community_model.dart'; // Added
import '../../features/community/domain/community_repository.dart';
import '../../features/feed/domain/feed_repository.dart';
import '../../features/community/domain/wiki_repository.dart';
import '../../features/feed/domain/post_model.dart';
import '../../features/community/domain/wiki_model.dart';
import '../../injection_container.dart' as di;
import 'package:cloud_firestore/cloud_firestore.dart'; // Added

class NotificationNavigator {
  static Future<void> navigate(BuildContext context, Map<String, dynamic> data) async {
    final type = data['type'];
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (type == 'chat' || type == 'live' || type == 'message' || type == 'chat_reaction') {
        final roomId = data['roomId'] ?? data['id'];
        final isPublic = data['isPublic'] == 'true' || data['isPublic'] == true;
        if (roomId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                chatRoomId: roomId,
                otherUserName: isPublic ? (data['title'] ?? 'Sala') : 'Cargando...',
                otherUserAvatar: data['senderAvatarUrl'] ?? '',
                otherUserId: isPublic ? '' : (data['senderId'] ?? ''),
                communityId: data['communityId'],
              ),
            ),
          );
        }
      } else if (type == 'post_like' || type == 'post_comment' || type == 'comment_reply' || type == 'comment_like') {
        final postId = data['postId'];
        if (postId != null) {
          _showLoading(context);
          final post = await di.sl<FeedRepository>().getPost(postId);
          if (context.mounted) Navigator.pop(context); // Remove loading
          
          if (post != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
          }
        }
      } else if (type == 'wiki_like' || type == 'wiki_comment' || type == 'wiki_reply') {
        final wikiId = data['wikiId'] ?? data['postId'];
        if (wikiId != null) {
          _showLoading(context);
          final wiki = await di.sl<WikiRepository>().getWiki(wikiId);
          if (context.mounted) Navigator.pop(context); // Remove loading
          
          if (wiki != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WikiDetailScreen(
                  wiki: wiki,
                  themeColor: Colors.blueAccent, 
                ),
              ),
            );
          }
        }
      } else if (type == 'wall' || type == 'follow') {
        final userId = data['userId'] ?? data['followerId'] ?? data['senderId'];
        if (userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
          );
        }
      } else if (type == 'moderation_report' || type == 'join_request') {
        final communityId = data['communityId'];
        if (communityId != null) {
          _showLoading(context);
          final community = await di.sl<CommunityRepository>().getCommunity(communityId);
          if (context.mounted) Navigator.pop(context); // Remove loading
          
          if (community != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ModerationCenterScreen(community: community),
              ),
            );
          }
        }
      } else if (type == 'join_approved') {
        final communityId = data['communityId'];
        if (communityId != null) {
          _showLoading(context);
          final community = await di.sl<CommunityRepository>().getCommunity(communityId);
          if (context.mounted) Navigator.pop(context); // Remove loading
          
          if (community != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(community: community),
              ),
            );
          }
        }
      } else if (type == 'donation') {
        final postId = data['postId'];
        final wikiId = data['wikiId'];
        
        if (postId != null) {
          _showLoading(context);
          final post = await di.sl<FeedRepository>().getPost(postId);
          if (context.mounted) Navigator.pop(context);
          if (post != null && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
          }
        } else if (wikiId != null) {
          _showLoading(context);
          final wiki = await di.sl<WikiRepository>().getWiki(wikiId);
          if (context.mounted) Navigator.pop(context);
          if (wiki != null && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => WikiDetailScreen(wiki: wiki, themeColor: Colors.blueAccent)));
          }
        } else {
          // Fallback to profile
          final senderId = data['senderId'];
          if (senderId != null && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: senderId)));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al abrir contenido: $e')),
        );
      }
    }
  }

  static void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }
}
