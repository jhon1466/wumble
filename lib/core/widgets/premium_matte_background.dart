import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';

class PremiumMatteBackground extends StatelessWidget {
  const PremiumMatteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Solid Dark Gray
        Container(color: const Color(0xFF0D0D0E)),
        
        // Subtle Radial Gradient for depth
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 1.2,
                colors: [
                  const Color(0xFF1A1A1C),
                  const Color(0xFF0D0D0E),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),

        // Faint accent glow (Top Right)
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Wumbleheme.primaryColor.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

