import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'profile_bloc.dart';
import '../../chat/domain/moderation_service.dart';
import '../../chat/domain/bot_framework.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/media_helper.dart';
import '../domain/user_model.dart';
import '../../community/domain/community_member_model.dart';
import '../../../../core/theme.dart';
import 'bubble_selector_screen.dart';
import 'frame_shop_screen.dart';
import '../../chat/domain/chat_model.dart';

String _youtubeSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" fill="currentColor"/></svg>';
String _facebookSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978 1.602 0 2.703.117 2.703.117v3.382h-1.728c-1.903 0-2.236 1.062-2.236 2.15v2.474h3.334L16.42 15.71h-2.923v7.98H9.101" fill="currentColor"/></svg>';
String _instagramSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 0C8.74 0 8.333.015 7.053.072 5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913.306.788.717 1.459 1.384 2.126s1.355 1.079 2.126 1.384c.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558.788-.306 1.459-.718 2.126-1.384s1.079-1.354 1.384-2.126c.296-.765.499-1.636.558-2.913.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913-.306-.789-.718-1.459-1.384-2.126s-1.354-1.079-2.126-1.384c-.765-.296-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071 1.17.055 1.805.249 2.227.415.562.217.96.477 1.382.896.419.42.679.819.896 1.381.164.422.36 1.057.413 2.227.057 1.266.07 1.646.07 4.85s-.015 3.584-.071 4.85c-.055 1.17-.249 1.805-.415 2.227-.217.562-.477.96-.896 1.382-.42.419-.819.679-1.381.896-.422.164-1.056.36-2.227.413-1.266.057-1.646.07-4.85.07s-3.584-.015-4.85-.071c-1.17-.055-1.805-.249-2.227-.415-.562-.217-.96-.477-1.382-.896-.419-.42-.679-.819-.896-1.381-.164-.422-.36-1.057-.413-2.227-.057-1.266-.07-1.646-.07-4.85s.015-3.584.071-4.85c.055-1.17.249-1.805.415-2.227.217-.562.477-.96.896-1.382.42-.419.819-.679 1.381-.896.422-.164 1.057-.36 2.227-.413 1.266-.057 1.646-.07 4.85-.07zM12 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.88 1.44 1.44 0 0 0 0-2.88z" fill="currentColor"/></svg>';
String _xSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z" fill="currentColor"/></svg>';
String _discordSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2758-3.68-.2758-5.4876 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9945a.0771.0771 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1971.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189z" fill="currentColor"/></svg>';
String _twitchSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z" fill="currentColor"/></svg>';
String _githubSvg = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" fill="currentColor"/></svg>';
String _steamSvg = '''
<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M11.979 0C5.678 0 .511 4.86.022 11.037l6.432 2.658c.545-.371 1.203-.59 1.912-.59.063 0 .125.004.188.006l2.861-4.142V8.91c0-2.495 2.028-4.524 4.524-4.524 2.494 0 4.524 2.031 4.524 4.527s-2.03 4.525-4.524 4.525h-.105l-4.076 2.911c0 .052.004.105.004.159 0 1.875-1.515 3.396-3.39 3.396-1.635 0-3.016-1.173-3.331-2.727L.436 15.27C1.862 20.307 6.486 24 11.979 24c6.627 0 11.999-5.373 11.999-12S18.605 0 11.979 0zM7.54 18.21l-1.473-.61c.262.543.714.999 1.314 1.25 1.297.539 2.793-.076 3.332-1.375.263-.63.264-1.319.005-1.949s-.75-1.121-1.377-1.383c-.624-.26-1.29-.249-1.878-.03l1.523.63c.956.4 1.409 1.5 1.009 2.455-.397.957-1.497 1.41-2.454 1.012H7.54zm11.415-9.303c0-1.662-1.353-3.015-3.015-3.015-1.665 0-3.015 1.353-3.015 3.015 0 1.665 1.35 3.015 3.015 3.015 1.663 0 3.015-1.35 3.015-3.015zm-5.273-.005c0-1.252 1.013-2.266 2.265-2.266 1.249 0 2.266 1.014 2.266 2.266 0 1.251-1.017 2.265-2.266 2.265-1.253 0-2.265-1.014-2.265-2.265z" fill="currentColor"/>
</svg>
''';

