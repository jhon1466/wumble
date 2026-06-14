import 'dart:async';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/community/presentation/widgets/member_mini_profile.dart';
import 'avatar_frame.dart';
import '../../features/community/presentation/widgets/bot_mini_profile.dart';
import '../../features/profile/domain/user_model.dart';
import '../theme.dart';
import '../utils/profile_manager.dart';
import '../utils/media_optimizer.dart';

// ─────────────────────────────────────────────────────────────
// UserAvatar — auto-fetches avatarUrl + frame via shared Singleton Stream
// ─────────────────────────────────────────────────────────────

class UserAvatar extends StatefulWidget {
  final String? userId;
  final String avatarUrl;
  final bool isOnline;
  final String? communityId;
  final double radius;
  final bool isClickable;
  final bool showOnlineStatus;
  final bool showOnlineIndicator;
  final BoxBorder? border;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final IconData? emptyIcon;
  final VoidCallback? onTap;
  final String? displayName;
  final bool isBot;
  /// If provided, this overrides the auto-fetched frame.
  final String? avatarFrameUrl;
  final bool isPreview;
  /// When true, doesn't wait for stream to render — but still listens if uid provided
  final bool skipFirestoreSync;

  /// When true, renders animations for the avatar frame.
  final bool isAnimated;

  UserAvatar({
    super.key,
    this.userId,
    required this.avatarUrl,
    this.isOnline = false,
    this.communityId,
    this.radius = 20,
    this.isClickable = true,
    this.showOnlineStatus = true,
    this.showOnlineIndicator = true,
    this.border,
    this.gradient,
    this.boxShadow,
    this.emptyIcon,
    this.onTap,
    this.displayName,
    this.isBot = false,
    this.avatarFrameUrl,
    this.isPreview = false,
    this.skipFirestoreSync = false,
    this.isAnimated = true,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _resolvedFrameId;
  String? _resolvedGlobalAvatar;
  String? _resolvedCommunityAvatar;
  bool _profileLoaded = false;
  bool _resolvedShowOnlineStatus = true;
  bool _resolvedIsOnline = false;
  
  StreamSubscription? _profileSub;
  StreamSubscription? _communitySub;

  @override
  void initState() {
    super.initState();
    _subscribeToProfile();
  }

  @override
  void didUpdateWidget(UserAvatar old) {
    super.didUpdateWidget(old);
    
    final bool idChanged = old.userId != widget.userId || old.communityId != widget.communityId;

    if (idChanged) {
      _cancelSub();
      _subscribeToProfile();
    }
  }

  void _subscribeToProfile() {
    final String? uid = widget.userId;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _profileLoaded = true);
      return;
    }
    
    final String? communityId = (widget.communityId != null && widget.communityId!.isNotEmpty) 
        ? widget.communityId 
        : null;

    // A. Shared Global listener
    _profileSub = UserProfileManager.getProfileStream(uid).listen((data) {
      if (!mounted) return;
      
      final globalAvatar = data['avatarUrl'] as String? ?? '';
      final globalFrame = data['avatarFrameUrl'] as String?;
      final showOnline = data['showOnlineStatus'] as bool? ?? true;
      final isOnline = data['isOnline'] as bool? ?? false;

      setState(() {
        _resolvedFrameId = globalFrame;
        _resolvedGlobalAvatar = globalAvatar.isNotEmpty ? globalAvatar : null;
        _resolvedShowOnlineStatus = showOnline;
        _resolvedIsOnline = isOnline;
        _profileLoaded = true;
      });
    });

    // B. Shared Community listener
    if (communityId != null) {
      _communitySub = UserProfileManager.getMemberStream(uid, communityId).listen((data) {
        if (!mounted) return;
        final communityAvatar = data['avatarUrl'] as String? ?? '';
        setState(() {
          _resolvedCommunityAvatar = communityAvatar.isNotEmpty ? communityAvatar : null;
          _profileLoaded = true;
        });
      });
    }
  }

  void _cancelSub() {
    if (widget.userId != null) {
      _profileSub?.cancel();
      UserProfileManager.releaseProfileStream(widget.userId!);
      
      if (widget.communityId != null && widget.communityId!.isNotEmpty) {
        _communitySub?.cancel();
        UserProfileManager.releaseMemberStream(widget.userId!, widget.communityId!);
      }
    }
    _profileSub = null;
    _communitySub = null;
    _profileLoaded = false;
  }

