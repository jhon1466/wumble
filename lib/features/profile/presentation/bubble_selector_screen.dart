import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../core/theme.dart';
import '../../chat/domain/chat_model.dart';
import '../../chat/presentation/widgets/chat_bubble.dart';
import '../domain/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'advanced_bubble_editor_screen.dart';
import '../../chat/domain/moderation_service.dart';
import '../../../core/utils/media_helper.dart';

class BubbleSelectorScreen extends StatefulWidget {
  final ChatBubbleStyle? currentStyle;
  final List<ChatBubbleStyle> ownedStyles;

  const BubbleSelectorScreen({super.key, this.currentStyle, this.ownedStyles = const []});

  @override
  State<BubbleSelectorScreen> createState() => _BubbleSelectorScreenState();
}

class _BubbleSelectorScreenState extends State<BubbleSelectorScreen> {
  late ChatBubbleStyle _selectedStyle; // Removed nullable since we always have a selection
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  final List<ChatBubbleStyle> _predefinedStyles = [
    const ChatBubbleStyle(
      id: 'default',
      name: 'Clásico',
      backgroundColorValue: 0xFF2E7D32, // Green shade 800
      textColorValue: 0xFFFFFFFF,
    ),
    const ChatBubbleStyle(
      id: 'neon_cyber',
      name: 'Neon Cyber',
      backgroundColorValue: 0xFF006064, // Cyan 900
      secondaryColorValue: 0xFF00E5FF, // Cyan accent
      textColorValue: 0xFFFFFFFF,
      topRightOrnamentUrl: 'assets/images/neon_tech.png',
      hasGlow: true,
    ),
    const ChatBubbleStyle(
      id: 'hellfire',
      name: 'Hellfire',
      backgroundColorValue: 0xFFB71C1C, // Red 900
      secondaryColorValue: 0xFFFF5722, // Deep orange
      textColorValue: 0xFFFFFFFF,
      topRightOrnamentUrl: 'assets/images/hellfire.png',
      hasGlow: true,
    ),
    const ChatBubbleStyle(
      id: 'angelic',
      name: 'Angelic Glory',
      backgroundColorValue: 0xFFF5F5F5, // Grey 100
      secondaryColorValue: 0xFFFFD700, // Gold
      textColorValue: 0xFF424242, // Dark grey for contrast
      topRightOrnamentUrl: 'assets/images/angel_wing.png',
      hasGlow: true,
    ),
    const ChatBubbleStyle(
      id: 'cyber_heart',
      name: 'Digital Love',
      backgroundColorValue: 0xFF880E4F, // Pink 900
      secondaryColorValue: 0xFFE91E63, // Pink
      textColorValue: 0xFFFFFFFF,
      topRightOrnamentUrl: 'assets/images/cyber_heart.png',
      hasGlow: true,
    ),
    const ChatBubbleStyle(
      id: 'style_starry',
      name: 'Starry Night',
      backgroundColorValue: 0xFF1A237E,
      secondaryColorValue: 0xFF3F51B5,
      textColorValue: 0xFFFFFFFF,
      shapeId: 'star',
      topRightOrnamentUrl: 'assets/images/sparkle.png',
      hasGlow: true,
    ),
    const ChatBubbleStyle(
      id: 'style_heart',
      name: 'Sweet Heart',
      backgroundColorValue: 0xFFD81B60,
      secondaryColorValue: 0xFFF48FB1,
      textColorValue: 0xFFFFFFFF,
      shapeId: 'heart',
      topRightOrnamentUrl: 'assets/images/cyber_heart.png',
    ),
    const ChatBubbleStyle(
      id: 'style_neon_grid',
      name: 'Neon Grid',
      backgroundColorValue: 0xFF000000,
      secondaryColorValue: 0xFF00E676,
      textColorValue: 0xFF00E676,
      shapeId: 'sharp',
      topRightOrnamentUrl: 'assets/images/tech_circuit.png',
      hasGlow: true,
    ),
    const ChatBubbleStyle(
      id: 'retro_pixel',
      name: 'Retro Pixel',
      backgroundColorValue: 0xFF212121,
      secondaryColorValue: 0xFF424242,
      textColorValue: 0xFF00FF00,
      shapeId: 'sharp',
    ),
    const ChatBubbleStyle(
      id: 'exotic_jagged',
      name: 'Jagged Flame',
      backgroundColorValue: 0xFFFF5722,
      secondaryColorValue: 0xFFFFEB3B,
      textColorValue: 0xFF000000,
      shapeId: 'jagged',
      hasGlow: true,
    ),
    ChatBubbleStyle(
      id: 'ocean_wavy',
      name: 'Ocean Wave',
      backgroundColorValue: 0xFF0277BD,
      secondaryColorValue: 0xFF81D4FA,
      textColorValue: 0xFFFFFFFF,
      shapeId: 'wavy',
    ),
    ChatBubbleStyle(
      id: 'vapor_sun',
      name: 'Vaporwave Sun',
      backgroundColorValue: 0xFF212121,
      secondaryColorValue: 0xFFFF1744,
      textColorValue: 0xFF00E5FF,
      shapeId: 'sharp',
      topRightOrnamentUrl: 'assets/images/vapor_sun.png',
      hasGlow: true,
    ),
    ChatBubbleStyle(
      id: 'gothic_cross',
      name: 'Silver Cross',
      backgroundColorValue: 0xFF121212,
      secondaryColorValue: 0xFF424242,
      textColorValue: 0xFFBDBDBD,
      shapeId: 'jagged',
      topRightOrnamentUrl: 'assets/images/gothic_cross.png',
    ),
    ChatBubbleStyle(
      id: 'kawaii_cat_style',
      name: 'Neko Pink',
      backgroundColorValue: 0xFFFCE4EC,
      secondaryColorValue: 0xFFF8BBD0,
      textColorValue: 0xFF880E4F,
      shapeId: 'cloud',
      topRightOrnamentUrl: 'assets/images/kawaii_cat.png',
    ),
    ChatBubbleStyle(
      id: 'classic_quill',
      name: 'Script Feather',
      backgroundColorValue: 0xFFFFF9C4,
      secondaryColorValue: 0xFFFBC02D,
      textColorValue: 0xFF5D4037,
      shapeId: 'wavy',
      topRightOrnamentUrl: 'assets/images/classic_feather.png',
    ),
    ChatBubbleStyle(
      id: 'dreamy_soft',
      name: 'Soft Cloud',
      backgroundColorValue: 0xFFF8BBD0,
      secondaryColorValue: 0xFFE1BEE7,
      textColorValue: 0xFF880E4F,
      shapeId: 'cloud',
      topRightOrnamentUrl: 'assets/images/sparkle.png',
    ),
    ChatBubbleStyle(
      id: 'cyber_neon',
      name: 'Neon Grid',
      backgroundColorValue: 0xFF000000,
      secondaryColorValue: 0xFF00E676,
      textColorValue: 0xFF00E676,
      shapeId: 'sharp',
      topRightOrnamentUrl: 'assets/images/tech_circuit.png',
      hasGlow: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.currentStyle ?? _predefinedStyles.first;
  }

  Future<void> _pickOrnament(String corner) async {
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() {
        switch (corner) {
          case 'topLeft':
            _selectedStyle = _selectedStyle.copyWith(topLeftOrnamentUrl: image.path);
            break;
          case 'topRight':
            _selectedStyle = _selectedStyle.copyWith(topRightOrnamentUrl: image.path);
            break;
          case 'bottomLeft':
            _selectedStyle = _selectedStyle.copyWith(bottomLeftOrnamentUrl: image.path);
            break;
          case 'bottomRight':
            _selectedStyle = _selectedStyle.copyWith(bottomRightOrnamentUrl: image.path);
            break;
        }
      });
    }
  }

  Future<void> _saveStyle() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');
      
      final repo = GetIt.I<ProfileRepository>();
      
      ChatBubbleStyle styleToSave = _selectedStyle;
      
      // Upload local images if any
      Future<String?> uploadIfLocal(String? path) async {
        if (path == null) return null;
        if (path.startsWith('http')) return path;
        if (path.startsWith('assets/')) return path;
        if (path.contains('brain') && path.endsWith('.png')) return path; // Keep artifact paths for now
        return await repo.uploadWallImage(user.uid, path);
      }

      styleToSave = styleToSave.copyWith(
        topLeftOrnamentUrl: await uploadIfLocal(styleToSave.topLeftOrnamentUrl),
        topRightOrnamentUrl: await uploadIfLocal(styleToSave.topRightOrnamentUrl),
        bottomLeftOrnamentUrl: await uploadIfLocal(styleToSave.bottomLeftOrnamentUrl),
        bottomRightOrnamentUrl: await uploadIfLocal(styleToSave.bottomRightOrnamentUrl),
      );

      await repo.updateProfile(
        userId: user.uid,
        chatBubbleStyle: styleToSave,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Burbuja actualizada correctamente'))),
        );
        Navigator.pop(context, styleToSave);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: Text(tr('Estilo de Burbuja')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CircularProgressIndicator()))
          else
            TextButton(
              onPressed: _saveStyle,
              child: Text(tr('GUARDAR'), style: TextStyle(color: Wumbleheme.primaryColor, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // FIXED PREVIEW AREA
          Container(
            height: 260,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Wumbleheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text(tr('Vista Previa'), style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 24),
                 _buildPreviewBubble(isMe: false, text: '¡Hola! Mira mi nueva burbuja personalizada. ✨'),
                 const SizedBox(height: 16),
                 _buildPreviewBubble(isMe: true, text: '¡Se ve increíble! Yo también quiero una. 😍'),
              ],
            ),
          ),
          
          // SCROLLABLE EDITOR AREA
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Personalizar Ornamentos'), style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(tr('Toca cada esquina para elegir una imagen.'), style: TextStyle(color: Colors.white38, fontSize: 13)),
                    const SizedBox(height: 24),
                    
                    // Corner Selector Grid (Visual Representation)
                    Center(
                      child: Container(
                        width: 220,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Stack(
                          children: [
                            _buildCornerSelector(Alignment.topLeft, 'topLeft', _selectedStyle.topLeftOrnamentUrl),
                            _buildCornerSelector(Alignment.topRight, 'topRight', _selectedStyle.topRightOrnamentUrl),
                            _buildCornerSelector(Alignment.bottomLeft, 'bottomLeft', _selectedStyle.bottomLeftOrnamentUrl),
                            _buildCornerSelector(Alignment.bottomRight, 'bottomRight', _selectedStyle.bottomRightOrnamentUrl),
                            const Center(
                               child: Icon(Icons.chat_bubble_outline, color: Colors.white12, size: 48),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tr('Tus Estilos & Tienda'), style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        if (ModerationService.workshopEnabled)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Wumbleheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(tr('Workshop'), style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                               final newStyle = await Navigator.push<ChatBubbleStyle>(
                                 context,
                                 MaterialPageRoute(builder: (_) => AdvancedBubbleEditorScreen(initialStyle: _selectedStyle)),
                               );
                               if (newStyle != null) {
                                 setState(() => _selectedStyle = newStyle);
                               }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: _predefinedStyles.length + widget.ownedStyles.length,
                      itemBuilder: (context, index) {
                        final style = index < _predefinedStyles.length 
                            ? _predefinedStyles[index] 
                            : widget.ownedStyles[index - _predefinedStyles.length];
                        final isSelected = _selectedStyle.id == style.id;
                        final isPurchased = index >= _predefinedStyles.length;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedStyle = style),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? Wumbleheme.primaryColor : Colors.white10,
                                width: isSelected ? 2 : 1,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Color(style.backgroundColorValue).withOpacity(0.9),
                                  Color(style.secondaryColorValue ?? style.backgroundColorValue).withOpacity(0.5),
                                ],
                              ),
                            ),
                             child: Stack(
                               children: [
                                 Center(
                                   child: Text(
                                     style.name,
                                     style: TextStyle(
                                       color: isSelected ? Colors.white : Colors.white70,
                                       fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                     ),
                                   ),
                                 ),
                                 if (isPurchased)
                                   Positioned(
                                     top: 4,
                                     right: 4,
                                     child: Icon(Icons.stars, color: Colors.amberAccent, size: 14),
                                   ),
                               ],
                             ),
                            ), // AnimatedContainer
                          ); // GestureDetector
                        }, // itemBuilder
                      ), // GridView
                      const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerSelector(Alignment alignment, String corner, String? url) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () => _pickOrnament(corner),
        child: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: [
              if (url != null)
                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: url != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: url.startsWith('http') 
                      ? Image.network(url, fit: BoxFit.cover) 
                      : (url.startsWith('assets/') 
                          ? Image.asset(url, fit: BoxFit.cover) 
                          : Image.file(File(url), fit: BoxFit.cover)),
                )
              : const Icon(Icons.add_photo_alternate_outlined, color: Colors.white24, size: 24),
        ),
      ),
    );
  }

  Widget _buildPreviewBubble({required bool isMe, required String text}) {
    return ChatBubble(
      message: ChatBubbleMessage(
        id: 'preview',
        senderId: isMe ? 'me' : 'other',
        senderName: isMe ? 'Yo' : 'Amigo',
        senderAvatarUrl: '',
        text: text,
        type: MessageType.text,
        timestamp: DateTime.now(),
        isMe: isMe,
        bubbleStyle: _selectedStyle,
      ),
    );
  }
}