class EditProfileScreen extends StatefulWidget {
  final UserProfile user;
  final String? communityId;
  final bool isGlobal;
  EditProfileScreen({super.key, required this.user, this.communityId, this.isGlobal = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _usernameController;
  late TextEditingController _statusTextController;
  late List<TextEditingController> _socialControllers;
  
  String? _avatarPath;
  String? _bannerPath;
  String? _backgroundPath;
  Color? _themeColor;
  late bool _showFollows;
  late List<TextEditingController> _titleControllers;
  late List<int?> _titleColors;
  ChatBubbleStyle? _bubbleStyle;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
    _usernameController = TextEditingController(text: widget.user.username);
    _statusTextController = TextEditingController(text: widget.user.status);
    _themeColor = widget.user.themeColorValue != null ? Color(widget.user.themeColorValue!) : null;
    _socialControllers = widget.user.socialLinks.map((link) => TextEditingController(text: link)).toList();
    if (_socialControllers.isEmpty) {
      _socialControllers.add(TextEditingController());
    }
    _showFollows = widget.user.showFollows;
    _titleControllers = widget.user.titles.map((t) => TextEditingController(text: t.text)).toList();
    _titleColors = widget.user.titles.map((t) => t.colorValue).toList();
    _bubbleStyle = widget.user.chatBubbleStyle;
    _birthday = widget.user.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    _statusTextController.dispose();
    for (var controller in _socialControllers) {
      controller.dispose();
    }
    for (var controller in _titleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final image = await MediaHelper.pickImageWithOptimization(context);

    if (image != null) {
      final size = (await image.length()) / (1024 * 1024);
      
      setState(() {
        if (type.contains('Avatar')) {
          _avatarPath = image.path;
        } else if (type == 'Banner') {
          _bannerPath = image.path;
        } else if (type == 'Fondo') {
          _backgroundPath = image.path;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imagen optimizada con éxito (${size.toStringAsFixed(2)}MB)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(tr('Editar Perfil')),
            backgroundColor: Wumbleheme.backgroundColor,
            actions: [
              BlocListener<ProfileBloc, ProfileState>(
                listener: (context, state) {
                  if (state is ProfileUpdateSuccess) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Wumbleheme.surfaceColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
                        content: Text(
                          tr('¡Perfil actualizado correctamente!'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(); // Close Success Dialog
                              Navigator.of(context).pop(); // Close Edit Screen
                            },
                            child: Text(tr('Genial'), style: TextStyle(color: Wumbleheme.secondaryColor)),
                          ),
                        ],
                      ),
                    );
                  } else if (state is ProfileError) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Wumbleheme.surfaceColor,
                        title: Text(tr('Error'), style: TextStyle(color: Colors.white)),
                        content: Text(state.message, style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(tr('Cerrar'), style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    final isLoading = state is ProfileUpdateInProgress;
                    return TextButton(
                      onPressed: isLoading
                          ? null
                           : () async {
                                // --- Phase 14: Profile Moderation (SECURE_GUARD_V1) ---
                                ModerationLevel level = ModerationLevel.medium;
                                if (widget.communityId != null) {
                                  try {
                                    final botsSnapshot = await FirebaseFirestore.instance
                                        .collection('communities')
                                        .doc(widget.communityId)
                                        .collection('bots')
                                        .where('isActive', isEqualTo: true)
                                        .where('isGuardian', isEqualTo: true)
                                        .limit(1)
                                        .get();
                                    if (botsSnapshot.docs.isNotEmpty) {
                                      final bot = BotConfig.fromFirestore(botsSnapshot.docs.first);
                                      level = bot.feedModerationSensitivity < 0.3 ? ModerationLevel.low : (bot.feedModerationSensitivity < 0.7 ? ModerationLevel.medium : ModerationLevel.high);
                                    }
                                  } catch (_) {}
                                }

                                // 1. IMAGE MODERATION (NSFW SCAN)
                                if (_avatarPath != null && _avatarPath != "[DELETE]") {
                                  final res = await ModerationService.analyzeImage(File(_avatarPath!), level: level);
                                  if (res.isFlagged && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Avatar bloqueado por System Assistant: ${res.reason}'), backgroundColor: Colors.red));
                                    return;
                                  }
                                }
                                if (_bannerPath != null && _bannerPath != "[DELETE]") {
                                  final res = await ModerationService.analyzeImage(File(_bannerPath!), level: level);
                                  if (res.isFlagged && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Banner bloqueado por System Assistant: ${res.reason}'), backgroundColor: Colors.red));
                                    return;
                                  }
                                }
                                if (_backgroundPath != null && _backgroundPath != "[DELETE]") {
                                  final res = await ModerationService.analyzeImage(File(_backgroundPath!), level: level);
                                  if (res.isFlagged && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fondo bloqueado por System Assistant: ${res.reason}'), backgroundColor: Colors.red));
                                    return;
                                  }
                                }

                                // 2. TEXT MODERATION
                                // Check Display Name
                                if (_nameController.text.isNotEmpty) {
                                  final res = await ModerationService.analyzeText(_nameController.text, level: level);
                                  if (res.isFlagged && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nombre bloqueado: ${res.reason}'), backgroundColor: Colors.red));
                                    return;
                                  }
                                }
                                // Check Bio
                                if (_bioController.text.isNotEmpty) {
                                  final res = await ModerationService.analyzeText(_bioController.text, level: level);
                                  if (res.isFlagged && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biografía bloqueada: ${res.reason}'), backgroundColor: Colors.red));
                                    return;
                                  }
                                }

                                if (!mounted) return;
                                context.read<ProfileBloc>().add(
                                    UpdateProfileRequested(
                                      userId: widget.user.id,
                                      communityId: widget.communityId,
                                      username: widget.communityId == null ? _usernameController.text : null,
                                      displayName: _nameController.text,
                                      bio: _bioController.text,
                                      status: _statusTextController.text,
                                      statusEmoji: null,
                                      avatarPath: _avatarPath,
                                      bannerPath: _bannerPath,
                                      backgroundPath: _backgroundPath,
                                      themeColorValue: _themeColor?.value,
                                      socialLinks: _socialControllers
                                          .map((c) => c.text.trim())
                                          .where((link) => link.isNotEmpty)
                                          .toList(),
                                      showFollows: _showFollows,
                                      titles: List.generate(_titleControllers.length, (i) => 
                                        CommunityLabel(text: _titleControllers[i].text, colorValue: _titleColors[i])),
                                      chatBubbleStyle: _bubbleStyle,
                                      birthday: _birthday,
                                    ),
                                  );
                            },
                      child: Text(
                        isLoading ? 'Guardando...' : 'Guardar',
                        style: TextStyle(
                          color: isLoading ? Wumbleheme.secondaryColor.withOpacity(0.5) : Wumbleheme.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // FULL BACKGROUND PREVIEW (WYSIWYG)
              Positioned.fill(
                child: Container(
                  color: Wumbleheme.backgroundColor,
                  child: _backgroundPath != null
                      ? (_backgroundPath == "[DELETE]"
                          ? null
                          : Image.file(File(_backgroundPath!), fit: BoxFit.cover))
                      : (widget.user.backgroundUrl.isNotEmpty
                          ? Image.network(widget.user.backgroundUrl, fit: BoxFit.cover)
                          : null),
                ),
              ),
              // DARK OVERLAY (Like real profile)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                ),
              ),

              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER PREVIEW (WYSIWYG)
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none, // Allow avatar to overflow
                      children: [
                        // Banner Selection Area
                        GestureDetector(
                          onTap: () => _pickImage('Banner'),
                          child: Container(
                            height: 240,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Wumbleheme.surfaceColor.withOpacity(0.5),
                              image: _bannerPath != null
                                  ? (_bannerPath == "[DELETE]"
                                      ? null
                                      : DecorationImage(
                                          image: FileImage(File(_bannerPath!)), 
                                          fit: BoxFit.cover,
                                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
                                        ))
                                  : (widget.user.bannerUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(widget.user.bannerUrl), 
                                          fit: BoxFit.cover,
                                          alignment: Alignment(0, widget.user.bannerAlignmentY),
                                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
                                        )
                                      : null),
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(tr('Cambiar Banner'), style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Delete Banner Button
                        if (_bannerPath != null || widget.user.bannerUrl.isNotEmpty)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withOpacity(0.5),
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () => setState(() => _bannerPath = "[DELETE]"),
                              ),
                            ),
                          ),
                        
                        // Avatar Selection Area (Overlapping Banner)
                        Positioned(
                          bottom: -20, // Moved up requested (was -40)
                          left: 0, 
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _pickImage('Avatar'),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _avatarPath != null
                                          ? (_avatarPath == "[DELETE]"
                                              ? Container(color: Wumbleheme.secondaryColor)
                                              : Image.file(File(_avatarPath!), fit: BoxFit.cover))
                                          : (widget.user.avatarUrl.isNotEmpty
                                              ? Image.network(widget.user.avatarUrl, fit: BoxFit.cover)
                                              : Container(
                                                  color: Wumbleheme.secondaryColor,
                                                  child: const Icon(Icons.person, size: 50, color: Colors.white),
                                                )),
                                    ),
                                  ),
                                  // Edit Icon
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Wumbleheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                  ),
                                  
                                  // Remove Avatar Button
                                  if (_avatarPath != null && _avatarPath != "[DELETE]" || (widget.user.avatarUrl.isNotEmpty && _avatarPath != "[DELETE]"))
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _avatarPath = "[DELETE]"),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 50), // Added space for avatar overlap

                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Name Field
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(tr('Nombre (Apodo)'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                prefixIcon: const Icon(Icons.person_outline, color: Wumbleheme.primaryColor),
                                hintText: tr('Tu nombre visible'),
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Username Field (ID)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(tr('ID de Usuario'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: _usernameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                prefixIcon: const Icon(Icons.alternate_email, color: Wumbleheme.primaryColor),
                                hintText: tr('Tu ID único'),
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          
                          // Bio Field
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(tr('Biografía'), style: const TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: _bioController,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 4,
                              maxLength: 140,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                hintText: tr('Cuéntanos algo sobre ti...'),
                                counterStyle: const TextStyle(color: Wumbleheme.textSecondary),
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          
                          // Status & Mood
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(tr('Estado'), style: const TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                           Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: _statusTextController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: tr('¿Qué estás pensando?'),
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: Wumbleheme.primaryColor, size: 20),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 12),
                          
                          // Birthday Field
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(tr('Fecha de Nacimiento'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          InkWell(
                            onTap: widget.user.birthday != null ? null : () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _birthday ?? DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                                locale: const Locale('es', 'ES'),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Wumbleheme.secondaryColor,
                                        onPrimary: Colors.white,
                                        surface: Wumbleheme.surfaceColor,
                                        onSurface: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null && picked != _birthday) {
                                setState(() => _birthday = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cake_outlined, color: Wumbleheme.primaryColor, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _birthday == null 
                                        ? 'Toca para configurar' 
                                        : '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}',
                                    style: TextStyle(
                                      color: _birthday == null ? Colors.white38 : Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.user.birthday != null)
                                    const Icon(Icons.lock_outline, color: Colors.white24, size: 16)
                                  else
                                    const Icon(Icons.calendar_today_outlined, color: Colors.white24, size: 16),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 30),

                          // Personalización (Bubbles + Frames)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(tr('Personalización'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          InkWell(
                            onTap: () async {
                              final result = await Navigator.push<ChatBubbleStyle>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BubbleSelectorScreen(
                                    currentStyle: _bubbleStyle,
                                    ownedStyles: widget.user.ownedBubbleStyles,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() => _bubbleStyle = result);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _bubbleStyle != null 
                                          ? Color(_bubbleStyle!.backgroundColorValue) 
                                          : Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white24),
                                      gradient: _bubbleStyle?.secondaryColorValue != null 
                                          ? LinearGradient(colors: [Color(_bubbleStyle!.backgroundColorValue), Color(_bubbleStyle!.secondaryColorValue!)]) 
                                          : null,
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tr('Burbuja de Chat'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(_bubbleStyle?.name ?? 'Clásico', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right, color: Colors.white24),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 8),

                          // Avatar Frame Card
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FrameShopScreen(user: widget.user),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Wumbleheme.primaryColor.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Icon(Icons.crop_square_rounded, color: Colors.white, size: 18),
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tr('Marco de Avatar'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(
                                        widget.user.avatarFrameUrl != null && widget.user.avatarFrameUrl!.isNotEmpty
                                            ? 'Marco equipado'
                                            : 'Sin marco',
                                        style: TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  Icon(Icons.chevron_right, color: Colors.white24),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 24),

                          // Theme Color Section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(tr('Color de Tema (Mini-Perfil)'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Wumbleheme.surfaceColor,
                                  title: Text(tr('Elige un color'), style: TextStyle(color: Colors.white)),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: _themeColor ?? Wumbleheme.primaryColor,
                                      onColorChanged: (color) => setState(() => _themeColor = color),
                                      displayThumbColor: true,
                                      pickerAreaHeightPercent: 0.8,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(tr('Hecho'), style: TextStyle(color: Wumbleheme.secondaryColor)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _themeColor ?? Wumbleheme.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(tr('Personalizar color del mini-perfil'), style: TextStyle(color: Colors.white70)),
                                  Spacer(),
                                  if (_themeColor != null)
                                    IconButton(
                                      icon: Icon(Icons.refresh, color: Colors.white24, size: 20),
                                      onPressed: () => setState(() => _themeColor = null),
                                      tooltip: tr('Restablecer'),
                                    ),
                                  Icon(Icons.chevron_right, color: Colors.white24),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 16),
                          
                          // Background Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickImage('Fondo'),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.white24),
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: Icon(Icons.image, color: Colors.white70),
                                  label: Text(
                                    (_backgroundPath != null && _backgroundPath != "[DELETE]") || widget.user.backgroundUrl.isNotEmpty 
                                        ? 'Cambiar Fondo' 
                                        : 'Añadir Fondo', 
                                    style: TextStyle(color: Colors.white, fontSize: 13)
                                  ),
                                ),
                              ),
                              if (_backgroundPath != "[DELETE]" && (_backgroundPath != null || widget.user.backgroundUrl.isNotEmpty)) ...[
                                SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => setState(() => _backgroundPath = "[DELETE]"),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: Colors.redAccent.withOpacity(0.05),
                                  ),
                                  child: Icon(Icons.delete_outline, color: Colors.redAccent),
                                ),
                              ],
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Privacy Section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(tr('Privacidad'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: SwitchListTile(
                              value: _showFollows,
                              onChanged: (v) => setState(() => _showFollows = v),
                              title: Text(tr('Mostrar Seguidores y Siguiendo'), style: TextStyle(color: Colors.white, fontSize: 14)),
                              subtitle: Text(tr('Si se desactiva, otros no podrán ver estas listas.'), style: TextStyle(color: Colors.white38, fontSize: 11)),
                              activeColor: Wumbleheme.secondaryColor,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            ),
                          ),
                          
                          SizedBox(height: 30),

                          // Mis Etiquetas Section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(tr('Mis Etiquetas (Títulos)'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                if (_titleControllers.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(tr('No tienes etiquetas personalizadas.'), 
                                      style: TextStyle(color: Colors.white24, fontSize: 12)),
                                  ),
                                ...List.generate(_titleControllers.length, (index) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: index < _titleControllers.length - 1 
                                          ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))) 
                                          : null,
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      leading: GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: Wumbleheme.surfaceColor,
                                              title: Text(tr('Color de la etiqueta'), style: TextStyle(color: Colors.white)),
                                              content: SingleChildScrollView(
                                                child: BlockPicker(
                                                  pickerColor: _titleColors[index] != null ? Color(_titleColors[index]!) : Wumbleheme.primaryColor,
                                                  onColorChanged: (color) {
                                                    setState(() {
                                                      _titleColors[index] = color.value;
                                                    });
                                                  },
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: Text(tr('Listo'), style: TextStyle(color: Wumbleheme.secondaryColor)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: _titleColors[index] != null ? Color(_titleColors[index]!) : Wumbleheme.primaryColor,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.white24),
                                          ),
                                          child: const Icon(Icons.palette, color: Colors.white, size: 12),
                                        ),
                                      ),
                                      title: TextField(
                                        controller: _titleControllers[index],
                                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          hintText: tr('Nombre de etiqueta...'),
                                          hintStyle: TextStyle(color: Colors.white24),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => setState(() {
                                          _titleControllers[index].dispose();
                                          _titleControllers.removeAt(index);
                                          _titleColors.removeAt(index);
                                        }),
                                      ),
                                    ),
                                  );
                                }),
                                InkWell(
                                  onTap: () => setState(() {
                                    _titleControllers.add(TextEditingController(text: 'Nueva Etiqueta'));
                                    _titleColors.add(0xFF18191C);
                                  }),
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_circle_outline, color: Wumbleheme.secondaryColor, size: 16),
                                        SizedBox(width: 8),
                                        Text(tr('Añadir Etiqueta'), style: TextStyle(color: Wumbleheme.secondaryColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 30),

                          // Social Links Section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(tr('Redes Sociales (Conexiones)'), style: TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                            ),
                          ),
                          
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _socialControllers.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: TextField(
                                          controller: _socialControllers[index],
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            hintText: tr('Enlace (YouTube, Instagram, etc.)'),
                                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: _getSocialIconWidget(_socialControllers[index].text),
                                            ),
                                          ),
                                          onChanged: (v) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                                      onPressed: () {
                                        setState(() {
                                          if (_socialControllers.length > 1) {
                                            _socialControllers[index].dispose();
                                            _socialControllers.removeAt(index);
                                          } else {
                                            _socialControllers[index].clear();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => _socialControllers.add(TextEditingController())),
                            icon: Icon(Icons.add_circle_outline, color: Wumbleheme.secondaryColor),
                            label: Text(tr('Añadir otra red social'), style: TextStyle(color: Wumbleheme.secondaryColor)),
                          ),
                          
                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // OVERLAY FOR LOADING STATE (Now covers AppBar too)
        BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileUpdateInProgress) {
              return Stack(
                children: [
                  // Semi-transparent background
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black.withOpacity(0.7),
                  ),
                  // Center Card
                  Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: EdgeInsets.all(24),
                        margin: EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Wumbleheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                             BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr('Actualizando Perfil'),
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                             SizedBox(height: 8),
                            Text(
                              tr('Por favor espera...'),
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: state.progress > 0 ? state.progress : null,
                                    strokeWidth: 6,
                                    color: Wumbleheme.secondaryColor,
                                    backgroundColor: Colors.white10,
                                  ),
                                  if (state.progress > 0)
                                    Text(
                                      '${(state.progress * 100).toInt()}%',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Optional Cancel button or just text instructions
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _getSocialIconWidget(String url) {
    final lowerUrl = url.toLowerCase();
    
    Color iconColor = Wumbleheme.primaryColor;
    String? svgData;

    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      svgData = _youtubeSvg;
      iconColor = const Color(0xFFFF0000);
    } else if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.com')) {
      svgData = _facebookSvg;
      iconColor = const Color(0xFF1877F2);
    } else if (lowerUrl.contains('instagram.com')) {
      svgData = _instagramSvg;
      iconColor = const Color(0xFFE4405F);
    } else if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      svgData = _xSvg;
      iconColor = Colors.white;
    } else if (lowerUrl.contains('discord.gg') || lowerUrl.contains('discord.com')) {
      svgData = _discordSvg;
      iconColor = const Color(0xFF5865F2);
    } else if (lowerUrl.contains('twitch.tv')) {
      svgData = _twitchSvg;
      iconColor = const Color(0xFF9146FF);
    } else if (lowerUrl.contains('github.com')) {
      svgData = _githubSvg;
      iconColor = Colors.white;
    } else if (lowerUrl.contains('steamcommunity.com') || lowerUrl.contains('steampowered.com')) {
      svgData = _steamSvg;
      iconColor = const Color(0xFF171A21);
    }

    if (svgData != null) {
      return SvgPicture.string(
        svgData, 
        width: 20, 
        height: 20, 
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    }
    
    return Icon(_getSocialIcon(url), color: iconColor, size: 20);
  }

  IconData _getSocialIcon(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) return Icons.play_circle_filled_rounded;
    if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.com')) return Icons.facebook_rounded;
    if (lowerUrl.contains('instagram.com')) return Icons.camera_alt_rounded;
    if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) return Icons.close_rounded;
    if (lowerUrl.contains('discord.gg') || lowerUrl.contains('discord.com')) return Icons.discord_rounded;
    if (lowerUrl.contains('twitch.tv')) return Icons.video_library_rounded;
    if (lowerUrl.contains('github.com')) return Icons.code_rounded;
    if (lowerUrl.contains('steamcommunity.com') || lowerUrl.contains('steampowered.com')) return Icons.games_rounded;
    return Icons.link_rounded;
  }
}

class _BuildPickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? previewPath;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _BuildPickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.previewPath,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          image: (previewPath != null && previewPath != "[DELETE]")
              ? DecorationImage(
                  image: FileImage(File(previewPath!)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.6),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: Wumbleheme.accentColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                  Text(subtitle, style: const TextStyle(color: Wumbleheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () {
                  onDelete!();
                },
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
