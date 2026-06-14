import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/feed/presentation/bloc/create_post_cubit.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/features/chat/domain/chat_repository.dart';
import 'package:wumble/features/chat/presentation/widgets/sticker_selector.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StatusCreationSheet extends StatefulWidget {
  final String communityId;
  final String? communityAvatarUrl;
  final String? communityAvatarFrameUrl;
  StatusCreationSheet({
    super.key, 
    required this.communityId,
    this.communityAvatarUrl,
    this.communityAvatarFrameUrl,
  });

  @override
  State<StatusCreationSheet> createState() => _StatusCreationSheetState();
}

class _StatusCreationSheetState extends State<StatusCreationSheet> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _images = [];
  String? _selectedStickerUrl;
  final List<TextEditingController> _pollOptionControllers = [];
  bool _isPosting = false;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(File(image.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _addPollOption() {
    if (_pollOptionControllers.length >= 5) return;
    setState(() {
      _pollOptionControllers.add(TextEditingController());
    });
  }

  void _removePollOption(int index) {
    setState(() {
      _pollOptionControllers[index].dispose();
      _pollOptionControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    final pollOptions = _pollOptionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (content.isEmpty && _images.isEmpty && _selectedStickerUrl == null && pollOptions.isEmpty) return;
    
    // Validate poll if present
    if (pollOptions.isNotEmpty && pollOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Una encuesta requiere al menos 2 opciones'))),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await context.read<CreatePostCubit>().createPost(
        communityId: widget.communityId,
        content: content,
        userId: user.uid,
        images: _images.isNotEmpty ? _images : null,
        stickerUrl: _selectedStickerUrl,
        pollOptions: pollOptions.isNotEmpty ? pollOptions : null,
        pollDurationDays: pollOptions.isNotEmpty ? 30 : null, // Default 30 days
        // No title = Status layout in PostCard
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var c in _pollOptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        margin: EdgeInsets.only(bottom: bottomPadding),
        decoration: BoxDecoration(
          color: Wumbleheme.backgroundColor.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  userId: user?.uid ?? '',
                  avatarUrl: widget.communityAvatarUrl ?? user?.photoURL ?? '',
                  avatarFrameUrl: widget.communityAvatarFrameUrl,
                  communityId: widget.communityId,
                  radius: 20,
                  showOnlineIndicator: false,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 6,
                    minLines: 1,
                    autofocus: true,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: tr('¿Qué estás pensando?'),
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),

            if (_images.isNotEmpty || _selectedStickerUrl != null) ...[
              SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._images.asMap().entries.map((entry) {
                      int index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                entry.value,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_selectedStickerUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: _selectedStickerUrl!,
                                height: 80,
                                width: 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedStickerUrl = null),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Integrated Poll Creation UI
            if (_pollOptionControllers.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.poll_outlined, size: 16, color: Wumbleheme.primaryColor),
                        SizedBox(width: 8),
                        Text(tr('Opciones de encuesta'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._pollOptionControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entry.value,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Opción ${index + 1}',
                                  hintStyle: const TextStyle(color: Colors.white24),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Wumbleheme.primaryColor)),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removePollOption(index),
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_pollOptionControllers.length < 5)
                      TextButton.icon(
                        onPressed: _addPollOption,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(tr('Añadir opción')),
                        style: TextButton.styleFrom(foregroundColor: Wumbleheme.primaryColor, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, color: Wumbleheme.primaryColor),
                  tooltip: tr('Agregar imagen'),
                ),
                IconButton(
                  onPressed: _showStickerPicker,
                  icon: const Icon(Icons.sticky_note_2_outlined, color: Wumbleheme.primaryColor),
                  tooltip: tr('Agregar sticker'),
                ),
                IconButton(
                  onPressed: _addPollOption,
                  icon: const Icon(Icons.poll_outlined, color: Wumbleheme.primaryColor),
                  tooltip: tr('Agregar encuesta'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: (_isPosting || (_controller.text.isEmpty && _images.isEmpty && _selectedStickerUrl == null)) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Wumbleheme.primaryColor,
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  ),
                  child: _isPosting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('Publicar'), style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            RepositoryProvider.value(
              value: di.sl<ChatRepository>(),
              child: StickerSelector(
                onStickerSelected: (url) {
                  setState(() => _selectedStickerUrl = url);
                  Navigator.pop(context);
                },
                onCustomStickerCreated: (file) {
                  // Not supported for status yet, but could be added
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
