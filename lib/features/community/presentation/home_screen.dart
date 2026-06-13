import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../domain/community_model.dart';
import 'bloc/community_bloc.dart';
import 'widgets/premium_community_card.dart';
import '../../auth/presentation/auth_bloc.dart';
import '../../profile/presentation/profile_bloc.dart';
import '../../profile/presentation/notifications_screen.dart';
import '../../profile/presentation/bloc/notification_count_bloc.dart';
import '../../../../core/theme.dart';
import 'community_screen.dart';
import 'package:wumble/core/widgets/premium_matte_background.dart';
import 'package:flutter/services.dart';
import '../domain/community_repository.dart';
import '../domain/community_member_model.dart';
import 'package:wumble/injection_container.dart';
import 'pages/community_info_screen.dart';
import 'pages/user_communities_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthBloc>().state;
    final communityState = context.read<CommunityBloc>().state;
    
    // Only load if authenticated and we don't already have communities loaded
    if (authState.status == AuthStatus.authenticated && authState.user != null) {
      if (communityState is! CommunityLoaded) {
        context.read<CommunityBloc>().add(LoadUserCommunities(authState.user!.uid));
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '¡Buenos días!';
    if (hour < 18) return '¡Buenas tardes!';
    return '¡Buenas noches!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Matte Gray Background
          const RepaintBoundary(child: PremiumMatteBackground()),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadData();
              },
              color: Wumbleheme.secondaryColor,
              backgroundColor: Wumbleheme.surfaceColor,
            child: CustomScrollView(
              cacheExtent: 800,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Builder(
                        builder: (context) {
                          final authUser = context.watch<AuthBloc>().state.user;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: BlocBuilder<ProfileBloc, ProfileState>(
                                  builder: (context, profileState) {
                                    String name = authUser?.displayName ?? 'Usuario';
                                    if (name == 'Usuario de Wumble') name = 'Usuario';
                                    String? avatarUrl;

                                    if (profileState is ProfileLoaded && profileState.isGlobal) {
                                      name = profileState.user.displayName;
                                      avatarUrl = profileState.user.avatarUrl;
                                    } else if (profileState is ProfileUpdateInProgress && profileState.user != null && profileState.isGlobal) {
                                      name = profileState.user!.displayName;
                                      avatarUrl = profileState.user!.avatarUrl;
                                    } else if (profileState is ProfileUpdateSuccess && profileState.isGlobal) {
                                      name = profileState.user.displayName;
                                      avatarUrl = profileState.user.avatarUrl;
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getGreeting(),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          name,
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1.0,
                                          ),
                                          maxLines: 2,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BlocBuilder<NotificationCountBloc, NotificationCountState>(
                                    builder: (context, state) {
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                                            onPressed: () {
                                              final userId = authUser?.uid;
                                              if (userId != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => NotificationsScreen(userId: userId),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          if (state.totalUnreadCount > 0)
                                            Positioned(
                                              right: 8,
                                              top: 8,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: Wumbleheme.backgroundColor, width: 2),
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 18,
                                                  minHeight: 18,
                                                ),
                                                child: Text(
                                                  state.totalUnreadCount > 99 ? '99+' : '${state.totalUnreadCount}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  BlocBuilder<ProfileBloc, ProfileState>(
                                    builder: (context, profileState) {
                                      String name = authUser?.displayName ?? 'Usuario';
                                      String? avatarUrl;
                                      if (profileState is ProfileLoaded && profileState.isGlobal) avatarUrl = profileState.user.avatarUrl;
                                      return _buildGlowingAvatar(avatarUrl, name);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Horizontal Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mis Comunidades',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const UserCommunitiesScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Ver todo',
                                style: TextStyle(
                                  color: Wumbleheme.secondaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Communities Grid
                  BlocBuilder<CommunityBloc, CommunityState>(
                    builder: (context, state) {
                      if (state is CommunityLoading) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (state is CommunityError) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('Error: ${state.message}')),
                        );
                      }

                      if (state is CommunityLoaded) {
                        if (state.communities.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(),
                          );
                        }

                        _animationController.forward();

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final community = state.communities[index];
                                return _buildAnimatedPremiumCard(community, index);
                              },
                              childCount: state.communities.length,
                            ),
                          ),
                        );
                      }

                      return const SliverToBoxAdapter(child: SizedBox());
                    },
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingAvatar(String? avatarUrl, String name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Wumbleheme.primaryColor.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Wumbleheme.primaryColor, Wumbleheme.secondaryColor],
          ),
        ),
        child: UserAvatar(
          userId: context.read<AuthBloc>().state.user?.uid ?? '',
          avatarUrl: avatarUrl ?? '',
          displayName: name,
          radius: 25,
          isClickable: true,
        ),
      ),
    );
  }

  Widget _buildAnimatedPremiumCard(Community community, int index) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: Interval((index * 0.1).clamp(0.0, 1.0), 1.0, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Interval((index * 0.1).clamp(0.0, 1.0), 1.0, curve: Curves.easeOut),
        )),
        child: PremiumCommunityCard(
          community: community,
          onLongPress: () => _showCommunityContextMenu(community),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.explore_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 20),
        const Text(
          'Aún no te has unido a ninguna unidad',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            // Ir a Explorar
          },
          child: const Text('Descubrir comunidades', style: TextStyle(color: Wumbleheme.secondaryColor)),
        ),
      ],
    );
  }

  void _showCommunityContextMenu(Community community) async {
    final authUser = context.read<AuthBloc>().state.user;
    if (authUser == null) return;

    // Fetch member profile to check mute status
    final memberProfile = await sl<CommunityRepository>().getMemberProfile(community.id, authUser.uid);
    if (!mounted) return;

    final bool isMuted = memberProfile?.isMuted ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161621).withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: community.themeColor.withOpacity(0.3), width: 2),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(community.iconUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${community.handle} • ${community.membersCount} miembros',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(color: Colors.white10, height: 1),
              
              // Actions
              _buildMenuOption(
                icon: isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                title: isMuted ? 'Activar notificaciones' : 'Silenciar notificaciones',
                color: isMuted ? Colors.greenAccent : Colors.orangeAccent,
                onTap: () {
                  Navigator.pop(context);
                  context.read<CommunityBloc>().add(ToggleCommunityNotifications(
                    communityId: community.id,
                    userId: authUser.uid,
                    mute: !isMuted,
                  ));
                },
              ),

              _buildMenuOption(
                icon: Icons.link_rounded,
                title: 'Copiar ID de comunidad',
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: community.handle));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ID copiado al portapapeles'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF2E2E3E),
                    ),
                  );
                },
              ),

              _buildMenuOption(
                icon: Icons.info_outline_rounded,
                title: 'Ver información',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityInfoScreen(community: community),
                    ),
                  );
                },
              ),

              _buildMenuOption(
                icon: Icons.exit_to_app_rounded,
                title: 'Abandonar comunidad',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _showLeaveConfirmation(community, authUser.uid);
                },
              ),
              
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color.withOpacity(0.9), size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(color: color.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w500),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLeaveConfirmation(Community community, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 12),
            const Text('¿Abandonar comunidad?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres dejar "${community.name}"? Los demás usuarios te extrañarán.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CommunityBloc>().add(LeaveCommunityEvent(
                communityId: community.id,
                userId: userId,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }
}


// Local widgets removed - using global PremiumMatteBackground
