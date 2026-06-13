import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wumble/features/community/presentation/pages/community_info_screen.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/feed/presentation/pages/create_post_screen.dart';
import 'package:wumble/features/feed/presentation/bloc/create_post_cubit.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/utils/media_optimizer.dart';
import 'package:wumble/core/utils/media_helper.dart';
import 'package:wumble/core/services/storage_service.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/auth/presentation/auth_bloc.dart';
import 'package:wumble/features/chat/domain/chat_repository.dart';
import 'package:wumble/features/chat/presentation/widgets/sticker_selector.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'package:wumble/features/community/presentation/widgets/member_mini_profile.dart';
import 'package:wumble/core/widgets/link_preview_card.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/feed/domain/feed_repository.dart';
import 'package:wumble/features/feed/domain/post_model.dart';
import 'package:wumble/features/feed/domain/post_comment_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/core/widgets/user_badge_widget.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/core/widgets/user_list_bottom_sheet.dart';
import 'package:wumble/features/profile/domain/user_model.dart';

import 'package:wumble/features/profile/presentation/widgets/donation_modal.dart';
import 'package:wumble/features/chat/domain/bot_framework.dart';
import 'package:wumble/features/chat/domain/moderation_service.dart';
import 'package:wumble/features/community/domain/moderation_report_model.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/features/chat/presentation/image_viewer_screen.dart';
import 'package:wumble/core/widgets/linkify_text.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FeedRepository _feedRepository = di.sl<FeedRepository>();
  final CommunityRepository _communityRepository = di.sl<CommunityRepository>(); // Added
  final TextEditingController _commentController = TextEditingController();
  
  bool _isLiked = false;
  bool _isSaved = false; // Added
  bool _isPinned = false; // Added
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isLoadingComments = true;
  List<PostComment> _comments = [];
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid; // Modified
  CommunityMember? _currentMemberProfile; // Added
  String? _currentUserAvatar; // added
  String? _currentUserName; // added
  String? _currentUserAvatarFrameUrl; // added
  PostComment? _replyingTo;

  final FocusNode _commentFocusNode = FocusNode();
  
  File? _selectedImage;
  bool _isUploadingImage = false;
  bool _showStickers = false;
  
  // Author data for reactive updates
  String? _authorName;
  String? _authorAvatarUrl;
  String? _authorAvatarFrameUrl; // added


  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.likes.contains(_currentUserId); // Modified
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
    _isPinned = widget.post.isPinned; // Added
    _authorName = widget.post.authorName;
    _authorAvatarUrl = widget.post.authorAvatarUrl;
    _authorAvatarFrameUrl = widget.post.authorAvatarFrameUrl; // added
    _loadComments();

    _fetchCurrentMemberProfile(); // Added
    _fetchAuthorProfile(); // Added
    _checkSavedStatus(); // Added
  }

  Future<void> _checkSavedStatus() async {
    if (_currentUserId == null) return;
    final saved = await _feedRepository.checkIfSaved(widget.post.id, _currentUserId!);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    if (_currentUserId == null) return;
    
    if (_currentMemberProfile == null) {
      _showJoinPrompt();
      return;
    }
    
    setState(() => _isSaved = !_isSaved);

    try {
      if (_isSaved) {
        await _feedRepository.savePost(widget.post.id, _currentUserId!);
      } else {
        await _feedRepository.unsavePost(widget.post.id, _currentUserId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaved = !_isSaved);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar')));
      }
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
          'Para interactuar con esta publicación, dar corazón, guardar o donar, necesitas ser miembro de esta comunidad.',
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
                final community = await di.sl<CommunityRepository>().getCommunity(widget.post.communityId);
                if (community != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityInfoScreen(community: community),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error fetching community: $e');
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

  Future<void> _togglePin() async {
    if (_currentUserId == null) return;
    
    final newPinnedStatus = !_isPinned;
    setState(() => _isPinned = newPinnedStatus);

    try {
      await _feedRepository.setPostPinned(widget.post.id, newPinnedStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newPinnedStatus ? 'Publicación fijada en destacados' : 'Publicación desfijada de destacados'),
            backgroundColor: Wumbleheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPinned = !newPinnedStatus);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cambiar estado de fijación')));
      }
    }
  }

  void _showReportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Reportar Publicación', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Razón del reporte...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              await _feedRepository.reportPost(widget.post.id, _currentUserId ?? 'anon', controller.text);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte enviado')));
            },
            child: const Text('ENVIAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAuthorProfile() async {
    try {
      final member = await di.sl<ProfileRepository>().getMemberProfile(widget.post.communityId, widget.post.authorId);
      if (member != null) {
        if (mounted) {
          setState(() {
            _authorName = member.displayName ?? 'Usuario';
            _authorAvatarUrl = member.avatarUrl;
            _authorAvatarFrameUrl = member.avatarFrameUrl; // NEW
          });

        }
      } else {
        // Fallback to global profile
        final global = await di.sl<ProfileRepository>().getUserProfile(widget.post.authorId).first;
        if (mounted) {
          setState(() {
            _authorName = global.displayName;
            _authorAvatarUrl = global.avatarUrl;
            _authorAvatarFrameUrl = global.avatarFrameUrl; // NEW
          });

        }
      }
    } catch (_) {
      // Keep initial data from widget.post if fetch fails
    }
  }

  Future<void> _fetchCurrentMemberProfile() async { // Added method
    if (_currentUserId == null) return;
    try {
      // 1. Siempre obtener perfil global como base
      final globalProfile = await di.sl<ProfileRepository>().getUserProfile(_currentUserId!).first;
      if (mounted) {
        setState(() {
          _currentUserAvatar = globalProfile.avatarUrl;
          _currentUserName = globalProfile.displayName;
          _currentUserAvatarFrameUrl = globalProfile.avatarFrameUrl; // NEW
        });

      }

      // 2. Si hay comunidad, el de miembro tiene prioridad (AISLAMIENTO)
      final profile = await di.sl<ProfileRepository>().getMemberProfile(widget.post.communityId, _currentUserId!);
      if (profile != null && mounted) {
        setState(() {
          _currentMemberProfile = profile;
          _currentUserAvatar = profile.avatarUrl ?? _currentUserAvatar;
          _currentUserName = profile.displayName ?? _currentUserName;
          _currentUserAvatarFrameUrl = profile.avatarFrameUrl ?? _currentUserAvatarFrameUrl; // NEW
        });

      }
    } catch (e) {
      debugPrint('Error fetching current member profile: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }


  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    final comments = await _feedRepository.getComments(widget.post.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _commentsCount = comments.length;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUserId == null) return;
    
    if (_currentMemberProfile == null) {
      _showJoinPrompt();
      return;
    }

    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likesCount++ : _likesCount--;
    });

    try {
      if (_isLiked) {
        await _feedRepository.likePost(widget.post.id, _currentUserId!);
      } else {
        await _feedRepository.unlikePost(widget.post.id, _currentUserId!);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _isLiked ? _likesCount++ : _likesCount--;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await MediaHelper.pickImageWithOptimization(context);
    if (pickedFile != null) {
      // Compress the image immediately
      final compressedPath = await MediaHelper.compressImage(pickedFile.path);
      setState(() {
        _selectedImage = File(compressedPath);
      });
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if ((text.isEmpty && _selectedImage == null) || _currentUserId == null) return;

    final authState = context.read<AuthBloc>().state;
    final currentUser = authState.user;
    if (currentUser == null || _currentMemberProfile == null) return;
    
    // --- Phase 13: Comment Moderation ---
    ModerationLevel level = ModerationLevel.medium;
    String? guardianBotId;
    try {
      final botsSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.post.communityId)
          .collection('bots')
          .where('isActive', isEqualTo: true)
          .where('isGuardian', isEqualTo: true)
          .limit(1)
          .get();
      if (botsSnapshot.docs.isNotEmpty) {
        guardianBotId = botsSnapshot.docs.first.id;
        final bot = BotConfig.fromFirestore(botsSnapshot.docs.first);
        level = bot.feedModerationSensitivity < 0.3 ? ModerationLevel.low : (bot.feedModerationSensitivity < 0.7 ? ModerationLevel.medium : ModerationLevel.high);
      }
    } catch (_) {}

    if (text.isNotEmpty) {
      final modResult = await ModerationService.analyzeText(text, level: level);
      if (modResult.isFlagged && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('COMENTARIO BLOQUEADO: ${modResult.reason}'), backgroundColor: Colors.redAccent),
        );
        return;
      } else if (modResult.confidence > 0.4 && guardianBotId != null) {
        // Yellow Zone: Report but allow
        ModerationService.reportToModerators(
          communityId: widget.post.communityId,
          reporterId: guardianBotId,
          targetId: 'pending_comment', 
          targetUserId: _currentUserId!,
          targetType: ModerationTargetType.comment,
          contentPreview: text,
          reason: 'COMENTARIO SOSPECHOSO: ${modResult.reason}',
          confidenceScore: modResult.confidence,
        );
      }
    }

    setState(() => _isUploadingImage = true);
    
    String? uploadedImageUrl;
    if (_selectedImage != null) {
      try {
        uploadedImageUrl = await di.sl<StorageService>().uploadPostImage(
          _selectedImage!,
          folder: 'comments/${widget.post.id}',
        );
      } catch (e) {
        debugPrint('Error uploading comment image: $e');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir imagen')));
           setState(() => _isUploadingImage = false);
        }
        return;
      }
    }

    final newComment = PostComment(
      id: _replyingTo != null ? DateTime.now().millisecondsSinceEpoch.toString() : '', // Generate ID for replies
      postId: widget.post.id,
      authorId: _currentUserId!,
      authorName: _currentUserName ?? currentUser.displayName ?? 'Usuario',
      authorAvatarUrl: _currentUserAvatar ?? currentUser.photoURL ?? '',
      authorAvatarFrameUrl: _currentUserAvatarFrameUrl, // NEW
      content: text,

      imageUrl: uploadedImageUrl,
      createdAt: DateTime.now(),
      authorLevel: _currentMemberProfile?.level ?? 1,
      authorTitles: _currentMemberProfile?.titles ?? [],
      authorRole: _currentMemberProfile?.role ?? 'member',
    );

    _commentController.clear();
    _removeSelectedImage();
    FocusScope.of(context).unfocus();

    // Optimistic UI update
    setState(() {
      _isUploadingImage = false;
      if (_replyingTo != null) {
         // Find comment and add reply locally
         final idx = _comments.indexWhere((c) => c.id == _replyingTo!.id);
         if (idx != -1) {
            _comments[idx].replies.add(newComment);
         }
      } else {
         _comments.insert(0, newComment);
         _commentsCount++;
      }
    });

    try {
      if (_replyingTo != null) {
         await _feedRepository.addReply(widget.post.id, _replyingTo!.id, newComment);
      } else {
         await _feedRepository.addComment(widget.post.id, newComment);
      }
      _replyingTo = null; // Reset reply state after sending
      _loadComments(); // Refresh to get real IDs and exact timestamps
    } catch (e) {
      // Revert if failed
      _replyingTo = null;
      _loadComments();
    }
  }

  Future<void> _sendSticker(String url) async {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState.user;
    if (currentUser == null || _currentUserId == null || _currentMemberProfile == null) return;
    
    setState(() => _showStickers = false);

    final newComment = PostComment(
      id: '',
      postId: widget.post.id,
      authorId: _currentUserId!,
      authorName: _currentUserName ?? currentUser.displayName ?? 'Usuario',
      authorAvatarUrl: _currentUserAvatar ?? currentUser.photoURL ?? '',
      authorAvatarFrameUrl: _currentUserAvatarFrameUrl, // NEW
      content: '', // Empty content for direct sticker messages

      stickerUrl: url,
      createdAt: DateTime.now(),
      authorLevel: _currentMemberProfile?.level ?? 1,
      authorTitles: _currentMemberProfile?.titles ?? [],
      authorRole: _currentMemberProfile?.role ?? 'member',
    );

    // Optimistic UI update
    setState(() {
      if (_replyingTo != null) {
         final idx = _comments.indexWhere((c) => c.id == _replyingTo!.id);
         if (idx != -1) _comments[idx].replies.add(newComment);
      } else {
         _comments.insert(0, newComment);
         _commentsCount++;
      }
    });

    try {
      if (_replyingTo != null) {
         await _feedRepository.addReply(widget.post.id, _replyingTo!.id, newComment);
      } else {
         await _feedRepository.addComment(widget.post.id, newComment);
      }
      _replyingTo = null;
      _loadComments();
    } catch (e) {
      _replyingTo = null;
      _loadComments();
    }
  }

  Future<void> _sendCustomSticker(File stickerFile) async {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState.user;
    if (currentUser == null || _currentUserId == null) return;

    setState(() {
      _showStickers = false;
      _isUploadingImage = true;
    });

    try {
      final uploadedUrl = await di.sl<StorageService>().uploadPostImage(
        stickerFile,
        folder: 'comments/${widget.post.id}',
      );
      
      final newComment = PostComment(
        id: '',
        postId: widget.post.id,
        authorId: _currentUserId!,
        authorName: _currentUserName ?? currentUser.displayName ?? 'Usuario',
        authorAvatarUrl: _currentUserAvatar ?? currentUser.photoURL ?? '',
        authorAvatarFrameUrl: _currentUserAvatarFrameUrl, // NEW
        content: '',

        stickerUrl: uploadedUrl,
        createdAt: DateTime.now(),
        authorLevel: _currentMemberProfile?.level ?? 1,
        authorTitles: _currentMemberProfile?.titles ?? [],
        authorRole: _currentMemberProfile?.role ?? 'member',
      );

      setState(() {
        if (_replyingTo != null) {
           final idx = _comments.indexWhere((c) => c.id == _replyingTo!.id);
           if (idx != -1) _comments[idx].replies.add(newComment);
        } else {
           _comments.insert(0, newComment);
           _commentsCount++;
        }
        _isUploadingImage = false;
      });

      if (_replyingTo != null) {
         await _feedRepository.addReply(widget.post.id, _replyingTo!.id, newComment);
      } else {
         await _feedRepository.addComment(widget.post.id, newComment);
      }
      _replyingTo = null;
      _loadComments();
    } catch (e) {
      debugPrint('Error uploading custom sticker: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar sticker personalizado')));
         setState(() => _isUploadingImage = false);
      }
    }
  }

  String _timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 365) return '${(difference.inDays / 365).floor()}a';
    if (difference.inDays > 30) return '${(difference.inDays / 30).floor()}mes';
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Ahora';
  }

  Color? _getParsedBackgroundColor(String? hexColor) {
    if (hexColor == null) return null;
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  void _showCommentOptions(PostComment comment, {bool isReply = false, String? parentCommentId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
                                communityId: widget.post.communityId,
                                avatarFrameUrl: comment.authorAvatarFrameUrl, // NEW
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
                                    else if (comment.imageUrl != null)
                                      CachedNetworkImage(imageUrl: MediaOptimizer.post(comment.imageUrl!), height: 60, fit: BoxFit.cover)
                                    else
                                      Text(comment.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
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
                                Navigator.pop(context);
                                _reactToComment(comment, emoji);
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 24)),
                              ),
                            );
                          }).toList(),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
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
                    icon: Icons.add_reaction_outlined,
                    title: 'Reaccionar con Sticker',
                    onTap: () {
                      Navigator.pop(context);
                      _showStickerCommentReactionPicker(comment);
                    },
                  ),
                  if (comment.content.isNotEmpty)
                    _buildMenuTile(
                      icon: Icons.copy_rounded,
                      title: 'Copiar texto',
                      onTap: () {
                        Navigator.pop(context);
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
                      Navigator.pop(context);
                      setState(() {
                        _replyingTo = isReply ? _comments.firstWhere((c) => c.id == parentCommentId) : comment;
                      });
                      _commentFocusNode.requestFocus();
                    },
                  ),
                  if (isAuthor) ...[
                    _buildMenuTile(
                      icon: Icons.edit_rounded,
                      title: 'Editar',
                      onTap: () {
                        Navigator.pop(context);
                        _showEditCommentDialog(comment, isReply: isReply, parentCommentId: parentCommentId);
                      },
                    ),
                    _buildMenuTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Eliminar',
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteCommentConfirmation(comment, isReply: isReply, parentCommentId: parentCommentId);
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

  void _showEditCommentDialog(PostComment comment, {bool isReply = false, String? parentCommentId}) {
    final controller = TextEditingController(text: comment.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Editar comentario', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Escribe algo...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != comment.content) {
                Navigator.pop(context);
                try {
                  if (isReply && parentCommentId != null) {
                    await _feedRepository.editReply(widget.post.id, parentCommentId, comment.id, newContent);
                  } else {
                    await _feedRepository.editComment(widget.post.id, comment.id, newContent);
                  }
                  _loadComments();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al editar')));
                }
              }
            },
            child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCommentConfirmation(PostComment comment, {bool isReply = false, String? parentCommentId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('¿Eliminar comentario?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (isReply && parentCommentId != null) {
                  await _feedRepository.deleteReply(widget.post.id, parentCommentId, comment.id);
                } else {
                  await _feedRepository.deleteComment(widget.post.id, comment.id);
                }
                _loadComments();
              } catch (e) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar')));
              }
            },
            child: const Text('SÍ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  Widget _buildRichText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _buildRichTextLine(line)).toList(),
    );
  }

  Widget _buildRichTextLine(String line) {
    if (line.isEmpty) return const SizedBox(height: 8);

    final tagMatch = RegExp(r'^\[([^\]]+)\]').firstMatch(line);
    String cleanText = line;
    bool isBold = false;
    bool isItalic = false;
    TextAlign textAlign = TextAlign.start;
    bool isList = false;
    bool isUnderlined = false;
    bool isStrikethrough = false;
    double? fontSize;
    Color? fontColor;
    Color? bgColor;
    String? fontFamily;

    if (tagMatch != null) {
      final tags = tagMatch.group(1)!;
      isBold = tags.contains('B');
      isItalic = tags.contains('I');
      isUnderlined = tags.contains('U');
      isStrikethrough = tags.contains('S');
      isList = tags.contains('L');
      
      if (tags.contains('C')) textAlign = TextAlign.center;
      if (tags.contains('R')) textAlign = TextAlign.right;
      if (tags.contains('J')) textAlign = TextAlign.justify;
      if (tags.contains('M')) {
        fontSize = 28;
        isBold = true;
      }
      
      // Extract parameterized tags
      final sizeMatch = RegExp(r'T=([^#TKGJMR ]+)').firstMatch(tags);
      if (sizeMatch != null && fontSize == null) fontSize = double.tryParse(sizeMatch.group(1)!);

      final colorMatch = RegExp(r'#=([A-Fa-f0-9]{6})').firstMatch(tags);
      if (colorMatch != null) fontColor = Color(int.parse('FF${colorMatch.group(1)}', radix: 16));

      final bgMatch = RegExp(r'G=([A-Fa-f0-9]{6})').firstMatch(tags);
      if (bgMatch != null) bgColor = Color(int.parse('FF${bgMatch.group(1)}', radix: 16));

      final fontMatch = RegExp(r'K=([^#TKGJMR ]+)').firstMatch(tags);
      if (fontMatch != null) fontFamily = fontMatch.group(1);

      cleanText = line.substring(tagMatch.group(0)!.length);
    }

    final decorations = <TextDecoration>[];
    if (isUnderlined) decorations.add(TextDecoration.underline);
    if (isStrikethrough) decorations.add(TextDecoration.lineThrough);

    final style = TextStyle(
      color: fontColor ?? Colors.white,
      backgroundColor: bgColor,
      fontSize: fontSize ?? 16,
      height: 1.6,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: decorations.isNotEmpty ? TextDecoration.combine(decorations) : null,
      fontFamily: fontFamily == 'serif' ? 'Serif' : (fontFamily == 'monospace' ? 'monospace' : null),
    );

    Widget content = LinkifyText(
      isList ? '• $cleanText' : cleanText,
      style: style,
      textAlign: textAlign,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: textAlign == TextAlign.center ? Center(child: content) : content,
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('¿Eliminar publicación?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Esta acción borrará permanentemente el post, sus comentarios y todos sus archivos multimedia. No se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    // Show a loading snackbar or use a cubit listener
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Eliminando publicación...'),
          ],
        ),
        duration: Duration(days: 1), // Semi-permanent until done
      ),
    );

    try {
      await _feedRepository.deletePost(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicación eliminada correctamente')),
        );
        Navigator.pop(context, true); // Return true to indicate feed should refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  void _editPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          communityId: widget.post.communityId ?? '',
          existingPost: widget.post,
        ),
      ),
    ).then((updated) {
       if (updated == true) {
          // If edited, we might want to refresh the detail or go back. 
          // Usually better to go back so feed refreshes.
          Navigator.pop(context, true);
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    final postBgColor = _getParsedBackgroundColor(widget.post.backgroundColor);
    
    return Scaffold(
      backgroundColor: postBgColor ?? Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Publicación'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          BlocBuilder<CommunityContextBloc, CommunityContextState>(
            builder: (context, state) {
              final bool isAuthor = _currentUserId == widget.post.authorId;
              final bool isModerator = state.memberProfile?.role == 'leader' || state.memberProfile?.role == 'curator';
              
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editPost();
                  } else if (value == 'delete') {
                    _showDeleteConfirmation();
                  } else if (value == 'report') {
                    _showReportDialog();
                  } else if (value == 'save') {
                    _toggleSave();
                  } else if (value == 'pin') {
                    _togglePin();
                  }
                },
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  if (isAuthor)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(_isSaved ? 'Quitar de guardados' : 'Guardar'),
                      ],
                    ),
                  ),
                  if (!isAuthor)
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report_problem, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Reportar', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  if (isModerator)
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.orangeAccent, size: 20),
                          SizedBox(width: 8),
                          Text(_isPinned ? 'Desfijar de destacados' : 'Fijar en destacados'),
                        ],
                      ),
                    ),
                  if (isAuthor || isModerator)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: widget.post.backgroundImageUrl != null,
      body: Container(
        decoration: widget.post.backgroundImageUrl != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(widget.post.backgroundImageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.darken,
                  ),
                ),
              )
            : null,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  top: widget.post.backgroundImageUrl != null ? MediaQuery.of(context).padding.top + 56 : 0,
                  bottom: 20,
                ),
                children: [
                  _buildPostContent(),
                  const Divider(color: Colors.white10, thickness: 1),
                  _buildCommentsSection(),
                ],
              ),
            ),
            _buildCommentInputBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent() {
    final hasRichContent = widget.post.blocks.isNotEmpty || widget.post.title != null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              UserAvatar(
                userId: widget.post.authorId,
                avatarUrl: _authorAvatarUrl ?? widget.post.authorAvatarUrl,
                displayName: _authorName ?? widget.post.authorName,
                communityId: widget.post.communityId,
                avatarFrameUrl: _authorAvatarFrameUrl, // NEW
                radius: 20,
              ),

              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.post.authorName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Note: For now using a hardcoded level or fetching it. 
                        // Realistically should be in post model or fetched.
                        const UserBadgeWidget(level: 1, showTitles: false), 
                      ],
                    ),
                    Text(
                      _timeAgo(widget.post.createdAt),
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          if (widget.post.title != null && widget.post.title!.isNotEmpty) ...[
            Text(
              widget.post.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Wumbleheme.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (widget.post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.post.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )).toList(),
              ),
            ),

          // Blocks (New Rich Content)
          if (widget.post.blocks.isNotEmpty)
            ...widget.post.blocks.map((block) {
              if (block['type'] == 'text') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildRichText(block['value'] ?? ''),
                );
              } else if (block['type'] == 'image') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
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
                        imageUrl: block['value'] ?? (block['file'] != null ? 'Local File' : ''), // value or fallback
                        width: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (context, _) => Container(
                          height: 200,
                          color: Colors.white10,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, _, __) => const Icon(Icons.broken_image, color: Colors.white24, size: 50),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

          // Legacy Content (Backward Compatibility)
          if (!hasRichContent) ...[
            if (widget.post.content.isNotEmpty)
              LinkifyText(
                widget.post.content,
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
              ),
            if (widget.post.images.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...widget.post.images.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageViewerScreen(imageUrl: url),
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          placeholder: (context, _) => Container(
                            height: 250,
                            color: Colors.white10,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, _, __) => const Icon(Icons.error),
                        ),
                      ),
                    ),
                  )),
            ],
          ],

          const SizedBox(height: 16),

          // Action Bar (Likes and Comments counts)
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 24,
                  color: _isLiked ? Colors.red : Colors.white54,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  UserListBottomSheet.show(
                    context,
                    title: 'A estas personas les gustó',
                    userIds: widget.post.likes,
                    communityId: widget.post.communityId,
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '$_likesCount',
                    style: TextStyle(
                      color: _isLiked ? Colors.red : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(
                    '$_commentsCount',
                    style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              if (widget.post.authorId != _currentUserId)
                IconButton(
                  icon: const Icon(Icons.volunteer_activism_rounded, size: 24, color: Colors.pinkAccent),
                  tooltip: 'Donar monedas',
                  onPressed: () {
                     if (_currentMemberProfile == null) {
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
                             id: widget.post.authorId,
                             username: _authorName ?? widget.post.authorName,
                             displayName: _authorName ?? widget.post.authorName,
                             avatarUrl: _authorAvatarUrl ?? widget.post.authorAvatarUrl,
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
                           postId: widget.post.id,
                           communityId: widget.post.communityId,
                         ),
                       ),
                     );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    if (_isLoadingComments) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'No hay comentarios aún. ¡Sé el primero!',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _comments.length,
      separatorBuilder: (context, index) => const Divider(color: Colors.white10, indent: 64),
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final isAuthor = comment.authorId == widget.post.authorId;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                userId: comment.authorId,
                avatarUrl: comment.authorAvatarUrl,
                displayName: comment.authorName, // Added
                communityId: widget.post.communityId,
                radius: 18,
                avatarFrameUrl: comment.authorAvatarFrameUrl, // NEW
              ),

              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                          onLongPress: () => _showCommentOptions(comment),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      comment.authorName,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  UserBadgeWidget(
                                    level: comment.authorLevel,
                                    titles: comment.authorTitles,
                                    role: comment.authorRole,
                                    fontSize: 8,
                                    showTitles: false,
                                  ),
                                  if (isAuthor) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Wumbleheme.secondaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Wumbleheme.secondaryColor.withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        'Autor',
                                        style: TextStyle(
                                          color: Wumbleheme.secondaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _showCommentOptions(comment),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 8.0),
                                      child: Icon(Icons.more_horiz, size: 18, color: Colors.white54),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _timeAgo(comment.createdAt),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinkifyText(
                                comment.content,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              if (comment.linkPreview != null && comment.linkPreview!.isNotEmpty)
                                LinkPreviewCard(data: comment.linkPreview!),
                            ],
                          ),
                        ),
                    if ((comment.imageUrl != null && comment.imageUrl!.isNotEmpty) || (comment.gifUrl != null && comment.gifUrl!.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageViewerScreen(imageUrl: comment.imageUrl ?? comment.gifUrl!),
                            ),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
                            child: CachedNetworkImage(
                              imageUrl: comment.imageUrl ?? comment.gifUrl!,
                              fit: BoxFit.contain,
                              placeholder: (context, _) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.white10,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (context, _, __) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.white10,
                                child: const Icon(Icons.error, color: Colors.white54, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (comment.stickerUrl != null && comment.stickerUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CachedNetworkImage(
                        imageUrl: MediaOptimizer.optimize(comment.stickerUrl!, width: 400, height: 400),
                        height: 100,
                        width: 100,
                        fit: BoxFit.contain,
                        placeholder: (context, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (context, _, __) => const Icon(Icons.broken_image, color: Colors.white24, size: 20),
                      ),
                    ],
                    _buildCommentReactions(comment),
                    const SizedBox(height: 4),
                    // Reply button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingTo = comment;
                        });
                        _commentFocusNode.requestFocus();
                      },
                      child: const Text(
                        'Responder',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Inner Replies
                    if (comment.replies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...comment.replies.map((reply) {
                        final isReplyAuthor = reply.authorId == widget.post.authorId;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserAvatar(
                                userId: reply.authorId,
                                avatarUrl: reply.authorAvatarUrl,
                                displayName: reply.authorName, // Added
                                communityId: widget.post.communityId,
                                radius: 12,
                                avatarFrameUrl: reply.authorAvatarFrameUrl, // NEW
                              ),

                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onLongPress: () => _showCommentOptions(reply, isReply: true, parentCommentId: comment.id),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  reply.authorName,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              UserBadgeWidget(
                                                level: reply.authorLevel,
                                                titles: reply.authorTitles,
                                                role: reply.authorRole,
                                                fontSize: 8,
                                                showTitles: false,
                                              ),
                                              if (isReplyAuthor) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Wumbleheme.secondaryColor.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Wumbleheme.secondaryColor.withOpacity(0.5)),
                                                  ),
                                                  child: Text('Autor', style: TextStyle(color: Wumbleheme.secondaryColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                              const Spacer(),
                                              GestureDetector(
                                                onTap: () => _showCommentOptions(reply, isReply: true, parentCommentId: comment.id),
                                                child: const Padding(
                                                  padding: EdgeInsets.only(left: 8.0),
                                                  child: Icon(Icons.more_horiz, size: 16, color: Colors.white54),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(_timeAgo(reply.createdAt), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          LinkifyText(reply.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                          if (reply.linkPreview != null && reply.linkPreview!.isNotEmpty)
                                            LinkPreviewCard(data: reply.linkPreview!),
                                        ],
                                      ),
                                    ),
                                    if ((reply.imageUrl != null && reply.imageUrl!.isNotEmpty) || (reply.gifUrl != null && reply.gifUrl!.isNotEmpty)) ...[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                                          child: CachedNetworkImage(
                                            imageUrl: MediaOptimizer.post(reply.imageUrl ?? reply.gifUrl!),
                                            fit: BoxFit.contain,
                                            placeholder: (context, _) => Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.white10,
                                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                            ),
                                            errorWidget: (context, _, __) => Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.white10,
                                              child: const Icon(Icons.error, color: Colors.white54, size: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (reply.stickerUrl != null && reply.stickerUrl!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      CachedNetworkImage(
                                        imageUrl: MediaOptimizer.optimize(reply.stickerUrl!, width: 300, height: 300),
                                        height: 80,
                                        width: 80,
                                        fit: BoxFit.contain,
                                        placeholder: (context, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        errorWidget: (context, _, __) => const Icon(Icons.broken_image, color: Colors.white24, size: 16),
                                      ),
                                    ],
                                    _buildCommentReactions(reply),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _replyingTo = comment; // Parent comment
                                          _commentController.text = '@${reply.authorName} ';
                                        });
                                        _commentFocusNode.requestFocus();
                                      },
                                      child: const Text(
                                        'Responder',
                                        style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentInputBox() {
    if (_currentMemberProfile == null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Wumbleheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_person_rounded, color: Wumbleheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contenido Protegido',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Únete para participar y comentar',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                       try {
                         final community = await _communityRepository.getCommunity(widget.post.communityId);
                         if (community != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommunityInfoScreen(community: community),
                              ),
                            );
                         }
                       } catch (e) {
                         debugPrint('Error fetching community: $e');
                       }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Wumbleheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('UNIRSE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_replyingTo != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Respondiendo a ${_replyingTo!.authorName}...',
                    style: TextStyle(color: Wumbleheme.secondaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.white54),
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (_selectedImage != null) ...[
             Stack(
               children: [
                 Container(
                   margin: const EdgeInsets.only(bottom: 12, left: 4),
                   height: 100,
                   width: 100,
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(12),
                     image: DecorationImage(
                       image: FileImage(_selectedImage!),
                       fit: BoxFit.cover,
                     ),
                   ),
                 ),
                 Positioned(
                   top: 4,
                   right: 4,
                   child: GestureDetector(
                     onTap: _removeSelectedImage,
                     child: const CircleAvatar(
                       radius: 12,
                       backgroundColor: Colors.black54,
                       child: Icon(Icons.close, size: 14, color: Colors.white),
                     ),
                   ),
                 ),
               ],
             ),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  _showStickers ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  color: _showStickers ? Wumbleheme.secondaryColor : Colors.white54,
                ),
                onPressed: () {
                  setState(() => _showStickers = !_showStickers);
                  if (_showStickers) FocusScope.of(context).unfocus();
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate, color: Colors.white54),
                onPressed: _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  onTap: () {
                    if (_showStickers) setState(() => _showStickers = false);
                  },
                  decoration: InputDecoration(
                    hintText: _replyingTo != null ? 'Escribe una respuesta...' : 'Añadir un comentario...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isUploadingImage 
               ? const Padding(
                   padding: EdgeInsets.all(12.0),
                   child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                 )
               : CircleAvatar(
                  backgroundColor: Wumbleheme.primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _addComment,
                  ),
                 ),
            ],
          ),
          if (_showStickers)
            RepositoryProvider.value(
              value: di.sl<ChatRepository>(),
              child: StickerSelector(
                onStickerSelected: _sendSticker,
                onCustomStickerCreated: _sendCustomSticker,
              ),
            ),
        ],
      ),
    );
  }

  void _reactToComment(PostComment comment, String reaction) {
    if (_currentUserId == null) return;
    
    if (_currentMemberProfile == null) {
      _showJoinPrompt();
      return;
    }

    _feedRepository.reactToComment(widget.post.id, comment.id, _currentUserId!, reaction).then((_) {
      if (mounted) _loadComments();
    });
  }

  void _showStickerCommentReactionPicker(PostComment comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Reaccionar con Sticker',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Expanded(
              child: StickerSelector(
                onStickerSelected: (url) {
                  Navigator.pop(ctx);
                  _reactToComment(comment, url);
                },
                onCustomStickerCreated: (file) {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentReactions(PostComment comment) {
    if (comment.reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: comment.reactions.entries.map((entry) {
          final reaction = entry.key;
          final userIds = entry.value;
          final hasReacted = userIds.contains(_currentUserId);
          final isStandardEmoji = !reaction.startsWith('http');

          return GestureDetector(
            onTap: () {
              UserListBottomSheet.show(
                context,
                title: isStandardEmoji ? 'Personas que reaccionaron $reaction' : 'Personas que reaccionaron',
                userIds: userIds,
                communityId: widget.post.communityId,
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
                  if (isStandardEmoji)
                    Text(reaction, style: const TextStyle(fontSize: 12))
                  else
                    CachedNetworkImage(
                      imageUrl: reaction,
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
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

  void _showFullEmojiCommentReactionPicker(PostComment comment) {
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
}
