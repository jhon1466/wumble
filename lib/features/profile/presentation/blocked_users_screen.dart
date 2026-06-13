import 'package:flutter/material.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';
import 'package:wumble/injection_container.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BlockedUsersScreen extends StatelessWidget {
  final String userId;
  const BlockedUsersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Usuarios Bloqueados', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<UserProfile>>(
        stream: sl<ProfileRepository>().getBlockedUsers(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded, size: 64, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes usuarios bloqueados',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los usuarios que bloquees aparecerán aquí',
                    style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54, size: 22)
                        : null,
                  ),
                  title: Text(
                    user.displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '@${user.username}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _showUnblockDialog(context, user),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: const Text('Desbloquear', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showUnblockDialog(BuildContext context, UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Desbloquear usuario', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Deseas desbloquear a ${user.displayName}? Podrá volver a interactuar contigo.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () {
              sl<ProfileBloc>().add(UnblockUserRequested(
                currentUserId: userId,
                targetUserId: user.id,
              ));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.displayName} ha sido desbloqueado'),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            },
            child: const Text('DESBLOQUEAR', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }
}
