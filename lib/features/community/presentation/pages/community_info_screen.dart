import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/core/utils/share_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/features/community/presentation/bloc/community_context_bloc.dart';
import 'package:wumble/features/chat/presentation/image_viewer_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/community/presentation/pages/community_settings_screen.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/presentation/community_screen.dart';
import 'package:wumble/core/utils/media_optimizer.dart';

class CommunityInfoScreen extends StatelessWidget {
  final Community community;
  final bool fromCommunityDetail;

  CommunityInfoScreen({
    super.key, 
    required this.community,
    this.fromCommunityDetail = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityContextBloc, CommunityContextState>(
      builder: (context, state) {
        // Definir estado del botón
        final isMember = state.memberProfile != null && state.activeCommunity?.id == community.id;
        final isPrivate = community.privacy == 'private';
        final isPending = state.hasPendingRequest;
        
        final bool showJoinButton = !isMember && !isPrivate;
        final bool canJoin = showJoinButton && !isPending;
        
        String buttonText = 'Unirse';
        if (isPending) buttonText = 'Pendiente';
        else if (community.privacy == 'approval') buttonText = 'Solicitar';

        final String? bgUrl = community.backgroundUrl.isNotEmpty 
            ? community.backgroundUrl 
            : (community.bannerUrl.isNotEmpty ? community.bannerUrl : null);
        final bool hasImageBg = bgUrl != null;

        return Scaffold(
          backgroundColor: Wumbleheme.backgroundColor,
          body: Stack(
            children: [
              // 1. Background Layer
              if (hasImageBg)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: MediaOptimizer.banner(bgUrl!),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Wumbleheme.backgroundColor),
                    errorWidget: (context, url, error) => Container(color: Wumbleheme.backgroundColor),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          community.themeColor.withOpacity(0.4),
                          Wumbleheme.backgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. Blur Overlay
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
              ),

              // 3. Content
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Banner y Botones Flotantes ──
                      SizedBox(
                        height: 220,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Banner Header
                            Positioned(
                              top: 0, left: 0, right: 0, height: 180,
                              child: GestureDetector(
                                onTap: community.bannerUrl.isNotEmpty
                                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: community.bannerUrl)))
                                    : null,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black, Colors.transparent],
                                      stops: [0.2, 0.9],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: community.themeColor.withOpacity(0.15),
                                      image: community.bannerUrl.isNotEmpty
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(MediaOptimizer.banner(community.bannerUrl)),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Botón de Volver
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 8,
                              left: 8,
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),

                            // Avatar Inset & Botones
                            Positioned(
                              top: 140,
                              left: 16,
                              right: 16,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Avatar
                                  GestureDetector(
                                    onTap: community.iconUrl.isNotEmpty
                                        ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: community.iconUrl)))
                                        : null,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Wumbleheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Wumbleheme.backgroundColor, width: 4),
                                        image: community.iconUrl.isNotEmpty
                                            ? DecorationImage(
                                                image: CachedNetworkImageProvider(MediaOptimizer.optimize(community.iconUrl, width: 240, height: 240)),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                                        ],
                                      ),
                                      child: community.iconUrl.isEmpty ? const Icon(Icons.group, size: 40, color: Colors.white54) : null,
                                    ),
                                  ),
                                  
                                  const Spacer(),
                                  
                                  // Botón de Compartir
                                  Container(
                                    margin: const EdgeInsets.only(right: 8, bottom: 4),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                    child: IconButton(
                                      icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
                                      onPressed: () {
                                        final String shareUrl = 'https://wumble.link/c/${community.handle ?? community.id}';
                                        final String shareText = '¡Mira esta comunidad en Wumble!\n$shareUrl\n\n${community.name}\n${community.description}';
                                        
                                        ShareHelper.share(
                                          context: context,
                                          text: shareText,
                                          subject: community.name,
                                          imageUrl: community.iconUrl,
                                        );
                                      },
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                  
                                    // Botón de Opciones (...)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8, bottom: 4),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                      child: IconButton(
                                        icon: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                                        onPressed: () => _showOptions(context, state.memberProfile),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  
                                  // Botón de Unirse
                                  if (showJoinButton)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      child: ElevatedButton(
                                        onPressed: canJoin ? () async {
                                         final navigator = Navigator.of(context);
                                         final scaffoldMessenger = ScaffoldMessenger.of(context);
                                         final userId = FirebaseAuth.instance.currentUser?.uid;
                                         if (userId == null) return;
                                         
                                         if (community.privacy == 'approval') {
                                           try {
                                             await di.sl<CommunityRepository>().requestJoinCommunity(community.id, userId);
                                             scaffoldMessenger.showSnackBar(
                                               SnackBar(
                                                 content: Text(tr('Solicitud enviada correctamente.')),
                                                 backgroundColor: community.themeColor,
                                               ),
                                             );
                                           } catch (e) {
                                             scaffoldMessenger.showSnackBar(
                                               SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                             );
                                           }
                                           return;
                                         }
                                         
                                         // Show loading dialog
                                         showDialog(
                                           context: context,
                                           barrierDismissible: false,
                                           barrierColor: Colors.black87,
                                           builder: (_) => WillPopScope(
                                             onWillPop: () async => false,
                                             child: Center(
                                               child: Column(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   CircularProgressIndicator(color: community.themeColor),
                                                   const SizedBox(height: 20),
                                                   Text(
                                                     'Uniéndote a ${community.name}...',
                                                     style: const TextStyle(
                                                       color: Colors.white,
                                                       fontSize: 16,
                                                       fontWeight: FontWeight.w500,
                                                       decoration: TextDecoration.none,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                           ),
                                         );
                                         
                                         try {
                                           // 1. Join via repository directly 
                                           await di.sl<CommunityRepository>().joinCommunity(community.id, userId);
                                           
                                           // 2. Poll until member profile is ready in Firestore
                                           final profileRepo = di.sl<ProfileRepository>();
                                           CommunityMember? memberProfile;
                                           for (int i = 0; i < 10; i++) {
                                             memberProfile = await profileRepo.getMemberProfile(community.id, userId);
                                             if (memberProfile != null) break;
                                             await Future.delayed(const Duration(milliseconds: 500));
                                           }
                                           
                                           // 3. Pre-load the Bloc state with everything needed
                                           final bloc = context.read<CommunityContextBloc>();
                                           bloc.add(JoinCommunityRequested(community: community));
                                           // Wait for the Bloc to process the event
                                           await Future.delayed(const Duration(milliseconds: 200));
                                           
                                           // 4. Close loading dialog
                                           navigator.pop();
                                           
                                           // 5. Navigate to the community
                                           if (fromCommunityDetail) {
                                             navigator.pop();
                                           } else {
                                             navigator.pushReplacement(
                                               MaterialPageRoute(
                                                 builder: (_) => CommunityDetailScreen(
                                                   community: community,
                                                   showWelcomeModal: true,
                                                 ),
                                               ),
                                             );
                                           }
                                         } catch (e) {
                                           if (navigator.canPop()) navigator.pop();
                                           scaffoldMessenger.showSnackBar(
                                             SnackBar(content: Text('Error al unirse: $e'), backgroundColor: Colors.red),
                                           );
                                         }
                                      } : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canJoin ? community.themeColor : Colors.grey[800],
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors.white54,
                                        disabledBackgroundColor: Colors.grey[800],
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: Text(
                                        buttonText,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 10),

                      // ── Info Principal ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título
                            Text(
                              community.name,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            
                            // Meta Data
                            Text(
                              '${community.membersCount} miembros · Creado el ${community.createdAt.day}/${community.createdAt.month}/${community.createdAt.year}',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            
                            // Creador
                            StreamBuilder<UserProfile>(
                              stream: di.sl<ProfileRepository>().getUserProfile(community.creatorId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();
                                final creator = snapshot.data!;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    UserAvatar(
                                      avatarUrl: creator.avatarUrl,
                                      radius: 10,
                                      avatarFrameUrl: creator.avatarFrameUrl,
                                      showOnlineIndicator: false,
                                      userId: creator.id,
                                      isClickable: true,
                                      isAnimated: false,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(tr('Creado por '), style: TextStyle(color: Colors.white54, fontSize: 13)),
                                    Text(
                                      creator.displayName,
                                      style: TextStyle(color: community.themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const Text(' ✿', style: TextStyle(color: Colors.pinkAccent, fontSize: 12)),
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // ── Topics ──
                            Text(tr('Categorías'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (community.category.isNotEmpty)
                                  _TopicPill(text: community.category.trim(), baseColor: community.themeColor),
                                if (community.privacy == 'open') _TopicPill(text: 'Abierta', baseColor: Colors.green),
                                if (community.privacy == 'approval') _TopicPill(text: 'Solo Solicitudes', baseColor: Colors.orange),
                                if (community.privacy == 'private') _TopicPill(text: 'Privada', baseColor: Colors.red),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // ── Descripción Larga ──
                            Text(tr('Descripción'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 12),
                            Text(
                              community.description.isEmpty 
                                ? '¡Bienvenidos a nuestra comunidad!\n\nÚnete para interactuar con nosotros, ver las últimas novedades y disfrutar de todo el contenido.'
                                : community.description,
                              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                            ),
                            
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOptions(BuildContext context, CommunityMember? member) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = currentUser?.uid == community.creatorId;
    final isLeader = member?.role == 'leader' || member?.role == 'creator' || isCreator;

    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 20),
          
          ListTile(
            leading: Icon(Icons.share_rounded, color: Colors.white),
            title: Text(tr('Compartir Comunidad'), style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              final String shareUrl = 'https://wumble.link/c/${community.handle ?? community.id}';
              final String shareText = '¡Mira esta comunidad en Wumble!\n$shareUrl\n\n${community.name}\n${community.description}';
              
              ShareHelper.share(
                context: context,
                text: shareText,
                subject: community.name,
                imageUrl: community.iconUrl,
              );
            },
          ),
          
          if (isLeader)
            ListTile(
              leading: Icon(Icons.settings_outlined, color: Colors.white),
              title: Text(tr('Ajustes de Comunidad'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunitySettingsScreen(
                      community: community,
                      member: member,
                    ),
                  ),
                );
              },
            ),
            
          if (member != null)
            ListTile(
              leading: Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
              title: Text(tr('Abandonar Comunidad'), style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                final bloc = context.read<CommunityContextBloc>();
                Navigator.pop(context); // Close bottom sheet
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: Wumbleheme.surfaceColor,
                    title: Text(tr('¿Abandonar Comunidad?'), style: TextStyle(color: Colors.white)),
                    content: Text(
                      tr('Perderás tu rango y progreso en esta comunidad. ¿Estás seguro de que quieres salir?'),
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // Close dialog
                          bloc.add(LeaveCommunityRequested());
                        },
                        child: Text(tr('Abandonar'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),

          Divider(color: Colors.white10),
          
          ListTile(
            leading: Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
            title: Text(tr('Reportar Comunidad'), style: TextStyle(color: Colors.orangeAccent)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('Reporte enviado correctamente. El equipo de moderación lo revisará pronto.')),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  final String text;
  final Color baseColor;

  const _TopicPill({required this.text, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: baseColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
