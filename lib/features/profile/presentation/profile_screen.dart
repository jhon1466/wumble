import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';
import 'package:wumble/features/auth/presentation/auth_bloc.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/feed/presentation/pages/create_post_screen.dart';
import 'package:wumble/features/feed/presentation/wiki_editor_screen.dart';
import 'package:wumble/features/chat/presentation/image_viewer_screen.dart';
import 'package:wumble/features/profile/presentation/widgets/profile_header.dart';
import 'package:wumble/features/profile/presentation/widgets/profile_content_widgets.dart';
import 'package:wumble/features/profile/presentation/widgets/follows_list_screen.dart';
import 'package:wumble/features/profile/presentation/wallet_screen.dart';
import 'package:wumble/features/moderation/domain/moderation_models.dart';
import 'package:wumble/core/widgets/linkify_text.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  final String? userId;
  final String? communityId;
  final bool isGlobal;

  const ProfileScreen({
    super.key,
    this.userId,
    this.communityId,
    this.isGlobal = true,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUserId = userId ?? currentUserId ?? "";

    // REGLA ABSOLUTA: si isGlobal=true, communityId SIEMPRE es null.
    // No importa qué diga CommunityContextBloc.
    final String? effectiveCommunityId;
    if (isGlobal) {
      effectiveCommunityId = null;
    } else {
      // Usar el communityId explícito si se pasó; si no, obtener del contexto
      effectiveCommunityId = communityId ?? context.read<CommunityContextBloc>().state.activeCommunity?.id;
    }

    // ¿Es el perfil global del usuario actual? → usamos el ProfileBloc raíz (no crear uno nuevo)
    final isRootProfile = isGlobal && effectiveUserId == currentUserId && effectiveCommunityId == null;

    if (isRootProfile) {
      return _ProfileView(
        key: ValueKey('profile_${effectiveUserId}_none'),
        isGlobal: true,
        communityId: null,
        userId: effectiveUserId,
      );
    }

    // Cualquier otro caso: perfil de otro usuario, o perfil de comunidad
    return BlocProvider(
      key: ValueKey('profile_${effectiveUserId}_${effectiveCommunityId}'),
      create: (_) => di.sl<ProfileBloc>()
        ..add(LoadProfileRequested(effectiveUserId, communityId: effectiveCommunityId))
        ..add(LoadSanctionsRequested(effectiveUserId, communityId: effectiveCommunityId)),
      child: _ProfileView(
        key: ValueKey('view_${effectiveUserId}_${effectiveCommunityId}'),
        isGlobal: effectiveCommunityId == null,
        communityId: effectiveCommunityId,
        userId: effectiveUserId,
      ),
    );
  }
}

