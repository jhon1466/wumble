import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/profile/presentation/level_rank_screen.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';
import 'package:wumble/features/profile/presentation/edit_profile_screen.dart';
import 'package:wumble/features/chat/domain/chat_repository.dart';
import 'package:wumble/features/chat/presentation/chat_detail_screen.dart';
import 'package:wumble/features/auth/presentation/auth_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/reputation_service.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/features/profile/presentation/widgets/profile_widgets.dart';
import 'package:wumble/features/profile/presentation/widgets/user_labels_management_dialog.dart';
import 'package:wumble/features/feed/presentation/pages/drafts_list_screen.dart';
import 'package:wumble/features/chat/presentation/image_viewer_screen.dart';
import 'package:wumble/features/profile/presentation/settings_screen.dart';
import 'package:wumble/core/utils/media_optimizer.dart';

import 'package:wumble/features/profile/presentation/frame_shop_screen.dart';

class ProfileHeader extends StatelessWidget {
  final UserProfile user;
  final Map<String, String>? levelTitles;
  final String? communityId;
  final bool? isOwner;
  final bool isGlobal; // Guard for explicit isolation
  final String? communityCreatorId; // Owner (creator) of the active community

  ProfileHeader({
    super.key,
    required this.user,
    this.levelTitles,
    this.communityId,
    this.isOwner,
    this.isGlobal = false, // Default to false for backward compatibility but usually passed
    this.communityCreatorId,
  });

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = (MediaQuery.of(context).padding.top).toDouble();
    final double avatarRadius = 50;
    final bool effectiveIsOwner = isOwner ?? (FirebaseAuth.instance.currentUser?.uid == user.id);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            // Status bar spacer
            Container(
              height: statusBarHeight,
              color: Wumbleheme.surfaceColor,
            ),
            
