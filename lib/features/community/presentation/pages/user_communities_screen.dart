import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/widgets/premium_matte_background.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/presentation/bloc/community_bloc.dart';
import 'package:wumble/features/community/presentation/widgets/premium_community_card.dart';
import 'package:wumble/features/auth/presentation/auth_bloc.dart';

class UserCommunitiesScreen extends StatefulWidget {
  UserCommunitiesScreen({super.key});

  @override
  State<UserCommunitiesScreen> createState() => _UserCommunitiesScreenState();
}

class _UserCommunitiesScreenState extends State<UserCommunitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthBloc>().state.user?.uid;

    return Scaffold(
      body: Stack(
        children: [
          PremiumMatteBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                Expanded(
                  child: BlocBuilder<CommunityBloc, CommunityState>(
                    builder: (context, state) {
                      if (state is CommunityLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is CommunityError) {
                        return Center(child: Text('Error: ${state.message}', style: const TextStyle(color: Colors.white70)));
                      }
                      if (state is CommunityLoaded) {
                        final filteredCommunities = state.communities.where((c) {
                          return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                 c.handle.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();

                        if (filteredCommunities.isEmpty) {
                          return _buildEmptyState();
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            if (userId != null) {
                              context.read<CommunityBloc>().add(LoadUserCommunities(userId));
                            }
                          },
                          color: Wumbleheme.secondaryColor,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: filteredCommunities.length,
                            itemBuilder: (context, index) {
                              return PremiumCommunityCard(
                                community: filteredCommunities[index],
                              );
                            },
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            tr('Mis Comunidades'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: tr('Buscar en mis comunidades...'),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No te has unido a ninguna comunidad aún' : 'No se encontraron resultados',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
        ],
      ),
    );
  }
}
