import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';
import 'package:wumble/features/chat/domain/chat_repository.dart';
import 'package:wumble/features/chat/presentation/chat_detail_screen.dart';
import '../bloc/community_context_bloc.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;

import 'package:wumble/features/chat/presentation/widgets/chat_room_card.dart';

class PublicChatListWidget extends StatefulWidget {
  final String communityId;
  final Color themeColor;

  const PublicChatListWidget({
    super.key,
    required this.communityId,
    required this.themeColor,
  });

  @override
  State<PublicChatListWidget> createState() => _PublicChatListWidgetState();
}

class _PublicChatListWidgetState extends State<PublicChatListWidget> with AutomaticKeepAliveClientMixin {
  late Stream<List<ChatRoom>> _chatsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  void _loadChats() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _chatsStream = context.read<ChatRepository>().getPublicChats(widget.communityId, userId: userId);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1E1E2C),
      child: StreamBuilder<List<ChatRoom>>(
        stream: _chatsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final chats = snapshot.data ?? [];
          
          if (chats.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay chats públicos aún.\n¡Sé el primero en crear uno!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: 1000,
            itemCount: chats.length,
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ChatRoomCard(
                chat: chat,
                currentUserId: currentUserId,
                themeColor: widget.themeColor,
                showDescription: true,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatRoom chat) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatRoomId: chat.id,
              otherUserName: chat.title ?? 'Chat Público',
              otherUserAvatar: chat.imageUrl ?? '',
              communityId: chat.communityId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: chat.imageUrl != null && chat.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(chat.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: widget.themeColor.withOpacity(0.2),
              ),
              child: (chat.imageUrl == null || chat.imageUrl!.isEmpty)
                  ? Icon(Icons.groups_rounded, color: widget.themeColor, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title ?? 'Sin título',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.isClosed)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.lock, color: Colors.redAccent, size: 14),
                        ),
                    ],
                  ),
                  if (chat.description != null && chat.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        chat.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 14, color: widget.themeColor),
                      const SizedBox(width: 4),
                      Text(
                        '${chat.participants.length} participantes',
                        style: TextStyle(color: widget.themeColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Spacer(),
                      Text(
                        _formatLastMessageTime(chat.lastMessageTime),
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Trailing
            SizedBox(width: 8),
            BlocBuilder<CommunityContextBloc, CommunityContextState>(
              builder: (context, state) {
                final bool isModerator = state.memberProfile?.role == 'leader' || state.memberProfile?.role == 'curator';
                if (!isModerator) return Icon(Icons.chevron_right_rounded, color: Colors.white24);
                
                return PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Wumbleheme.surfaceColor,
                          title: Text(tr('¿Eliminar sala de chat?'), style: TextStyle(color: Colors.white)),
                          content: Text('Esta acción borrará permanentemente la sala y todos sus mensajes para todos los miembros.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('CANCELAR'))),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(tr('ELIMINAR'), style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await di.sl<ChatRepository>().deleteChatRoom(chat.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Chat eliminado'))));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(tr('Eliminar Chat'), style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(time);
    return DateFormat('MMM d').format(time);
  }
}
