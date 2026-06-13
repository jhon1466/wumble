import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/core/widgets/avatar_frame.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/core/widgets/purchase_celebration.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';
import 'package:wumble/features/profile/domain/custom_frame_model.dart';
import 'publish_frame_screen.dart';

class CommunityWorkshopScreen extends StatefulWidget {
  const CommunityWorkshopScreen({super.key});

  @override
  State<CommunityWorkshopScreen> createState() => _CommunityWorkshopScreenState();
}

class _CommunityWorkshopScreenState extends State<CommunityWorkshopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildLiveAvatarPreview(UserProfile user, String? frameId) {
    if (frameId == null) {
      return UserAvatar(
        avatarUrl: user.avatarUrl,
        radius: 40,
        isClickable: false,
        showOnlineIndicator: false,
      );
    }
    
    // We can use FramedAvatar manually or just UserAvatar with avatarFrameUrl
    return UserAvatar(
      avatarUrl: user.avatarUrl,
      avatarFrameUrl: frameId,
      radius: 40,
      isClickable: false,
      showOnlineIndicator: false,
    );
  }

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

  @override
  Widget build(BuildContext context) {
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
        UserProfile? userProfile;
        if (state is ProfileLoaded) {
          userProfile = state.user;
        } else if (state is ProfileUpdateSuccess) {
          userProfile = state.user;
        } else if (state is ProfileActionSuccess && context.read<ProfileBloc>().state is ProfileLoaded) {
          userProfile = (context.read<ProfileBloc>().state as ProfileLoaded).user;
        }

        return Scaffold(
          backgroundColor: Wumbleheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Wumbleheme.surfaceColor,
            elevation: 0,
            title: const Text('Workshop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Wumbleheme.primaryColor,
              labelColor: Wumbleheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Marcos'),
                Tab(text: 'Packs'),
                Tab(text: 'Tus Creaciones'),
              ],
            ),
            actions: [
              if (userProfile != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.yellowAccent, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${userProfile.coins}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.yellowAccent),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          body: userProfile == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _FramesMarketplaceTab(userProfile: userProfile),
                    _PacksMarketplaceTab(userProfile: userProfile),
                    _MyCreationsTab(userProfile: userProfile),
                  ],
                ),
          floatingActionButton: userProfile == null ? null : FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PublishFrameScreen()),
              );
            },
            backgroundColor: Wumbleheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }
}

class _FramesMarketplaceTab extends StatelessWidget {
  final UserProfile userProfile;

  const _FramesMarketplaceTab({required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('avatar_frames').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        final List<AvatarFrame> dynamicFramesList = [];
        
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final customFrame = CustomAvatarFrame.fromMap(data, doc.id);
          final uiFrame = customFrame.toAvatarFrame();
          
          // Pre-populate global cache to avoid redundant gets in UserAvatar/FramedAvatar
          AvatarFrame.dynamicFrames[doc.id] = uiFrame;
          dynamicFramesList.add(uiFrame);
        }

        // Let's combine static default frames (price 0) and dynamic frames
        final defaultFrames = AvatarFrame.catalog.where((f) => f.price == 0).toList();

        final List<AvatarFrame> allFrames = [...defaultFrames, ...dynamicFramesList];

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: allFrames.length,
          itemBuilder: (context, index) {
            return _FrameCard(
              frame: allFrames[index],
              userProfile: userProfile,
            );
          },
        );
      },
    );
  }
}

class _FrameCard extends StatelessWidget {
  final AvatarFrame frame;
  final UserProfile userProfile;

  const _FrameCard({
    required this.frame,
    required this.userProfile,
  });

