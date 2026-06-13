import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/features/chat/domain/chat_repository.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils/media_helper.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:io';

class CreatePublicChatScreen extends StatefulWidget {
  final String communityId;
  final Color themeColor;
  final ChatRoom? existingChat;

  const CreatePublicChatScreen({
    super.key,
    required this.communityId,
    required this.themeColor,
    this.existingChat,
  });

  @override
  State<CreatePublicChatScreen> createState() => _CreatePublicChatScreenState();
}

class _CreatePublicChatScreenState extends State<CreatePublicChatScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  File? _imageFile;
  File? _bannerFile;
  File? _backgroundFile;
  bool _isLoading = false;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingChat != null) {
      _titleController.text = widget.existingChat!.title ?? '';
      _descController.text = widget.existingChat!.description ?? '';
      _isPublic = widget.existingChat!.isPublic;
    }
  }

  Future<void> _pickImage() async {
    final image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<void> _pickBanner() async {
    final image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() => _bannerFile = File(image.path));
    }
  }

  Future<void> _pickBackground() async {
    final image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() => _backgroundFile = File(image.path));
    }
  }

  Future<void> _createChat() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un título')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storage = StorageService();
      
      String imageUrl = widget.existingChat?.imageUrl ?? '';
      if (_imageFile != null) {
        imageUrl = await storage.uploadChatImage(_imageFile!);
      }

      String bannerUrl = widget.existingChat?.bannerUrl ?? '';
      if (_bannerFile != null) {
        bannerUrl = await storage.uploadChatImage(_bannerFile!);
      }

      String backgroundImageUrl = widget.existingChat?.backgroundImageUrl ?? '';
      if (_backgroundFile != null) {
        backgroundImageUrl = await storage.uploadChatImage(_backgroundFile!);
      }

      if (widget.existingChat != null) {
        // Edit mode
        await context.read<ChatRepository>().updateChatRoom(
          widget.existingChat!.id,
          title: _titleController.text != widget.existingChat!.title ? _titleController.text : null,
          description: _descController.text != widget.existingChat!.description ? _descController.text : null,
          imageUrl: _imageFile != null ? imageUrl : null,
          bannerUrl: _bannerFile != null ? bannerUrl : null,
        );
        if (_backgroundFile != null) {
          await context.read<ChatRepository>().updateChatBackground(widget.existingChat!.id, backgroundImageUrl);
        }
      } else {
        // Create mode
        await context.read<ChatRepository>().createPublicChat(
          communityId: widget.communityId,
          creatorId: user.uid,
          title: _titleController.text,
          description: _descController.text,
          imageUrl: imageUrl,
          creatorName: user.displayName ?? 'Usuario',
          creatorAvatar: user.photoURL ?? '',
          isPublic: _isPublic,
          bannerUrl: bannerUrl,
          backgroundImageUrl: backgroundImageUrl,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.existingChat != null ? 'Editar Chat' : 'Nuevo Chat Público'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _createChat,
                child: Text(
                  widget.existingChat != null ? 'GUARDAR' : 'PUBLICAR',
                  style: TextStyle(
                    color: widget.themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Immersive Preview Section (Banner + Icon)
                  SizedBox(
                    height: 240,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Banner Selector
                        GestureDetector(
                          onTap: _pickBanner,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              image: _bannerFile != null
                                  ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                                  : (widget.existingChat?.bannerUrl != null)
                                      ? DecorationImage(image: CachedNetworkImageProvider(widget.existingChat!.bannerUrl!), fit: BoxFit.cover)
                                      : null,
                            ),
                            child: Stack(
                              children: [
                                if (_bannerFile == null && widget.existingChat?.bannerUrl == null)
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.wallpaper, color: Colors.white24, size: 48),
                                        const SizedBox(height: 8),
                                        const Text('Toca para añadir un banner', style: TextStyle(color: Colors.white38, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.7)],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit, color: Colors.white70, size: 14),
                                        SizedBox(width: 4),
                                        const Text('Banner', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_bannerFile != null || widget.existingChat?.bannerUrl != null)
                                   const Positioned(
                                    bottom: 50,
                                    right: 16,
                                    child: Text('BANNER DE LA TARJETA', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Icon Selector (Overlaid)
                        Positioned(
                          bottom: 0,
                          left: 24,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Wumbleheme.surfaceColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Wumbleheme.backgroundColor, width: 4),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 5)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: _imageFile != null
                                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                                    : (widget.existingChat?.imageUrl?.isNotEmpty == true)
                                        ? CachedNetworkImage(imageUrl: widget.existingChat!.imageUrl!, fit: BoxFit.cover)
                                        : Center(
                                            child: Icon(Icons.add_a_photo_rounded, color: widget.themeColor, size: 32),
                                          ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 2. Fields Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader('INFORMACIÓN GENERAL'),
                        const SizedBox(height: 16),
                        
                        _customTextField(
                          controller: _titleController,
                          label: 'Título del Chat',
                          hint: 'Ej: Zona de Rol, Debate Amino...',
                          icon: Icons.title_rounded,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        _customTextField(
                          controller: _descController,
                          label: 'Descripción (Opcional)',
                          hint: '¿De qué trata este chat?',
                          icon: Icons.description_outlined,
                          maxLines: 4,
                        ),

                        const SizedBox(height: 32),
                        _sectionHeader('APARIENCIA DE LA SALA'),
                        const SizedBox(height: 12),
                        
                        // Room Background Selector
                        GestureDetector(
                          onTap: _pickBackground,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                    image: _backgroundFile != null
                                        ? DecorationImage(image: FileImage(_backgroundFile!), fit: BoxFit.cover)
                                        : (widget.existingChat?.backgroundImageUrl != null)
                                            ? DecorationImage(image: CachedNetworkImageProvider(widget.existingChat!.backgroundImageUrl!), fit: BoxFit.cover)
                                            : null,
                                  ),
                                  child: (_backgroundFile == null && widget.existingChat?.backgroundImageUrl == null)
                                      ? const Icon(Icons.image_search_rounded, color: Colors.white24)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Imagen de Fondo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        (_backgroundFile == null && widget.existingChat?.backgroundImageUrl == null)
                                          ? 'Personaliza el interior del chat'
                                          : 'Cambiar imagen de fondo',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: widget.themeColor),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                        _sectionHeader('PRIVACIDAD'),
                        const SizedBox(height: 12),
                        
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: const Text('Chat Público', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Cualquiera en la comunidad puede unirse', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            value: _isPublic,
                            activeColor: widget.themeColor,
                            onChanged: (val) => setState(() => _isPublic = val),
                          ),
                        ),

                        const SizedBox(height: 40),
                        const Center(
                          child: Text(
                            'El banner se muestra en la lista de chats. El fondo es lo que se ve al estar dentro de la sala.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: widget.themeColor,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _customTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            prefixIcon: Icon(icon, color: widget.themeColor.withOpacity(0.5), size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: widget.themeColor.withOpacity(0.3), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
