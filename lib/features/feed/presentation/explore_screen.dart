import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'widgets/user_card.dart';
import '../../community/domain/community_model.dart';
import '../../community/presentation/bloc/community_bloc.dart';
import '../../community/presentation/bloc/discover_bloc.dart';
import '../../community/presentation/widgets/premium_community_card.dart';
import '../../../../core/theme.dart';
import 'bloc/search_bloc.dart';
import '../../community/presentation/widgets/member_mini_profile.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/notifications_screen.dart';
import '../../auth/presentation/auth_bloc.dart';
import '../domain/post_model.dart';
import 'pages/post_detail_screen.dart';
import 'widgets/post_card.dart';
import '../../chat/presentation/bubble_shop_screen.dart';
import '../../community/presentation/pages/community_workshop_screen.dart';
import '../../community/presentation/widgets/featured_banner.dart';
import '../../../../core/widgets/premium_matte_background.dart';
import 'pages/unified_search_screen.dart';
import '../../community/presentation/widgets/shimmer_community_widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      final discoverState = context.read<DiscoverBloc>().state;
      if (discoverState is! DiscoverLoaded) {
        context.read<DiscoverBloc>().add(LoadDiscoverCommunities());
      }
      context.read<GlobalSearchBloc>().add(ClearSearch());
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      context.read<DiscoverBloc>().add(LoadMoreDiscoverCommunities());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
        context.read<DiscoverBloc>().add(LoadDiscoverCommunities());
      } else {
        _selectedCategory = category;
        context.read<DiscoverBloc>().add(LoadDiscoverCommunities(category: category));
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
    });
    context.read<DiscoverBloc>().add(LoadDiscoverCommunities());
  }

  Future<void> _onRefresh() async {
    if (_selectedCategory != null) {
      context.read<DiscoverBloc>().add(LoadDiscoverCommunities(category: _selectedCategory));
    } else {
      context.read<DiscoverBloc>().add(LoadDiscoverCommunities());
    }
    
    await context.read<DiscoverBloc>().stream.firstWhere(
      (state) => state is DiscoverLoaded || state is DiscoverError
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const RepaintBoundary(child: PremiumMatteBackground()),
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: Wumbleheme.secondaryColor,
            backgroundColor: Wumbleheme.surfaceColor,
            child: CustomScrollView(
              controller: _scrollController,
              cacheExtent: 1000,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: false,
                  pinned: true,
                  expandedHeight: 100.0,
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Padding(
                      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Descubrir',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                          Row(
                            children: [
                              _buildHeaderIconButton(
                                icon: Icons.search_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const UnifiedSearchScreen()),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildHeaderIconButton(
                                icon: Icons.storefront_rounded,
                                onTap: () => _showStoreMenu(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                BlocBuilder<DiscoverBloc, DiscoverState>(
                  builder: (context, state) {
                    List<Community> communities = [];
                    bool isLoading = false;

                    if (state is DiscoverLoaded) {
                      communities = state.communities;
                    } else if (state is DiscoverLoading) {
                      isLoading = true;
                    }

                    return MultiSliver(
                      children: [
                        // Featured Section
                        if (_selectedCategory == null)
                          state is DiscoverLoading && communities.isEmpty
                            ? const SliverToBoxAdapter(child: ShimmerFeaturedBanner())
                            : (state is DiscoverLoaded && state.featuredCommunities.isNotEmpty)
                                ? SliverToBoxAdapter(child: FeaturedBanner(communities: state.featuredCommunities))
                                : const SliverToBoxAdapter(child: SizedBox.shrink()),

                        // New Communities Horizontal List (Recientes)
                        if (_selectedCategory == null && state is DiscoverLoaded && state.newCommunities.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Comunidades Recientes'),
                                SizedBox(
                                  height: 220,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: state.newCommunities.length,
                                    itemBuilder: (context, index) => Container(
                                      width: 160,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: PremiumCommunityCard(community: state.newCommunities[index]),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),

                        // Trending Horizontal List
                        if (_selectedCategory == null && state is DiscoverLoaded && state.trendingCommunities.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Comunidades Populares'),
                                SizedBox(
                                  height: 220,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: state.trendingCommunities.length,
                                    itemBuilder: (context, index) => Container(
                                      width: 160,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: PremiumCommunityCard(community: state.trendingCommunities[index]),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),


                        // Main Explore Title
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            _selectedCategory != null ? 'Comunidades de $_selectedCategory' : 'Explorar todas',
                          ),
                        ),
                        
                        // Main Grid
                        if (state is DiscoverLoading && communities.isEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => const ShimmerCommunityCard(),
                                childCount: 6,
                              ),
                            ),
                          )
                        else if (communities.isEmpty && state is! DiscoverLoading)
                          _buildEmptyResults()
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => RepaintBoundary(child: PremiumCommunityCard(community: communities[index])),
                                childCount: communities.length,
                              ),
                            ),
                          ),

                        // Pagination Loader
                        if (state is DiscoverLoaded && state.isLoadingMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Wumbleheme.secondaryColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                          
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStoreMenu(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Mercado',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.storefront_rounded, color: Colors.amber, size: 28),
            title: const Text('Workshop de Marcos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Compra o publica marcos de perfil', style: TextStyle(color: Colors.white54, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CommunityWorkshopScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_rounded, color: Colors.lightBlue, size: 28),
            title: const Text('Tienda de Burbujas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Personaliza tus chats', style: TextStyle(color: Colors.white54, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BubbleShopScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 64, color: Colors.white10),
              const SizedBox(height: 16),
              const Text(
                'No hay comunidades que coincidan',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.9),
          letterSpacing: -0.5,
        ),
      ),
    );
  }



  Widget _buildHeaderIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