  void _showFrameDetailsDialog(BuildContext context, bool isCreator, bool isOwned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: UserAvatar(
                avatarUrl: userProfile.avatarUrl,
                avatarFrameUrl: frame.id,
                radius: 60,
                isClickable: false,
                showOnlineIndicator: false,
                isPreview: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              frame.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Autor Detail
            if (frame.uploaderId != null)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(frame.uploaderId).get(),
                builder: (context, snapshot) {
                  String authorName = 'Cargando...';
                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
                    authorName = snapshot.data!.get('displayName') ?? 'Usuario Desconocido';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white54, size: 18),
                        const SizedBox(width: 8),
                        Text('Autor: $authorName', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                },
              ),
            // Date Detail
            if (frame.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Publicado el: ${frame.createdAt!.day.toString().padLeft(2, '0')}/${frame.createdAt!.month.toString().padLeft(2, '0')}/${frame.createdAt!.year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            // Credits Detail
            if (frame.credits != null && frame.credits!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.attribution_rounded, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Créditos: ${frame.credits}',
                        style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 20),
            // Action Buttons
            if (isCreator)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text('Editar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublishFrameScreen(
                              initialFrames: [
                                CustomAvatarFrame(
                                  id: frame.id,
                                  uploaderId: frame.uploaderId!,
                                  name: frame.name,
                                  price: frame.price,
                                  type: frame.type,
                                  url: frame.networkUrl!,
                                  createdAt: frame.createdAt ?? DateTime.now(),
                                  credits: frame.credits,
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Borrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        FirebaseFirestore.instance.collection('avatar_frames').doc(frame.id).delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marco eliminado exitosamente.'), backgroundColor: Colors.redAccent),
                        );
                      },
                    ),
                  ),
                ],
              )
            else if (isOwned)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: null,
                child: const Text('Ya lo posees', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Wumbleheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<ProfileBloc>().add(PurchaseFrameRequested(userProfile.id, frame.id, frame.price));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Comprar por ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Icon(Icons.monetization_on, color: Colors.yellowAccent, size: 18),
                    Text(' ${frame.price}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCreator = frame.uploaderId == userProfile.id;
    final bool isOwned = frame.price == 0 || userProfile.ownedFrames.contains(frame.id);

    return InkWell(
      onTap: () => _showFrameDetailsDialog(context, isCreator, isOwned),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Live Preview
            UserAvatar(
              avatarUrl: userProfile.avatarUrl,
              avatarFrameUrl: frame.id,
              radius: 40,
              isClickable: false,
              showOnlineIndicator: false,
              isPreview: true,
            ),
            const SizedBox(height: 16),
            Text(
              frame.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (isCreator)
              const Chip(
                label: Text('Tú Creador', style: TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: Colors.indigoAccent,
                visualDensity: VisualDensity.compact,
              )
            else if (isOwned)
              const Chip(
                label: Text('Obtenido', style: TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: Colors.green,
                visualDensity: VisualDensity.compact,
              )
            else
              Chip(
                avatar: const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                label: Text('${frame.price} AC', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber.withOpacity(0.1),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _MyCreationsTab extends StatelessWidget {
  final UserProfile userProfile;

  const _MyCreationsTab({required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('avatar_frames')
          .where('uploaderId', isEqualTo: userProfile.id)
          .orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Aún no has creado ningún marco público.', style: TextStyle(color: Colors.white54)));
        }

        final dynamicFrames = docs.map<AvatarFrame>((doc) => CustomAvatarFrame.fromMap(doc.data() as Map<String, dynamic>, doc.id).toAvatarFrame()).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: dynamicFrames.length,
          itemBuilder: (context, index) {
            return _FrameCard(
              frame: dynamicFrames[index],
              userProfile: userProfile,
            );
          },
        );
      },
    );
  }
}

class _PacksMarketplaceTab extends StatelessWidget {
  final UserProfile userProfile;

  const _PacksMarketplaceTab({required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('avatar_frames').where('packId', isNull: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Aún no hay packs creados en la comunidad.', style: TextStyle(color: Colors.white54)),
          );
        }

        // Parse to AvatarFrame and group by packId
        final Map<String, List<AvatarFrame>> packs = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final frame = CustomAvatarFrame.fromMap(data, doc.id).toAvatarFrame();
          
          // Pre-populate global cache
          AvatarFrame.dynamicFrames[doc.id] = frame;
          
          if (frame.packId != null) {
            if (!packs.containsKey(frame.packId)) {
              packs[frame.packId!] = [];
            }
            packs[frame.packId!]!.add(frame);
          }
        }

        final packEntries = packs.values.toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.70, // Slightly taller for pack info
          ),
          itemCount: packEntries.length,
          itemBuilder: (context, index) {
            return _PackCard(
              packFrames: packEntries[index],
              userProfile: userProfile,
            );
          },
        );
      },
    );
  }
}

class _PackCard extends StatelessWidget {
  final List<AvatarFrame> packFrames;
  final UserProfile userProfile;

  const _PackCard({
    required this.packFrames,
    required this.userProfile,
  });

