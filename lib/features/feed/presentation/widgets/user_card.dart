import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../profile/domain/user_model.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/user_avatar.dart';

class UserCard extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;

  final String? communityId;
  final double radius;

  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
    this.communityId,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            UserAvatar(
              userId: user.id,
              avatarUrl: user.avatarUrl,
              displayName: user.displayName,
              isOnline: user.isOnline,
              radius: radius,
              communityId: communityId,
              gradient: LinearGradient(
                colors: [
                  Wumbleheme.primaryColor,
                  Wumbleheme.secondaryColor,
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Wumbleheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LV ${user.level}',
                          style: const TextStyle(
                            color: Wumbleheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      color: Wumbleheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (user.bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        user.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Follow Icon/Button
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
