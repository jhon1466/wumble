import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'package:wumble/core/services/storage_service.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/community/domain/wiki_repository.dart';
import 'package:wumble/features/community/domain/wiki_model.dart';
import 'package:wumble/features/community/domain/wiki_comment_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/community/presentation/pages/community_info_screen.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/widgets/user_badge_widget.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/core/widgets/user_list_bottom_sheet.dart';
import 'package:wumble/features/chat/presentation/widgets/sticker_selector.dart';
import 'package:wumble/features/chat/presentation/image_viewer_screen.dart';
import 'package:wumble/core/utils/media_optimizer.dart';

import 'package:wumble/features/feed/presentation/wiki_editor_screen.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/profile/presentation/profile_screen.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/presentation/widgets/member_mini_profile.dart';
import 'package:wumble/features/profile/presentation/widgets/donation_modal.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:wumble/core/widgets/linkify_text.dart';
import 'package:wumble/core/utils/link_navigator.dart';

class WikiDetailScreen extends StatefulWidget {
  final WikiPage wiki;
  final Color themeColor;

  const WikiDetailScreen({
    super.key,
    required this.wiki,
    required this.themeColor,
  });

  @override
  State<WikiDetailScreen> createState() => _WikiDetailScreenState();
}

class _WikiDetailScreenState extends State<WikiDetailScreen> {
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLoadingLike = false;
  String? _authorName;
  String? _authorAvatarUrl;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _isLiked = false;
    _likesCount = widget.wiki.likesCount;
    _commentsCount = widget.wiki.commentsCount;
    _checkLikeStatus();
    _fetchAuthorProfile();
    _fetchWikiData();
  }

  Future<void> _fetchWikiData() async {
    try {
      debugPrint('WikiDetailScreen: Obteniendo datos actualizados de Wiki ${widget.wiki.id}...');
      final wiki = await di.sl<WikiRepository>().getWiki(widget.wiki.id);
      debugPrint('WikiDetailScreen: Datos recibidos -> Likes: ${wiki.likesCount}, Comments: ${wiki.commentsCount}');
      if (mounted) {
        setState(() {
          _likesCount = wiki.likesCount;
          _commentsCount = wiki.commentsCount;
        });
      }
    } catch (e) {
      debugPrint('WikiDetailScreen: Error en _fetchWikiData: $e');
    }
  }

  Future<void> _fetchAuthorProfile() async {
    try {
      final member = await di.sl<ProfileRepository>().getMemberProfile(widget.wiki.communityId, widget.wiki.authorId);
      if (member != null) {
        if (mounted) {
          setState(() {
            _authorName = member.displayName ?? 'Usuario';
            _authorAvatarUrl = member.avatarUrl;
          });
        }
      } else {
        final global = await di.sl<ProfileRepository>().getUserProfile(widget.wiki.authorId).first;
        if (mounted) {
          setState(() {
            _authorName = global.displayName;
            _authorAvatarUrl = global.avatarUrl;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _authorName = 'Usuario';
        });
      }
    }
  }

  Future<void> _checkLikeStatus() async {
    if (_currentUserId == null) return;
    final liked = await di.sl<WikiRepository>().checkIfLiked(widget.wiki.id, _currentUserId!);
    if (mounted) {
      setState(() {
        _isLiked = liked;
      });
    }
  }

  void _showJoinPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¡Únete a la comunidad!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Para interactuar con esta wiki, dar corazón o donar, necesitas ser miembro de esta comunidad.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final community = await di.sl<CommunityRepository>().getCommunity(widget.wiki.communityId);
                if (community != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityInfoScreen(community: community),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error fetching community (wiki prompt): $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Wumbleheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('UNIRSE AHORA'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_currentUserId == null || _isLoadingLike) return;

    // Check membership
    final memberProfile = context.read<CommunityContextBloc>().state.memberProfile;
    if (memberProfile == null) {
      _showJoinPrompt();
      return;
    }

    setState(() => _isLoadingLike = true);
    
    try {
      if (_isLiked) {
        await di.sl<WikiRepository>().unlikeWiki(widget.wiki.id, _currentUserId!);
        setState(() {
          _isLiked = false;
          _likesCount = (_likesCount > 0) ? _likesCount - 1 : 0;
        });
      } else {
        await di.sl<WikiRepository>().likeWiki(widget.wiki.id, _currentUserId!);
        setState(() {
          _isLiked = true;
          _likesCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingLike = false);
    }
  }

  Future<void> _deleteWiki() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.wiki.type == 'oc' ? 'Borrar Personaje' : 'Borrar Wiki'),
        content: Text(widget.wiki.type == 'oc'
            ? '¿Estás seguro de que quieres borrar este personaje? Esta acción no se puede deshacer.'
            : '¿Estás seguro de que quieres borrar esta Wiki? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await di.sl<WikiRepository>().deleteWiki(widget.wiki.id);
        if (mounted) {
          Navigator.pop(context, true); // Close detail with success result
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.wiki.type == 'oc' ? 'Personaje borrado' : 'Wiki borrada')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al borrar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header with Cover and Icon
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Wumbleheme.backgroundColor,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              BlocBuilder<CommunityContextBloc, CommunityContextState>(
                builder: (context, state) {
                  final String? userId = FirebaseAuth.instance.currentUser?.uid;
                  final bool isAuthor = userId != null && userId == widget.wiki.authorId;
                  final bool isModerator = state.memberProfile?.role == 'leader' || state.memberProfile?.role == 'curator';
                  
                  if (!isAuthor && !isModerator) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WikiEditorScreen(
                                communityId: widget.wiki.communityId,
                                wikiToEdit: widget.wiki,
                              ),
                            ),
                          );
                          if (updated == true && mounted) {
                            // Refrescar si es necesario
                          }
                        } else if (value == 'delete') {
                          _deleteWiki();
                        }
                      },
                      itemBuilder: (context) => [
                        if (isAuthor)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                SizedBox(width: 12),
                                Text('Editar', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              SizedBox(width: 12),
                              Text('Borrar', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                      color: Wumbleheme.surfaceColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover Image
                  if (widget.wiki.coverUrl != null && widget.wiki.coverUrl!.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewerScreen(imageUrl: widget.wiki.coverUrl!),
                        ),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: widget.wiki.coverUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.themeColor.withOpacity(0.3),
                            widget.themeColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Wumbleheme.backgroundColor,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // Wiki Icon and Title in Header
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Wiki Icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Wumbleheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: widget.themeColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: widget.wiki.iconUrl != null && widget.wiki.iconUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.wiki.iconUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(widget.wiki.type == 'oc' ? Icons.face_retouching_natural : Icons.menu_book_rounded, color: widget.themeColor, size: 40),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.wiki.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 10.0,
                                        color: Colors.black,
                                        offset: Offset(2.0, 2.0),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.wiki.isApproved)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'CURADO',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interaction Bar
                  Row(
                    children: [
                      _interactionItem(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        label: '$_likesCount',
                        color: _isLiked ? Colors.red : Colors.white70,
                        onTap: _toggleLike,
                      ),
                      const SizedBox(width: 20),
                      _interactionItem(
                        icon: Icons.chat_bubble_outline,
                        label: '$_commentsCount',
                        color: Colors.white70,
                        onTap: _showCommentsSheet,
                      ),
                      if (widget.wiki.authorId != _currentUserId) ...[
                        const SizedBox(width: 20),
                        _interactionItem(
                          icon: Icons.volunteer_activism_rounded,
                          label: 'Donar',
                          color: Colors.pinkAccent,
                          onTap: () {
                             if (context.read<CommunityContextBloc>().state.memberProfile == null) {
                                _showJoinPrompt();
                                return;
                             }
                             showModalBottomSheet(
                               context: context,
                               backgroundColor: Colors.transparent,
                               isScrollControlled: true,
                               builder: (context) => Padding(
                                 padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                 child: DonationModal(
                                   targetUser: UserProfile(
                                     id: widget.wiki.authorId,
                                     username: _authorName ?? 'Autor',
                                     displayName: _authorName ?? 'Autor',
                                     avatarUrl: _authorAvatarUrl ?? '',
                                     bannerUrl: '',
                                     backgroundUrl: '',
                                     bio: '',
                                     reputation: 0,
                                     level: 1,
                                     titles: [],
                                     followers: 0,
                                     following: 0,
                                     checkIns: 0,
                                   ),
                                   wikiId: widget.wiki.id,
                                   communityId: widget.wiki.communityId,
                                 ),
                               ),
                             );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Author Section
                  _buildAuthorSection(),
                  const SizedBox(height: 24),

                  // Info Labels (Properties)
                  if (widget.wiki.labels.isNotEmpty) ...[
                    const Text(
                      'Información',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Wumbleheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: widget.wiki.labels.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: const TextStyle(color: Wumbleheme.textSecondary, fontSize: 13),
                              ),
                              Text(
                                entry.value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // About Content
                  const Text(
                    'Sobre',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Wumbleheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (widget.wiki.blocks.isNotEmpty)
                    ...widget.wiki.blocks.map((block) {
                      if (block['type'] == 'text') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildRichText(block['value'] ?? ''),
                        );
                      } else if (block['type'] == 'image') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImageViewerScreen(imageUrl: block['value'] ?? ''),
                                ),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: block['value'] ?? '',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    })
                  else
                    LinkifyText(
                      widget.wiki.content.isEmpty ? 'Sin descripción.' : widget.wiki.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.6,
                      ),
                    ),
                  
                  const SizedBox(height: 80), // Space for bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorSection() {
    if (_authorName == null) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return _authorCard(_authorName!, _authorAvatarUrl ?? '');
  }

  Widget _authorCard(String name, String avatar) {
    return InkWell(
      onTap: () async {
        final profileRepo = di.sl<ProfileRepository>();
        final member = await profileRepo.getMemberProfile(widget.wiki.communityId, widget.wiki.authorId);
        
        if (context.mounted) {
          final user = member != null 
              ? UserProfile.fromCommunityMember(member)
              : await profileRepo.getUserProfile(widget.wiki.authorId).first;
              
          if (context.mounted) {
            MemberMiniProfile.show(
              context,
              user: user,
              member: member,
              communityId: widget.wiki.communityId,
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            UserAvatar(
              userId: widget.wiki.authorId,
              avatarUrl: avatar,
              displayName: name,
              radius: 20,
              communityId: widget.wiki.communityId,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Autor',
                    style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hardcoded or fetched level if available in CommunityMember
                      const UserBadgeWidget(level: 1, showTitles: false),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WikiCommentsSheet(
        wiki: widget.wiki,
        onCommentAdded: () {
          setState(() {
            _commentsCount++;
          });
        },
        onCommentDeleted: () {
          setState(() {
            _commentsCount = (_commentsCount > 0) ? _commentsCount - 1 : 0;
          });
        },
      ),
    );
  }

  Widget _interactionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(String raw) {
    final tagRe   = RegExp(r'^\[([^\]]+)\]');
    final sizeRe  = RegExp(r'T=(\d+(?:\.\d+)?)');
    final colorRe = RegExp(r'#=([A-Fa-f0-9]{6})');
    final bgRe    = RegExp(r'G=([A-Fa-f0-9]{6})');
    final fontRe  = RegExp(r'K=([a-zA-Z0-9_-]+)');

    final lineWidgets = raw.split('\n').map<Widget>((line) {
      final m = tagRe.firstMatch(line);
      if (m == null) {
        return LinkifyText(
          line, 
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)
        );
      }
      final tags    = m.group(1)!;
      final content = line.substring(m.group(0)!.length);

      TextAlign align = TextAlign.start;
      if (tags.contains('C')) align = TextAlign.center;
      else if (tags.contains('R')) align = TextAlign.right;
      else if (tags.contains('J')) align = TextAlign.justify;

      double fontSize = tags.contains('M') ? 26 : 16;
      final sm = sizeRe.firstMatch(tags);
      if (sm != null) fontSize = double.tryParse(sm.group(1)!) ?? fontSize;

      Color color = Colors.white;
      final cm = colorRe.firstMatch(tags);
      if (cm != null) color = Color(int.parse('FF${cm.group(1)!.toUpperCase()}', radix: 16));

      Color? bg;
      final bm = bgRe.firstMatch(tags);
      if (bm != null) bg = Color(int.parse('FF${bm.group(1)!.toUpperCase()}', radix: 16));

      String? family;
      final fm = fontRe.firstMatch(tags);
      if (fm != null) {
        final f = fm.group(1)!.toLowerCase();
        if (f == 'serif' || f == 'monospace') family = f;
      }

      final decs = <TextDecoration>[];
      if (tags.contains('U')) decs.add(TextDecoration.underline);
      if (tags.contains('S')) decs.add(TextDecoration.lineThrough);

      return SizedBox(
        width: double.infinity,
        child: LinkifyText(
          content,
          textAlign: align,
          style: TextStyle(
            fontWeight:      tags.contains('B') ? FontWeight.bold   : FontWeight.normal,
            fontStyle:       tags.contains('I') ? FontStyle.italic  : FontStyle.normal,
            decoration:      decs.isNotEmpty ? TextDecoration.combine(decs) : null,
            fontSize:        fontSize,
            color:           color,
            backgroundColor: bg,
            fontFamily:      family,
            height:          1.5,
          ),
        ),
      );
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lineWidgets);
  }
}

class _WikiCommentsSheet extends StatefulWidget {
  final WikiPage wiki;
  final VoidCallback? onCommentAdded;
  final VoidCallback? onCommentDeleted;

  const _WikiCommentsSheet({
    required this.wiki, 
    this.onCommentAdded, 
    this.onCommentDeleted
  });

  @override
  State<_WikiCommentsSheet> createState() => _WikiCommentsSheetState();
}

class _WikiCommentsSheetState extends State<_WikiCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<WikiComment> _comments = [];
  bool _isLoading = true;
  bool _showStickers = false;

  bool _isEditing = false;
  String? _editingCommentId;
  WikiComment? _replyingTo;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _fetchCurrentUserProfile();
  }

  String? _currentUserAminoName;
  String? _currentUserAminoAvatar;
  CommunityMember? _currentMemberProfile;

  Future<void> _fetchCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // 1. Siempre obtener perfil global como base
      final globalProfile = await di.sl<ProfileRepository>().getUserProfile(user.uid).first;
      if (mounted) {
        setState(() {
          _currentUserAminoName = globalProfile.displayName;
          _currentUserAminoAvatar = globalProfile.avatarUrl;
        });
      }

      // 2. Si hay comunidad, el de miembro tiene prioridad (AISLAMIENTO)
      final member = await di.sl<ProfileRepository>().getMemberProfile(widget.wiki.communityId, user.uid);
      if (member != null && mounted) {
        setState(() {
          _currentUserAminoName = member.displayName ?? _currentUserAminoName;
          _currentUserAminoAvatar = member.avatarUrl ?? _currentUserAminoAvatar;
          _currentMemberProfile = member;
        });
      }
    } catch (e) {
      debugPrint('Error fetchCurrentUserProfile (Wiki): $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await di.sl<WikiRepository>().getWikiComments(widget.wiki.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await di.sl<WikiRepository>().deleteWikiComment(widget.wiki.id, commentId);
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == commentId);
        });
        widget.onCommentDeleted?.call();
        _loadComments();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar: $e')));
    }
  }

  void _startEditing(WikiComment comment) {
    setState(() {
      _isEditing = true;
      _editingCommentId = comment.id;
      _commentController.text = comment.content;
    });
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _currentMemberProfile == null) return;

    if (_isEditing && _editingCommentId != null) {
      try {
        final originalComment = _comments.firstWhere((c) => c.id == _editingCommentId);
        final updatedComment = originalComment.copyWith(content: text);
        await di.sl<WikiRepository>().updateWikiComment(widget.wiki.id, updatedComment);
        if (mounted) {
          setState(() {
            _isEditing = false;
            _editingCommentId = null;
            _commentController.clear();
          });
          _loadComments();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al editar: $e')));
      }
      return;
    }

    // Pre-limpiar para feedback inmediato
    _commentController.clear();
    FocusScope.of(context).unfocus();

    try {
      final profileRepo = di.sl<ProfileRepository>();
      
      String authorName = _currentUserAminoName ?? user.displayName ?? 'Usuario';
      String authorAvatar = _currentUserAminoAvatar ?? user.photoURL ?? '';

      final newComment = WikiComment(
        id: '',
        wikiId: widget.wiki.id,
        authorId: user.uid,
        authorName: authorName,
        authorAvatarUrl: authorAvatar,
        content: text,
        createdAt: DateTime.now(),
        authorLevel: _currentMemberProfile?.level ?? 1,
        authorTitles: _currentMemberProfile?.titles ?? [],
        authorRole: _currentMemberProfile?.role ?? 'member',
      );

      if (_replyingTo != null) {
        await di.sl<WikiRepository>().addWikiReply(widget.wiki.id, _replyingTo!.id, newComment);
      } else {
        await di.sl<WikiRepository>().addWikiComment(widget.wiki.id, newComment);
      }

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
        widget.onCommentAdded?.call();
        _loadComments();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _sendSticker(String url) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentMemberProfile == null) return;

    final newComment = WikiComment(
      id: '',
      wikiId: widget.wiki.id,
      authorId: user.uid,
      authorName: user.displayName ?? 'Usuario',
      authorAvatarUrl: user.photoURL ?? '',
      content: '',
      stickerUrl: url,
      createdAt: DateTime.now(),
    );

    setState(() => _showStickers = false);

    try {
      String authorName = _currentUserAminoName ?? user.displayName ?? 'Usuario';
      String authorAvatar = _currentUserAminoAvatar ?? user.photoURL ?? '';

      final newComment = WikiComment(
        id: '',
        wikiId: widget.wiki.id,
        authorId: user.uid,
        authorName: authorName,
        authorAvatarUrl: authorAvatar,
        content: '',
        stickerUrl: url,
        createdAt: DateTime.now(),
        authorLevel: _currentMemberProfile?.level ?? 1,
        authorTitles: _currentMemberProfile?.titles ?? [],
        authorRole: _currentMemberProfile?.role ?? 'member',
      );

      if (_replyingTo != null) {
        await di.sl<WikiRepository>().addWikiReply(widget.wiki.id, _replyingTo!.id, newComment);
      } else {
        await di.sl<WikiRepository>().addWikiComment(widget.wiki.id, newComment);
      }

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
        widget.onCommentAdded?.call();
        _loadComments();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _sendCustomSticker(File stickerFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentMemberProfile == null) return;

    setState(() => _showStickers = false);

    try {
      final uploadedUrl = await di.sl<StorageService>().uploadPostImage(
        stickerFile,
        folder: 'wiki_comments/${widget.wiki.id}',
      );

      String authorName = _currentUserAminoName ?? user.displayName ?? 'Usuario';
      String authorAvatar = _currentUserAminoAvatar ?? user.photoURL ?? '';

      final newComment = WikiComment(
        id: '',
        wikiId: widget.wiki.id,
        authorId: user.uid,
        authorName: authorName,
        authorAvatarUrl: authorAvatar,
        content: '',
        stickerUrl: uploadedUrl,
        createdAt: DateTime.now(),
        authorLevel: _currentMemberProfile?.level ?? 1,
        authorTitles: _currentMemberProfile?.titles ?? [],
        authorRole: _currentMemberProfile?.role ?? 'member',
      );

      await di.sl<WikiRepository>().addWikiComment(widget.wiki.id, newComment);
      if (mounted) {
        widget.onCommentAdded?.call();
        _loadComments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar sticker personalizado: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Wumbleheme.backgroundColor,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                ? Center(child: Text('Sin comentarios aún', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final c = _comments[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserAvatar(
                              userId: c.authorId,
                              avatarUrl: c.authorAvatarUrl,
                              displayName: c.authorName,
                              radius: 18,
                              communityId: widget.wiki.communityId,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onLongPress: () => _showCommentOptions(c),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                (c.authorId == _currentUserId ? (_currentUserAminoName ?? c.authorName) : c.authorName), 
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            UserBadgeWidget(
                                              level: c.authorLevel,
                                              titles: c.authorTitles,
                                              role: c.authorRole,
                                              fontSize: 8,
                                              showTitles: false,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                          if (c.stickerUrl != null)
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ImageViewerScreen(imageUrl: c.stickerUrl!),
                                                ),
                                              ),
                                              child: CachedNetworkImage(
                                                imageUrl: MediaOptimizer.optimize(c.stickerUrl!, width: 400, height: 400),
                                                height: 100,
                                                width: 100,
                                                fit: BoxFit.contain,
                                                placeholder: (context, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                errorWidget: (context, _, __) => const Icon(Icons.broken_image, color: Colors.white24, size: 20),
                                              ),
                                            )
                                        else if (c.imageUrl != null && c.imageUrl!.isNotEmpty)
                                          GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ImageViewerScreen(imageUrl: c.imageUrl!),
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
                                                child: CachedNetworkImage(
                                                  imageUrl: MediaOptimizer.post(c.imageUrl!),
                                                  fit: BoxFit.contain,
                                                  placeholder: (context, _) => Container(
                                                    width: 100,
                                                    height: 100,
                                                    color: Colors.white10,
                                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                  ),
                                                  errorWidget: (context, _, __) => const Icon(Icons.error, color: Colors.white54, size: 20),
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          LinkifyText(c.content, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        _buildCommentReactions(c),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _replyingTo = c;
                                      });
                                    },
                                    child: const Text(
                                      'Responder',
                                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (c.replies.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...c.replies.map((reply) => Padding(
                                      padding: const EdgeInsets.only(top: 8.0, left: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onLongPress: () => _showCommentOptions(reply, isReply: true, parentCommentId: c.id),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    UserAvatar(
                                                      userId: reply.authorId,
                                                      avatarUrl: reply.authorAvatarUrl,
                                                      displayName: reply.authorName,
                                                      radius: 12,
                                                      communityId: widget.wiki.communityId,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        reply.authorName, 
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)
                                                      )
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 32),
                                                  child: Column( // Added Column here to hold multiple children
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      LinkifyText(reply.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                                      _buildCommentReactions(reply),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 32, top: 4),
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _replyingTo = c;
                                                  _commentController.text = '@${reply.authorName} ';
                                                });
                                              },
                                              child: const Text(
                                                'Responder',
                                                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showCommentOptions(c),
                              icon: const Icon(Icons.more_vert, size: 18, color: Colors.white38),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          if (_showStickers)
            SizedBox(
              height: 300,
              child: StickerSelector(
                onStickerSelected: _sendSticker,
                onCustomStickerCreated: _sendCustomSticker,
              ),
            ),

          // Replying To Header
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Wumbleheme.surfaceColor,
              child: Row(
                children: [
                  Text(
                    'Respondiendo a ${_replyingTo!.authorName}',
                    style: TextStyle(color: Wumbleheme.primaryColor, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // Input Section
          if (_currentMemberProfile == null) ...[
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Wumbleheme.primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_person_rounded, color: Wumbleheme.primaryColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modo Lectura',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Únete para participar',
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                             try {
                               final community = await di.sl<CommunityRepository>().getCommunity(widget.wiki.communityId);
                               if (community != null && mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommunityInfoScreen(community: community),
                                    ),
                                  );
                               }
                             } catch (e) {
                               debugPrint('Error fetching community (wiki): $e');
                             }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Wumbleheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('UNIRSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Wumbleheme.surfaceColor,
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_showStickers ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.white54),
                    onPressed: () => setState(() => _showStickers = !_showStickers),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un comentario...',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Wumbleheme.primaryColor),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCommentOptions(WikiComment comment, {bool isReply = false, String? parentCommentId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bool isAuthor = comment.authorId == _currentUserId;
        
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Wumbleheme.surfaceColor.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white10),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 8,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Comment Preview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const Text(
                          'COMENTARIO',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserAvatar(
                                userId: comment.authorId,
                                avatarUrl: comment.authorAvatarUrl,
                                displayName: comment.authorName,
                                radius: 14,
                                communityId: widget.wiki.communityId,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment.authorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    if (comment.stickerUrl != null)
                                      CachedNetworkImage(imageUrl: MediaOptimizer.optimize(comment.stickerUrl!, width: 240, height: 240), height: 60)
                                    else
                                      LinkifyText(comment.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10, height: 1),

                  // Reactions Bar
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ...['❤️', '😂', '😮', '😢', '👍', '🔥', '🎉', '😡', '🤔'].map((emoji) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _reactToComment(comment, emoji);
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                alignment: Alignment.center,
                                child: Text(emoji, style: const TextStyle(fontSize: 24)),
                              ),
                            );
                          }).toList(),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showFullEmojiCommentReactionPicker(comment);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const Icon(Icons.add, color: Colors.white70, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 1),

                  // Menu Options
                  _buildMenuTile(
                    icon: Icons.copy_rounded,
                    title: 'Copiar texto',
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: comment.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comentario copiado'),
                          backgroundColor: Wumbleheme.primaryColor,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.reply_rounded,
                    title: 'Responder',
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _replyingTo = isReply ? _comments.firstWhere((c) => c.id == parentCommentId) : comment;
                        if (isReply) {
                          _commentController.text = '@${comment.authorName} ';
                        }
                      });
                    },
                  ),
                  if (isAuthor) ...[
                    _buildMenuTile(
                      icon: Icons.edit_rounded,
                      title: 'Editar',
                      onTap: () {
                        Navigator.pop(ctx);
                        if (isReply) {
                           // Wiki doesn't have edit reply implemented the same way, but let's stick to the comment edit for now or skip if not supported
                        } else {
                          _startEditing(comment);
                        }
                      },
                    ),
                    _buildMenuTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Eliminar',
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (isReply && parentCommentId != null) {
                           di.sl<WikiRepository>().deleteWikiReply(widget.wiki.id, parentCommentId, comment).then((_) => _loadComments());
                        } else {
                          _deleteComment(comment.id);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(icon, color: color.withOpacity(0.8), size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showJoinPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¡Únete a la comunidad!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Para reaccionar a comentarios necesitas ser miembro de esta comunidad.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final community = await di.sl<CommunityRepository>().getCommunity(widget.wiki.communityId);
                if (community != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityInfoScreen(community: community),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error fetching community (wiki comments prompt): $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Wumbleheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('UNIRSE AHORA'),
          ),
        ],
      ),
    );
  }

  void _reactToComment(WikiComment comment, String reaction) {
    if (_currentUserId == null) return;
    
    if (_currentMemberProfile == null) {
      _showJoinPrompt();
      return;
    }

    di.sl<WikiRepository>().reactToWikiComment(widget.wiki.id, comment.id, _currentUserId!, reaction).then((_) {
      if (mounted) _loadComments();
    });
  }

  void _showFullEmojiCommentReactionPicker(WikiComment comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Wumbleheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            Navigator.pop(ctx);
            _reactToComment(comment, emoji.emoji);
          },
          config: Config(
            height: 350,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: Wumbleheme.backgroundColor,
              columns: 7,
              buttonMode: ButtonMode.MATERIAL,
              emojiSizeMax: 28,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: Wumbleheme.backgroundColor,
              indicatorColor: Wumbleheme.primaryColor,
              iconColorSelected: Wumbleheme.primaryColor,
              iconColor: Wumbleheme.textSecondary,
              dividerColor: Colors.white10,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Wumbleheme.backgroundColor,
              buttonIconColor: Colors.white,
              hintTextStyle: const TextStyle(color: Wumbleheme.textSecondary, fontSize: 14),
              inputTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentReactions(WikiComment comment) {
    if (comment.reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: comment.reactions.entries.map((entry) {
          final reaction = entry.key;
          final userIds = entry.value;
          final hasReacted = _currentUserId != null && userIds.contains(_currentUserId);

          final isStandardEmoji = !reaction.startsWith('http');

          return GestureDetector(
            onTap: () {
              UserListBottomSheet.show(
                context,
                title: isStandardEmoji ? 'Personas que reaccionaron $reaction' : 'Personas que reaccionaron',
                userIds: userIds,
                communityId: widget.wiki.communityId,
              );
            },
            onLongPress: () => _reactToComment(comment, reaction),

            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasReacted 
                    ? Wumbleheme.primaryColor.withOpacity(0.2) 
                    : Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasReacted 
                      ? Wumbleheme.primaryColor.withOpacity(0.5) 
                      : Colors.white12,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reaction, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '${userIds.length}',
                    style: TextStyle(
                      color: hasReacted ? Wumbleheme.primaryColor : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
