import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/community_model.dart';
import '../community_screen.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils/media_optimizer.dart';

class PremiumCommunityCard extends StatelessWidget {
  final Community community;
  final VoidCallback? onLongPress;

  const PremiumCommunityCard({super.key, required this.community, this.onLongPress});

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bannerHeight = 85.0;
    final iconSize = 56.0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityDetailScreen(community: community),
            ),
          );
        },
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: Wumbleheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner & Overlapping Icon Section
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner Image
                    AspectRatio(
                      aspectRatio: 16 / 7,
                      child: CachedNetworkImage(
                        imageUrl: community.bannerUrl.isNotEmpty 
                            ? MediaOptimizer.banner(community.bannerUrl)
                            : 'https://via.placeholder.com/600x300?text=Banner',
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: community.themeColor.withOpacity(0.2),
                          child: Icon(Icons.panorama_rounded, color: community.themeColor.withOpacity(0.5)),
                        ),
                      ),
                    ),

                    // Icon Overlay
                    Positioned(
                      left: 12,
                      bottom: -iconSize / 3,
                      child: Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: Wumbleheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Wumbleheme.surfaceColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: community.iconUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: MediaOptimizer.optimize(community.iconUrl, width: 200, height: 200),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white10),
                              )
                            : Container(
                                color: community.themeColor.withOpacity(0.3),
                                child: Icon(Icons.group_rounded, color: community.themeColor, size: 24),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Content Section
                Padding(
                  padding: EdgeInsets.fromLTRB(14, (iconSize / 3) + 8, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        community.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Member Count Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_formatNumber(community.membersCount)} miembros',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