            // Banner area
            GestureDetector(
              onTap: user.bannerUrl.isNotEmpty
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewerScreen(imageUrl: user.bannerUrl),
                        ),
                      )
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 440),
                decoration: BoxDecoration(
                  color: Wumbleheme.surfaceColor,
                  image: user.bannerUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(MediaOptimizer.banner(user.bannerUrl)),
                          fit: BoxFit.cover,
                          alignment: Alignment(0, (user.bannerAlignmentY ?? 0.0).toDouble()),
                        )
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                        Wumbleheme.backgroundColor.withOpacity(0.85),
                      ],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit/Logout buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                              tooltip: tr('Atrás'),
                            ),
                            if (effectiveIsOwner) ...[
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                offset: const Offset(0, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (value) {
                                  if (value == 'logout') {
                                    _handleLogout(context);
                                  } else if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(user: user, communityId: communityId),
                                      ),
                                    );
                                  } else if (value == 'drafts') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DraftsListScreen(communityId: communityId ?? 'global'),
                                      ),
                                    );
                                  } else if (value == 'status') {
                                    _showQuickStatusEditor(context, user, communityId);
                                  } else if (value == 'settings') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SettingsScreen(user: user),
                                      ),
                                    );
                                  } else if (value == 'frames') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FrameShopScreen(user: user),
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text(tr('Editar Perfil')),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'drafts',
                                    child: Row(
                                      children: [
                                        Icon(Icons.description_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text(tr('Borradores')),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'status',
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_reaction_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text(tr('Cambiar Estado')),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'frames',
                                    child: Row(
                                      children: [
                                        Icon(Icons.style_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text(tr('Inventario de Marcos')),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'settings',
                                    child: Row(
                                      children: [
                                        Icon(Icons.settings_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text(tr('Ajustes')),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'logout',
                                    child: Row(
                                      children: [
                                        Icon(Icons.logout, color: Colors.red, size: 20),
                                        SizedBox(width: 10),
                                        Text(tr('Cerrar Sesión'), style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (FirebaseAuth.instance.currentUser != null)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                onSelected: (value) {
                                  // Handle report or other actions
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Row(
                                      children: [
                                        Icon(Icons.report_problem_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text(tr('Reportar')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: statusBarHeight + 110),
          child: Column(
            children: [
              // Avatar + Status Area - Ultra-wide container to ensure FULL hit testing for the bubble
              SizedBox(
                width: 300, // Expanded to 280 to allow more room for right-positioned bubble
                height: 110,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter, // This centers the Avatar (non-positioned)
                  children: [
                    UserAvatar(
                      userId: user.id,
                      avatarUrl: user.avatarUrl,
                      displayName: user.displayName,
                      radius: avatarRadius,
                      communityId: communityId,
                      isClickable: true,
                      avatarFrameUrl: user.avatarFrameUrl,
                      onTap: user.avatarUrl.isNotEmpty
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ImageViewerScreen(imageUrl: user.avatarUrl)),
                              )
                          : null,
                      border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 2),
                    ),

                    // Status Bubble - Wide container for emoji + text status
                    // Status Bubble - Optimized for text only
                    if (effectiveIsOwner || (user.status != null && user.status!.isNotEmpty))
                    Positioned(
                      left: 140 + 30, // Adjusted to better fit the new bubble design
                      top: -20,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (user.status != null && user.status!.isNotEmpty) {
                            _showFullStatus(context, user.id, user.displayName, user.avatarUrl, null, user.status, communityId);
                          } else if (effectiveIsOwner) {
                            _showQuickStatusEditor(context, user, communityId);
                          }
                        },
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.4, // Dynamic width based on screen
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2D31), // Discord-like Status Bubble
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: (user.status != null && user.status!.isNotEmpty)
                              ? Text(
                                  user.status!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const Icon(Icons.add_comment_rounded, size: 20, color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 5),

              // Level Badge
              if (!isGlobal)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LevelRankScreen(
                          user: user,
                          levelTitles: levelTitles,
                          themeColor: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                    ),
                    child: Text(
                      'LV ${user.level} • ${ReputationService.getLevelTitle(user.level, levelTitles)}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),

              // Custom Labels (formerly titles)
              if (user.titles.isNotEmpty) ...[
                SizedBox(height: 10),
                GestureDetector(
                  onTap: FirebaseAuth.instance.currentUser?.uid == user.id 
                      ? () => _showLabelsManager(context, user) 
                      : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: user.titles.map((title) => ProfileTitleBadge(title: title)).toList(),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 8),

              // Display Name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (user.isBot) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tr('BOT'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),

                ],
              ),

              // Community role badge (owner / admin / moderator)
              if (!isGlobal && _roleBadge(user, communityCreatorId) != null) ...[
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final badge = _roleBadge(user, communityCreatorId)!;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: badge.colors),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: badge.colors.last.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badge.icon, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          badge.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Meta Data (Username + Joined)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    height: 25,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                        ),
                        if (user.joinedAt != null) ...[
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 8),
                          Text(
                            'Se unió en ${_formatDate(user.joinedAt!)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),


              SizedBox(height: 10),

              // Interaction Buttons
              if (FirebaseAuth.instance.currentUser?.uid != user.id)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FollowButton(targetUser: user),
                      const SizedBox(width: 16),
                      _ChatButton(targetUser: user, communityId: communityId),
                    ],
                  ),
                ),

              SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Cerrar Sesión')),
        content: Text(tr('¿Estás seguro de que quieres salir?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Salir'), style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true && context.mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // Determines the community role badge to show (owner / admin / moderator).
  _RoleBadge? _roleBadge(UserProfile u, String? creatorId) {
    final bool isCreator =
        creatorId != null && creatorId.isNotEmpty && creatorId == u.id;
    if (isCreator) {
      return _RoleBadge(
        label: tr('Dueño'),
        icon: Icons.workspace_premium,
        colors: [Color(0xFF8E2DE2), Color(0xFF7B1FA2)],
      );
    }
    switch (u.communityRole) {
      case 'leader':
        return _RoleBadge(
          label: tr('Admin'),
          icon: Icons.shield,
          colors: [Color(0xFFFFB300), Color(0xFFF57C00)],
        );
      case 'curator':
        return _RoleBadge(
          label: tr('Moderador'),
          icon: Icons.verified_user,
          colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
        );
      default:
        return null;
    }
  }

  void _showFullStatus(BuildContext context, String userId, String name, String avatarUrl, String? emoji, String? status, String? communityId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(0xFF000000), // Pure black as requested/in screenshot
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                'Estado de $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(
                  userId: userId,
                  avatarUrl: avatarUrl,
                  radius: 45,
                  showOnlineIndicator: false,
                  communityId: communityId,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2D31),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showQuickStatusEditor(BuildContext context, UserProfile user, String? communityId) {
    final TextEditingController controller = TextEditingController(text: user.status ?? '');
    String? selectedEmoji = user.statusEmoji;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: Color(0xFF18191C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('EDITAR ESTADO'),
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              SizedBox(height: 20),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: tr('¿Qué estás pensando?'),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    context.read<ProfileBloc>().add(
                      UpdateProfileRequested(
                        userId: user.id,
                        communityId: communityId,
                        status: controller.text,
                        statusEmoji: null,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(tr('Guardar Estado'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showLabelsManager(BuildContext context, UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => UserLabelsManagementDialog(
        user: user,
        communityId: communityId,
        onUpdate: (newLabels) {
          if (communityId != null) {
            context.read<ProfileBloc>().add(
                  UpdateProfileRequested(
                    userId: user.id,
                    communityId: communityId,
                    titles: newLabels,
                  ),
                );
          } else {
            // Global titles update logic if applicable
            context.read<ProfileBloc>().add(
                  UpdateProfileRequested(
                    userId: user.id,
                    titles: newLabels,
                  ),
                );
          }
        },
      ),
    );
  }
}

// ──── Follow Button ────

class _FollowButton extends StatelessWidget {
  final UserProfile targetUser;
  _FollowButton({required this.targetUser});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUser.id)
          .snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.hasData && snapshot.data!.exists;

        return SizedBox(
          width: 140,
          height: 42,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              gradient: isFollowing ? null : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  secondaryColor,
                  secondaryColor.withOpacity(0.8),
                ],
              ),
              boxShadow: isFollowing ? null : [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: isFollowing ? Border.all(color: secondaryColor.withOpacity(0.5), width: 1.5) : null,
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                if (isFollowing) {
                  context.read<ProfileBloc>().add(
                    UnfollowUserRequested(
                      currentUserId: currentUserId,
                      targetUserId: targetUser.id,
                    ),
                  );
                } else {
                  context.read<ProfileBloc>().add(
                    FollowUserRequested(
                      currentUserId: currentUserId,
                      targetUserId: targetUser.id,
                    ),
                  );
                }
              },
              icon: Icon(
                isFollowing ? Icons.how_to_reg_rounded : Icons.person_add_alt_1_rounded,
                size: 18,
                color: isFollowing ? secondaryColor : Colors.white,
              ),
              label: Text(
                isFollowing ? tr('SIGUIENDO') : tr('SEGUIR'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: isFollowing ? secondaryColor : Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.transparent : Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ──── Chat Button ────

class _ChatButton extends StatelessWidget {
  final UserProfile targetUser;
  final String? communityId;
  _ChatButton({required this.targetUser, this.communityId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 42,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            ),
            child: TextButton.icon(
              onPressed: () => _openChat(context),
              icon: Icon(Icons.forum_rounded, size: 18, color: Colors.white),
              label: Text(
                tr('CHAT'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatRepo = context.read<ChatRepository>();
      final firestore = FirebaseFirestore.instance;

      String currentUserName = 'Usuario';
      String currentUserAvatar = '';

      // Priority: Community Profile -> Global Profile
      if (communityId != null && communityId!.isNotEmpty) {
        final memberDoc = await firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(currentUser.uid)
            .get();
        
        if (memberDoc.exists) {
          final memberData = memberDoc.data()!;
          currentUserName = memberData['displayName'] ?? 'Usuario';
          currentUserAvatar = memberData['avatarUrl'] ?? '';
        } else {
          // Fallback to global
          final globalUserDoc = await firestore.collection('users').doc(currentUser.uid).get();
          final globalUserData = globalUserDoc.data() ?? {};
          currentUserName = globalUserData['displayName'] ?? globalUserData['username'] ?? 'Usuario';
          currentUserAvatar = globalUserData['avatarUrl'] ?? '';
        }
      } else {
        // Global context
        final globalUserDoc = await firestore.collection('users').doc(currentUser.uid).get();
        final globalUserData = globalUserDoc.data() ?? {};
        currentUserName = globalUserData['displayName'] ?? globalUserData['username'] ?? 'Usuario';
        currentUserAvatar = globalUserData['avatarUrl'] ?? '';
      }

      final room = await chatRepo.getOrCreateChatRoom(
        currentUserId: currentUser.uid,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
        otherUserId: targetUser.id,
        otherUserName: targetUser.displayName,
        otherUserAvatar: targetUser.avatarUrl,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatRoomId: room.id,
              otherUserName: targetUser.displayName,
              otherUserAvatar: targetUser.avatarUrl,
              otherUserId: targetUser.id,
              communityId: communityId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir chat: $errorMsg')),
        );
      }
    }
  }
}

class _RoleBadge {
  final String label;
  final IconData icon;
  final List<Color> colors;
  const _RoleBadge({
    required this.label,
    required this.icon,
    required this.colors,
  });
}
