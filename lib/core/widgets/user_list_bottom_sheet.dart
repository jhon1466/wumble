import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/profile/presentation/profile_screen.dart';

class UserListBottomSheet extends StatefulWidget {
  final String title;
  final List<String> userIds;
  final String? communityId;

  UserListBottomSheet({
    super.key,
    required this.title,
    required this.userIds,
    this.communityId,
  });

  /// Shows a bottom sheet with a list of users.
  /// [userIds] is the list of user IDs to display.
  /// [title] is the header text of the sheet.
  /// [communityId] is optional context for profile navigation.
  static void show(BuildContext context, {
    required String title,
    required List<String> userIds,
    String? communityId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => UserListBottomSheet(
        title: title,
        userIds: userIds,
        communityId: communityId,
      ),
    );
  }

  @override
  State<UserListBottomSheet> createState() => _UserListBottomSheetState();
}

class _UserListBottomSheetState extends State<UserListBottomSheet> {
  final List<UserProfile> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (widget.userIds.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final repo = di.sl<ProfileRepository>();
      // Deduplicate and limit to prevent massive loads
      final ids = widget.userIds.toSet().toList();
      
      // Batch fetch first 50 users using Future.wait
      final List<Future<UserProfile>> futures = ids.take(50).map((id) async {
        // 1. Get Global profile first (always has the real username)
        final profile = await repo.getUserProfile(id).first;
        
        // 2. Overlay Community data if available
        if (widget.communityId != null) {
          try {
            final member = await repo.getMemberProfile(widget.communityId!, id);
            if (member != null) {
              // Merge community fields while keeping the global username
              return profile.copyWith(
                displayName: (member.displayName?.isNotEmpty ?? false) ? member.displayName : profile.displayName,
                avatarUrl: (member.avatarUrl?.isNotEmpty ?? false) ? member.avatarUrl : profile.avatarUrl,
                avatarFrameUrl: member.avatarFrameUrl ?? profile.avatarFrameUrl,
                bio: (member.bio?.isNotEmpty ?? false) ? member.bio : profile.bio,
                level: member.level,
                reputation: member.reputation,
                titles: member.titles.isNotEmpty ? member.titles : profile.titles,
              );
            }
          } catch (e) {
            debugPrint('Error loading member profile for $id in bottom sheet: $e');
          }
        }
        return profile;
      }).toList();
      final List<UserProfile> loadedUsers = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _users.addAll(loadedUsers);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users for bottom sheet: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar usuarios';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Wumbleheme.secondaryColor))
                : _error != null
                    ? _buildError()
                    : _users.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        tr('No hay usuarios por aquí'),
        style: TextStyle(color: Colors.white24, fontSize: 16),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          onTap: () {
            Navigator.pop(context); // Close sheet
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  userId: user.id,
                  communityId: widget.communityId,
                  isGlobal: widget.communityId == null,
                ),
              ),
            );
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          hoverColor: Colors.white.withOpacity(0.05),
          leading: UserAvatar(
            userId: user.id,
            avatarUrl: user.avatarUrl,
            displayName: user.displayName,
            radius: 22,
            communityId: widget.communityId,
            avatarFrameUrl: user.avatarFrameUrl,
            skipFirestoreSync: true,
            isAnimated: false,
          ),
          title: Text(
            user.displayName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: (user.username.isNotEmpty && user.username != user.id)
              ? Text(
                  '@${user.username}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                )
              : null,
          trailing: const Icon(Icons.chevron_right, color: Colors.white10, size: 18),
        );
      },
    );
  }
}
