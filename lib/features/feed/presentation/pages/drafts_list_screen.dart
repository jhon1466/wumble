import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:wumble/features/feed/presentation/bloc/create_post_cubit.dart';
import 'package:wumble/features/feed/domain/draft_model.dart';
import 'package:wumble/features/feed/presentation/pages/create_post_screen.dart';
import 'package:wumble/injection_container.dart';

class DraftsListScreen extends StatefulWidget {
  final String communityId;

  const DraftsListScreen({super.key, required this.communityId});

  @override
  State<DraftsListScreen> createState() => _DraftsListScreenState();
}

class _DraftsListScreenState extends State<DraftsListScreen> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Scaffold(body: Center(child: Text('Inicia sesión para ver borradores')));

    return BlocProvider(
      create: (context) => sl<CreatePostCubit>()..loadDrafts(userId),
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E2C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Borradores', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: BlocBuilder<CreatePostCubit, CreatePostState>(
          builder: (context, state) {
            if (state is DraftsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CreatePostFailure) {
              return Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.white)));
            } else if (state is DraftsLoaded) {
              if (state.drafts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notes, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('No tienes borradores guardados', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.drafts.length,
                itemBuilder: (context, index) {
                  final draft = state.drafts[index];
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        draft.title?.isNotEmpty == true ? draft.title! : 'Sin título',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Actualizado: ${DateFormat('dd MMM yyyy, HH:mm').format(draft.updatedAt)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, userId, draft.id),
                      ),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatePostScreen(
                              communityId: widget.communityId,
                              draft: draft,
                            ),
                          ),
                        );
                        if (result == true) {
                          // If published, refresh drafts (though it should be deleted upon publication)
                          if (context.mounted) {
                            context.read<CreatePostCubit>().loadDrafts(userId);
                          }
                        }
                      },
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String userId, String draftId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Eliminar borrador', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que quieres eliminar este borrador?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              context.read<CreatePostCubit>().deleteDraft(userId, draftId);
              Navigator.pop(dialogCtx);
            },
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
