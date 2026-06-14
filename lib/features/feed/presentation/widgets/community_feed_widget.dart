import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:wumble/features/feed/domain/category_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/post_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/feed/domain/feed_repository.dart';
import '../bloc/community_feed_bloc.dart';
import '../bloc/create_post_cubit.dart';
import '../pages/create_post_screen.dart';
import '../pages/post_detail_screen.dart';
import 'post_card.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'status_creation_sheet.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/core/theme.dart';

class CommunityFeedWidget extends StatefulWidget {
  final String communityId;
  final String sortMode; // 'recent' | 'popular'

  final String? categoryId;
  final bool? isFeatured;
  final bool showCarousel;

  const CommunityFeedWidget({
    super.key,
    required this.communityId,
    this.sortMode = 'recent',
    this.categoryId,
    this.isFeatured,
    this.showCarousel = false,
  });

  @override
  State<CommunityFeedWidget> createState() => CommunityFeedWidgetState();
}

class CommunityFeedWidgetState extends State<CommunityFeedWidget> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    _checkAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndLoad();
  }

  @override
  void didUpdateWidget(covariant CommunityFeedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortMode != widget.sortMode || 
        oldWidget.categoryId != widget.categoryId || 
        oldWidget.communityId != widget.communityId ||
        oldWidget.isFeatured != widget.isFeatured) {
      _checkAndLoad();
    }
  }

  void _checkAndLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final bloc = context.read<CommunityFeedBloc>();
      if (bloc.state is CommunityFeedInitial) {
        bloc.add(
          LoadCommunityFeed(
            widget.communityId,
            sortMode: widget.sortMode,
            categoryId: widget.categoryId,
            isFeatured: widget.isFeatured,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.offset >= threshold) {
      final state = context.read<CommunityFeedBloc>().state;
      if (state is CommunityFeedLoaded && state.hasMore) {
        context.read<CommunityFeedBloc>().add(LoadMoreCommunityFeed(widget.communityId));
      }
    }
  }

  void refresh() {
    context.read<CommunityFeedBloc>().add(
      LoadCommunityFeed(
        widget.communityId, 
        sortMode: widget.sortMode,
        categoryId: widget.categoryId,
        isFeatured: widget.isFeatured,
      ),
    );
  }

  Future<void> _onRefresh() async {
    context.read<CommunityFeedBloc>().add(
      LoadCommunityFeed(
        widget.communityId, 
        sortMode: widget.sortMode,
        categoryId: widget.categoryId,
        isFeatured: widget.isFeatured,
      ),
    );
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      final state = context.read<CommunityFeedBloc>().state;
      return state is CommunityFeedLoading;
    }).timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<CommunityFeedBloc, CommunityFeedState>(
      builder: (context, state) {
        final List<Post> posts;
        final bool isInitialLoad;
        final bool isLoadingMore;
        final bool hasMore;

        if (state is CommunityFeedLoading) {
          posts = [];
          isInitialLoad = true;
          isLoadingMore = false;
          hasMore = false;
        } else if (state is CommunityFeedLoadingMore) {
          posts = state.currentPosts;
          isInitialLoad = false;
          isLoadingMore = true;
          hasMore = true;
        } else if (state is CommunityFeedLoaded) {
          posts = state.posts;
          isInitialLoad = false;
          isLoadingMore = false;
          hasMore = state.hasMore;
        } else if (state is CommunityFeedError) {
          posts = [];
          isInitialLoad = false;
          isLoadingMore = false;
          hasMore = false;
        } else {
          posts = [];
          isInitialLoad = false;
          isLoadingMore = false;
          hasMore = false;
        }

        List<Post> filteredPosts = posts;
        if (widget.isFeatured == true && posts.isNotEmpty) {
           filteredPosts = posts.where((p) => p.isFeatured != true).toList();
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.white,
          backgroundColor: Color(0xFF1E1E2C),
          child: CustomScrollView(
            controller: _scrollController,
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Pinned Posts (Pins) ──
              if (widget.showCarousel && state is CommunityFeedLoaded && state.posts.any((p) => p.isPinned == true))
                SliverToBoxAdapter(
                  child: _PinnedPostsList(
                    pinnedPosts: state.posts.where((p) => p.isPinned == true).toList(),
                  ),
                ),

              // ── Featured Content Carousel ──
              if (widget.showCarousel && state is CommunityFeedLoaded && state.posts.any((p) => p.isFeatured == true))
                SliverToBoxAdapter(
                  child: _FeaturedCarousel(
                    featuredPosts: state.posts.where((p) => p.isFeatured == true).toList(),
                  ),
                ),

              // ── QUICK POST BAR ──
              if (widget.sortMode == 'recent' && widget.categoryId == null)
                SliverToBoxAdapter(
                  child: _buildQuickPostBar(context),
                ),

              // ── Category Filter Bar ──
              if (state is CommunityFeedLoaded && state.categories.isNotEmpty && widget.categoryId != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryBarDelegate(
                    categories: state.categories,
                    selectedCategoryId: state.selectedCategoryId,
                    onCategorySelected: (catId) {
                      context.read<CommunityFeedBloc>().add(
                        LoadCommunityFeed(
                          widget.communityId,
                          sortMode: widget.sortMode,
                          categoryId: catId,
                        ),
                      );
                    },
                  ),
                ),
              // ── Initial loading spinner ──
              if (isInitialLoad)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              // ── Error view ──
              else if (state is CommunityFeedError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Error al cargar: ${state.message}',
                            style: const TextStyle(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _onRefresh,
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                            label: Text(tr('Reintentar'), style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              // ── Empty state ──
              else if (posts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.feed_outlined, size: 60, color: Colors.white24),
                          SizedBox(height: 10),
                          Text(tr('Aún no hay publicaciones'), style: TextStyle(color: Colors.white24)),
                          SizedBox(height: 4),
                          Text(
                            'Desliza hacia abajo para actualizar',
                            style: TextStyle(color: Colors.white12, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              // ── Post List ──
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = filteredPosts[index];
                      return PostCard(post: post);
                    },
                    childCount: filteredPosts.length,
                  ),
                ),

              // ── Load-more indicator / end caption ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
                  child: Center(
                    child: isLoadingMore
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                          )
                        : !hasMore && posts.isNotEmpty
                            ? const Text(
                                '— Fin del feed —',
                                style: TextStyle(color: Colors.white24, fontSize: 12),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickPostBar(BuildContext context) {
    return BlocBuilder<CommunityContextBloc, CommunityContextState>(
      builder: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return const SizedBox.shrink();

        final avatarUrl = state.memberProfile?.avatarUrl ?? user.photoURL ?? '';
        final frameUrl = state.memberProfile?.avatarFrameUrl;

        return GestureDetector(
          onTap: () => _showQuickPost(context, avatarUrl, frameUrl),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                UserAvatar(
                  userId: user.uid,
                  avatarUrl: avatarUrl,
                  avatarFrameUrl: frameUrl,
                  communityId: widget.communityId,
                  radius: 16,
                  showOnlineIndicator: false,
                ),
                const SizedBox(width: 12),
                const Text(
                  '¿Qué estás pensando?',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const Spacer(),
                const Icon(Icons.image_outlined, color: Colors.white38, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showQuickPost(BuildContext context, String? communityAvatarUrl, String? communityAvatarFrameUrl) async {
    final bloc = BlocProvider.of<CommunityFeedBloc>(context);
    final contextBloc = BlocProvider.of<CommunityContextBloc>(context);
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: contextBloc),
          BlocProvider(create: (_) => di.sl<CreatePostCubit>()),
        ],
        child: StatusCreationSheet(
          communityId: widget.communityId,
          communityAvatarUrl: communityAvatarUrl,
          communityAvatarFrameUrl: communityAvatarFrameUrl,
        ),
      ),
    );

    if (result == true && mounted) {
      refresh();
    }
  }
}

/// Strips Amino tag prefixes like [B], [BIC], [T=16], [#=FF0000] etc. from each line.
String _stripTags(String text) {
  final tagRe = RegExp(r'^\[([^\]]+)\]');
  return text.split('\n').map((line) {
    final m = tagRe.firstMatch(line);
    return m != null ? line.substring(m.group(0)!.length) : line;
  }).join('\n');
}

class _PinnedPostsList extends StatelessWidget {
  final List<Post> pinnedPosts;
  const _PinnedPostsList({required this.pinnedPosts});

  @override
  Widget build(BuildContext context) {
    // Limit to top 3 pins like Amino
    final displayPins = pinnedPosts.take(3).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: displayPins.map((post) {
          final isLast = displayPins.indexOf(post) == displayPins.length - 1;
          return Column(
            children: [
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.push_pin_rounded, color: Colors.orangeAccent, size: 16),
                title: Text(
                  post.title ?? post.content.split('\n').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FeaturedCarousel extends StatelessWidget {
  final List<Post> featuredPosts;
  const _FeaturedCarousel({required this.featuredPosts});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: PageView.builder(
        itemCount: featuredPosts.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (context, index) {
          final post = featuredPosts[index];
          final imageUrl = post.images.isNotEmpty ? post.images.first : null;
          final String title = post.title ?? post.content.split('\n').first;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
                  // --- Background ---
                  if (imageUrl != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white10),
                          errorWidget: (context, url, error) => Container(color: Colors.white10),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: const Color(0xFF262626), // Gris Oscuro Mate
                        ),
                      ),
                    ),

                  // --- Overlay Gradient ---
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.2, 1.0],
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- Content ---
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 12, color: Colors.black),
                              SizedBox(width: 4),
                              Text(
                                'DESTACADO',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        if (post.authorName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                if (post.authorAvatarUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: post.authorAvatarUrl!,
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  'por ${post.authorName}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final List<PostCategory> categories;
  final String? selectedCategoryId;
  final Function(String?) onCategorySelected;

  _CategoryBarDelegate({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1E1E2C),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAll = selectedCategoryId == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tr('Todo')),
                selected: isAll,
                onSelected: (_) => onCategorySelected(null),
                backgroundColor: Colors.white.withOpacity(0.05),
                selectedColor: Colors.blueAccent,
                labelStyle: TextStyle(color: isAll ? Colors.white : Colors.white70),
              ),
            );
          }
          final cat = categories[index - 1];
          final isSelected = selectedCategoryId == cat.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${cat.icon} ${cat.name}'),
              selected: isSelected,
              onSelected: (_) => onCategorySelected(cat.id),
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: Colors.blueAccent,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
            ),
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 60;
  @override
  double get minExtent => 60;
  @override
  bool shouldRebuild(covariant _CategoryBarDelegate oldDelegate) {
    return oldDelegate.selectedCategoryId != selectedCategoryId || oldDelegate.categories != categories;
  }
}
