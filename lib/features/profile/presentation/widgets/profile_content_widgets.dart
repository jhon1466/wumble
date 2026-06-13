import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'package:wumble/features/community/presentation/pages/community_info_screen.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/utils/media_helper.dart';
import '../../domain/user_model.dart';
import '../../../auth/presentation/auth_bloc.dart';

import '../profile_bloc.dart';
import '../profile_screen.dart';
import 'package:wumble/features/feed/presentation/pages/post_detail_screen.dart';
import 'package:wumble/features/community/presentation/pages/wiki_detail_screen.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../feed/domain/feed_repository.dart';
import '../../../community/domain/wiki_repository.dart';
import '../../../feed/domain/post_model.dart';
import '../../../community/domain/wiki_model.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/features/feed/presentation/widgets/post_card.dart';
import 'package:wumble/features/community/presentation/widgets/wiki_card.dart';
import 'package:wumble/features/profile/presentation/widgets/wall_message_card.dart';

class ProfileWall extends StatefulWidget {
  final UserProfile user;
  final String? communityId;

  const ProfileWall({
    super.key, 
    required this.user,
    this.communityId,
  });

  @override
  State<ProfileWall> createState() => _ProfileWallState();
}

class _ProfileWallState extends State<ProfileWall> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;
  String? _selectedImagePath;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final path = await MediaHelper.pickImageWithOptimization(context);
    if (path != null) {
      setState(() => _selectedImagePath = path.path);
    }
  }

  Future<void> _sendComment(UserProfile currentUser) async {
    if (_commentController.text.trim().isEmpty && _selectedImagePath == null) return;

    setState(() {
      _isSending = true;
      _uploadProgress = 0;
    });

    try {
      String? imageUrl;
      if (_selectedImagePath != null) {
        imageUrl = await di.sl<ProfileRepository>().uploadWallImage(
          widget.user.id,
          _selectedImagePath!,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      final wallMessage = WallMessage(
        id: '', // Firestore will generate
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        senderAvatar: currentUser.avatarUrl,
        senderAvatarFrame: currentUser.avatarFrameUrl, // NEW: Include frame
        text: _commentController.text.trim(),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await di.sl<ProfileRepository>().sendWallMessage(
        widget.user.id, 
        wallMessage,
        communityId: widget.communityId, // Added communityId
      );
      
      _commentController.clear();
      setState(() {
        _selectedImagePath = null;
        _uploadProgress = 0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar comentario: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final currentUser = authState.user;
        if (currentUser == null) return const SizedBox.shrink();

        // 14/02/2026: Sincronización en tiempo real del usuario actual para el input bar
        // 23/02/2026: AISLAMIENTO - Escuchar perfil de miembro si hay comunidad
        final profileStream = widget.communityId != null
            ? FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('members')
                .doc(currentUser.uid)
                .snapshots()
            : FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: profileStream,
          builder: (context, userSnapshot) {
            String viewerAvatar = currentUser.photoURL ?? '';
            String viewerName = currentUser.displayName ?? 'Usuario';
            String? viewerFrame; // NEW

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data()!;
              viewerAvatar = data['avatarUrl'] ?? viewerAvatar;
              viewerName = data['displayName'] ?? data['username'] ?? viewerName;
              viewerFrame = data['avatarFrameUrl']; // NEW
            }

            return Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
              child: Column(
                children: [
                  // Comment Input logic with Privacy Check
                  BlocBuilder<CommunityContextBloc, CommunityContextState>(
                    builder: (context, communityState) {
                      final bool isCommunityMember = widget.communityId == null || communityState.memberProfile != null;
                      
                      return StreamBuilder<bool>(
                        stream: widget.user.id == currentUser.uid 
                            ? Stream.value(true) 
                            : di.sl<ProfileRepository>().isFollowing(currentUser.uid, widget.user.id),
                        builder: (context, followSnapshot) {
                          final isFollowing = followSnapshot.data ?? false;
                          bool canComment = false;
                          String disabledMessage = '';
                          bool showJoinButton = false;
                          
                          if (!isCommunityMember) {
                            canComment = false;
                            disabledMessage = 'Únete a esta comunidad para comentar en los muros.';
                            showJoinButton = true;
                          } else if (widget.user.id == currentUser.uid) {
                            canComment = true;
                          } else {
                            switch (widget.user.wallPrivacy) {
                              case 'everyone':
                                canComment = true;
                                break;
                              case 'followers':
                                canComment = isFollowing;
                                disabledMessage = 'Solo los seguidores de este usuario pueden comentar en su muro.';
                                break;
                              case 'only_me':
                              default:
                                canComment = false;
                                disabledMessage = 'Este usuario ha desactivado los comentarios en su muro.';
                                break;
                            }
                          }
    
                          if (!canComment) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Wumbleheme.surfaceColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                children: [
                                  Icon(showJoinButton ? Icons.group_add_outlined : Icons.lock_outline, color: Colors.white24, size: 24),
                                  const SizedBox(height: 8),
                                  Text(
                                    disabledMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                                  ),
                                  if (showJoinButton && communityState.activeCommunity != null) ...[
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CommunityInfoScreen(community: communityState.activeCommunity!),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Wumbleheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                        minimumSize: const Size(0, 32),
                                      ),
                                      child: const Text('UNIRSE AHORA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
    
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Wumbleheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                if (_selectedImagePath != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(_selectedImagePath!),
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        if (_isSending)
                                          Positioned.fill(
                                            child: Container(
                                              color: Colors.black45,
                                              child: Center(
                                                child: CircularProgressIndicator(value: _uploadProgress),
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          top: 5,
                                          right: 5,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _selectedImagePath = null),
                                            child: const CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.black54,
                                              child: Icon(Icons.close, size: 16, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Wumbleheme.surfaceColor,
                                      backgroundImage: viewerAvatar.isNotEmpty 
                                          ? CachedNetworkImageProvider(viewerAvatar) 
                                          : null,
                                      child: viewerAvatar.isEmpty 
                                          ? const Icon(Icons.person, size: 20, color: Colors.white24)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _commentController,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: widget.user.id == currentUser.uid 
                                              ? 'Escribe algo en tu muro...' 
                                              : 'Deja un comentario...',
                                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.image_outlined, color: Colors.white38),
                                      onPressed: _pickImage,
                                    ),
                                    if (_isSending)
                                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    else
                                      IconButton(
                                        icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.secondary),
                                        onPressed: () => _sendComment(UserProfile(
                                          id: currentUser.uid,
                                          username: '',
                                          displayName: viewerName,
                                          avatarUrl: viewerAvatar,
                                          avatarFrameUrl: viewerFrame, // NEW: Include frame
                                          bannerUrl: '', backgroundUrl: '', bio: '', reputation: 0, level: 1, titles: [], followers: 0, following: 0, checkIns: 0,
                                        )),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Messages Stream
                  StreamBuilder<List<WallMessage>>(
                    stream: di.sl<ProfileRepository>().getWallMessages(
                      widget.user.id,
                      communityId: widget.communityId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.3),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Column(
                          children: [
                            const SizedBox(height: 30),
                            const Icon(Icons.message_outlined, size: 48, color: Colors.white12),
                            const SizedBox(height: 10),
                            const Text(
                              'El muro está vacío.',
                              style: TextStyle(color: Colors.white24),
                            ),
                            const Text(
                              '¡Sé el primero en comentar!',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: messages.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return WallMessageCard(
                            profileOwnerId: widget.user.id,
                            message: msg,
                            communityId: widget.communityId,
                            onReply: () => _showReplyDialog(context, msg, currentUser, viewerName, viewerAvatar, viewerFrame),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${date.day}/${date.month}';
  }

  void _showReplyDialog(BuildContext context, WallMessage msg, User currentUser, String senderName, String senderAvatar, String? senderAvatarFrame) {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Wumbleheme.surfaceColor,
          title: const Text('Responder a comentario', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: TextField(
            controller: replyController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Escribe tu respuesta...',
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Wumbleheme.secondaryColor)),
            ),
            maxLines: 3,
            minLines: 1,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Wumbleheme.secondaryColor),
              onPressed: () async {
                final text = replyController.text.trim();
                if (text.isEmpty) return;
                
                Navigator.pop(context); // Close dialog

                final reply = WallReply(
                  id: '',
                  senderId: currentUser.uid,
                  senderName: senderName,
                  senderAvatar: senderAvatar,
                  senderAvatarFrame: senderAvatarFrame, // NEW: Include frame
                  text: text,
                  createdAt: DateTime.now(),
                );

                try {
                  await di.sl<ProfileRepository>().addWallMessageReply(
                    widget.user.id,
                    msg.id,
                    reply,
                    communityId: widget.communityId,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al responder: $e')),
                    );
                  }
                }
              },
              child: const Text('Responder', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class ProfilePosts extends StatefulWidget {
  final UserProfile user;
  final String? communityId;
  const ProfilePosts({super.key, required this.user, this.communityId});

  @override
  State<ProfilePosts> createState() => _ProfilePostsState();
}

class _ProfilePostsState extends State<ProfilePosts> {
  late Future<List<Post>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = di.sl<FeedRepository>().getUserPosts(
      widget.user.id, 
      communityId: widget.communityId,
    );
  }

  @override
  void didUpdateWidget(ProfilePosts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.communityId != widget.communityId) {
      _postsFuture = di.sl<FeedRepository>().getUserPosts(
        widget.user.id, 
        communityId: widget.communityId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Post>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.4),
            child: const Center(
              child: CircularProgressIndicator(color: Wumbleheme.secondaryColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 10),
                Text(
                  'Error al cargar posts.\nRevisa la consola para el link del índice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(Icons.article_outlined, size: 48, color: Colors.white12),
                SizedBox(height: 10),
                Text('No hay publicaciones aún.', style: TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post);
          },
        );
      },
    );
  }
}

class ProfileWikis extends StatefulWidget {
  final UserProfile user;
  final String? communityId;
  final bool ocOnly; // true -> show only Original Characters; false -> only wikis
  const ProfileWikis({super.key, required this.user, this.communityId, this.ocOnly = false});

  @override
  State<ProfileWikis> createState() => _ProfileWikisState();
}

class _ProfileWikisState extends State<ProfileWikis> {
  late Future<List<WikiPage>> _wikisFuture;

  @override
  void initState() {
    super.initState();
    _wikisFuture = di.sl<WikiRepository>().getUserWikis(
      widget.user.id, 
      communityId: widget.communityId,
    );
  }

  @override
  void didUpdateWidget(ProfileWikis oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.communityId != widget.communityId) {
      _wikisFuture = di.sl<WikiRepository>().getUserWikis(
        widget.user.id, 
        communityId: widget.communityId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WikiPage>>(
      future: _wikisFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.4),
            child: const Center(
              child: CircularProgressIndicator(color: Wumbleheme.secondaryColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 10),
                Text(
                  'Error al cargar wikis.\nRevisa la consola para el link del índice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        final all = snapshot.data ?? [];
        final wikis = all
            .where((w) => widget.ocOnly ? w.type == 'oc' : w.type != 'oc')
            .toList();

        if (wikis.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(widget.ocOnly ? Icons.face_retouching_natural : Icons.book_outlined,
                    size: 48, color: Colors.white12),
                const SizedBox(height: 10),
                Text(widget.ocOnly ? 'No hay personajes todavía.' : 'No hay entradas Wiki.',
                    style: const TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: wikis.length,
          itemBuilder: (context, index) {
            final wiki = wikis[index];
            return WikiCard(wiki: wiki);
          },
        );
      },
    );
  }
}

class ProfileSavedPosts extends StatefulWidget {
  final UserProfile user;
  const ProfileSavedPosts({super.key, required this.user});

  @override
  State<ProfileSavedPosts> createState() => _ProfileSavedPostsState();
}

class _ProfileSavedPostsState extends State<ProfileSavedPosts> {
  late Future<List<Post>> _savedPostsFuture;

  @override
  void initState() {
    super.initState();
    _savedPostsFuture = di.sl<FeedRepository>().getSavedPosts(widget.user.id);
  }

  @override
  void didUpdateWidget(ProfileSavedPosts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _savedPostsFuture = di.sl<FeedRepository>().getSavedPosts(widget.user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Post>>(
      future: _savedPostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.4),
            child: const Center(
              child: CircularProgressIndicator(color: Wumbleheme.secondaryColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                SizedBox(height: 10),
                Text('Error al cargar guardados', style: TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(Icons.bookmark_border, size: 48, color: Colors.white12),
                SizedBox(height: 10),
                Text('No tienes publicaciones guardadas.', style: TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post);
          },
        );
      },
    );
  }
}
