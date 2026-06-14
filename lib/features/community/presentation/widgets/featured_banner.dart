import 'dart:ui';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/community_model.dart';
import '../community_screen.dart';
import '../../../../core/theme.dart';

class FeaturedBanner extends StatelessWidget {
  final List<Community> communities;

  FeaturedBanner({super.key, required this.communities});

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            tr('Comunidades Destacadas'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: communities.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final community = communities[index];
              return _FeaturedCard(community: community);
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Community community;

  const _FeaturedCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityDetailScreen(community: community),
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        margin: const EdgeInsets.only(right: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Banner Image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: community.bannerUrl.isNotEmpty 
                      ? community.bannerUrl 
                      : (community.iconUrl.isNotEmpty ? community.iconUrl : 'https://via.placeholder.com/600x300'),
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: Wumbleheme.surfaceColor,
                    child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white24)),
                  ),
                  placeholder: (context, url) => Container(color: Wumbleheme.surfaceColor),
                ),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Dejamos espacio a la derecha para que el nombre y descripción no choquen con el badge de miembros
                    Padding(
                      padding: const EdgeInsets.only(right: 130), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            community.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Member count badge - Repositioned to bottom right
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_rounded, size: 14, color: community.themeColor),
                      const SizedBox(width: 6),
                      Text(
                        '${community.membersCount} ${tr('miembros')}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Logo Badge
              Positioned(
                top: 20,
                right: 20,
                child: Hero(
                  tag: 'featured_icon_${community.id}',
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                      image: community.iconUrl.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(community.iconUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
