import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wumble/core/config/app_secrets.dart';

/// Supabase config (lives in app_secrets.dart, gitignored / not in repo).
class SupabaseConfig {
  static const String url = AppSecrets.supabaseUrl;
  static const String anonKey = AppSecrets.supabaseAnonKey;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

/// One user currently present in a community channel.
class OnlineUser {
  final String uid;
  final String name;
  final String avatarUrl;
  const OnlineUser({required this.uid, required this.name, required this.avatarUrl});
}

/// Tracks live presence for a single community using Supabase Realtime.
///
/// Costs nothing on Firebase: presence lives in-memory on Supabase's Realtime
/// server (broadcast), it is NOT persisted in any database. When the socket
/// drops, Supabase removes the user from the channel automatically.
class CommunityPresence {
  final String communityId;
  RealtimeChannel? _channel;
  // BehaviorSubject replays the latest value to new subscribers (so a modal
  // opened after presence is established immediately sees who's online).
  final _controller = BehaviorSubject<List<OnlineUser>>.seeded(const []);

  CommunityPresence(this.communityId);

  /// Stream that always starts with the current online list.
  Stream<List<OnlineUser>> get stream => _controller.stream;

  /// Current online users (synchronous snapshot).
  List<OnlineUser> get current => _controller.value;

  /// Joins the community channel and starts broadcasting [me]'s presence.
  void connect(OnlineUser me) {
    if (!SupabaseConfig.isConfigured) {
      // Presence disabled (no Supabase configured): emit empty and stop.
      debugPrint('⚠️ Presence: Supabase NO configurado (faltan --dart-define). '
          'Ejecuta con --dart-define-from-file=dart_defines.json');
      _controller.add(const []);
      return;
    }
    debugPrint('🔌 Presence: conectando a community-$communityId como ${me.name}');
    try {
      final client = Supabase.instance.client;
      final channel = client.channel(
        'community-$communityId',
        opts: const RealtimeChannelConfig(self: true),
      );
      _channel = channel;

      void emit() {
        final states = channel.presenceState();
        final users = <String, OnlineUser>{};
        for (final s in states) {
          for (final p in s.presences) {
            final data = p.payload;
            final uid = (data['uid'] ?? '').toString();
            if (uid.isEmpty) continue;
            users[uid] = OnlineUser(
              uid: uid,
              name: (data['name'] ?? 'Usuario').toString(),
              avatarUrl: (data['avatar'] ?? '').toString(),
            );
          }
        }
        debugPrint('👥 Presence sync community-$communityId: '
            '${users.length} en línea -> ${users.keys.toList()}');
        if (!_controller.isClosed) _controller.add(users.values.toList());
      }

      channel
          .onPresenceSync((_) => emit())
          .onPresenceJoin((_) => emit())
          .onPresenceLeave((_) => emit())
          .subscribe((status, error) async {
        debugPrint('🔌 Presence status: $status ${error ?? ''}');
        if (status == RealtimeSubscribeStatus.subscribed) {
          await channel.track({
            'uid': me.uid,
            'name': me.name,
            'avatar': me.avatarUrl,
          });
          debugPrint('✅ Presence: tracked ${me.name} en community-$communityId');
        }
      });
    } catch (e) {
      debugPrint('CommunityPresence error: $e');
      if (!_controller.isClosed) _controller.add(const []);
    }
  }

  Future<void> dispose() async {
    try {
      final ch = _channel;
      if (ch != null) {
        await ch.untrack();
        await Supabase.instance.client.removeChannel(ch);
      }
    } catch (_) {}
    await _controller.close();
  }
}

/// Shares a single [CommunityPresence] per community across widgets
/// (e.g. the nav pill and the activity modal) using reference counting,
/// so only one Realtime channel is open per community at a time.
class PresenceManager {
  static final Map<String, CommunityPresence> _instances = {};
  static final Map<String, int> _refs = {};

  static CommunityPresence acquire(String communityId, OnlineUser me) {
    final existing = _instances[communityId];
    if (existing != null) {
      _refs[communityId] = (_refs[communityId] ?? 0) + 1;
      return existing;
    }
    final p = CommunityPresence(communityId)..connect(me);
    _instances[communityId] = p;
    _refs[communityId] = 1;
    return p;
  }

  static void release(String communityId) {
    final remaining = (_refs[communityId] ?? 1) - 1;
    if (remaining <= 0) {
      _instances.remove(communityId)?.dispose();
      _refs.remove(communityId);
    } else {
      _refs[communityId] = remaining;
    }
  }
}
