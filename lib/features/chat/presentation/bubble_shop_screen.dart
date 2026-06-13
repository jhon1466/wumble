import 'package:flutter/material.dart';
import '../domain/chat_model.dart';
import '../domain/bubble_pack_model.dart';
import 'widgets/chat_bubble.dart';
import '../../profile/domain/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme.dart';
import '../../profile/domain/profile_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BubbleShopScreen extends StatefulWidget {
  const BubbleShopScreen({super.key});

  @override
  State<BubbleShopScreen> createState() => _BubbleShopScreenState();
}

class _BubbleShopScreenState extends State<BubbleShopScreen> {
  String _selectedCategory = 'Todos';
  final List<String> _categories = ['Todos', 'Aesthetic', 'Anime', 'Gótico', 'Tech', 'Nature'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Workshop (Comunidad)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<UserProfile>(
            stream: GetIt.I<ProfileRepository>().getUserProfile(FirebaseAuth.instance.currentUser?.uid ?? ''),
            builder: (context, snapshot) {
              final coins = snapshot.data?.coins ?? 0;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: Colors.yellow, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          coins.toString(),
                          style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryBar(),
          Expanded(
            child: _buildCommunityList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityList() {
    return StreamBuilder<List<BubblePack>>(
      stream: GetIt.I<ProfileRepository>().getWorkshopPacks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }
        var packs = snapshot.data ?? [];
        if (_selectedCategory != 'Todos') {
          packs = packs.where((p) => p.category == _selectedCategory).toList();
        }
        
        if (packs.isEmpty) {
          return const Center(child: Text('El Workshop está vacío para esta categoría.\n¡Sé el primero en crear algo increíble!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: packs.length,
          itemBuilder: (context, index) {
            return _buildPackCard(packs[index]);
          },
        );
      },
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
              backgroundColor: Wumbleheme.surfaceColor,
              selectedColor: Wumbleheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPackCard(BubblePack pack) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pack Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(pack.description, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pack.price == 0 ? Colors.green.withOpacity(0.2) : Wumbleheme.secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pack.price == 0 ? 'GRATIS' : '${pack.price} AC',
                    style: TextStyle(
                      color: pack.price == 0 ? Colors.green : Wumbleheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Style Previews
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: pack.styles.length,
              itemBuilder: (context, sIndex) {
                final style = pack.styles[sIndex];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: _buildMiniPreview(style, pack),
                  ),
                );
              },
            ),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                   final user = FirebaseAuth.instance.currentUser;
                   if (user == null) return;

                   try {
                     await GetIt.I<ProfileRepository>().purchaseBubblePack(user.uid, pack);
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text('¡Pack ${pack.name} añadido a tu colección! 🎉'),
                           backgroundColor: Colors.green,
                         ),
                       );
                     }
                   } catch (e) {
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Error al obtener el pack: $e')),
                       );
                     }
                   }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Wumbleheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OBTENER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          if (pack.isPublic && pack.creatorId != null && pack.creatorId!.isNotEmpty)
            Padding(
               padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
               child: Center(
                 child: _CreatorName(creatorId: pack.creatorId!),
               ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniPreview(ChatBubbleStyle style, BubblePack pack) {
     return GestureDetector(
       onTap: () => _showBubblePreviewDialog(context, style, pack),
       child: SizedBox(
         width: 120,
         child: AbsorbPointer(
           child: ChatBubble(
             message: ChatBubbleMessage(
               id: 'preview_${style.id}',
               senderId: 'me',
               senderName: '',
               senderAvatarUrl: '',
               text: style.name,
               type: MessageType.text,
               timestamp: DateTime.now(),
               isMe: true,
               bubbleStyle: style,
             ),
           ),
         ),
       ),
     );
  }

  void _showBubblePreviewDialog(BuildContext context, ChatBubbleStyle style, BubblePack pack) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Wumbleheme.backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(style.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(pack.name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white10, height: 1),
              
              // Mock Chat View
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                ),
                child: Column(
                  children: [
                    // Other person message
                    ChatBubble(
                      message: ChatBubbleMessage(
                        id: 'mock_1',
                        senderId: 'other',
                        senderName: 'Amigo',
                        senderAvatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Felix',
                        text: '¡Hola! Mira esta burbuja increíble que acabo de conseguir. ✨',
                        type: MessageType.text,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
                        isMe: false,
                        isOneOnOne: false,
                        bubbleStyle: style,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // My message
                    ChatBubble(
                      message: ChatBubbleMessage(
                        id: 'mock_2',
                        senderId: 'me',
                        senderName: 'Tú',
                        senderAvatarUrl: FirebaseAuth.instance.currentUser?.photoURL ?? '',
                        text: '¡Está genial! Combina perfecto con tu perfil. ¿Dónde la compraste?',
                        type: MessageType.text,
                        timestamp: DateTime.now(),
                        isMe: true,
                        isOneOnOne: false,
                        bubbleStyle: style,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white10, height: 1),
              
              // Footer / Action
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Autor', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        _CreatorName(creatorId: pack.creatorId ?? '', small: true),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Wumbleheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorName extends StatelessWidget {
  final String creatorId;
  final bool small;

  const _CreatorName({required this.creatorId, this.small = false});

  @override
  Widget build(BuildContext context) {
    if (creatorId.isEmpty) return const Text('Oficial', style: TextStyle(color: Colors.white24, fontSize: 10));
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(creatorId).get(),
      builder: (context, snapshot) {
        String name = 'Cargando...';
        if (snapshot.hasData && snapshot.data!.exists) {
          name = snapshot.data!.get('displayName') ?? 'Usuario de Wumble';
          if (name == 'Usuario de Wumble') name = 'Usuario';
        } else if (snapshot.hasError) {
          name = 'Error';
        }
        
        return Text(
          'Publicado por $name',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: small ? 11 : 12,
            fontWeight: small ? FontWeight.bold : FontWeight.normal,
          ),
        );
      },
    );
  }
}
