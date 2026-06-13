import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../community/domain/community_model.dart';
import '../../../../core/theme.dart';

class CommunityCard extends StatelessWidget {
  final Community community;

  const CommunityCard({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: community.themeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background Image with Gradient Overlay
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: community.bannerUrl.isNotEmpty 
                    ? community.bannerUrl 
                    : (community.iconUrl.isNotEmpty ? community.iconUrl : 'https://via.placeholder.com/300'),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Wumbleheme.surfaceColor),
                errorWidget: (context, url, error) => Container(color: Wumbleheme.surfaceColor),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: community.themeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: community.themeColor, width: 0.5),
                    ),
                    child: Text(
                      '${community.membersCount} Miembros',
                      style: TextStyle(
                        color: community.themeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    community.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    community.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
