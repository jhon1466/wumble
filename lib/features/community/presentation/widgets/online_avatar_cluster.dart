import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/services/presence_service_supabase.dart';

/// Small stacked cluster of online member avatars shown inside the nav pill.
/// Renders nothing when Supabase isn't configured or nobody is online.
class OnlineAvatarCluster extends StatefulWidget {
  final String communityId;
  final int max;
  const OnlineAvatarCluster({super.key, required this.communityId, this.max = 3});

  @override
  State<OnlineAvatarCluster> createState() => _OnlineAvatarClusterState();
}

class _OnlineAvatarClusterState extends State<OnlineAvatarCluster> {
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
    final p = _presence;
    if (p == null) return const SizedBox.shrink();

    return StreamBuilder<List<OnlineUser>>(
      stream: p.stream,
      builder: (context, snap) {
        final users = snap.data ?? const [];
        if (users.isEmpty) return const SizedBox.shrink();

        final shown = users.take(widget.max).toList();
        final extra = users.length - shown.length;
        const double size = 24;
        const double overlap = 16;

        return SizedBox(
          width: overlap * shown.length + (size - overlap) + (extra > 0 ? 22 : 0),
          height: size + 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < shown.length; i++)
                Positioned(
                  left: i * overlap,
                  child: _ring(child: _avatar(shown[i].avatarUrl, size)),
                ),
              if (extra > 0)
                Positioned(
                  left: shown.length * overlap,
                  child: _ring(
                    child: Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: Wumbleheme.surfaceColor, shape: BoxShape.circle),
                      child: Text('+$extra',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        color: Color(0xFF22C55E), // green online ring
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }

  Widget _avatar(String url, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Wumbleheme.surfaceColor,
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty
          ? const Icon(Icons.person, color: Colors.white24, size: 13)
          : null,
    );
  }
}
