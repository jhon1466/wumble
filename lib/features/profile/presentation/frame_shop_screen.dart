import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/core/widgets/avatar_frame.dart';
import 'package:wumble/core/widgets/purchase_celebration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/features/profile/domain/custom_frame_model.dart';

class FrameShopScreen extends StatefulWidget {
  final UserProfile user;

  const FrameShopScreen({super.key, required this.user});

  @override
  State<FrameShopScreen> createState() => _FrameShopScreenState();
}

class _FrameShopScreenState extends State<FrameShopScreen> {
  String? _previewFrameId;



  @override
  Widget build(BuildContext context) {
    // Basic frames list starts with the base catalog that are either price 0 or owned
    final defaultFrames = AvatarFrame.catalog;

    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (previous, current) => current is ProfileActionSuccess || current is ProfileError,
      listener: (context, state) {
        if (state is ProfileActionSuccess) {
          if (state.isPurchase) {
            _showCelebrationOverlay(context, state.message);
          } else {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          }
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        // Obtenemos el usuario actualizado del estado si es posible, si no usamos el del widget original
        UserProfile currentUser = widget.user;
        if (state is ProfileLoaded) {
          currentUser = state.user;
        } else if (state is ProfileUpdateSuccess) {
          currentUser = state.user;
        }

        return Scaffold(
          backgroundColor: Wumbleheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Inventario de Marcos'),
            backgroundColor: Wumbleheme.surfaceColor,
          ),
          body: Column(
            children: [
              // Preview Area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Wumbleheme.surfaceColor.withOpacity(0.4),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: Column(
                  children: [
                    UserAvatar(
                      avatarUrl: currentUser.avatarUrl,
                      radius: 56,
                      avatarFrameUrl: _previewFrameId ?? currentUser.avatarFrameUrl,
                      showOnlineIndicator: false,
                      isClickable: false,
                      displayName: currentUser.displayName,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _previewFrameId != null
                          ? AvatarFrame.findById(_previewFrameId!)?.name ?? 'Vista Previa'
                          : currentUser.avatarFrameUrl != null && currentUser.avatarFrameUrl!.isNotEmpty
                              ? 'Marco actual: ${AvatarFrame.findById(currentUser.avatarFrameUrl!)?.name ?? currentUser.avatarFrameUrl}'
                              : 'Sin Marco',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Frames Grid
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('avatar_frames').snapshots(),
                  builder: (context, snapshot) {
                    // Determine all viewable frames
                    List<AvatarFrame> allFrames = List.from(defaultFrames);

                    if (snapshot.hasData) {
                      final customFrames = snapshot.data!.docs
                          .map((doc) => CustomAvatarFrame.fromMap(doc.data() as Map<String, dynamic>, doc.id).toAvatarFrame())
                          .where((f) => currentUser.ownedFrames.contains(f.id) || f.uploaderId == currentUser.id)
                          .toList();
                      
                      allFrames.addAll(customFrames);
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: allFrames.length,
                      itemBuilder: (context, index) {
                        final frame = allFrames[index];
                        final isOwned = currentUser.ownedFrames.contains(frame.id) || frame.price == 0;
                        final isEquipped = currentUser.avatarFrameUrl == frame.id;
                        final isPreviewing = _previewFrameId == frame.id;

                        return _buildFrameCard(
                          currentUser: currentUser,
                          frame: frame,
                          isOwned: isOwned,
                          isEquipped: isEquipped,
                          isPreviewing: isPreviewing,
                        );
                      },
                    );
                  }
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFrameCard({
    required UserProfile currentUser,
    required AvatarFrame frame,
    required bool isOwned,
    required bool isEquipped,
    required bool isPreviewing,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _previewFrameId = isPreviewing ? null : frame.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPreviewing
                ? frame.primaryColor
                : isEquipped
                    ? Colors.greenAccent
                    : Colors.white.withOpacity(0.1),
            width: isPreviewing || isEquipped ? 2 : 1,
          ),
          boxShadow: isPreviewing
              ? [BoxShadow(color: frame.primaryColor.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Frame preview using FramedAvatar
            Expanded(
              child: Center(
                child: FramedAvatar(
                  frameId: frame.id,
                  size: 80,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white12,
                    backgroundImage: currentUser.avatarUrl.isNotEmpty
                        ? NetworkImage(currentUser.avatarUrl)
                        : null,
                    child: currentUser.avatarUrl.isEmpty
                        ? Text(
                            currentUser.displayName.isNotEmpty
                                ? currentUser.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              frame.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isEquipped
                    ? () => _handleEquip(null)
                    : () => _handleEquip(frame.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEquipped ? Colors.grey[800] : Wumbleheme.secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isEquipped ? 'QUITAR' : 'PONER',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEquip(String? frameId) {
    context.read<ProfileBloc>().add(EquipFrameRequested(widget.user.id, frameId));
    setState(() {
      _previewFrameId = null;
    });
  }

  void _handlePurchase(AvatarFrame frame, UserProfile currentUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Comprar: ${frame.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FramedAvatar(
              frameId: frame.id,
              size: 80,
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white12,
                backgroundImage: widget.user.avatarUrl.isNotEmpty
                    ? NetworkImage(widget.user.avatarUrl)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: Colors.yellowAccent),
                const SizedBox(width: 6),
                Text('${frame.price} AC', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (frame.packId != null && frame.packPrice > 0) ...[
                Builder(builder: (context) {
                  // Calculate completion price
                  final ownedCount = currentUser.ownedFrames.where((id) {
                    // This is a bit expensive but okay for a dialog
                    // We check if other frames in the same pack are owned
                    // For now, let's assume we need to know the individual price
                    return false; // We just use the logic from repository for final price
                  }).length;
                  
                  // In the UI we show a "Complete pack" button
                  // The price will be calculated in the repository
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<ProfileBloc>().add(PurchasePackRequested(widget.user.id, frame.packId!));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Wumbleheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Column(
                        children: [
                          const Text('COMPLETAR PACK COMPLETO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          Text(
                            'Obtén los ${frame.packSize} marcos del pack "${frame.packName}"',
                            style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCELAR'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<ProfileBloc>().add(PurchaseFrameRequested(widget.user.id, frame.id, frame.price));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('COMPRAR SOLO ESTE'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  } // end _handlePurchase

  void _showCelebrationOverlay(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => PurchaseCelebrationOverlay(
        onFinished: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }
}