  @override
  void dispose() {
    _cancelSub();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ─────────────────────────────────────────────────────────────
    // AISLAMIENTO TOTAL DE AVATAR
    // Si hay communityId, NO caemos al global live stream para el avatarUrl.
    // Usamos: Miembro > Prop (que suele venir de denormalización del Hub)
    // El global solo se usa si NO estamos en un Hub.
    // ─────────────────────────────────────────────────────────────
    final String? effectiveAvatarUrl;
    if (widget.communityId != null && widget.communityId!.isNotEmpty) {
      // Prioridad Hub: Stream de Miembro > Prop de la Widget (para carga instantánea)
      effectiveAvatarUrl = widget.isPreview 
          ? (widget.avatarUrl.isNotEmpty ? widget.avatarUrl : _resolvedCommunityAvatar)
          : (_resolvedCommunityAvatar ?? (widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null));
    } else {
      // Prioridad Global/General
      effectiveAvatarUrl = widget.isPreview
          ? (widget.avatarUrl.isNotEmpty ? widget.avatarUrl : _resolvedGlobalAvatar)
          : (_resolvedGlobalAvatar ?? (widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null));
    }

    // ── Avatar base ──────────────────────────────────────────
    // NOTE: Outer RepaintBoundary is at line 378/387. No inner RPB needed.
    Widget avatarBody = CircleAvatar(
      radius: widget.radius,
      backgroundColor: Wumbleheme.surfaceColor,
      backgroundImage: (effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty)
          ? CachedNetworkImageProvider(
              MediaOptimizer.avatar(
                effectiveAvatarUrl, 
                size: (widget.radius * 2).toInt(),
              ),
            )
          : null,
      child: (effectiveAvatarUrl == null || effectiveAvatarUrl.isEmpty)
          ? (widget.displayName != null && widget.displayName!.isNotEmpty)
              ? Text(
                  widget.displayName![0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: widget.radius * 0.8,
                  ),
                )
              : Icon(widget.emptyIcon ?? Icons.person,
                  size: widget.radius * 1.2, color: Colors.white24)
          : null,
    );

    // ── Border / gradient / shadow container ─────────────────
    if (widget.border != null || widget.gradient != null || widget.boxShadow != null) {
      avatarBody = Container(
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: widget.border,
          gradient: widget.gradient,
          boxShadow: widget.boxShadow,
        ),
        child: avatarBody,
      );
    }

    // ── Online indicator ─────────────────────────────────────
    final bool effectiveIsOnline = (widget.skipFirestoreSync || widget.userId == null) 
        ? widget.isOnline 
        : _resolvedIsOnline;
    
    bool effectiveShowOnline = false; // 🛑 DISABLED BY USER REQUEST

    Widget avatarWithIndicator = effectiveShowOnline && effectiveIsOnline
        ? Stack(
            children: [
              avatarBody,
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: widget.radius * 0.6,
                  height: widget.radius * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Wumbleheme.surfaceColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : avatarBody;

    // ── Bot badge ────────────────────────────────────────────
    if (widget.isBot) {
      avatarWithIndicator = Stack(
        children: [
          avatarWithIndicator,
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Wumbleheme.surfaceColor, width: 1.5),
              ),
              child: Text(
                tr('BOT'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Frame overlay ────────────────────────────────────────
    Widget finalAvatar;
    // Otherwise use the one resolved from the user's profile for real-time sync.
    // However, if we have a provided frame (e.g. from community member doc), prioritize it if resolve is still null/empty.
    final effectiveFrame = (widget.avatarFrameUrl != null && widget.avatarFrameUrl!.isNotEmpty)
        ? widget.avatarFrameUrl
        : _resolvedFrameId;

    if (effectiveFrame != null && effectiveFrame.isNotEmpty) {
      final avatarDiameter = widget.radius * 2;
      finalAvatar = RepaintBoundary(
        child: FramedAvatar(
          size: avatarDiameter,
          frameId: effectiveFrame,
          isAnimated: widget.isAnimated,
          child: avatarWithIndicator,
        ),
      );
    } else {
      finalAvatar = RepaintBoundary(child: avatarWithIndicator);
    }

    // ── Tap / click ──────────────────────────────────────────
    if (!widget.isClickable && widget.onTap == null) return finalAvatar;
    if (widget.userId == null && widget.onTap == null) return finalAvatar;

    return GestureDetector(
      onTap: widget.onTap ?? () {
        if (widget.isBot && widget.userId != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => BotMiniProfile(
              botId: widget.userId,
              communityId: widget.communityId,
            ),
          );
          return;
        }

        if (widget.userId == null) return;

        final user = UserProfile(
          id: widget.userId!,
          username: '',
          displayName: widget.displayName ?? 'Usuario',
          avatarUrl: effectiveAvatarUrl ?? '',
          bannerUrl: '',
          backgroundUrl: '',
          bio: '',
          reputation: 0,
          level: 1,
          titles: const [],
          followers: 0,
          following: 0,
          checkIns: 0,
          avatarFrameUrl: effectiveFrame,
        );

        MemberMiniProfile.show(
          context,
          user: user,
          communityId: widget.communityId,
        );
      },
      child: finalAvatar,
    );
  }
}
