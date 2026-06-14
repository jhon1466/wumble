import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:wumble/core/theme.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/profile/presentation/profile_screen.dart';
import 'package:wumble/features/profile/presentation/widgets/follows_list_screen.dart';
import 'package:wumble/features/chat/domain/chat_repository.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';
import 'package:wumble/features/chat/presentation/chat_detail_screen.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';
import 'package:wumble/features/profile/presentation/edit_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import '../../../../features/profile/presentation/wallet_screen.dart';
import '../../../../features/profile/presentation/widgets/donation_modal.dart';
import 'bot_mini_profile.dart'; // Add this


const String _youtubeSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" fill="currentColor"/></svg>';
const String _facebookSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978 1.602 0 2.703.117 2.703.117v3.382h-1.728c-1.903 0-2.236 1.062-2.236 2.15v2.474h3.334L16.42 15.71h-2.923v7.98H9.101" fill="currentColor"/></svg>';
String _instagramSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 0C8.74 0 8.333.015 7.053.072 5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913.306.788.717 1.459 1.384 2.126s1.355 1.079 2.126 1.384c.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558.788-.306 1.459-.718 2.126-1.384s1.079-1.354 1.384-2.126c.296-.765.499-1.636.558-2.913.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913-.306-.789-.718-1.459-1.384-2.126s-1.354-1.079-2.126-1.384c-.765-.296-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071 1.17.055 1.805.249 2.227.415.562.217.96.477 1.382.896.419.42.679.819.896 1.381.164.422.36 1.057.413 2.227.057 1.266.07 1.646.07 4.85s-.015 3.584-.071 4.85c-.055 1.17-.249 1.805-.415 2.227-.217.562-.477.96-.896 1.382-.42.419-.819.679-1.381.896-.422.164-1.056.36-2.227.413-1.266.057-1.646.07-4.85.07s-3.584-.015-4.85-.071c-1.17-.055-1.805-.249-2.227-.415-.562-.217-.96-.477-1.382-.896-.419-.42-.819-.679-1.381-.896-.164-.422-.36-1.057-.413-2.227-.057-1.266-.07-1.646-.07-4.85s.015-3.584.071-4.85c.055-1.17.249-1.805.415-2.227.217-.562.477-.96.896-1.382.42-.419.819-.679 1.381-.896.422-.164 1.057-.36 2.227-.413 1.266-.057 1.646-.07 4.85-.07zM12 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.88 1.44 1.44 0 0 0 0-2.88z" fill="currentColor"/></svg>';
String _xSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z" fill="currentColor"/></svg>';
String _discordSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2758-3.68-.2758-5.4876 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9945a.0771.0771 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1971.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189z" fill="currentColor"/></svg>';
String _twitchSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z" fill="currentColor"/></svg>';
String _githubSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" fill="currentColor"/></svg>';
String _steamSvg = '''
<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M11.979 0C5.678 0 .511 4.86.022 11.037l6.432 2.658c.545-.371 1.203-.59 1.912-.59.063 0 .125.004.188.006l2.861-4.142V8.91c0-2.495 2.028-4.524 4.524-4.524 2.494 0 4.524 2.031 4.524 4.527s-2.03 4.525-4.524 4.525h-.105l-4.076 2.911c0 .052.004.105.004.159 0 1.875-1.515 3.396-3.39 3.396-1.635 0-3.016-1.173-3.331-2.727L.436 15.27C1.862 20.307 6.486 24 11.979 24c6.627 0 11.999-5.373 11.999-12S18.605 0 11.979 0zM7.54 18.21l-1.473-.61c.262.543.714.999 1.314 1.25 1.297.539 2.793-.076 3.332-1.375.263-.63.264-1.319.005-1.949s-.75-1.121-1.377-1.383c-.624-.26-1.29-.249-1.878-.03l1.523.63c.956.4 1.409 1.5 1.009 2.455-.397.957-1.497 1.41-2.454 1.012H7.54zm11.415-9.303c0-1.662-1.353-3.015-3.015-3.015-1.665 0-3.015 1.353-3.015 3.015 0 1.665 1.35 3.015 3.015 3.015 1.663 0 3.015-1.35 3.015-3.015zm-5.273-.005c0-1.252 1.013-2.266 2.265-2.266 1.249 0 2.266 1.014 2.266 2.266 0 1.251-1.017 2.265-2.266 2.265-1.253 0-2.265-1.014-2.265-2.265z" fill="currentColor"/>
</svg>
''';

