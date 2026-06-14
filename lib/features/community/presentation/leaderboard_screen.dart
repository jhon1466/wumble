import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/injection_container.dart';
import 'package:wumble/features/community/presentation/widgets/member_mini_profile.dart';
import 'package:wumble/features/community/domain/reputation_service.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/core/theme.dart';

class LeaderboardScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final Color themeColor;
  final Map<String, String>? levelTitles;

  const LeaderboardScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.themeColor,
    this.levelTitles,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        toolbarHeight: 40,
        title: Text(
          'Salón de Fama',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 24,
            letterSpacing: 1.0,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.6),
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5],
            colors: [
              widget.themeColor.withOpacity(0.35), 
              Wumbleheme.backgroundColor,
            ],
          ),
        ),
        child: _LeaderboardList(
          communityId: widget.communityId, 
          type: 'allTime', 
          levelTitles: widget.levelTitles
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatefulWidget {
  final String communityId;
  final String type;
  final Map<String, String>? levelTitles;

  const _LeaderboardList({required this.communityId, required this.type, this.levelTitles});

  @override
  State<_LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<_LeaderboardList> with AutomaticKeepAliveClientMixin {
  late Future<List<CommunityMember>> _leaderboardFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = sl<CommunityRepository>().getCommunityLeaderboard(widget.communityId, widget.type);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _leaderboardFuture = sl<CommunityRepository>().getCommunityLeaderboard(widget.communityId, widget.type);
    });
    await _leaderboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1E1E2C),
      child: FutureBuilder<List<CommunityMember>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
  
          final members = snapshot.data ?? [];
  
          if (members.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Text(tr('No hay datos aún'), style: const TextStyle(color: Colors.white54)),
                  ),
                ),
              ],
            );
          }
  
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 80)), // Gap for AppBar title
              // PODIUM (Top 3)
              if (members.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    child: _PodiumWidget(members: members, type: widget.type, communityId: widget.communityId),
                  ),
                ),
  
              // LIST (4+)
              if (members.length > 3)
                SliverFixedExtentList(
                  itemExtent: 72.0,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final actualIndex = index + 3;
                      if (actualIndex >= members.length) return null;
                      final member = members[actualIndex];
                      return _RankingListItem(member: member, rank: actualIndex + 1, type: widget.type, levelTitles: widget.levelTitles, communityId: widget.communityId);
                    },
                    childCount: members.length - 3,
                  ),
                ),
                
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          );
        },
      ),
    );
  }
}

class _PodiumWidget extends StatelessWidget {
  final List<CommunityMember> members;
  final String type;
  final String communityId;

  const _PodiumWidget({required this.members, required this.type, required this.communityId});

  @override
  Widget build(BuildContext context) {
    final first = members.isNotEmpty ? members[0] : null;
    final second = members.length > 1 ? members[1] : null;
    final third = members.length > 2 ? members[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd Place
        if (second != null) 
          Expanded(child: _buildPodiumItem(context, second, 2, 80, Colors.grey.shade300, communityId)),
        
        // 1st Place (Center, larger)
        if (first != null) 
          Flexible(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildPodiumItem(context, first, 1, 100, Colors.amber, communityId),
            ),
          ),
          
        // 3rd Place
        if (third != null) 
          Expanded(child: _buildPodiumItem(context, third, 3, 80, const Color(0xFFCD7F32), communityId)),
      ],
    );
  }

  Widget _buildPodiumItem(BuildContext context, CommunityMember member, int rank, double size, Color color, String communityId) {
    final isMins = type == '24h' || type == '7d';
    
    String valueText;
    if (type == '24h') {
      valueText = _formatMinutes(member.onlineMinutes24h);
    } else if (type == '7d') {
      valueText = _formatMinutes(member.onlineMinutes7d);
    } else {
      valueText = '${member.reputation} Rep';
    }

    return GestureDetector(
      onTap: () => MemberMiniProfile.show(
        context,
        user: UserProfile.fromCommunityMember(member),
        member: member,
        communityId: communityId,
      ),
      child: Column(
        children: [
          // Crown for #1
          if (rank == 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.emoji_events, color: Colors.amber, size: 30),
            ),
            
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
                UserAvatar(
                  userId: member.userId,
                  avatarUrl: member.avatarUrl ?? '',
                  displayName: member.displayName, // Added
                  radius: size / 2,
                  communityId: communityId,
                  skipFirestoreSync: true,
                  avatarFrameUrl: member.avatarFrameUrl, // NEW
                  isOnline: member.isOnline,
                  isAnimated: false,

                  border: Border.all(color: color, width: 3),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                  ],
                  onTap: () => MemberMiniProfile.show(
                    context,
                    user: UserProfile.fromCommunityMember(member),
                    member: member,
                    communityId: communityId,
                  ),
                ),
              Transform.translate(
                offset: const Offset(0, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            member.displayName ?? 'Usuario',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            valueText,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes == 0) return '0 mins';
    if (totalMinutes < 60) return '$totalMinutes mins';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class _RankingListItem extends StatelessWidget {
  final CommunityMember member;
  final int rank;
  final String type;
  final Map<String, String>? levelTitles;
  final String communityId;

  const _RankingListItem({required this.member, required this.rank, required this.type, this.levelTitles, required this.communityId});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => MemberMiniProfile.show(
          context,
          user: UserProfile.fromCommunityMember(member),
          member: member,
          communityId: communityId,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Wumbleheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$rank',
                  style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              UserAvatar(
                userId: member.userId,
                avatarUrl: member.avatarUrl ?? '',
                displayName: member.displayName, // Added
                radius: 20,
                communityId: communityId,
                avatarFrameUrl: member.avatarFrameUrl,
                skipFirestoreSync: true,
                isOnline: member.isOnline,
                isAnimated: false,
  
                onTap: () => MemberMiniProfile.show(
                  context,
                  user: UserProfile.fromCommunityMember(member),
                  member: member,
                  communityId: communityId,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName ?? 'Usuario',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'LV ${member.level} • ${ReputationService.getLevelTitle(member.level, levelTitles)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _getValueText(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getValueText() {
    if (type == '24h') {
      return _formatMinutes(member.onlineMinutes24h);
    } else if (type == '7d') {
      return _formatMinutes(member.onlineMinutes7d);
    } else {
      return '${member.reputation} Rep';
    }
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes == 0) return '0 mins';
    if (totalMinutes < 60) return '$totalMinutes mins';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}
