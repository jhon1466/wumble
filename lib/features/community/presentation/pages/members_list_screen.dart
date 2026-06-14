import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/presentation/bloc/community_members_bloc.dart';
import 'package:wumble/features/community/presentation/widgets/member_mini_profile.dart';
import 'package:wumble/features/community/presentation/widgets/online_now_bar.dart';
import 'package:wumble/core/widgets/user_badge_widget.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/features/profile/domain/user_model.dart';

class MembersListScreen extends StatelessWidget {
  final Community community;

  const MembersListScreen({
    super.key,
    required this.community,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<CommunityMembersBloc>()..add(LoadInitialMembers(community.id)),
      child: _MembersListView(community: community),
    );
  }
}

class _MembersListView extends StatefulWidget {
  final Community community;

  const _MembersListView({required this.community});

  @override
  State<_MembersListView> createState() => _MembersListViewState();
}

class _MembersListViewState extends State<_MembersListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<CommunityMembersBloc>().add(LoadMoreMembers(widget.community.id));
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll - 200);
  }

  void _onSearchChanged(String query) {
    _currentQuery = query;
    if (query.isEmpty) {
      context.read<CommunityMembersBloc>().add(ClearSearch(widget.community.id));
    } else {
      context.read<CommunityMembersBloc>().add(SearchMembers(widget.community.id, query));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBackground = widget.community.backgroundUrl.isNotEmpty;

    return Stack(
      children: [
        if (hasBackground) ...[
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: widget.community.backgroundUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.85)),
          ),
        ],
        Scaffold(
          backgroundColor: hasBackground ? Colors.transparent : Wumbleheme.backgroundColor,
          appBar: AppBar(
            title: Text('Miembros de ${widget.community.name}', style: const TextStyle(fontSize: 16)),
            backgroundColor: Wumbleheme.surfaceColor.withValues(alpha: 0.8),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: tr('Buscar miembro...'),
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _currentQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          OnlineNowBar(communityId: widget.community.id),
          Expanded(
            child: BlocBuilder<CommunityMembersBloc, CommunityMembersState>(
        builder: (context, state) {
          if (state.isLoading && state.members.isEmpty) {
            return Center(child: CircularProgressIndicator(color: widget.community.themeColor));
          }

          if (state.error != null && state.members.isEmpty) {
            return Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)));
          }

          if (state.members.isEmpty) {
            return const Center(
              child: Text(
                'No se encontraron miembros',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            itemExtent: 72.0, // Optimized fixed height
            cacheExtent: 1000, // Pre-render nearby items
            itemCount: state.hasReachedMax ? state.members.length : state.members.length + 1,
            itemBuilder: (context, index) {
              if (index >= state.members.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: widget.community.themeColor),
                  ),
                );
              }

              final member = state.members[index];
              return _MemberTile(member: member, themeColor: widget.community.themeColor, communityId: widget.community.id);
            },
          );
        },
            ),
          ),
        ],
      ),
    ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final CommunityMember member;
  final Color themeColor;
  final String? communityId;

  const _MemberTile({required this.member, required this.themeColor, this.communityId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        MemberMiniProfile.show(
          context,
          user: UserProfile.fromCommunityMember(member),
          member: member,
          communityId: communityId,
        );
      },
      leading: UserAvatar(
        userId: member.userId,
        avatarUrl: member.avatarUrl ?? '',
        displayName: member.displayName,
        radius: 24,
        communityId: communityId,
        showOnlineIndicator: false,
        isOnline: false,
        showOnlineStatus: false,
        avatarFrameUrl: member.avatarFrameUrl,
        skipFirestoreSync: true, // Use data directly from the member list
        isAnimated: false,
      ),
      title: Text(
        member.displayName ?? 'Usuario Anónimo',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: UserBadgeWidget(
          level: member.level,
          titles: member.titles,
          role: member.role,
          fontSize: 10,
          isBot: member.isBot,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white10, size: 20),
    );
  }
}
