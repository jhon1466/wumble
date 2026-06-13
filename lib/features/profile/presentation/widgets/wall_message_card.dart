import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../injection_container.dart';
import '../../domain/user_model.dart';
import '../../domain/profile_repository.dart';
import '../profile_screen.dart';

class WallMessageCard extends StatefulWidget {
  final String profileOwnerId; // The user whose wall this is
  final WallMessage message;
  final String? communityId;
  final VoidCallback? onReply;

  const WallMessageCard({
    super.key,
    required this.profileOwnerId,
    required this.message,
    this.communityId,
    this.onReply,
  });

  @override
  State<WallMessageCard> createState() => _WallMessageCardState();
}

class _WallMessageCardState extends State<WallMessageCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.message.likes.length;
    _checkStatus();
  }

  void _checkStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLiked = widget.message.likes.contains(user.uid);
        _canDelete = user.uid == widget.message.senderId || user.uid == widget.profileOwnerId;
      });
    }
  }

  void _toggleLike() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount--;
      } else {
        _isLiked = true;
        _likesCount++;
      }
    });

    sl<ProfileRepository>().toggleWallMessageLike(
      widget.profileOwnerId,
      widget.message.id,
      user.uid,
      communityId: widget.communityId,
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_outlined, color: Colors.white70),
              title: const Text('Reportar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte enviado')));
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('¿Eliminar comentario?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción quitará el mensaje del muro permanentemente.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await sl<ProfileRepository>().deleteWallMessage(
                widget.profileOwnerId,
                widget.message.id,
                communityId: widget.communityId,
              );
            }, 
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.secondary;
    final String timeStr = timeago.format(widget.message.createdAt, locale: 'es_short');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Avatar
          UserAvatar(
            userId: widget.message.senderId,
            avatarUrl: widget.message.senderAvatar,
            displayName: widget.message.senderName,
            communityId: widget.communityId,
            avatarFrameUrl: widget.message.senderAvatarFrame,
            radius: 16,
            isClickable: true,
          ),
          const SizedBox(width: 12),
          
          // Right Column: Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name & Time
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                userId: widget.message.senderId,
                                communityId: widget.communityId,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          widget.message.senderName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• $timeStr',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
                      onPressed: _showOptions,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 2),

                // Message Text
                if (widget.message.text.isNotEmpty)
                  Text(
                    widget.message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                  ),

                // Immersive Image Content
                if (widget.message.imageUrl != null && widget.message.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
                        child: CachedNetworkImage(
                          imageUrl: widget.message.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.white10,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, err) => const Icon(Icons.error, color: Colors.white54, size: 20),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Interaction Bar
                Row(
                  children: [
                    _InteractionButton(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.redAccent : Colors.white38,
                      count: _likesCount,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 24),
                    _InteractionButton(
                      icon: Icons.chat_bubble_outline,
                      color: Colors.white38,
                      count: widget.message.replies.length,
                      onTap: widget.onReply ?? () {},
                    ),
                  ],
                ),

                // Replies Section
                if (widget.message.replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.message.replies.map((reply) => _WallReplyItem(
                        reply: reply,
                        communityId: widget.communityId,
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WallReplyItem extends StatelessWidget {
  final WallReply reply;
  final String? communityId;

  const _WallReplyItem({
    required this.reply,
    this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    final String timeStr = timeago.format(reply.createdAt, locale: 'es_short');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: reply.senderId,
            avatarUrl: reply.senderAvatar,
            displayName: reply.senderName,
            communityId: communityId,
            avatarFrameUrl: reply.senderAvatarFrame,
            radius: 12,
            isClickable: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.senderName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.text,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _InteractionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
