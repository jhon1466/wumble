import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wumble/injection_container.dart';
import 'package:wumble/features/feed/domain/feed_repository.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/community/domain/wiki_repository.dart';
import 'package:wumble/features/feed/presentation/pages/post_detail_screen.dart';
import 'package:wumble/features/community/presentation/community_screen.dart';
import 'package:wumble/features/community/presentation/pages/wiki_detail_screen.dart';
import 'package:wumble/features/profile/presentation/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LinkNavigator {
  static void handleUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Detect if it's our internal domain
    if (uri.host == 'wumble.link') {
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        final type = segments[0];
        final id = segments[1];

        _showLoadingOverlay(context);

        try {
          if (type == 'p') {
            // Post
            final post = await sl<FeedRepository>().getPost(id);
            _hideLoading(context);
            if (post != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
              );
            }
          } else if (type == 'c') {
            // Community (id is handle)
            // Search community by handle
            final snapshot = await FirebaseFirestore.instance
                .collection('communities')
                .where('handle', isEqualTo: id)
                .limit(1)
                .get();
            
            _hideLoading(context);
            
            if (snapshot.docs.isNotEmpty) {
              final community = await sl<CommunityRepository>().getCommunity(snapshot.docs.first.id);
              if (community != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CommunityDetailScreen(community: community)),
                );
              }
            }
          } else if (type == 'u') {
            // User Profile
            _hideLoading(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
            );
          } else if (type == 'w') {
            // Wiki
            final wiki = await sl<WikiRepository>().getWiki(id);
            _hideLoading(context);
            if (wiki != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WikiDetailScreen(
                    wiki: wiki,
                    themeColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              );
            }
          } else {
            _hideLoading(context);
            _launchExternal(uri);
          }
        } catch (e) {
          _hideLoading(context);
          _launchExternal(uri);
        }
      } else {
        _launchExternal(uri);
      }
    } else {
      _launchExternal(uri);
    }
  }

  static void _launchExternal(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void _showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  static void _hideLoading(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
