import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../chat_detail_screen.dart';
import '../../domain/chat_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme.dart';
import '../../../community/presentation/bloc/community_context_bloc.dart';
import '../../../community/presentation/pages/community_info_screen.dart';
class ChatRoomCard extends StatelessWidget {
  final ChatRoom chat;
  final String currentUserId;
  final Color themeColor;
  final bool showDescription;

  const ChatRoomCard({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.themeColor,
    this.showDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOneToOne = chat.privateChatKey != null;
    final title = isOneToOne ? chat.getOtherUserName(currentUserId) : (chat.title ?? 'Sin título');
    final avatarUrl = isOneToOne ? chat.getOtherUserAvatar(currentUserId) : (chat.imageUrl ?? '');
    
    // Determine banner: Use chat banner, otherwise community-like gradient
    final bannerUrl = chat.bannerUrl;
    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;

    return BlocBuilder<CommunityContextBloc, CommunityContextState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  chatRoomId: chat.id,
                  otherUserName: title,
                  otherUserAvatar: avatarUrl,
                  communityId: chat.communityId,
                ),
              ),
            );
          },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 128, // Slighly larger than previous 120
        decoration: BoxDecoration(
          color: hasBanner ? Wumbleheme.surfaceColor.withOpacity(0.3) : const Color(0xFF1E1E20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 1. Immersive Banner Background
            if (hasBanner)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                  errorWidget: (context, url, error) => Container(color: themeColor.withOpacity(0.1)),
                ),
              ),
            
            // 2. Glass Overlay / Darkening
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: hasBanner 
                      ? [
                          Colors.black.withOpacity(0.85),
                          Colors.black.withOpacity(0.4),
                        ]
                      : [
                          const Color(0xFF1E1E20),
                          const Color(0xFF161618),
                        ],
                  ),
                ),
              ),
            ),

            if (hasBanner)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(color: Colors.transparent),
                ),
              ),

            // 3. Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Icon / Avatar
                  // Icon / Avatar with Unread Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Hero(
                        tag: 'chat_icon_${chat.id}',
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Icon(Icons.groups_rounded, color: Colors.white24, size: 30),
                                  )
                                : Icon(isOneToOne ? Icons.person_rounded : Icons.groups_rounded, 
                                     color: themeColor.withOpacity(0.5), size: 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Texts
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showDescription 
                            ? (chat.description ?? 'Sin descripción')
                            : (chat.lastMessage.isEmpty ? '¡Saluda a los demás!' : chat.lastMessage),
                          maxLines: showDescription ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Interaction Row
                        Row(
                          children: [
                            _InfoPill(
                              icon: Icons.people_outline_rounded,
                              label: '${chat.participants.length}',
                              color: themeColor,
                            ),
                            const SizedBox(width: 8),
                            if (chat.isClosed)
                             _InfoPill(
                                icon: Icons.lock_outline_rounded,
                                label: tr('Cerrado'),
                                color: Colors.redAccent,
                              ),
                            const Spacer(),
                            Text(
                              _formatTime(chat.lastMessageTime),
                              style: const TextStyle(color: Colors.white24, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 4. Compact Notification Indicator (Right Side)
                  if (chat.unreadCounts[currentUserId] != null && chat.unreadCounts[currentUserId]! > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          '${chat.unreadCounts[currentUserId]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }


  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(time);
    return DateFormat('MMM d').format(time);
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
