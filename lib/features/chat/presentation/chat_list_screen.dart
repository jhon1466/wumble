import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_detail_screen.dart';
import 'chat_bloc.dart';
import '../domain/chat_repository.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/user_avatar.dart';

import 'widgets/chat_room_card.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tus chats')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Chats'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state is ChatLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ChatError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text('Error: ${state.message}', style: const TextStyle(color: Wumbleheme.textSecondary)),
                  ],
                ),
              );
            }

            if (state is ChatRoomsLoaded) {
              if (state.rooms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes chats aún',
                        style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Visita el perfil de alguien y toca "CHAT"',
                        style: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swipe_left, size: 16, color: Wumbleheme.primaryColor.withOpacity(0.5)),
                        const SizedBox(width: 8),
                        Text(
                          'Desliza hacia la izquierda para eliminar',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 120),
                      itemCount: state.rooms.length,
                      itemBuilder: (context, index) {
                        final room = state.rooms[index];
                        
                        return Dismissible(
                    key: Key(room.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      final isPublic = room.isPublic;
                      final isOneToOne = room.privateChatKey != null;
                      final title = isOneToOne ? room.getOtherUserName(currentUser.uid) : (room.title ?? 'Sin título');
                      
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Wumbleheme.surfaceColor,
                          title: Text(isPublic ? '¿Abandonar chat?' : '¿Borrar chat?', style: const TextStyle(color: Colors.white)),
                          content: Text(
                            isPublic 
                              ? '¿Estás seguro de que quieres salir de "${room.title}"?' 
                              : '¿Estás seguro de que quieres eliminar tu conversación con $title? Esta acción no se puede deshacer.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('CANCELAR', style: TextStyle(color: Colors.white38)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(isPublic ? 'SALIR' : 'BORRAR', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      if (room.isPublic) {
                        context.read<ChatBloc>().add(LeaveChatEvent(
                          chatRoomId: room.id, 
                          userId: currentUser.uid,
                          username: currentUser.displayName ?? 'Usuario'
                        ));
                      } else {
                        context.read<ChatBloc>().add(DeleteChatRoomEvent(room.id));
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(room.isPublic ? Icons.exit_to_app : Icons.delete_forever, color: Colors.white, size: 28),
                    ),
                    child: ChatRoomCard(
                      chat: room,
                      currentUserId: currentUser.uid,
                      themeColor: Wumbleheme.primaryColor,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }

            return const SizedBox.shrink();
          },
        ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}
