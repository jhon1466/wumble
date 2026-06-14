import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../../injection_container.dart';
import '../../../chat/domain/chat_model.dart';
import '../../../chat/domain/chat_repository.dart';
import '../../../chat/presentation/chat_detail_screen.dart';

class PublicChatsWidget extends StatelessWidget {
  final String communityId;

  PublicChatsWidget({super.key, required this.communityId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRoom>>(
      stream: sl<ChatRepository>().getPublicChats(communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
        }
        
        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white24),
                SizedBox(height: 10),
                Text(tr('No hay chats públicos activos'), style: TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final chat = chats[index];
            // Since we don't have current user ID easily available here without Bloc, passing empty for 'otherUser' logic or
            // adapting ChatDetailScreen to handle group chats better.
            // For now, assume simple navigation.
            
            return InkWell(
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      chatRoomId: chat.id,
                      otherUserId: 'public', // Placeholder
                      otherUserName: chat.participantNames.values.join(', '), 
                      otherUserAvatar: '',
                      communityId: communityId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    // Avatar/Icon (Placeholder or generated from participants)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(25),
                        image: chat.backgroundImageUrl != null 
                          ? DecorationImage(image: NetworkImage(chat.backgroundImageUrl!), fit: BoxFit.cover)
                          : null,
                      ),
                       child: chat.backgroundImageUrl == null 
                          ? const Icon(Icons.forum, color: Colors.white) 
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat.title ?? 'Chat Público',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (chat.description != null && chat.description!.isNotEmpty) 
                              ? chat.description! 
                              : '¡Únete a la conversación!',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        const Icon(Icons.people_outline, color: Colors.white54, size: 16),
                        Text(
                          '${chat.participants.length}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
