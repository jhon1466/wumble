import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/linkify_text.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../../injection_container.dart';
import '../../domain/wiki_model.dart';
import '../../domain/wiki_repository.dart';
import '../../../feed/presentation/wiki_editor_screen.dart';
import '../pages/wiki_detail_screen.dart';

class WikiCard extends StatefulWidget {
  final WikiPage wiki;
  final VoidCallback? onDeleted;

  const WikiCard({super.key, required this.wiki, this.onDeleted});

  @override
  State<WikiCard> createState() => _WikiCardState();
}

class _WikiCardState extends State<WikiCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isAuthor = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.wiki.likesCount;
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final liked = await sl<WikiRepository>().checkIfLiked(widget.wiki.id, user.uid);
      if (mounted) {
        setState(() {
          _isLiked = liked;
          _isAuthor = user.uid == widget.wiki.authorId;
        });
      }
    }
  }

  void _toggleLike() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount--;
        sl<WikiRepository>().unlikeWiki(widget.wiki.id, user.uid);
      } else {
        _isLiked = true;
        _likesCount++;
        sl<WikiRepository>().likeWiki(widget.wiki.id, user.uid);
      }
    });
  }

  void _handleShare() {
    final String shareUrl = 'https://wumble.link/w/${widget.wiki.id}';
    final String kind = widget.wiki.type == 'oc' ? 'personaje' : 'Wiki';
    final String shareText = '¡Mira este $kind en Wumble!\n$shareUrl\n\n${widget.wiki.title}\n${widget.wiki.content}';
    
    ShareHelper.share(
      context: context,
      text: shareText,
      subject: widget.wiki.title,
      imageUrl: widget.wiki.iconUrl ?? widget.wiki.coverUrl,
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
            ListTile(
              leading: const Icon(Icons.ios_share_rounded, color: Colors.white70),
              title: const Text('Compartir', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _handleShare();
              },
            ),
            if (_isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                title: Text(widget.wiki.type == 'oc' ? 'Editar Personaje' : 'Editar Wiki', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => WikiEditorScreen(
                        communityId: widget.wiki.communityId, 
                        wikiToEdit: widget.wiki
                      )
                    )
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
            ],
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
        title: Text(widget.wiki.type == 'oc' ? '¿Eliminar Personaje?' : '¿Eliminar Wiki?', style: const TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await sl<WikiRepository>().deleteWiki(widget.wiki.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wiki eliminada')));
                widget.onDeleted?.call();
              }
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
    final String timeStr = timeago.format(widget.wiki.createdAt, locale: 'es_short');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                userId: widget.wiki.authorId,
                avatarUrl: widget.wiki.authorAvatarUrl,
                displayName: widget.wiki.authorName,
                communityId: widget.wiki.communityId,
                avatarFrameUrl: widget.wiki.authorAvatarFrameUrl,
                radius: 18,
                isClickable: true,
                isAnimated: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.wiki.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• $timeStr',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 20),
                onPressed: _showOptions,
              ),
            ],
          ),

          // Wiki Content (Indented)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title (+ OC badge for characters)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.wiki.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (widget.wiki.type == 'oc') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF8E2DE2), Color(0xFF6A1B9A)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Immersive Image Card
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WikiDetailScreen(
                          wiki: widget.wiki,
                          themeColor: themeColor,
                        ),
                      ),
                    );
                    if (result == true && mounted) {
                      widget.onDeleted?.call();
                    }
                  },
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Main Image
                        Positioned.fill(
                          child: (widget.wiki.iconUrl ?? widget.wiki.coverUrl) != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.wiki.iconUrl ?? widget.wiki.coverUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.white12),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [themeColor.withOpacity(0.3), Colors.black54],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      widget.wiki.type == 'oc'
                                          ? Icons.face_retouching_natural
                                          : Icons.book_outlined,
                                      color: Colors.white24,
                                      size: 48,
                                    ),
                                  ),
                                ),
                        ),
                        // Glass Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Labels / Rating
                        if (widget.wiki.labels.containsKey('Calificación'))
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.wiki.labels['Calificación']!,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),

                // Snippet (if any)
                if (widget.wiki.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LinkifyText(
                      widget.wiki.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                    ),
                  ),

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
                      count: widget.wiki.commentsCount,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WikiDetailScreen(
                              wiki: widget.wiki,
                              themeColor: themeColor,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white38),
                      onPressed: _handleShare,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
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
          Icon(icon, size: 18, color: color),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