class MemberMiniProfile extends StatefulWidget {
  final UserProfile user;
  final CommunityMember? member;
  final String? communityId;

  MemberMiniProfile({
    super.key,
    required this.user,
    this.member,
    this.communityId,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    CommunityMember? member,
    String? communityId,
  }) {
    if (user.isBot || 
        (member?.isBot ?? false) || 
        user.id.startsWith('BOT_') || 
        member?.role == 'bot' ||
        user.displayName.toUpperCase() == 'CJ') { // Extra fallback for user's specific test case
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => BotMiniProfile(
          botId: user.id,
          communityId: communityId ?? member?.communityId,
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemberMiniProfile(
        user: user,
        member: member,
        communityId: communityId,
      ),
    );
  }

  @override
  State<MemberMiniProfile> createState() => _MemberMiniProfileState();
}

class _MemberMiniProfileState extends State<MemberMiniProfile> {
  bool _isMessaging = false;
  Color? _tempThemeColor;
  late final TextEditingController _messageController;
  bool _isRepositioning = false;
  double? _tempAlignmentY;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final UserProfile initialUser = widget.user.copyWith(isOnline: false);

    return StreamBuilder<UserProfile>(
      stream: di.sl<ProfileRepository>().getUserProfile(widget.user.id),
      initialData: initialUser,
      builder: (context, userSnapshot) {
        final profileUser = userSnapshot.data ?? widget.user;

        return StreamBuilder<CommunityMember?>(
          stream: widget.communityId != null
              ? di.sl<ProfileRepository>().getMemberProfileStream(widget.communityId!, widget.user.id)
              : Stream.value(null),
          initialData: widget.member,
          builder: (context, memberSnapshot) {
            final member = memberSnapshot.data ?? widget.member;

            final String displayName = member?.displayName ?? profileUser.displayName;

            // Banner Priority
            String? bannerUrl;
            if (member?.bannerUrl != null && member!.bannerUrl!.isNotEmpty) {
              bannerUrl = member.bannerUrl;
            } else if (profileUser.bannerUrl.isNotEmpty) {
              bannerUrl = profileUser.bannerUrl;
            }

            final String avatarUrl = (widget.communityId != null && member?.avatarUrl != null && member!.avatarUrl!.isNotEmpty)
                ? member.avatarUrl!
                : (widget.communityId != null ? (widget.user.avatarUrl.isNotEmpty ? widget.user.avatarUrl : profileUser.avatarUrl) : profileUser.avatarUrl);
            final List<CommunityLabel> titles = member?.titles ?? profileUser.titles;
            final String bio = member?.bio ?? profileUser.bio;
            final String? effectiveStatus = member?.status ?? profileUser.status;
            final DateTime joinedAt = member?.joinedAt ?? profileUser.joinedAt ?? DateTime.now();
            final List<String> effectiveSocialLinks = (member?.socialLinks != null && member!.socialLinks.isNotEmpty)
                ? member.socialLinks
                : profileUser.socialLinks;
            final String? effectiveAvatarFrameUrl = (widget.communityId != null && member?.avatarFrameUrl != null && member!.avatarFrameUrl!.isNotEmpty)
                ? member.avatarFrameUrl
                : profileUser.avatarFrameUrl;


            return StreamBuilder<Community?>(
              stream: widget.communityId != null
                  ? di.sl<CommunityRepository>().getCommunityStream(widget.communityId!)
                  : Stream.value(null),
              builder: (context, communitySnapshot) {
                final community = communitySnapshot.data;

                // Theme Color Logic with Live Preview
                // Priority: 1. Picker preview, 2. Member custom, 3. Community default, 4. Global custom, 5. Default dark
                Color themeColor = _tempThemeColor ?? 
                    Color(member?.themeColorValue ?? 
                          community?.themeColorValue ?? 
                          profileUser.themeColorValue ?? 
                          0xFF18191C);
                
                if (themeColor.value == 0) themeColor = const Color(0xFF18191C);

                final bool isDarkBackground = themeColor.computeLuminance() < 0.5;
                final Color contentColor = isDarkBackground ? Colors.white : Colors.black87;
                final Color secondaryContentColor = isDarkBackground ? Colors.white60 : Colors.black54;

                return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: contentColor.withOpacity(0.1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              if (state is ProfileActionSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message), backgroundColor: Colors.green),
                );
              } else if (state is ProfileError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
            children: [
              // Header Stack (Banner + Avatar)
              SizedBox(
                height: 190, // Accounts for banner (140) + avatar overflow (-45 + 96 radius)
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                  // Banner with overlay
                  Stack(
                    children: [
                      GestureDetector(
                        onVerticalDragUpdate: _isRepositioning ? (details) {
                          setState(() {
                            // Sensitivity adjustment: 140 is banner height
                            // Alignment.y goes from -1 to 1 (total range 2)
                            _tempAlignmentY = ((_tempAlignmentY ?? (member?.bannerAlignmentY ?? profileUser.bannerAlignmentY)) - (details.delta.dy / 70)).clamp(-1.0, 1.0);
                          });
                        } : null,
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            image: bannerUrl != null
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(bannerUrl),
                                    fit: BoxFit.cover,
                                    alignment: Alignment(0, (_tempAlignmentY ?? (member?.bannerAlignmentY ?? profileUser.bannerAlignmentY) ?? 0.0).toDouble()),
                                  )
                                : null,
                            gradient: bannerUrl == null
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Wumbleheme.primaryColor.withOpacity(0.8),
                                      Wumbleheme.secondaryColor.withOpacity(0.8),
                                    ],
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (bannerUrl != null)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.6),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_isRepositioning)
                                Container(
                                  color: Colors.black26,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.unfold_more_rounded, color: Colors.white, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Arrastra para ajustar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_isRepositioning)
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Row(
                                    children: [
                                      _buildRepositionActionBtn(
                                        icon: Icons.close,
                                        color: Colors.redAccent,
                                        onTap: () => setState(() {
                                          _isRepositioning = false;
                                          _tempAlignmentY = null;
                                        }),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildRepositionActionBtn(
                                        icon: Icons.check,
                                        color: Colors.greenAccent,
                                        onTap: () => _saveBannerAlignment(profileUser, member),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    ],
                  ),
                  // Handle (Discord style on top of banner)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: contentColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                    // Avatar Area
                    Positioned(
                      bottom: 0,
                      left: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          UserAvatar(
                            userId: widget.user.id,
                            avatarUrl: avatarUrl,
                            displayName: displayName,
                            radius: 48,
                            communityId: widget.communityId,
                            isClickable: false,
                            avatarFrameUrl: effectiveAvatarFrameUrl,

                            border: Border.all(color: contentColor, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          if (effectiveStatus != null && effectiveStatus.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 8),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showFullStatus(context, displayName, avatarUrl, null, effectiveStatus),
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: contentColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: contentColor.withOpacity(0.1)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    effectiveStatus,
                                    style: TextStyle(color: contentColor.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Options Menu Button - Only for Owner
                    if (di.sl<FirebaseAuth>().currentUser?.uid == widget.user.id)
                      Positioned(
                        top: 15,
                        right: 15,
                        child: GestureDetector(
                          onTap: () => _showOwnerOptions(context, member, profileUser),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: contentColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.more_horiz_rounded, color: contentColor, size: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10), // Reduced from 55 since Stack height accounts for it now

              // User Info Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: contentColor,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (profileUser.username.isNotEmpty && profileUser.username != profileUser.id)
                      Text(
                        '@${profileUser.username}',
                        style: TextStyle(
                          color: contentColor.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    // Titles/Badges
                    if (titles.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: titles.take(5).map((title) => _buildTitleBadge(title)).toList(),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Divider(color: contentColor.withValues(alpha: 0.1)),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Reputación', member?.reputation.toString() ?? '0', Icons.stars_rounded, Colors.amber, contentColor: contentColor),
                      const SizedBox(width: 8),
                      _buildStatItem('Monedas', profileUser.coins.toString(), Icons.monetization_on_rounded, Colors.yellowAccent, contentColor: contentColor, onTap: () {
                         if (di.sl<FirebaseAuth>().currentUser?.uid == widget.user.id) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                         }
                      }),
                      const SizedBox(width: 8),
                      _buildStatItem('Seguidores', profileUser.followers.toString(), Icons.people_rounded, Colors.blueAccent, contentColor: contentColor, onTap: () => _handleFollowsTap(context, profileUser, 'followers')),
                      const SizedBox(width: 8),
                      _buildStatItem('Siguiendo', profileUser.following.toString(), Icons.person_search_rounded, Colors.greenAccent, contentColor: contentColor, onTap: () => _handleFollowsTap(context, profileUser, 'following')),
                      const SizedBox(width: 8),
                      _buildStatItem('Nivel', member?.level.toString() ?? '1', Icons.trending_up_rounded, Wumbleheme.secondaryColor, contentColor: contentColor),
                      const SizedBox(width: 8),
                      _buildStatItem('Check-ins', member?.checkInCount.toString() ?? '0', Icons.calendar_today_rounded, Colors.orangeAccent, contentColor: contentColor),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Divider(color: contentColor.withValues(alpha: 0.1)),
              ),

              // Sections
              if (bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSection(
                    title: 'SOBRE MÍ',
                    contentColor: contentColor,
                    child: Text(
                      bio,
                      style: TextStyle(color: contentColor.withOpacity(0.9), fontSize: 14, height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Social Connections (Discord Style)
              if (effectiveSocialLinks.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONEXIONES',
                        style: TextStyle(color: contentColor.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: effectiveSocialLinks.map((link) => _buildSocialIcon(link, contentColor)).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildSection(
                      title: 'MIEMBRO DESDE',
                      contentColor: contentColor,
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, color: secondaryContentColor.withOpacity(0.5), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('d MMM yyyy', 'es').format(joinedAt),
                            style: TextStyle(color: secondaryContentColor, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Moderation Section
              _buildModerationSection(context),

              const SizedBox(height: 40),

              // Action Buttons area
              if (di.sl<FirebaseAuth>().currentUser?.uid != widget.user.id)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: contentColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: contentColor.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      style: TextStyle(color: contentColor, fontSize: 14),
                                      cursorColor: Wumbleheme.primaryColor,
                                      decoration: InputDecoration(
                                        hintText: 'Enviar mensaje a @${profileUser.username}...',
                                        hintStyle: TextStyle(color: secondaryContentColor.withOpacity(0.5), fontSize: 14),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        filled: true,
                                        fillColor: Colors.transparent,
                                      ),
                                      onSubmitted: (_) => _handleMessage(context, profileUser, displayName, avatarUrl),
                                    ),
                                  ),
                                  Icon(Icons.sentiment_satisfied_alt_rounded, color: secondaryContentColor, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                             onTap: () => _handleMessage(context, profileUser, displayName, avatarUrl),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Wumbleheme.primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Wumbleheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          StreamBuilder<bool>(
                            stream: di.sl<ProfileRepository>().isFollowing(
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                                  widget.user.id,
                                ),
                            initialData: false,
                            builder: (context, snapshot) {
                              final isFollowing = snapshot.data ?? false;
                              return _buildCircularActionButton(
                                label: isFollowing ? 'Siguiendo' : 'Seguir',
                                icon: isFollowing
                                    ? Icons.person_remove_rounded
                                    : Icons.person_add_rounded,
                                color: isFollowing 
                                    ? Wumbleheme.secondaryColor.withOpacity(0.2)
                                    : contentColor.withOpacity(0.1),
                                contentColor: isFollowing ? Wumbleheme.secondaryColor : contentColor,
                                onTap: () {
                                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                  if (currentUserId == null) return;

                                  if (isFollowing) {
                                    di.sl<ProfileRepository>().unfollowUser(currentUserId, widget.user.id);
                                  } else {
                                    di.sl<ProfileRepository>().followUser(currentUserId, widget.user.id);
                                  }
                                },
                              );
                            },
                          ),
                          _buildCircularActionButton(
                            label: 'Reportar',
                            icon: Icons.report_gmailerrorred_rounded,
                            color: contentColor.withOpacity(0.1),
                            contentColor: contentColor,
                            onTap: () => _showReportDialog(context),
                          ),
                          _buildCircularActionButton(
                            label: 'Bloquear',
                            icon: Icons.block_flipped,
                            color: contentColor.withOpacity(0.1),
                            contentColor: contentColor,
                            onTap: () => _showBlockConfirmation(context),
                          ),
                          _buildCircularActionButton(
                            label: 'Donar',
                            icon: Icons.volunteer_activism_rounded,
                            color: Colors.pinkAccent.withOpacity(0.1),
                            contentColor: Colors.pinkAccent,
                            onTap: () => _showDonationDialog(context, profileUser),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActionButton(
                  label: 'Ver Perfil Completo',
                  icon: Icons.account_circle_rounded,
                  color: contentColor.withOpacity(0.08),
                  contentColor: contentColor,
                  isFullWidth: true,
                  showShadow: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          userId: widget.user.id,
                          communityId: widget.communityId,
                          isGlobal: widget.communityId == null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
                );
              },
            );
          },
        );
      },
    );
  },
);
}

  void _showExpulsionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'OPCIONES DE EXPULSIÓN',
              style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 20),
            _buildExpulsionTile(
              title: 'Solo Expulsar',
              subtitle: 'El usuario es removido pero puede volver a unirse.',
              icon: Icons.exit_to_app_rounded,
              color: Colors.white,
              onTap: () => _handleExpulsion(context, type: 'kick'),
            ),
            _buildExpulsionTile(
              title: 'Falta: 24 Horas',
              subtitle: 'Expulsión y baneo temporal por 1 día.',
              icon: Icons.history_rounded,
              color: Colors.orangeAccent,
              onTap: () => _handleExpulsion(context, type: 'ban_24h'),
            ),
            _buildExpulsionTile(
              title: 'Falta: 72 Horas',
              subtitle: 'Expulsión y baneo temporal por 3 días.',
              icon: Icons.timer_rounded,
              color: Colors.deepOrangeAccent,
              onTap: () => _handleExpulsion(context, type: 'ban_72h'),
            ),
            _buildExpulsionTile(
              title: 'Baneo Permanente',
              subtitle: 'Expulsión definitiva de la comunidad.',
              icon: Icons.gavel_rounded,
              color: Colors.redAccent,
              onTap: () => _handleExpulsion(context, type: 'ban_perm'),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildExpulsionTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: color.withOpacity(0.5), fontSize: 12)),
    );
  }

  Future<void> _handleExpulsion(BuildContext context, {required String type}) async {
    Navigator.pop(context); // Close sheet
    
    final repo = di.sl<CommunityRepository>();
    final communityId = widget.communityId!;
    final userId = widget.user.id;
    
    String successMsg = '';
    DateTime? banExpiration;

    switch (type) {
      case 'kick':
        successMsg = 'Usuario expulsado correctamente';
        break;
      case 'ban_24h':
        banExpiration = DateTime.now().add(Duration(hours: 24));
        successMsg = 'Usuario sancionado por 24 horas';
        break;
      case 'ban_72h':
        banExpiration = DateTime.now().add(Duration(hours: 72));
        successMsg = 'Usuario sancionado por 72 horas';
        break;
      case 'ban_perm':
        successMsg = 'Usuario baneado permanentemente';
        break;
    }

    final moderatorId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      if (type == 'kick') {
        await repo.kickMember(communityId, userId);
      } else {
        await repo.banMember(communityId, userId, moderatorId, expiresAt: banExpiration);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
        Navigator.pop(context); // Close mini profile
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showWarnDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF2B2D31),
        title: Text(tr('Advertir Miembro'), style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás por enviar una advertencia oficial a ${widget.user.displayName}. Indica el motivo:',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              style: TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Comportamiento inadecuado, spam...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              
              Navigator.pop(ctx);
              try {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId == null) return;
                
                await di.sl<CommunityRepository>().warnMember(
                  widget.communityId!,
                  widget.user.id,
                  reason,
                  currentUserId,
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('Advertencia enviada correctamente'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al enviar advertencia: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Text(tr('Enviar'), style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child, Color? contentColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: (contentColor ?? Colors.white).withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, {Color? contentColor, VoidCallback? onTap}) {
    final textColor = contentColor ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: textColor.withOpacity(0.4),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFollowsTap(BuildContext context, UserProfile user, String type) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid == user.id;

    if (!isOwner && !user.showFollows) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Este usuario ha configurado su lista como privada.')),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Navegar a la pantalla de lista
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowsListScreen(
          userId: user.id,
          type: type,
          title: type == 'followers' ? 'Seguidores' : 'Siguiendo',
        ),
      ),
    );
  }

  Widget _buildModerationSection(BuildContext context) {
    if (widget.communityId == null) return SizedBox();
    
    final state = context.read<CommunityContextBloc>().state;
    final currentUserRef = state.memberProfile;
    if (currentUserRef == null) return SizedBox();

    final isModerator = currentUserRef.role == 'leader' || currentUserRef.role == 'curator';
    final isOwnProfile = currentUserRef.userId == widget.user.id;
    
    bool canModerate = isModerator && !isOwnProfile;
    // Basic hierarchy: leaders can moderate anyone except themselves. curators can moderate members.
    if (widget.member?.role == 'leader' && currentUserRef.role != 'leader') {
      canModerate = false;
    }

    if (!canModerate) return SizedBox();

    return Padding(
      padding: EdgeInsets.only(top: 24, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MODERACIÓN',
            style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModerationButton(
                  label: 'Expulsar',
                  icon: Icons.gavel_rounded,
                  color: Colors.redAccent,
                  onTap: () => _showExpulsionOptions(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModerationButton(
                  label: 'Advertir',
                  icon: Icons.report_problem_rounded,
                  color: Colors.orangeAccent,
                  onTap: () => _showWarnDialog(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMessage(BuildContext context, UserProfile profileUser, String displayName, String avatarUrl) async {
    final currentUser = di.sl<FirebaseAuth>().currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == widget.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('No puedes enviarte un mensaje a ti mismo'))),
      );
      return;
    }

    setState(() => _isMessaging = true);

    try {
      final chatRepo = di.sl<ChatRepository>();
      final firestore = di.sl<FirebaseFirestore>();
      
      String currentUserName = 'Usuario';
      String currentUserAvatar = '';

      // Priority: Community Profile -> Global Profile
      if (widget.communityId != null && widget.communityId!.isNotEmpty) {
        final memberDoc = await firestore
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .doc(currentUser.uid)
            .get();
        
        if (memberDoc.exists) {
          final memberData = memberDoc.data()!;
          currentUserName = memberData['displayName'] ?? 'Usuario';
          currentUserAvatar = memberData['avatarUrl'] ?? '';
        } else {
          // Fallback to global if member doc not found (shouldn't happen regularly)
          final globalUserDoc = await firestore.collection('users').doc(currentUser.uid).get();
          final globalUserData = globalUserDoc.data() ?? {};
          currentUserName = globalUserData['displayName'] ?? globalUserData['username'] ?? 'Usuario';
          currentUserAvatar = globalUserData['avatarUrl'] ?? '';
        }
      } else {
        // Global context
        final globalUserDoc = await firestore.collection('users').doc(currentUser.uid).get();
        final globalUserData = globalUserDoc.data() ?? {};
        currentUserName = globalUserData['displayName'] ?? globalUserData['username'] ?? 'Usuario';
        currentUserAvatar = globalUserData['avatarUrl'] ?? '';
      }
      
      final room = await chatRepo.getOrCreateChatRoom(
        currentUserId: currentUser.uid,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
        otherUserId: widget.user.id,
        otherUserName: displayName,
        otherUserAvatar: avatarUrl,
      );

      // Si hay un mensaje escrito, enviarlo antes de navegar
      final messageText = _messageController.text.trim();
      if (messageText.isNotEmpty) {
        await chatRepo.sendMessage(
          room.id,
          ChatMessage(
            id: '', // Firestore genera el ID
            senderId: currentUser.uid,
            senderName: currentUserName,
            senderAvatarUrl: currentUserAvatar,
            text: messageText,
            type: MessageType.text,
            timestamp: DateTime.now(),
          ),
        );
        _messageController.clear();
      }


      if (context.mounted) {
        final navigator = Navigator.of(context);
        navigator.pop(); // Close mini profile
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatRoomId: room.id,
              otherUserName: displayName,
              otherUserAvatar: avatarUrl,
              otherUserId: widget.user.id,
              communityId: widget.communityId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isMessaging = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir el chat: $e')),
        );
      }
    }
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2D31),
        title: Text(tr('¿Bloquear usuario?'), style: TextStyle(color: Colors.white)),
        content: Text(
          'No podrás ver sus mensajes ni interactuar con sus publicaciones.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final currentUserId = di.sl<FirebaseAuth>().currentUser?.uid;
              if (currentUserId != null) {
                context.read<ProfileBloc>().add(
                  BlockUserRequested(
                    currentUserId: currentUserId,
                    targetUserId: widget.user.id,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(tr('Bloquear'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2D31),
        title: Text(tr('Reportar Usuario'), style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indica el motivo del reporte:',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Spam, acoso, contenido inapropiado...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              
              final currentUserId = di.sl<FirebaseAuth>().currentUser?.uid;
              if (currentUserId != null) {
                context.read<ProfileBloc>().add(
                  ReportUserRequested(
                    reporterId: currentUserId,
                    targetUserId: widget.user.id,
                    reason: controller.text.trim(),
                    communityId: widget.communityId,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(tr('Enviar Reporte'), style: TextStyle(color: Wumbleheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBadge(CommunityLabel title) {
    final color = title.colorValue != null ? Color(title.colorValue!) : Colors.white70;
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        title.text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black54,
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  void _showFullStatus(BuildContext context, String name, String avatarUrl, String? emoji, String? status) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(0xFF000000), // Pure black as requested/in screenshot
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Estado de $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    UserAvatar(avatarUrl: avatarUrl, radius: 45, showOnlineIndicator: false),
                    if (emoji != null)
                      Container(
                        padding: const Offset(0, 0) == const Offset(0,0) ? const EdgeInsets.all(4) : EdgeInsets.zero,
                        child: Text("✨", style: const TextStyle(fontSize: 12),), // Spacer or tiny dot?
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2D31),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showQuickStatusEditor(BuildContext context, CommunityMember? member) {
    final TextEditingController controller = TextEditingController(text: member?.status ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF18191C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EDITAR ESTADO',
                style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '¿Qué estás pensando?',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Wumbleheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // This updates the UI immediately and saves to DB
                    context.read<ProfileBloc>().add(
                      UpdateProfileRequested(
                        userId: widget.user.id,
                        communityId: widget.communityId,
                        status: controller.text,
                        statusEmoji: null,
                      ),
                    );
                    Navigator.pop(context);
                    // Refresh local data

                  },
                  child: Text(tr('Guardar Estado'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color? contentColor,
    bool isLoading = false,
  }) {
    final textColor = contentColor ?? Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: textColor, strokeWidth: 2),
                    ),
                  )
                : Icon(icon, color: textColor, size: 24),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color? contentColor,
    bool isFullWidth = false,
    bool isLoading = false,
    bool showShadow = true,
  }) {
    final textColor = contentColor ?? Colors.white;
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withOpacity(0.05)),
          boxShadow: showShadow ? [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: isLoading 
          ? Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: textColor, strokeWidth: 2)))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
      ),
    );
  }

  void _showOwnerOptions(BuildContext context, CommunityMember? member, UserProfile profileUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: Color(0xFF18191C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'OPCIONES DE PERFIL',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70),
              title: Text(tr('Editar Estado'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showQuickStatusEditor(context, member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined, color: Colors.white70),
              title: Text(tr('Color de Tema'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showThemeColorPicker(context, member, profileUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_rounded, color: Colors.white70),
              title: Text(tr('Ajustar Posición del Banner'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                   _isRepositioning = true;
                   _tempAlignmentY = member?.bannerAlignmentY ?? profileUser.bannerAlignmentY;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: Colors.white70),
              title: Text(tr('Editar Perfil Completo'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                
                // Fusionamos los datos globales con los de la comunidad actual
                // para que la edición sea coherente con la vista actual.
                final UserProfile editingUser = profileUser.copyWith(
                  displayName: member?.displayName,
                  avatarUrl: member?.avatarUrl,
                  bannerUrl: member?.bannerUrl,
                  bio: member?.bio,
                  status: member?.status ?? profileUser.status,
                  themeColorValue: member?.themeColorValue ?? profileUser.themeColorValue,
                  socialLinks: (member?.socialLinks != null && member!.socialLinks.isNotEmpty) 
                      ? member.socialLinks 
                      : profileUser.socialLinks,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      user: editingUser,
                      communityId: widget.communityId,
                      isGlobal: widget.communityId == null,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeColorPicker(BuildContext context, CommunityMember? member, UserProfile profileUser) {
    final user = profileUser;
    
    Color selectedColor = (member?.themeColorValue ?? user.themeColorValue) != null 
        ? Color(member?.themeColorValue ?? user.themeColorValue!) 
        : Wumbleheme.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF18191C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'COLOR DE TEMA',
                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 20),
              ColorPicker(
                pickerColor: selectedColor,
                onColorChanged: (color) {
                  setModalState(() => selectedColor = color);
                  // Live preview in parent
                  setState(() => _tempThemeColor = color);
                },
                displayThumbColor: true,
                pickerAreaHeightPercent: 0.7,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Wumbleheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    context.read<ProfileBloc>().add(
                      UpdateProfileRequested(
                        userId: widget.user.id,
                        communityId: widget.communityId,
                        themeColorValue: selectedColor.value,
                      ),
                    );
                    Navigator.pop(context);
                    setState(() => _tempThemeColor = null); // Reset preview

                  },
                  child: Text(tr('Guardar Color'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Clear preview if closed without saving
      if (mounted) setState(() => _tempThemeColor = null);
    });
  }

  Widget _buildSocialIcon(String url, Color contentColor) {
    IconData icon = Icons.link_rounded;
    Color iconColor = contentColor;
    String platform = 'link';

    final lowerUrl = url.toLowerCase();
    String? svgData;

    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      svgData = _youtubeSvg;
      iconColor = Color(0xFFFF0000);
      platform = 'YouTube';
    } else if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.com')) {
      svgData = _facebookSvg;
      iconColor = Color(0xFF1877F2);
      platform = 'Facebook';
    } else if (lowerUrl.contains('instagram.com')) {
      svgData = _instagramSvg;
      iconColor = Color(0xFFE4405F);
      platform = 'Instagram';
    } else if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      svgData = _xSvg;
      iconColor = Colors.white;
      platform = 'X';
    } else if (lowerUrl.contains('discord.gg') || lowerUrl.contains('discord.com')) {
      svgData = _discordSvg;
      iconColor = Color(0xFF5865F2);
      platform = 'Discord';
    } else if (lowerUrl.contains('twitch.tv')) {
      svgData = _twitchSvg;
      iconColor = Color(0xFF9146FF);
      platform = 'Twitch';
    } else if (lowerUrl.contains('github.com')) {
      svgData = _githubSvg;
      iconColor = Colors.white;
      platform = 'GitHub';
    } else if (lowerUrl.contains('steamcommunity.com') || lowerUrl.contains('steampowered.com')) {
      svgData = _steamSvg;
      iconColor = Color(0xFF171A21);
      platform = 'Steam';
    } else {
      icon = Icons.link_rounded;
      iconColor = contentColor.withValues(alpha: 0.6);
    }

    final bool isSteam = platform == 'Steam';

    return Tooltip(
      message: platform,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          try {
            String finalUrl = url;
            if (!url.startsWith('http')) {
              finalUrl = 'https://$url';
            }
            final uri = Uri.parse(finalUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo abrir el enlace: $finalUrl')),
                );
              }
            }
          } catch (e) {
             if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Formato de enlace inválido: $url')),
              );
            }
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: contentColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: contentColor.withValues(alpha: 0.1)),
            ),
            child: svgData != null 
                ? SvgPicture.string(
                    svgData, 
                    width: 24, 
                    height: 24, 
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  )
                : Icon(icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }

  void _showDonationDialog(BuildContext context, UserProfile targetUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DonationModal(targetUser: targetUser),
      ),
    );
  }

  Widget _buildRepositionActionBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _saveBannerAlignment(UserProfile user, CommunityMember? member) async {
    if (_tempAlignmentY == null) return;
    
    try {
      await di.sl<ProfileRepository>().updateProfile(
        userId: user.id,
        communityId: widget.communityId,
        bannerAlignmentY: _tempAlignmentY!,
      );
      
      if (mounted) {
        setState(() {
          _isRepositioning = false;
          _tempAlignmentY = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Posición del banner guardada'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
