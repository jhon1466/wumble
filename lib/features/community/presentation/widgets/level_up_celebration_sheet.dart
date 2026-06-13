import 'package:flutter/material.dart';
import 'dart:ui';
import '../../domain/community_model.dart';
import '../../domain/reputation_service.dart';
import '../../../../core/theme.dart';

class LevelUpCelebrationSheet extends StatelessWidget {
  final Community community;
  final int newLevel;
  final String newTitle;

  const LevelUpCelebrationSheet({
    super.key,
    required this.community,
    required this.newLevel,
    required this.newTitle,
  });

  static void show(BuildContext context, Community community, int level) {
    final title = ReputationService.getLevelTitle(level, community.levelTitles);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => LevelUpCelebrationSheet(
        community: community,
        newLevel: level,
        newTitle: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = community.themeColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Wumbleheme.backgroundColor.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
      ),
      child: Stack(
        children: [
          // Animated Background effects (Radial Glow)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    themeColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                
                // Animated level Badge
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Transform.scale(
                        scale: value,
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [themeColor, themeColor.withOpacity(0.5)],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'NIVEL',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            newLevel.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),

                // Congratulations text
                const Text(
                  '¡FELICIDADES!',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Has alcanzado un nuevo rango en',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  community.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // New Title Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withOpacity(0.5), width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'NUEVO TÍTULO',
                        style: TextStyle(
                          color: themeColor.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        newTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Continue Button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 8,
                    shadowColor: themeColor.withOpacity(0.5),
                  ),
                  child: const Text(
                    'INCREÍBLE',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Confetti-like particles (Static for now but visual)
          ...List.generate(5, (i) => Positioned(
            top: 100.0 + (i * 50),
            left: 50.0 + (i * 60),
            child: Icon(Icons.star, color: Colors.amber.withOpacity(0.3), size: 20),
          )),
        ],
      ),
    );
  }
}