class _ProfileView extends StatefulWidget {
  final bool isGlobal;
  final String? communityId;
  final String? userId;
  const _ProfileView({super.key, required this.isGlobal, this.communityId, this.userId});

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  UserProfile? _lastUser;
  String? _lastLoadedCommunityId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return BlocListener<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfileActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            }
            if (state is ProfileError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, profileState) {
              return BlocBuilder<CommunityContextBloc, CommunityContextState>(
              builder: (context, contextState) {
                // ─── Obtener usuario del estado del ProfileBloc ───
                UserProfile? user;

                if (profileState is ProfileLoaded &&
                    profileState.communityId == widget.communityId) {
                  user = profileState.user;
                  _lastUser = user;
                  _lastLoadedCommunityId = widget.communityId;
                } else if (profileState is ProfileUpdateSuccess &&
                    profileState.communityId == widget.communityId) {
                  user = profileState.user;
                  _lastUser = user;
                  _lastLoadedCommunityId = widget.communityId;
                } else if (_lastUser != null &&
                    _lastLoadedCommunityId == widget.communityId) {
                  user = _lastUser;
                }

                // ─── Ownership ───
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                final isOwner = currentUid != null &&
                    (widget.userId == null || widget.userId == currentUid);

                // ─── Fusión de datos de comunidad (SOLO en contexto de comunidad) ───
                // En global, NUNCA mezclamos datos del CommunityContextBloc.
                if (!widget.isGlobal && user != null) {
                  final local = contextState.memberProfile;
                  if (local != null && isOwner) {
                    user = user.copyWith(
                      displayName: (local.displayName?.isNotEmpty == true)
                          ? local.displayName
                          : user.displayName,
                      avatarUrl: (local.avatarUrl?.isNotEmpty == true)
                          ? local.avatarUrl
                          : user.avatarUrl,
                      bannerUrl: (local.bannerUrl?.isNotEmpty == true)
                          ? local.bannerUrl
                          : user.bannerUrl,
                      backgroundUrl: (local.backgroundUrl?.isNotEmpty == true)
                          ? local.backgroundUrl
                          : user.backgroundUrl,
                      bio: (local.bio?.isNotEmpty == true) ? local.bio : user.bio,
                      status: local.status ?? user.status,
                      joinedAt: local.joinedAt,
                      reputation: local.reputation,
                      level: local.level,
                      titles: local.titles.isNotEmpty ? local.titles : user.titles,
                      communityRole: local.role,
                    );
                  }
                }

                if (user == null) {
                  return const Scaffold(
                    backgroundColor: Wumbleheme.backgroundColor,
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final effectiveUser = user;
                final effectiveBgUrl = effectiveUser.backgroundUrl;

                // ─── Determinación dinámica de pestañas ───
                final List<Map<String, dynamic>> visibleTabs = [
                  {'label': 'Muro', 'index': 0, 'widget': ProfileWall(user: effectiveUser, communityId: widget.communityId)},
                ];

                if (!widget.isGlobal) {
                  visibleTabs.add({'label': 'Posts', 'index': 1, 'widget': ProfilePosts(user: effectiveUser, communityId: widget.communityId)});
                  visibleTabs.add({'label': 'Personajes', 'index': 5, 'widget': ProfileWikis(user: effectiveUser, communityId: widget.communityId, ocOnly: true)});
                  visibleTabs.add({'label': 'Wiki', 'index': 2, 'widget': ProfileWikis(user: effectiveUser, communityId: widget.communityId)});
                }

                if (isOwner) {
                  visibleTabs.add({'label': 'Guardados', 'index': 3, 'widget': ProfileSavedPosts(user: effectiveUser)});
                }

                final bool showSanctions = isOwner || (authState.user?.uid == currentUid && (user.globalRole != 'user'));
                if (showSanctions) {
                  visibleTabs.add({
                    'label': 'Sanciones', 
                    'index': 4, 
                    'widget': _ProfileSanctions(sanctions: profileState is ProfileLoaded ? profileState.sanctions : [])
                  });
                }

                return DefaultTabController(
                  length: visibleTabs.length,
                  child: Scaffold(
                    backgroundColor: Wumbleheme.backgroundColor,
                    floatingActionButton: isOwner && !widget.isGlobal
                        ? FloatingActionButton(
                            onPressed: () =>
                                _showCreateMenu(context, contextState.activeCommunity?.id),
                            backgroundColor: Wumbleheme.secondaryColor,
                            child: const Icon(Icons.add, color: Colors.white),
                          )
                        : null,
                    body: Stack(
                      children: [
                        if (effectiveBgUrl.isNotEmpty)
                          Positioned.fill(
                            key: const ValueKey('profile_background_fixed_layer'),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.4),
                                BlendMode.darken,
                              ),
                              child: GestureDetector(
                                onTap: effectiveBgUrl.isNotEmpty
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ImageViewerScreen(imageUrl: effectiveBgUrl),
                                          ),
                                        )
                                    : null,
                                behavior: HitTestBehavior.opaque,
                                child: CachedNetworkImage(
                                  imageUrl: effectiveBgUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.transparent),
                                  errorWidget: (context, url, error) =>
                                      Container(color: Wumbleheme.backgroundColor),
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                ),
                              ),
                            ),
                          ),
  
                        // NestedScrollView como hijo no posicionado para definir el tamaño del Stack
                        NestedScrollView(
                          headerSliverBuilder: (context, innerBoxIsScrolled) {
                            return [
                              SliverToBoxAdapter(
                                child: ProfileHeader(
                                  communityId: widget.communityId,
                                  user: effectiveUser,
                                  isOwner: isOwner,
                                  isGlobal: widget.isGlobal,
                                  communityCreatorId:
                                      contextState.activeCommunity?.creatorId,
                                  levelTitles:
                                      contextState.activeCommunity?.id ==
                                              widget.communityId
                                          ? contextState.activeCommunity?.levelTitles
                                          : null,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    // --- CINTURÓN DE ESTADÍSTICAS ---
                                    ClipRRect(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.3),
                                            border: Border.symmetric(
                                              horizontal: BorderSide(
                                                color: Colors.white.withOpacity(0.1),
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildStatItem(
                                                  'Reputación',
                                                  '${effectiveUser.reputation}',
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .secondary),
                                              _buildStatItem(
                                                  'Seguidores',
                                                  '${effectiveUser.followers}',
                                                  Theme.of(context).colorScheme.secondary,
                                                  onTap: () => _handleFollowsTap(context, effectiveUser, 'followers'),
                                              ),
                                              _buildStatItem(
                                                  'Siguiendo',
                                                  '${effectiveUser.following}',
                                                  Theme.of(context).colorScheme.secondary,
                                                  onTap: () => _handleFollowsTap(context, effectiveUser, 'following'),
                                              ),
                                              _buildStatItem(
                                                  'Monedas',
                                                  '${effectiveUser.coins}',
                                                  Colors.yellowAccent,
                                                  onTap: () {
                                                     if (isOwner) {
                                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                                                     }
                                                  },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Wumbleheme.surfaceColor.withOpacity(
                                              effectiveUser.backgroundUrl.isNotEmpty
                                                  ? 0.9
                                                  : 1.0),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Biografía',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16, color: Colors.white)),
                                            const SizedBox(height: 10),
                                            LinkifyText(effectiveUser.bio,
                                                style: const TextStyle(
                                                    color:
                                                        Wumbleheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _TabBarDelegate(
                                  TabBar(
                                    isScrollable: true,
                                    tabAlignment: TabAlignment.start,
                                    indicatorColor: Colors.white,
                                    indicatorWeight: 2.5,
                                    indicatorSize: TabBarIndicatorSize.label,
                                    unselectedLabelColor: Colors.white.withOpacity(0.5),
                                    labelColor: Colors.white,
                                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                    // Padding calculado para que 3 pestañas llenen el ancho
                                    labelPadding: EdgeInsets.symmetric(
                                      horizontal: (MediaQuery.of(context).size.width / 3 - 36) / 2,
                                    ),
                                    dividerColor: Colors.white.withOpacity(0.08),
                                    tabs: visibleTabs.map((t) => Tab(text: t['label'])).toList(),
                                  ),
                                ),
                              ),

                            ];
                          },
                          body: TabBarView(
                            children: visibleTabs.map<Widget>((t) => t['widget'] as Widget).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  );
}

  Widget _buildStatItem(String label, String value, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.bold, 
              color: color,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              color: Colors.white70,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleFollowsTap(BuildContext context, UserProfile user, String type) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid == user.id;

    if (!isOwner && !user.showFollows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este usuario ha configurado su lista como privada.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Navegar a la pantalla de lista
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowsListScreen(
          userId: user.id,
          type: type,
          title: type == 'followers' ? 'Seguidores' : 'Siguiendo',
        ),
      ),
    );
  }

  void _showCreateMenu(BuildContext context, String? communityId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.article_outlined, color: Colors.white),
              title: const Text('Crear Post',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreatePostScreen(communityId: communityId ?? ''),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined,
                  color: Colors.white),
              title: const Text('Crear Wiki',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WikiEditorScreen(communityId: communityId ?? ''),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.face_retouching_natural,
                  color: Colors.white),
              title: const Text('Crear Personaje (OC)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WikiEditorScreen(communityId: communityId ?? '', isOC: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSanctions extends StatelessWidget {
  final List<Sanction> sanctions;

  const _ProfileSanctions({required this.sanctions});

  @override
  Widget build(BuildContext context) {
    if (sanctions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Este usuario no tiene sanciones registradas.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: sanctions.length,
      itemBuilder: (context, index) {
        final sanction = sanctions[index];
        final color = _getSanctionColor(sanction.type);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getSanctionIcon(sanction.type), color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    sanction.type.name.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sanction.communityId == null ? Colors.purple.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: sanction.communityId == null ? Colors.purple.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      sanction.communityId == null ? 'GLOBAL' : 'COMUNIDAD',
                      style: TextStyle(
                        color: sanction.communityId == null ? Colors.purpleAccent : Colors.lightBlueAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!sanction.isActive)
                    const Text('REVOCADA', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              Text(sanction.reason, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(sanction.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (sanction.expiresAt != null) ...[
                    const Text(' • ', style: TextStyle(color: Colors.white54)),
                    Text(
                      'Expira: ${DateFormat('dd/MM/yyyy').format(sanction.expiresAt!)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getSanctionColor(SanctionType type) {
    switch (type) {
      case SanctionType.warning: return Colors.orange;
      case SanctionType.strike: return Colors.redAccent;
      case SanctionType.ban: return Colors.black;
    }
  }

  IconData _getSanctionIcon(SanctionType type) {
    switch (type) {
      case SanctionType.warning: return Icons.warning_amber_rounded;
      case SanctionType.strike: return Icons.gavel_rounded;
      case SanctionType.ban: return Icons.block_rounded;
    }
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Wumbleheme.backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}


