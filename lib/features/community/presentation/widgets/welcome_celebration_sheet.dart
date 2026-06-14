import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../domain/community_model.dart';
import '../../../../core/theme.dart';

class WelcomeCelebrationSheet extends StatelessWidget {
  final Community community;

  WelcomeCelebrationSheet({super.key, required this.community});

  static void show(BuildContext context, Community community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => WelcomeCelebrationSheet(community: community),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Wumbleheme.backgroundColor.withOpacity(0.9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: community.themeColor.withOpacity(0.3), width: 1.5),
      ),
      child: Stack(
        children: [
          // Background Gradient Glow
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    community.themeColor.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                // Grab Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 40),

                // Celebration Icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: community.themeColor.withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: community.iconUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: community.iconUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: community.themeColor,
                              child: const Icon(Icons.group, size: 60, color: Colors.white),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Welcome Text
                Text(
                  tr('¡BIENVENIDO!'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    community.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    (community.isWelcomeMessageEnabled && community.welcomeMessage != null && community.welcomeMessage!.isNotEmpty)
                        ? community.welcomeMessage!
                        : 'Ahora eres parte oficial de esta gran comunidad.\n¡Explora, comparte y diviértete!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Quick Actions or Stats
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat(Icons.people_alt_rounded, community.membersCount.toString(), 'Miembros'),
                      _buildQuickStat(Icons.verified_user_rounded, 'Nv. 1', 'Tu Rango'),
                      _buildQuickStat(Icons.stars_rounded, '0', 'Reputación'),
                    ],
                  ),
                ),
                SizedBox(height: 40),

                // Action Button
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: community.themeColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      elevation: 12,
                      shadowColor: community.themeColor.withOpacity(0.5),
                    ),
                    child: Text(
                      tr('EMPEZAR A EXPLORAR'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}
