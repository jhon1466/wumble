import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/services/presence_service_supabase.dart';

/// Horizontal "En línea ahora" strip backed by Supabase Realtime presence.
/// Renders nothing when Supabase isn't configured or nobody is online.
class OnlineNowBar extends StatefulWidget {
  final String communityId;
  const OnlineNowBar({super.key, required this.communityId});

  @override
  State<OnlineNowBar> createState() => _OnlineNowBarState();
}

class _OnlineNowBarState extends State<OnlineNowBar> {
  CommunityPresence? _presence;

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.isConfigured) return;
    final u = FirebaseAuth.instance.currentUser;
    _presence = PresenceManager.acquire(
      widget.communityId,
      OnlineUser(
        uid: u?.uid ?? 'anon',
        name: u?.displayName ?? 'Usuario',
        avatarUrl: u?.photoURL ?? '',
      ),
    );
  }

  @override
  void dispose() {
    if (_presence != null) PresenceManager.release(widget.communityId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured || _presence == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<OnlineUser>>(
      stream: _presence!.stream,
      builder: (context, snapshot) {
        final users = snapshot.data ?? const [];
        if (users.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF22C55E), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${tr('En línea ahora')} · ${users.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _OnlineAvatar(user: users[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnlineAvatar extends StatelessWidget {
  final OnlineUser user;
  const _OnlineAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Wumbleheme.surfaceColor,
                backgroundImage: user.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.avatarUrl)
                    : null,
                child: user.avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white24, size: 22)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Wumbleheme.backgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
