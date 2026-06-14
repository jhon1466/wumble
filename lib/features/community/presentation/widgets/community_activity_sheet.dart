import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/services/presence_service_supabase.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/presentation/pages/members_list_screen.dart';
import 'package:wumble/features/community/presentation/widgets/member_mini_profile.dart';
import 'package:wumble/features/profile/domain/user_model.dart';

/// Opens the "Actividad en círculo" modal: online-now + staff (owner/admins/mods).
void showCommunityActivity(BuildContext context, Community community) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActivitySheet(community: community),
  );
}

class _ActivitySheet extends StatefulWidget {
  final Community community;
  const _ActivitySheet({required this.community});

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet> {
  late final CommunityPresence _presence;
  late final Future<List<CommunityMember>> _staffFuture;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _presence = PresenceManager.acquire(
      widget.community.id,
      OnlineUser(
        uid: u?.uid ?? 'anon',
        name: u?.displayName ?? 'Usuario',
        avatarUrl: u?.photoURL ?? '',
      ),
    );
    _staffFuture = _loadStaff();
  }

  Future<List<CommunityMember>> _loadStaff() async {
    final snap = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.community.id)
        .collection('members')
        .where('role', whereIn: ['leader', 'curator']).get();
    return snap.docs.map((d) => CommunityMember.fromFirestore(d)).toList();
  }

  @override
  void dispose() {
    PresenceManager.release(widget.community.id);
    super.dispose();
  }

  void _openMini(UserProfile user, {CommunityMember? member}) {
    MemberMiniProfile.show(
      context,
      user: user,
      member: member,
      communityId: widget.community.id,
    );
  }

  void _openMiniFromOnline(OnlineUser u) {
    _openMini(UserProfile.fromMap(
        {'displayName': u.name, 'avatarUrl': u.avatarUrl}, u.uid));
  }

  void _openMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MembersListScreen(community: widget.community)),
    );
  }

  void _openAllOnline() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Wumbleheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    StreamBuilder<List<OnlineUser>>(
                      stream: _presence.stream,
                      builder: (context, snap) => Text(
                        'En línea ahora · ${snap.data?.length ?? 0}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<OnlineUser>>(
                  stream: _presence.stream,
                  builder: (context, snap) {
                    final users = snap.data ?? const [];
                    if (users.isEmpty) {
                      return Center(
                          child: Text(tr('Nadie conectado.'),
                              style: const TextStyle(color: Colors.white24)));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        final u = users[i];
                        return InkWell(
                          onTap: () => _openMiniFromOnline(u),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    _avatar(u.avatarUrl, 20),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Wumbleheme.backgroundColor, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(u.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Wumbleheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Wumbleheme.secondaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr('Miembros activos'),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    StreamBuilder<List<OnlineUser>>(
                      stream: _presence.stream,
                      builder: (context, snap) => _countChip(
                          const Color(0xFF22C55E), '${snap.data?.length ?? 0}'),
                    ),
                    const SizedBox(width: 6),
                    _countChip(Colors.white24, _fmtCount(widget.community.membersCount)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    _onlineCard(),
                    FutureBuilder<List<CommunityMember>>(
                      future: _staffFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Wumbleheme.secondaryColor)),
                          );
                        }
                        final staff = snap.data ?? [];
                        final creatorId = widget.community.creatorId;
                        final owner = staff.where((m) => m.userId == creatorId).toList();
                        final admins = staff
                            .where((m) => m.role == 'leader' && m.userId != creatorId)
                            .toList();
                        final mods = staff.where((m) => m.role == 'curator').toList();
                        return Column(
                          children: [
                            if (owner.isNotEmpty)
                              _section('Dueño', Icons.workspace_premium, owner,
                                  showAll: false),
                            if (admins.isNotEmpty)
                              _section('Administradores', Icons.shield, admins),
                            if (mods.isNotEmpty)
                              _section('Mods', Icons.verified_user, mods),
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
      },
    );
  }

  Widget _countChip(Color dot, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _cardWrap({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }

  Widget _onlineCard() {
    return StreamBuilder<List<OnlineUser>>(
      stream: _presence.stream,
      builder: (context, snap) {
        final users = snap.data ?? const [];
        return _cardWrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader(Icons.circle, 'En línea ahora',
                  trailingTap: users.isEmpty ? null : _openAllOnline,
                  iconColor: const Color(0xFF22C55E)),
              const SizedBox(height: 8),
              if (users.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(tr('Nadie conectado por ahora.'),
                      style: const TextStyle(color: Colors.white24, fontSize: 13)),
                )
              else
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _onlineAvatar(users[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _onlineAvatar(OnlineUser u) {
    return GestureDetector(
      onTap: () => _openMiniFromOnline(u),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                _avatar(u.avatarUrl, 22),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
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
            Text(u.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<CommunityMember> members,
      {bool showAll = true}) {
    return _cardWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(icon, title, trailingTap: showAll ? _openMembers : null),
          const SizedBox(height: 4),
          ...members.map((m) => _memberRow(m)),
        ],
      ),
    );
  }

  Widget _memberRow(CommunityMember m) {
    return InkWell(
      onTap: () => _openMini(UserProfile.fromCommunityMember(m), member: m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _avatar(m.avatarUrl ?? '', 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                m.displayName ?? 'Usuario',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader(IconData icon, String title,
      {VoidCallback? trailingTap, Color iconColor = Colors.white54}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        if (trailingTap != null)
          GestureDetector(
            onTap: trailingTap,
            child: Text(tr('Ver todo'),
                style: TextStyle(color: Wumbleheme.secondaryColor, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _avatar(String url, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Wumbleheme.surfaceColor,
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty
          ? Icon(Icons.person, color: Colors.white24, size: radius)
          : null,
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