  void _showPackDetailsDialog(BuildContext context, bool isCreator, bool allOwned) {
    // Determine overlapping/dynamic price as user might own some frames
    int remainingPrice = 0;
    int missingFrames = 0;
    for (var f in packFrames) {
      if (!userProfile.ownedFrames.contains(f.id)) {
        remainingPrice += f.price;
        missingFrames++;
      }
    }
    
    // The cost is either the calculated missing price, or the full pack price if missing all, or max capped at pack price
    int finalPrice = packFrames.first.packPrice;
    if (missingFrames < packFrames.length && remainingPrice < finalPrice) {
      finalPrice = remainingPrice;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: UserAvatar(
                avatarUrl: userProfile.avatarUrl,
                avatarFrameUrl: packFrames.first.id,
                radius: 50,
                isClickable: false,
                showOnlineIndicator: false,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              packFrames.first.packName ?? 'Pack sin nombre',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Contiene ${packFrames.length} marcos',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Frames Grid inside BottomSheet
            const Divider(color: Colors.white10),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Marcos incluidos:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen height
              ),
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: packFrames.length,
                itemBuilder: (context, index) {
                  final frame = packFrames[index];
                  final bool alreadyOwned = userProfile.ownedFrames.contains(frame.id);
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: alreadyOwned ? Colors.green.withOpacity(0.3) : Colors.white10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        UserAvatar(
                          avatarUrl: userProfile.avatarUrl,
                          avatarFrameUrl: frame.id,
                          radius: 24,
                          isClickable: false,
                          showOnlineIndicator: false,
                        ),
                        const SizedBox(height: 4),
                        if (alreadyOwned)
                          const Icon(Icons.check_circle, color: Colors.green, size: 14)
                        else
                          const Icon(Icons.lock_outline, color: Colors.white24, size: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            // Credits Detail
            if (packFrames.first.credits != null && packFrames.first.credits!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.attribution_rounded, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Créditos: ${packFrames.first.credits}',
                        style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Action Button
            if (isCreator)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text('Editar Pack', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublishFrameScreen(
                              initialFrames: packFrames.map((f) => CustomAvatarFrame(
                                id: f.id,
                                uploaderId: f.uploaderId!,
                                name: f.name,
                                price: f.price,
                                packPrice: f.packPrice,
                                packSize: f.packSize,
                                type: f.type,
                                url: f.networkUrl!,
                                createdAt: f.createdAt ?? DateTime.now(),
                                packId: f.packId,
                                packName: f.packName,
                                credits: f.credits,
                              )).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Borrar Todo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: Wumbleheme.surfaceColor,
                            title: const Text('¿Eliminar Pack?', style: TextStyle(color: Colors.white)),
                            content: const Text('Esto eliminará todos los marcos del pack de forma permanente.', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          Navigator.pop(ctx);
                          for (var f in packFrames) {
                            FirebaseFirestore.instance.collection('avatar_frames').doc(f.id).delete();
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pack eliminado exitosamente.'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                    ),
                  ),
                ],
              )
            else if (allOwned)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: null,
                child: const Text('Ya posees todos los marcos', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (missingFrames < packFrames.length)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Ya tienes ${packFrames.length - missingFrames} marcos de este pack.\nEl precio se ha ajustado para cubrir sólo los restantes.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Wumbleheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      int delay = 0;
                      for(var f in packFrames) {
                        if (!userProfile.ownedFrames.contains(f.id)) {
                          Future.delayed(Duration(milliseconds: delay), () {
                            context.read<ProfileBloc>().add(PurchaseFrameRequested(userProfile.id, f.id, f.price));
                          });
                          delay += 350;
                        }
                      }
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Comprando marcos del pack...')));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Comprar Pack por ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Icon(Icons.monetization_on, color: Colors.yellowAccent, size: 18),
                        Text(' $finalPrice', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (packFrames.isEmpty) return const SizedBox();
    
    final AvatarFrame firstFrame = packFrames.first;
    final bool isCreator = firstFrame.uploaderId == userProfile.id;
    int ownedCount = 0;
    for (var f in packFrames) {
      if (userProfile.ownedFrames.contains(f.id)) {
        ownedCount++;
      }
    }
    final bool allOwned = ownedCount == packFrames.length;

    return InkWell(
      onTap: () => _showPackDetailsDialog(context, isCreator, allOwned),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pack Preview (First Frame)
            UserAvatar(
              avatarUrl: userProfile.avatarUrl,
              avatarFrameUrl: firstFrame.id,
              radius: 35,
              isClickable: false,
              showOnlineIndicator: false,
            ),
            const SizedBox(height: 20),
            Text(
              firstFrame.packName ?? 'Pack',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${packFrames.length} marcos',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 8),
            if (isCreator)
              const Chip(
                label: Text('Tú Creador', style: TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: Colors.indigoAccent,
                visualDensity: VisualDensity.compact,
              )
            else if (allOwned)
              const Chip(
                label: Text('Obtenido', style: TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: Colors.green,
                visualDensity: VisualDensity.compact,
              )
            else
              Chip(
                avatar: const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                label: Text('${firstFrame.packPrice} AC', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber.withOpacity(0.1),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

