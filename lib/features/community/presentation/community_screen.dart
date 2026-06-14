import 'dart:async';
import 'package:wumble/core/localization/translations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/community_context_bloc.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;
import '../../../../core/utils/share_helper.dart';
import '../../../../main.dart';

import '../../feed/presentation/widgets/community_feed_widget.dart';
import 'package:wumble/features/feed/presentation/widgets/status_creation_sheet.dart';
import '../../feed/presentation/pages/create_post_screen.dart';
import '../../feed/presentation/bloc/community_feed_bloc.dart';
import '../../feed/presentation/bloc/create_post_cubit.dart';
import '../../feed/presentation/wiki_editor_screen.dart';
import 'shared_folder_screen.dart';
import '../domain/community_model.dart';
import '../domain/community_member_model.dart';
import '../domain/navigation_tab_model.dart';
import '../domain/community_repository.dart';
import 'widgets/wiki_list_widget.dart';
import 'widgets/community_navigation_pill.dart';
import 'pages/banned_screen.dart';
import 'pages/community_settings_screen.dart';
import 'leaderboard_screen.dart';
import 'widgets/welcome_celebration_sheet.dart';
import 'widgets/level_up_celebration_sheet.dart';
import 'widgets/daily_check_in_dialog.dart';
import 'pages/members_list_screen.dart'; // Added
import 'widgets/community_activity_sheet.dart';
import 'pages/create_public_chat_screen.dart'; // Added
import 'widgets/public_chat_list_widget.dart'; // Added
import '../../profile/presentation/notifications_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../feed/presentation/widgets/quiz_list_widget.dart';
import '../../feed/presentation/widgets/poll_list_widget.dart';
import '../../feed/presentation/pages/create_quiz_screen.dart';
import '../../feed/presentation/pages/create_poll_screen.dart';
import '../../chat/presentation/image_viewer_screen.dart';
import '../../profile/domain/user_model.dart';
import '../../profile/domain/profile_repository.dart';
import 'widgets/member_mini_profile.dart';
import '../../profile/presentation/profile_bloc.dart';
import '../../auth/presentation/auth_bloc.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'pages/community_info_screen.dart';
import 'widgets/community_unread_badge.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Community community;
  final bool isNewlyCreated;
  final bool showWelcomeModal; // Agregado para mostrar el modal de bienvenida garantizado

  const CommunityDetailScreen({
    super.key, 
    required this.community,
    this.isNewlyCreated = false,
    this.showWelcomeModal = false,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _lastCheckInTrigger = 0;
  final Map<int, GlobalKey<CommunityFeedWidgetState>> _feedKeys = {};
  final Map<int, GlobalKey<WikiListWidgetState>> _wikiKeys = {};
  final Map<int, GlobalKey<QuizListWidgetState>> _quizKeys = {};
  final Map<int, GlobalKey<PollListWidgetState>> _pollKeys = {};
  bool _tabListenerAttached = false;
  int _currentTabIndex = 0;
  int? _lastLevel;

  // ── Optimization: drawer community list cached for widget lifetime ──
  Future<List<Community>>? _userCommunitiesFuture;

  final GlobalKey<SharedFolderScreenState> _sharedFolderKey = GlobalKey<SharedFolderScreenState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addObserver(this);
    
    // Get visible tabs for initial count (not sorting here as build will sort)
    final tabs = _getVisibleTabs(widget.community);


    // Cache the user communities list for the drawer (never re-fetched during screen lifetime)
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _userCommunitiesFuture =
          di.sl<CommunityRepository>().getUserCommunities(currentUserId);
    }

    // Set active community context
    context.read<CommunityContextBloc>().add(EnterCommunity(widget.community));

    if (widget.isNewlyCreated || widget.showWelcomeModal) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          WelcomeCelebrationSheet.show(context, widget.community);
        }
      });
    }

    _lastCheckInTrigger = context.read<CommunityContextBloc>().state.checkInCompletedTrigger;

    // Start tracking active time
  }


  @override
  void didUpdateWidget(covariant CommunityDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.community.id != widget.community.id) {
      _feedKeys.clear();
      
      // Update community context when community changes (reused widget)
      context.read<CommunityContextBloc>().add(EnterCommunity(widget.community));
      
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        _userCommunitiesFuture =
            di.sl<CommunityRepository>().getUserCommunities(currentUserId);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<CommunityContextBloc>().add(ExitCommunity());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommunityContextBloc, CommunityContextState>(
      listenWhen: (previous, current) {
        // Celebration for joining
        if (!previous.isNewlyJoined && current.isNewlyJoined) return true;
        
        // Celebration for leveling up
        if (previous.memberProfile != null && current.memberProfile != null) {
          if (current.memberProfile!.level > previous.memberProfile!.level) {
            return true;
          }
        }

        // Celebration for check-in
        if (previous.checkInCompletedTrigger < current.checkInCompletedTrigger) {
          return true;
        }
        
        // Handle leaving community (only if it's the same community and NOT newly joined)
        if (previous.memberProfile != null && 
            current.memberProfile == null && 
            !current.isLoading &&
            !current.isNewlyJoined && // Protective check for join replication lag
            previous.activeCommunity?.id == current.activeCommunity?.id) {
          return true;
        }

        // Welcome / Join success (Transition or initial true)
        if ((!previous.isNewlyJoined && current.isNewlyJoined) || 
            (current.isNewlyJoined && previous.activeCommunity?.id != current.activeCommunity?.id)) {
          return true;
        }

        return false;
      },
      listener: (context, state) {
        final community = state.activeCommunity ?? widget.community;
        
        if (state.isNewlyJoined) {
          WelcomeCelebrationSheet.show(context, community);
          context.read<CommunityContextBloc>().add(ClearJoinSuccess());
        }

        if (state.memberProfile == null && !state.isLoading) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Has abandonado ${community.name}'),
               backgroundColor: community.themeColor,
             ),
           );
           Navigator.of(context).pop();
           return;
        }

        if (state.memberProfile != null) {
          if (_lastLevel != null && state.memberProfile!.level > _lastLevel!) {
            LevelUpCelebrationSheet.show(context, community, state.memberProfile!.level);
          }
          _lastLevel = state.memberProfile!.level;
        }

        // Handle Check-in Celebration
        if (state.checkInCompletedTrigger > _lastCheckInTrigger) {
          DailyCheckInDialog.show(
            context, 
            community, 
            coinAmount: state.lastCoinReward ?? 0,
          );
          _lastCheckInTrigger = state.checkInCompletedTrigger;
        }
      },
      builder: (context, state) {
                   // Ensure we ONLY use data from the state IF it matches the current navigation ID
                   // This prevents showing Community A's tabs while switching to Community B.
                   final community = (state.activeCommunity?.id == widget.community.id)
                       ? state.activeCommunity!
                       : widget.community;

                   final visibleTabs = _getVisibleTabs(community);

                  if (state.memberProfile?.isBanned == true) {
                    return BannedScreen(
                      community: community,
                      expiresAt: state.memberProfile?.banExpiresAt,
                    );
                  }

                  return DefaultTabController(
                    key: ValueKey('tab_controller_${community.id}_${visibleTabs.length}'),
                    length: visibleTabs.length,
                    child: Builder(
                      builder: (tabContext) {
                        // Update local state when tab changes for creator pill only
                        final tc = DefaultTabController.of(tabContext);
                        if (!_tabListenerAttached && tc != null) {
                          _tabListenerAttached = true;
                          tc.addListener(() {
                            if (!tc.indexIsChanging && mounted) {
                              if (_currentTabIndex != tc.index) {
                                HapticFeedback.selectionClick();
                                setState(() => _currentTabIndex = tc.index);
                              }
                            }
                          });
                        }

                        return Scaffold(
                          key: _scaffoldKey,
                          drawer: _buildDrawer(tabContext, community),
                          body: Stack(
                            children: [
                      // 1. Immersive Background Layer for Members
                      if (community.backgroundUrl.isNotEmpty || community.bannerUrl.isNotEmpty)
                        Positioned.fill(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CachedNetworkImage(
                                  imageUrl: community.backgroundUrl.isNotEmpty 
                                      ? community.backgroundUrl 
                                      : community.bannerUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 600, 
                                  memCacheHeight: 1200,
                                ),
                              ),
                              Positioned.fill(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: Container(
                                    color: Colors.black.withOpacity(0.65),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  community.themeColor.withOpacity(0.3),
                                  Wumbleheme.backgroundColor,
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 2. Main Content
                      CustomScrollView(
                        slivers: [
                          // Compact Header
                          SliverAppBar(
                            pinned: true,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            flexibleSpace: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(color: Colors.black.withOpacity(0.15)),
                              ),
                            ),
                            leading: IconButton(
                                  icon: const Icon(Icons.menu, color: Colors.white),
                                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                ),
                            title: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: community.iconUrl.isNotEmpty
                                          ? () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ImageViewerScreen(imageUrl: community.iconUrl),
                                                ),
                                              )
                                          : null,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(9),
                                          border: Border.all(color: Colors.white24, width: 1),
                                          image: community.iconUrl.isNotEmpty
                                              ? DecorationImage(image: CachedNetworkImageProvider(community.iconUrl), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: community.iconUrl.isEmpty ? const Icon(Icons.group, size: 16, color: Colors.white) : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            community.name,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            actions: state.memberProfile != null
                              ? [
                                  _HeaderIconButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    onTap: () {
                                      final chatIndex = visibleTabs.indexWhere((t) => t.type == NavigationTabType.chats);
                                      if (chatIndex != -1) {
                                        DefaultTabController.of(tabContext)!.animateTo(chatIndex);
                                      }
                                    },
                                  ),
                                  _HeaderIconButton(
                                    icon: Icons.notifications_none_rounded,
                                    onTap: () {
                                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                      if (currentUserId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => NotificationsScreen(userId: currentUserId),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  _HeaderIconButton(
                                    icon: Icons.more_horiz_rounded,
                                    onTap: () => _showCommunityOptions(context, state.memberProfile),
                                  ),
                                  const SizedBox(width: 8),
                                ]
                              : [],
                          ),

                          // Navigation Pills (Always visible)
                          SliverPersistentHeader(
                              pinned: true,
                              delegate: _SliverAppBarDelegate(
                                PreferredSize(
                                  preferredSize: const Size.fromHeight(60),
                                  child: Container(
                                    height: 60,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Builder(
                                      builder: (context) {
                                        final tc2 = DefaultTabController.of(context);
                                        if (tc2 == null) return const SizedBox();
                                        
                                        return TabBar(
                                          controller: tc2,
                                          isScrollable: true,
                                          tabAlignment: TabAlignment.start,
                                          indicator: const BoxDecoration(), // No default indicator
                                          dividerColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          labelPadding: const EdgeInsets.only(right: 10),
                                          tabs: visibleTabs.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final tab = entry.value;
                                            return _CategoryPill(
                                              label: tab.title,
                                              icon: _getTabIcon(tab.type),
                                              index: index,
                                              controller: tc2,
                                              color: community.themeColor,
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // No spacing needed when pills are always visible

                          // Content Area
                          SliverFillRemaining(
                              child: _LazyTabBarView(
                                memberProfile: state.memberProfile,
                                community: community,
                                tabs: visibleTabs,
                                feedKeys: _feedKeys,
                                wikiKeys: _wikiKeys,
                                quizKeys: _quizKeys,
                                pollKeys: _pollKeys,
                                sharedFolderKey: _sharedFolderKey,
                              ),
                          ),
                        ],
                      ),

                      // 3. Navigation Overlay (Floating Pill - Always visible)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: CommunityNavigationPill(
                              themeColor: community.themeColor,
                              isMember: state.memberProfile != null,
                              communityId: community.id,
                                activeTabType: (visibleTabs.length > _currentTabIndex) 
                                    ? visibleTabs[_currentTabIndex].type 
                                    : visibleTabs.first.type,
                                onMenuTap: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                                onPlusTap: () async {
                                  final result = await _showCreateMenu(context, community);
                                  if (result == true) {
                                    // Refresh current tab
                                    final currentIdx = _currentTabIndex < visibleTabs.length ? _currentTabIndex : 0;
                                    final activeTab = visibleTabs[currentIdx];
                                    
                                    if (activeTab.type == NavigationTabType.featured || 
                                        activeTab.type == NavigationTabType.recent || 
                                        activeTab.type == NavigationTabType.category) {
                                      _feedKeys[currentIdx]?.currentState?.refresh();
                                    } else if (activeTab.type == NavigationTabType.wikis) {
                                      _wikiKeys[currentIdx]?.currentState?.refresh();
                                    } else if (activeTab.type == NavigationTabType.quizzes) {
                                      _quizKeys[currentIdx]?.currentState?.refresh();
                                    } else if (activeTab.type == NavigationTabType.polls) {
                                      _pollKeys[currentIdx]?.currentState?.refresh();
                                    } else {
                                      // Force list widgets to refresh by updating state if no key found
                                      setState(() {}); 
                                    }
                                  }
                                },
                              onMembersTap: () {
                                showCommunityActivity(context, community);
                              },
                              onJoinTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommunityInfoScreen(
                                      community: community,
                                      fromCommunityDetail: true,
                                    ),
                                  ),
                                );
                              },
                              onCreateTap: () async {
                                final currentIdx = _currentTabIndex < visibleTabs.length ? _currentTabIndex : 0;
                                final activeTab = visibleTabs[currentIdx];
                                switch (activeTab.type) {
                                  case NavigationTabType.featured:
                                  case NavigationTabType.recent:
                                  case NavigationTabType.category:
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreatePostScreen(communityId: community.id),
                                      ),
                                    );
                                    if (result == true) {
                                      // Refrescar el feed de la pestaña actual a través de su Key
                                      _feedKeys[_currentTabIndex]?.currentState?.refresh();
                                    }
                                    break;
                                  case NavigationTabType.chats:
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreatePublicChatScreen(
                                          communityId: community.id,
                                          themeColor: community.themeColor,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      setState(() {}); 
                                    }
                                    break;
                                  case NavigationTabType.wikis:
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => WikiEditorScreen(
                                          communityId: community.id,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      setState(() {}); // Refresh list
                                    }
                                    break;
                                  case NavigationTabType.quizzes:
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreateQuizScreen(
                                          communityId: community.id,
                                          themeColor: community.themeColor,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      setState(() {}); // Refresh list
                                    }
                                    break;
                                  case NavigationTabType.sharedFolder:
                                    _sharedFolderKey.currentState?.pickAndUploadImage();
                                    break;
                                  case NavigationTabType.polls:
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreatePollScreen(
                                          communityId: community.id,
                                          themeColor: community.themeColor,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      setState(() {}); // Refresh list
                                    }
                                    break;
                                  default:
                                    // Handle others
                                    break;
                                }
                              },
                            ),
                      ),

                      // 4. Landing View Overlay removed in favor of guest browsing

                      // Loading Overlay
                      if (state.isLoading)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
  }

  void _navigateToTab(BuildContext context, List<CommunityNavigationTab> tabs, NavigationTabType type) {
    final index = tabs.indexWhere((t) => t.type == type);
    if (index != -1) {
      HapticFeedback.selectionClick();
      DefaultTabController.of(context).animateTo(index);
    }
  }

  List<CommunityNavigationTab> _getVisibleTabs(Community community) {
    if (community.navigationTabs.isEmpty) {
      return Community.defaultTabs;
    }
    return community.navigationTabs
        .where((t) => !t.isHidden)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Widget _buildLandingView(BuildContext context, Community community, CommunityContextState state) {
    // Definir estado del botón
    final isPrivate = community.privacy == 'private';
    final isPending = state.hasPendingRequest;
    final canJoin = !isPrivate && !isPending;
    
    String buttonText = 'Unirse';
    if (isPending) buttonText = 'Pendiente';
    else if (isPrivate) buttonText = 'Privada';
    else if (community.privacy == 'approval') buttonText = 'Solicitar';

    final String? bgUrl = community.backgroundUrl.isNotEmpty 
        ? community.backgroundUrl 
        : (community.bannerUrl.isNotEmpty ? community.bannerUrl : null);
    final bool hasImageBg = bgUrl != null;

    return Positioned.fill(
      child: Stack(
        children: [
          if (hasImageBg)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bgUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Wumbleheme.backgroundColor),
                errorWidget: (context, url, error) => Container(color: Wumbleheme.backgroundColor),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      community.themeColor.withOpacity(0.4),
                      Wumbleheme.backgroundColor,
                    ],
                  ),
                ),
              ),
            ),

          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.black.withOpacity(0.65),
              ),
            ),
          ),

          Positioned.fill(
            child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner y Botones Flotantes ──
              SizedBox(
                height: 220, // Altura total: 180 (banner) + 40 (botones sobresaliendo)
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner Header
                    Positioned(
                      top: 0, left: 0, right: 0, height: 180,
                      child: GestureDetector(
                        onTap: community.bannerUrl.isNotEmpty
                            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: community.bannerUrl)))
                            : null,
                        child: ShaderMask(
                          shaderCallback: (rect) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black, Colors.transparent],
                              stops: [0.2, 0.9], // Balanced fade-out to show blur behind buttons
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.dstIn,
                          child: Container(
                            decoration: BoxDecoration(
                              color: community.themeColor.withOpacity(0.15),
                              image: community.bannerUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(community.bannerUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Botón de Volver (Seguridad para navegación)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),

                    // Avatar Inset & Botones
                    Positioned(
                      top: 140, // 180 (banner) - 40 (mitad del avatar)
                      left: 16,
                      right: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar Cuadrado Redondeado
                          GestureDetector(
                            onTap: community.iconUrl.isNotEmpty
                                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: community.iconUrl)))
                                : null,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Wumbleheme.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Wumbleheme.backgroundColor, width: 4),
                                image: community.iconUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(community.iconUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: community.iconUrl.isEmpty ? const Icon(Icons.group, size: 40, color: Colors.white54) : null,
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Botón de Compartir
                          Container(
                            margin: const EdgeInsets.only(right: 8, bottom: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
                              onPressed: () {
                                final String shareUrl = 'https://wumble.link/c/${community.handle ?? community.id}';
                                final String shareText = '¡Mira esta comunidad en Wumble!\n$shareUrl\n\n${community.name}\n${community.description}';
                                
                                ShareHelper.share(
                                  context: context,
                                  text: shareText,
                                  subject: community.name,
                                  imageUrl: community.iconUrl,
                                );
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          
                          // Botón de Opciones (...)
                          Container(
                            margin: const EdgeInsets.only(right: 8, bottom: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                              onPressed: () {
                                _showCommunityOptions(context, state.memberProfile);
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          
                          // Botón de Unirse
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ElevatedButton(
                              onPressed: canJoin ? () => context.read<CommunityContextBloc>().add(JoinCommunityRequested()) : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canJoin ? community.themeColor : Colors.grey[800],
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white54,
                                disabledBackgroundColor: Colors.grey[800],
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(
                                buttonText,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 10), // Reduced space since stack height encapsulates the buttons

              
              // ── Info Principal ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      community.name,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    
                    // Meta Data
                    Text(
                      '${community.membersCount} miembros · Creado el ${community.createdAt.day}/${community.createdAt.month}/${community.createdAt.year}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    
                    // Creador (Tagline visual)
                    StreamBuilder<UserProfile>(
                      stream: di.sl<ProfileRepository>().getUserProfile(community.creatorId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final creator = snapshot.data!;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              avatarUrl: creator.avatarUrl,
                              radius: 10,
                              avatarFrameUrl: creator.avatarFrameUrl,
                              showOnlineIndicator: false,
                              userId: creator.id,
                              isClickable: true,
                            ),
                            const SizedBox(width: 8),
                            Text(tr('Creado por '), style: TextStyle(color: Colors.white54, fontSize: 13)),
                            Text(
                              creator.displayName,
                              style: TextStyle(color: community.themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(' ✿', style: TextStyle(color: Colors.pinkAccent, fontSize: 12)),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // ── Topics ──
                    Text(tr('Categorías'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (community.category.isNotEmpty)
                          _buildTopicPill(community.category.trim(), community.themeColor),
                        if (community.privacy == 'open') _buildTopicPill('Abierta', Colors.green),
                        if (community.privacy == 'approval') _buildTopicPill('Solo Solicitudes', Colors.orange),
                        if (community.privacy == 'private') _buildTopicPill('Privada', Colors.red),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // ── Descripción Larga ──
                    Text(tr('Descripción'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text(
                      community.description.isEmpty 
                        ? '¡Bienvenidos a nuestra comunidad!\n\nÚnete para interactuar con nosotros, ver las últimas novedades y disfrutar de todo el contenido.'
                        : community.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                    ),
                    
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
}

  Widget _buildTopicPill(String text, Color baseColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: baseColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDrawer(BuildContext tabContext, Community community) {
    return BlocBuilder<CommunityContextBloc, CommunityContextState>(
      builder: (context, state) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final visibleTabs = _getVisibleTabs(community);
        
        return Drawer(
          backgroundColor: Colors.transparent, 
          child: Stack(
            children: [
              // 1. Immersive Drawer Background
              if (community.backgroundUrl.isNotEmpty) 
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: community.backgroundUrl,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.4),
                    colorBlendMode: BlendMode.darken,
                  ),
                )
              else 
                Positioned.fill(
                  child: Container(color: Wumbleheme.backgroundColor),
                ),

              // Frosted glass blur effect
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.7)),
              ),

              Row(
                children: [
                  if (currentUserId != null)
                    _buildCommunitiesSidebar(context, currentUserId, community),
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // --- 1. Community Top Bar ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      community.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
                                ],
                              ),
                            ),
                          ),

                          // --- 2. User Profile Header ---
                          if (state.memberProfile != null) 
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  UserAvatar(
                                    userId: state.memberProfile!.userId,
                                    avatarUrl: state.memberProfile!.avatarUrl ?? '',
                                    displayName: state.memberProfile!.displayName ?? '',
                                    radius: 45,
                                    communityId: community.id,
                                    isAnimated: true,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    state.memberProfile!.displayName ?? 'Usuario',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  // Username & IDs row
                                  Builder(
                                    builder: (context) {
                                      final profileState = context.read<ProfileBloc>().state;
                                      String? username;
                                      int followersCount = 0;
                                      int followingCount = 0;

                                      if (profileState is ProfileLoaded) {
                                        username = profileState.user.username;
                                        followersCount = profileState.user.followers;
                                        followingCount = profileState.user.following;
                                      }
                                      
                                      // Fallback username if null
                                      username ??= (state.memberProfile!.displayName ?? 'usuario').toLowerCase().replaceAll(' ', '_');

                                      return Column(
                                        children: [
                                          Text(
                                            '@$username',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8), // Better visibility
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          // Stats Row: Seguidores | Siguiendo (REAL DATA)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _buildStatItem('$followersCount', 'Seguidores'),
                                              _buildStatDivider(),
                                              _buildStatItem('$followingCount', 'Siguiendo'),
                                              _buildStatDivider(),
                                              _buildStatItem('${community.membersCount}', 'Miembros'),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                          // --- 3. Scrollable Navigation List ---
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                if (state.memberProfile != null) ...[
                                  _buildCheckInCard(context, state.memberProfile!, community),
                                  const Divider(color: Colors.white12, height: 1),
                                ],
                                ListTile(
                                  leading: const Icon(Icons.home_rounded, color: Colors.white70),
                                  title: Text(tr('Inicio'), style: TextStyle(color: Colors.white)),
                                  onTap: () => Navigator.pop(context),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.chat_bubble_rounded, color: Colors.white70),
                                  title: Text(tr('Mis Chats'), style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToTab(tabContext, visibleTabs, NavigationTabType.chats);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.emoji_events_rounded, color: Colors.white70),
                                  title: Text(tr('Líderes'), style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToTab(tabContext, visibleTabs, NavigationTabType.leaderboard);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.people_alt_rounded, color: Colors.white70),
                                  title: Text(tr('Miembros'), style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    showCommunityActivity(context, community);
                                  },
                                ),
                                const Divider(color: Colors.white10, height: 1),
                                ListTile(
                                  leading: const Icon(Icons.menu_book_rounded, color: Colors.white70),
                                  title: Text(tr('Wiki'), style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToTab(tabContext, visibleTabs, NavigationTabType.wikis);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.quiz_outlined, color: Colors.white70),
                                  title: Text(tr('Quizzes'), style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToTab(tabContext, visibleTabs, NavigationTabType.quizzes);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.folder_shared_outlined, color: Colors.white70),
                                  title: Text(tr('Carpeta Compartida'), style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToTab(tabContext, visibleTabs, NavigationTabType.sharedFolder);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.poll_outlined, color: Colors.white70),
                                  title: Text(tr('Encuestas'), style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToTab(tabContext, visibleTabs, NavigationTabType.polls);
                                  },
                                ),
                                const Divider(color: Colors.white10),
                                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommunitiesSidebar(BuildContext context, String currentUserId, Community currentCommunity) {
    return Container(
      width: 72,
      color: Colors.black.withOpacity(0.3), // Darker Sidebar background
      child: SafeArea(
        child: FutureBuilder<List<Community>>(
          future: _userCommunitiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final communities = snapshot.data ?? [];
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: communities.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = communities[index];
                      final isCurrent = c.id == currentCommunity.id;
                      
                      return GestureDetector(
                        onTap: () {
                          if (!isCurrent) {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => CommunityDetailScreen(community: c)),
                            );
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: isCurrent ? Border.all(color: c.themeColor, width: 2) : null,
                                color: c.themeColor,
                                image: c.iconUrl.isNotEmpty 
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(c.iconUrl), 
                                      fit: BoxFit.cover
                                    ) 
                                  : null,
                              ),
                              child: c.iconUrl.isEmpty ? const Icon(Icons.group, color: Colors.white) : null,
                            ),
                            // Real notification badge
                            if (!isCurrent) 
                              Positioned(
                                top: -4,
                                right: 6,
                                child: CommunityUnreadBadge(communityId: c.id),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Sidebar Action Buttons (Home and Discovery)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      // Home button: Returns to global hub
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // close drawer
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context); // back to home
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.home_rounded, color: Colors.white54, size: 28),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Discover button
                      GestureDetector(
                        onTap: () {
                          // Navigate back to the home screen explicitly on the Explore tab
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const MainScaffold(initialIndex: 1)),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.explore_rounded, color: Colors.white54, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<bool?> _showCreateMenu(BuildContext context, Community community) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161621).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                '¿QUÉ QUIERES CREAR?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 16,
                children: [
                  _buildCreateOption(
                    context,
                    icon: Icons.chat_outlined,
                    label: 'Estado',
                    color: Colors.pinkAccent,
                    onTap: () async {
                      final bloc = context.read<CommunityContextBloc>();
                      final memberProfile = bloc.state.memberProfile;
                      final result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => MultiBlocProvider(
                          providers: [
                            BlocProvider.value(value: bloc),
                            BlocProvider(create: (_) => di.sl<CreatePostCubit>()),
                          ],
                          child: StatusCreationSheet(
                            communityId: community.id,
                            communityAvatarUrl: memberProfile?.avatarUrl,
                            communityAvatarFrameUrl: memberProfile?.avatarFrameUrl,
                          ),
                        ),
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                  _buildCreateOption(
                    context,
                    icon: Icons.edit_note_rounded,
                    label: 'Blog',
                    color: Colors.blueAccent,
                    onTap: () async {
                      final result = await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => CreatePostScreen(communityId: community.id))
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                  _buildCreateOption(
                    context,
                    icon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                    color: Colors.greenAccent,
                    onTap: () async {
                      final result = await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => CreatePublicChatScreen(
                          communityId: community.id, 
                          themeColor: community.themeColor
                        ))
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                  _buildCreateOption(
                    context,
                    icon: Icons.menu_book_rounded,
                    label: 'Wiki',
                    color: Colors.orangeAccent,
                    onTap: () async {
                      final result = await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => WikiEditorScreen(communityId: community.id))
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                  _buildCreateOption(
                    context,
                    icon: Icons.face_retouching_natural,
                    label: 'Personaje',
                    color: Colors.deepPurpleAccent,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WikiEditorScreen(
                            communityId: community.id,
                            isOC: true,
                          ),
                        ),
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                  _buildCreateOption(
                    context,
                    icon: Icons.quiz_rounded,
                    label: 'Quiz',
                    color: Colors.purpleAccent,
                    onTap: () async {
                      final result = await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => CreateQuizScreen(
                          communityId: community.id, 
                          themeColor: community.themeColor
                        ))
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                  _buildCreateOption(
                    context,
                    icon: Icons.poll_rounded,
                    label: 'Encuesta',
                    color: Colors.tealAccent,
                    onTap: () async {
                      final result = await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => CreatePollScreen(
                          communityId: community.id, 
                          themeColor: community.themeColor
                        ))
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                  _buildCreateOption(
                    context,
                    icon: Icons.sensors_rounded,
                    label: 'En Vivo',
                    color: Colors.redAccent,
                    enabled: false,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: () {
        if (enabled) {
          Navigator.pop(context);
          onTap();
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: enabled ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled ? color.withOpacity(0.4) : Colors.white10,
                width: 1.5,
              ),
              boxShadow: enabled ? [
                BoxShadow(color: color.withOpacity(0.1), blurRadius: 12, spreadRadius: 0),
              ] : [],
            ),
            child: Icon(icon, color: enabled ? color : Colors.white24, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white.withOpacity(0.9) : Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showCommunityOptions(BuildContext context, CommunityMember? member) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = currentUser?.uid == widget.community.creatorId;
    final isLeader = member?.role == 'leader' || member?.role == 'creator' || isCreator;

    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          
          ListTile(
            leading: const Icon(Icons.share_rounded, color: Colors.white),
            title: Text(tr('Compartir Comunidad'), style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              final String shareUrl = 'https://wumble.link/c/${widget.community.handle ?? widget.community.id}';
              final String shareText = '¡Mira esta comunidad en Wumble!\n$shareUrl\n\n${widget.community.name}\n${widget.community.description}';
              
              ShareHelper.share(
                context: context,
                text: shareText,
                subject: widget.community.name,
                imageUrl: widget.community.iconUrl,
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: Colors.white),
            title: Text(tr('Información y Guías'), style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommunityInfoScreen(
                    community: widget.community,
                    fromCommunityDetail: true,
                  ),
                ),
              );
            },
          ),
          
          if (isLeader)
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white),
              title: Text(tr('Ajustes de Comunidad'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunitySettingsScreen(
                      community: widget.community,
                      member: member,
                    ),
                  ),
                );
              },
            ),
            
          if (member != null)
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
              title: Text(tr('Abandonar Comunidad'), style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                final bloc = context.read<CommunityContextBloc>();
                Navigator.pop(context); // Close bottom sheet
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: Wumbleheme.surfaceColor,
                    title: Text(tr('¿Abandonar Comunidad?'), style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Perderás tu rango y progreso en esta comunidad. ¿Estás seguro de que quieres salir?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // Close dialog
                          bloc.add(LeaveCommunityRequested());
                        },
                        child: Text(tr('Abandonar'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),

          const Divider(color: Colors.white10),
          
          ListTile(
            leading: const Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
            title: Text(tr('Reportar Comunidad'), style: TextStyle(color: Colors.orangeAccent)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reporte enviado correctamente. El equipo de moderación lo revisará pronto.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18, // Reduced slightly to fit 3 items
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11, // Reduced slightly to fit 3 items
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white24,
    );
  }

  Widget _buildCheckInCard(BuildContext context, CommunityMember member, Community community) {
    bool hasCheckedInToday = false;
    if (member.lastCheckIn != null) {
      final now = DateTime.now();
      hasCheckedInToday = member.lastCheckIn!.year == now.year &&
          member.lastCheckIn!.month == now.month &&
          member.lastCheckIn!.day == now.day;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          decoration: BoxDecoration(
            color: hasCheckedInToday 
                ? Colors.green.withOpacity(0.1) 
                : community.themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasCheckedInToday 
                  ? Colors.green.withOpacity(0.3) 
                  : community.themeColor.withOpacity(0.3),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: hasCheckedInToday 
                  ? null 
                    : () {
                        context.read<CommunityContextBloc>().add(CheckInRequested());
                        _scaffoldKey.currentState?.closeDrawer();
                      },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasCheckedInToday ? Colors.green : community.themeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasCheckedInToday ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasCheckedInToday ? '¡YA HAS HECHO CHECK-IN!' : 'CHECK-IN DIARIO',
                            style: TextStyle(
                              color: hasCheckedInToday ? Colors.green : community.themeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            hasCheckedInToday ? 'Vuelve mañana para más rep.' : 'Gana +15 de reputación hoy',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (!hasCheckedInToday)
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTabIcon(NavigationTabType type) {
    switch (type) {
      case NavigationTabType.featured:
        return Icons.label_important_outline_rounded;
      case NavigationTabType.recent:
        return Icons.access_time_rounded;
      case NavigationTabType.chats:
        return Icons.chat_bubble_outline_rounded;
      case NavigationTabType.wikis:
        return Icons.menu_book_rounded;
      case NavigationTabType.quizzes:
        return Icons.quiz_outlined;
      case NavigationTabType.polls:
        return Icons.poll_outlined;
      case NavigationTabType.sharedFolder:
        return Icons.folder_shared_outlined;
      case NavigationTabType.leaderboard:
        return Icons.emoji_events_outlined;
      case NavigationTabType.externalLink:
        return Icons.link_rounded;
      case NavigationTabType.category:
        return Icons.category_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
        splashRadius: 20,
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index;
  final TabController? controller;
  final Color color;
  final VoidCallback? onTap;

  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.index,
    this.controller,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null) return const SizedBox();
    return AnimatedBuilder(
      animation: controller!,
      builder: (context, _) {
        final isActive = controller?.index == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.24) : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isActive ? color.withOpacity(0.5) : Colors.white10,
              width: 1.5,
            ),
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: -2)] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : Colors.white60),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSize child;

  _SliverAppBarDelegate(this.child);

  @override
  double get minExtent => child.preferredSize.height;
  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5),
              ),
            ),
            child: child,
          ),
        ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// Lazy TabBarView — Only builds tabs when they're first selected.
// Prevents 8 simultaneous Firestore queries on community entry.
// ─────────────────────────────────────────────────────────────
class _LazyTabBarView extends StatefulWidget {
  final CommunityMember? memberProfile;
  final Community community;
  final List<CommunityNavigationTab> tabs;
  final Map<int, GlobalKey<CommunityFeedWidgetState>> feedKeys;
  final Map<int, GlobalKey<WikiListWidgetState>> wikiKeys;
  final Map<int, GlobalKey<QuizListWidgetState>> quizKeys;
  final Map<int, GlobalKey<PollListWidgetState>> pollKeys;
  final GlobalKey<SharedFolderScreenState> sharedFolderKey;

  const _LazyTabBarView({
    required this.memberProfile,
    required this.community,
    required this.tabs,
    required this.feedKeys,
    required this.wikiKeys,
    required this.quizKeys,
    required this.pollKeys,
    required this.sharedFolderKey,
  });

  @override
  State<_LazyTabBarView> createState() => _LazyTabBarViewState();
}

class _LazyTabBarViewState extends State<_LazyTabBarView> {
  final Set<int> _loadedTabs = {0}; // Tab 0 (Destacados) loads immediately

  @override
  void didUpdateWidget(covariant _LazyTabBarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If community ID or tabs changed, refresh loaded tabs to ensure index 0 is always there
    if (oldWidget.community.id != widget.community.id || oldWidget.tabs.length != widget.tabs.length) {
      setState(() {
        _loadedTabs.clear();
        _loadedTabs.add(0);
        // We might want to clear keys too but it's handled by TabController changes usually
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tc = DefaultTabController.of(context);
    if (tc != null) {
      tc.addListener(() {
        if (!tc.indexIsChanging && mounted) {
          final idx = tc.index;
          if (!_loadedTabs.contains(idx)) {
            setState(() => _loadedTabs.add(idx));
          }
        }
      });
    }
  }

  Widget _buildTab(int index) {
    if (!_loadedTabs.contains(index)) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }

    final c = widget.community;
    final tab = widget.tabs[index];
    
    switch (tab.type) {
      case NavigationTabType.featured:
        return BlocProvider(
          key: ValueKey('featured_${c.id}'),
          create: (_) => di.sl<CommunityFeedBloc>(),
          child: CommunityFeedWidget(
            key: widget.feedKeys[index] ??= GlobalKey<CommunityFeedWidgetState>(),
            communityId: c.id,
            sortMode: 'recent',
            showCarousel: true,
          ),
        );
      case NavigationTabType.recent:
        return BlocProvider(
          key: ValueKey('recent_${c.id}'),
          create: (_) => di.sl<CommunityFeedBloc>(),
          child: CommunityFeedWidget(
            key: widget.feedKeys[index] ??= GlobalKey<CommunityFeedWidgetState>(),
            communityId: c.id,
            sortMode: 'recent',
          ),
        );
      case NavigationTabType.chats:
        return PublicChatListWidget(
          key: ValueKey('chats_${c.id}'),
          communityId: c.id,
          themeColor: c.themeColor,
        );
      case NavigationTabType.leaderboard:
        return LeaderboardScreen(
          key: ValueKey('leaderboard_${c.id}'),
          communityId: c.id,
          communityName: c.name,
          themeColor: c.themeColor,
          levelTitles: c.levelTitles,
        );
      case NavigationTabType.wikis:
        return WikiListWidget(
          key: widget.wikiKeys[index] ??= GlobalKey<WikiListWidgetState>(), 
          communityId: c.id
        );
      case NavigationTabType.quizzes:
        return QuizListWidget(
          key: widget.quizKeys[index] ??= GlobalKey<QuizListWidgetState>(), 
          communityId: c.id
        );
      case NavigationTabType.sharedFolder:
        return SharedFolderScreen(
          key: widget.sharedFolderKey, 
          communityId: c.id,
        );
      case NavigationTabType.polls:
        return PollListWidget(
          key: widget.pollKeys[index] ??= GlobalKey<PollListWidgetState>(),
          communityId: c.id
        );
      case NavigationTabType.category:
        return BlocProvider(
          key: ValueKey('category_${c.id}_${tab.content}'),
          create: (_) => di.sl<CommunityFeedBloc>(),
          child: CommunityFeedWidget(
            key: widget.feedKeys[index] ??= GlobalKey<CommunityFeedWidgetState>(),
            communityId: c.id,
            sortMode: 'recent',
            categoryId: tab.content ?? '',
          ),
        );
      case NavigationTabType.externalLink:
        return _CommunityWebViewTab(
          key: ValueKey('web_${c.id}_${tab.content}'),
          url: tab.content ?? '',
          themeColor: c.themeColor,
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: List.generate(widget.tabs.length, _buildTab),
    );
  }
}

class _CommunityWebViewTab extends StatefulWidget {
  final String url;
  final Color themeColor;

  const _CommunityWebViewTab({
    super.key,
    required this.url,
    required this.themeColor,
  });

  @override
  State<_CommunityWebViewTab> createState() => _CommunityWebViewTabState();
}

class _CommunityWebViewTabState extends State<_CommunityWebViewTab> with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true; // Mantener la página viva al cambiar de pestaña

  Uri _parseUrl(String input) {
    if (input.isEmpty) return Uri.parse('https://google.com');
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      return Uri.parse('https://$input');
    }
    return Uri.parse(input);
  }

  @override
  void initState() {
    super.initState();
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Wumbleheme.backgroundColor)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) setState(() => _progress = progress / 100);
            },
            onPageStarted: (String url) {
              if (mounted) setState(() { _isLoading = true; _hasError = false; });
            },
            onPageFinished: (String url) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) setState(() { _isLoading = false; _hasError = true; });
            },
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(_parseUrl(widget.url));
    } catch (e) {
      _hasError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Req for KeepAlive
    
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text(tr('No se pudo cargar la página.'), style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(Icons.open_in_browser_rounded, color: widget.themeColor),
              label: Text(tr('ABRIR EN NAVEGADOR'), style: TextStyle(color: widget.themeColor)),
              onPressed: () async {
                final url = _parseUrl(widget.url);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
            ),
          ),
      ],
    );
  }
}
