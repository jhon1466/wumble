import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/features/community/domain/shared_image_model.dart';
import 'package:wumble/features/community/domain/shared_folder_repository.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/injection_container.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'dart:io';

class SharedImageViewer extends StatefulWidget {
  final SharedImage image;
  final String communityId;
  final VoidCallback? onDelete;

  const SharedImageViewer({
    super.key,
    required this.image,
    required this.communityId,
    this.onDelete,
  });

  static void show(BuildContext context, {required SharedImage image, required String communityId, VoidCallback? onDelete}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedImageViewer(
          image: image,
          communityId: communityId,
          onDelete: onDelete,
        ),
      ),
    );
  }

  @override
  State<SharedImageViewer> createState() => _SharedImageViewerState();
}

class _SharedImageViewerState extends State<SharedImageViewer> {
  Future<CommunityMember?>? _authorFuture;
  Future<CommunityMember?>? _currentUserMemberFuture;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _authorFuture = sl<CommunityRepository>().getMemberProfile(widget.communityId, widget.image.authorId);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _currentUserMemberFuture = sl<CommunityRepository>().getMemberProfile(widget.communityId, currentUserId);
    }
  }

  Future<void> _setAsCommunityIcon() async {
    try {
      await sl<CommunityRepository>().updateCommunity(
        widget.communityId,
        {'iconUrl': widget.image.imageUrl},
        null, null, null
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Icono de la comunidad actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar icono: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('¿Eliminar imagen?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await sl<SharedFolderRepository>().deleteImage(
          communityId: widget.communityId,
          imageId: widget.image.id,
          imageUrl: widget.image.imageUrl,
        );
        if (mounted) {
          Navigator.pop(context); // Close viewer
          widget.onDelete?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Imagen eliminada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/shared_${widget.image.id}.jpg';
      await Dio().download(widget.image.imageUrl, path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen guardada en la galería')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showMoreOptions(bool isLeader) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.white),
            title: const Text('Guardar en el dispositivo', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _downloadImage();
            },
          ),
          if (isLeader)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.amber),
              title: const Text('Establecer como icono del Amino', style: TextStyle(color: Colors.amber)),
              onTap: () {
                Navigator.pop(context);
                _setAsCommunityIcon();
              },
            ),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined, color: Colors.white70),
            title: const Text('Reportar imagen', style: TextStyle(color: Colors.white70)),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement report
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canDelete = currentUserId == widget.image.authorId;

    return FutureBuilder<CommunityMember?>(
      future: _currentUserMemberFuture,
      builder: (context, memberSnapshot) {
        final isLeader = memberSnapshot.data?.role == 'leader' || memberSnapshot.data?.role == 'curator';
        
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 80,
            leading: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            actions: [
              if (_isDownloading)
                const Center(child: Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: () => _confirmDelete(context),
                ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onPressed: () => _showMoreOptions(isLeader),
              ),
            ],
          ),
          body: Stack(
            children: [
              Center(
                child: Hero(
                  tag: 'shared_image_${widget.image.id}',
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.image.imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white24)),
                      errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
                    ),
                  ),
                ),
              ),
              // Author Info Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    ),
                  ),
                  child: FutureBuilder<CommunityMember?>(
                    future: _authorFuture,
                    builder: (context, snapshot) {
                      final member = snapshot.data;
                      return Row(
                        children: [
                          UserAvatar(
                            userId: widget.image.authorId,
                            avatarUrl: member?.avatarUrl ?? '',
                            displayName: member?.displayName ?? 'Usuario',
                            radius: 20,
                            communityId: widget.communityId,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member?.displayName ?? 'Cargando...',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                timeagoFormat(widget.image.createdAt),
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  String timeagoFormat(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return 'Hace ${diff.inDays}d';
    if (diff.inHours > 0) return 'Hace ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Hace ${diff.inMinutes}m';
    return 'Recién subido';
  }
}
