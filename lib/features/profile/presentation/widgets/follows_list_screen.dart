import 'package:flutter/material.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/profile/presentation/profile_screen.dart';
import 'package:wumble/core/widgets/user_avatar.dart';

class FollowsListScreen extends StatefulWidget {
  final String userId;
  final String title;
  final String type; // 'followers' or 'following'

  const FollowsListScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.type,
  });

  @override
  State<FollowsListScreen> createState() => _FollowsListScreenState();
}

class _FollowsListScreenState extends State<FollowsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<UserProfile> _users = [];
  dynamic _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _fetchPage();
      }
    }
  }

  Future<void> _fetchPage() async {
    if (_isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final repo = di.sl<ProfileRepository>();
      final result = widget.type == 'followers'
          ? await repo.getFollowersPaginated(widget.userId, lastDoc: _lastDoc)
          : await repo.getFollowingPaginated(widget.userId, lastDoc: _lastDoc);

      if (mounted) {
        setState(() {
          _users.addAll(result.users);
          _lastDoc = result.lastDoc;
          _hasMore = result.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Wumbleheme.surfaceColor,
        elevation: 0,
      ),
      body: _error != null && _users.isEmpty
          ? _buildErrorState()
          : _users.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator(color: Wumbleheme.secondaryColor))
              : _users.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : _buildList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          TextButton(
            onPressed: _fetchPage,
            child: const Text('Reintentar', style: TextStyle(color: Wumbleheme.secondaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.type == 'followers' ? Icons.people_outline : Icons.person_search_outlined,
            size: 80,
            color: Colors.white10,
          ),
          const SizedBox(height: 16),
          Text(
            widget.type == 'followers' ? 'Aún no tiene seguidores' : 'No sigue a nadie todavía',
            style: const TextStyle(color: Wumbleheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: Wumbleheme.secondaryColor)),
          );
        }

        final user = _users[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: UserAvatar(
            userId: user.id,
            avatarUrl: user.avatarUrl,
            displayName: user.displayName,
            radius: 26,
            isClickable: false, // ListTile handles the tap
            avatarFrameUrl: user.avatarFrameUrl,
            isOnline: user.isOnline,

          ),
          title: Text(
            user.displayName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: (user.username.isNotEmpty && user.username != user.id)
              ? Text(
                  '@${user.username}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                )
              : null,
          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: user.id, isGlobal: true),
              ),
            );
          },
        );
      },
    );
  }
}
