import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';

class ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const ProfileStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Wumbleheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class ProfileTitleBadge extends StatelessWidget {
  final CommunityLabel title;

  const ProfileTitleBadge({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final customColor = title.colorValue != null ? Color(title.colorValue!) : Wumbleheme.accentColor;
    
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: customColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        title.text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black54,
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
