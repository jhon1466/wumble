import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils/media_optimizer.dart';
import '../../../community/presentation/bloc/community_context_bloc.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/user_list_bottom_sheet.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/post_model.dart';
import '../../domain/feed_repository.dart';
import '../pages/post_detail_screen.dart';
import '../pages/create_post_screen.dart';
import '../../../profile/domain/user_model.dart';
import '../../../profile/presentation/widgets/donation_modal.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../../core/widgets/linkify_text.dart';
import '../bloc/community_feed_bloc.dart';
import 'integrated_poll_widget.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onTap;

  PostCard({super.key, required this.post, this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isSaved = false;
  late bool _isPinned;
  late bool _isFeatured;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.post.isPinned;
    _isFeatured = widget.post.isFeatured;
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    if (_currentUserId == null) return;
    final saved = await di.sl<FeedRepository>().checkIfSaved(widget.post.id, _currentUserId!);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _togglePin() async {
    final newPinnedStatus = !_isPinned;
    setState(() => _isPinned = newPinnedStatus);

    try {
      await di.sl<FeedRepository>().setPostPinned(widget.post.id, newPinnedStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newPinnedStatus ? 'Publicación fijada (superior)' : 'Publicación desfijada'),
            backgroundColor: Wumbleheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isPinned = !newPinnedStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al cambiar pin'))),
        );
      }
    }
  }

  Future<void> _toggleFeatured() async {
    final newFeaturedStatus = !_isFeatured;
    setState(() => _isFeatured = newFeaturedStatus);

    try {
      await di.sl<FeedRepository>().setPostFeatured(widget.post.id, newFeaturedStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newFeaturedStatus ? 'Publicación destacada en el feed' : 'Publicación quitada de destacados'),
            backgroundColor: Wumbleheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isFeatured = !newFeaturedStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al cambiar destacado'))),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    if (_currentUserId == null) return;
    final repo = di.sl<FeedRepository>();
    try {
      if (_isSaved) {
        await repo.unsavePost(widget.post.id, _currentUserId!);
      } else {
        await repo.savePost(widget.post.id, _currentUserId!);
      }
      if (mounted) {
        setState(() => _isSaved = !_isSaved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isSaved ? 'Guardado en tu perfil' : 'Eliminado de guardados')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Error al procesar'))));
    }
  }

  void _handleShare() {
    final String shareUrl = 'https://wumble.link/p/${widget.post.id}';
    final String shareText = '¡Mira esta publicación en Wumble!\n$shareUrl\n\n${widget.post.title ?? ""}\n${widget.post.content}';
    
    final String imageUrl = widget.post.images.isNotEmpty ? widget.post.images.first : (widget.post.backgroundImageUrl ?? '');
    
    ShareHelper.share(
      context: context,
      text: shareText,
      subject: widget.post.title ?? 'Mira este post en Wumble',
      imageUrl: imageUrl,
    );
  }

  void _showReportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Text(tr('Reportar Publicación'), style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Razón del reporte...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              await di.sl<FeedRepository>().reportPost(widget.post.id, _currentUserId ?? 'anon', controller.text);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Reporte enviado'))));
            },
            child: Text(tr('ENVIAR'), style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Text(tr('¿Eliminar publicación?'), style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await di.sl<FeedRepository>().deletePost(widget.post.id);
              if (mounted) {
                // Notificar al Bloc para recarga reactiva
                try {
                  context.read<CommunityFeedBloc>().add(CommunityFeedPostDeleted(widget.post.id));
                } catch (_) {}
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Publicación eliminada'))));
              }
            },
            child: Text(tr('ELIMINAR'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 365) return '${(difference.inDays / 365).floor()}a';
    if (difference.inDays > 30) return '${(difference.inDays / 30).floor()}mes';
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Ahora';
  }

  String _stripTags(String text) {
    final tagRe = RegExp(r'^\[([^\]]+)\]');
    return text.split('\n').map((line) {
      final m = tagRe.firstMatch(line);
      return m != null ? line.substring(m.group(0)!.length) : line;
    }).join('\n');
  }

  void _showOptions(BuildContext context) {
    final bool isAuthor = _currentUserId == widget.post.authorId;
    
    // Role check for moderator options
    final communityState = context.read<CommunityContextBloc>().state;
    final bool isModerator = communityState.memberProfile?.role == 'leader' || communityState.memberProfile?.role == 'curator';

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
            ListTile(
              leading: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.white70),
              title: Text(_isSaved ? 'Quitar de guardados' : 'Guardar publicación', style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _toggleSave();
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded, color: Colors.white70),
              title: Text(tr('Compartir'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _handleShare();
              },
            ),

            if (isModerator) ...[
              ListTile(
                leading: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.orangeAccent),
                title: Text(_isPinned ? 'Desfijar del encabezado' : 'Fijar en el encabezado', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _togglePin();
                },
              ),
              ListTile(
                leading: Icon(_isFeatured ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.yellowAccent),
                title: Text(_isFeatured ? 'Quitar de destacados (feed)' : 'Destacar en el feed', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFeatured();
                },
              ),
            ],

            if (!isAuthor)
              ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                title: Text(tr('Reportar contenido'), style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
              ),
            if (isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                title: Text(tr('Editar post'), style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(communityId: widget.post.communityId ?? '', existingPost: widget.post)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(tr('Eliminar definitivamente'), style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation();
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgImage = widget.post.backgroundImageUrl ?? (widget.post.images.isNotEmpty ? widget.post.images.first : null);
    final bgColor = widget.post.backgroundColor != null 
        ? Color(int.parse(widget.post.backgroundColor!.replaceFirst('#', '0xFF'))) 
        : const Color(0xFF1E1E1E);

    final String cleanSnippet = _stripTags(widget.post.content).replaceAll('\n', ' ').trim();
    final bool hasTitle = widget.post.title != null && widget.post.title!.trim().isNotEmpty;
    // --- ESTADO (Modo Comentario) ---
    // Si no tiene título y NO tiene una imagen de fondo explícita, es un estado.
    // Ignoramos widget.post.images porque esas deben aparecer debajo del texto en modo estado.
    final bool isStatus = !hasTitle && (widget.post.backgroundImageUrl == null || widget.post.backgroundImageUrl!.isEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                userId: widget.post.authorId,
                avatarUrl: widget.post.authorAvatarUrl,
                displayName: widget.post.authorName,
                communityId: widget.post.communityId,
                avatarFrameUrl: widget.post.authorAvatarFrameUrl,
                radius: 18,
                isClickable: true,
                isAnimated: false, // Prevents lag in feeds
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.post.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${_timeAgo(widget.post.createdAt)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 20),
                onPressed: () => _showOptions(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onTap ?? () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post)));
                    if (result == true && mounted) {
                      try {
                        context.read<CommunityFeedBloc>().add(CommunityFeedPostDeleted(widget.post.id));
                      } catch (_) {}
                    }
                  },
                  child: isStatus 
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cleanSnippet.isNotEmpty)
                              LinkifyText(
                                cleanSnippet,
                                maxLines: 15,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            if (widget.post.images.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: MediaOptimizer.post(widget.post.images.first),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(color: Colors.white10, height: 200),
                                ),
                              ),
                            ],
                            if (widget.post.stickerUrl != null && widget.post.stickerUrl!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              CachedNetworkImage(
                                imageUrl: MediaOptimizer.optimize(widget.post.stickerUrl!, width: 480, height: 480),
                                height: 120,
                                width: 120,
                                fit: BoxFit.contain,
                                placeholder: (context, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                errorWidget: (context, _, __) => const Icon(Icons.broken_image, color: Colors.white24, size: 24),
                              ),
                            ],
                          ],
                        )
                      : Container(
                          height: bgImage != null ? 240 : (hasTitle ? 120 : 100),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            image: bgImage != null
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(MediaOptimizer.banner(bgImage)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: bgImage == null ? Border.all(color: Colors.white10) : null,
                          ),
                          child: Stack(
                            children: [
                              if (bgImage != null)
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  height: 120,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.post.type == 'blog' ? Icons.article_rounded : Icons.image_rounded, 
                                        size: 10, color: Colors.white
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.post.type == 'article' || widget.post.type == 'blog'
                                            ? 'Artículo'
                                            : widget.post.type == 'image'
                                                ? 'Imagen'
                                                : widget.post.type == 'video'
                                                    ? 'Video'
                                                    : widget.post.type == 'link'
                                                        ? 'Enlace'
                                                        : widget.post.type == 'quiz'
                                                            ? 'Quiz'
                                                            : widget.post.type == 'poll'
                                                                ? 'Encuesta'
                                                                : widget.post.type.toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.post.tags.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: widget.post.tags.take(3).map((tag) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tag,
                                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          )).toList(),
                                        ),
                                      ),
                                    if (hasTitle)
                                      Text(
                                        widget.post.title!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    if (hasTitle && cleanSnippet.isNotEmpty) 
                                      const SizedBox(height: 4),
                                      if (cleanSnippet.isNotEmpty)
                                        LinkifyText(
                                          cleanSnippet,
                                          maxLines: hasTitle ? 1 : 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: bgImage != null ? Colors.white70 : Colors.white60, 
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                    if (widget.post.stickerUrl != null && widget.post.stickerUrl!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      CachedNetworkImage(
                                        imageUrl: MediaOptimizer.optimize(widget.post.stickerUrl!, width: 240, height: 240),
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (widget.post.pollOptions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: IntegratedPollWidget(post: widget.post),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        UserListBottomSheet.show(context, title: 'Personas que les gustó', userIds: widget.post.likes, communityId: widget.post.communityId);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_border_rounded, size: 18, color: Colors.white54),
                            const SizedBox(width: 6),
                            Text('${widget.post.likesCount}', style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: widget.onTap ?? () { Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post))); },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white54),
                            const SizedBox(width: 6),
                            Text('${widget.post.commentsCount}', style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.post.authorId != FirebaseAuth.instance.currentUser?.uid)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                             showModalBottomSheet(
                               context: context,
                               backgroundColor: Colors.transparent,
                               isScrollControlled: true,
                               builder: (context) => Padding(
                                 padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                 child: DonationModal(
                                   targetUser: UserProfile(
                                     id: widget.post.authorId,
                                     username: widget.post.authorName,
                                     displayName: widget.post.authorName,
                                     avatarUrl: widget.post.authorAvatarUrl,
                                     bannerUrl: '',
                                     backgroundUrl: '',
                                     bio: '',
                                     reputation: 0,
                                     level: 1,
                                     titles: const [],
                                     followers: 0,
                                     following: 0,
                                     checkIns: 0,
                                     coins: 0,
                                   ),
                                   postId: widget.post.id,
                                   communityId: widget.post.communityId,
                                 ),
                               ),
                             );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.volunteer_activism_rounded, size: 18, color: Colors.pinkAccent),
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: _handleShare,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.ios_share_rounded, size: 18, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Divider(color: Colors.white10, height: 1),
          ),
        ],
      ),
    );
  }
}
