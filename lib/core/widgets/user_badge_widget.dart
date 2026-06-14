import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';

class UserBadgeWidget extends StatelessWidget {
  final int level;
  final List<CommunityLabel> titles;
  final String role;
  final double fontSize;
  final bool showTitles;
  final bool isBot;

  const UserBadgeWidget({
    super.key,
    required this.level,
    this.titles = const [],
    this.role = 'member',
    this.fontSize = 10,
    this.showTitles = true,
    this.isBot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // BOT Badge
        if (isBot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF673AB7), // Deep Purple
                  Color(0xFF9575CD),
                ],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              tr('BOT'),
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),

        // Level Badge
        if (!isBot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getLevelColor(level),
                  _getLevelColor(level).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: _getLevelColor(level).withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              'LV $level',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),

        // Role Badge (if special and has a valid name)
        if (role != 'member' && _getRoleName(role).isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _getRoleColor(role),
                width: 1,
              ),
            ),
            child: Text(
              _getRoleName(role),
              style: TextStyle(
                color: _getRoleColor(role),
                fontSize: fontSize - 1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Custom Titles
        if (showTitles && titles.isNotEmpty)
          ...titles.map((title) {
            final customColor = title.colorValue != null ? Color(title.colorValue!) : Colors.white24;
            final isDark = customColor == Colors.white24;
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : customColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: customColor,
                  width: 0.5,
                ),
              ),
              child: Text(
                title.text,
                style: TextStyle(
                  color: isDark ? Colors.white70 : customColor,
                  fontSize: fontSize - 1,
                  fontWeight: isDark ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            );
          }),
      ],
    );
  }

  Color _getLevelColor(int level) {
    if (level >= 15) return Colors.red;
    if (level >= 10) return Colors.purple;
    if (level >= 5) return Colors.blue;
    return Colors.green;
  }

  Color _getRoleColor(String role) {
    if (role == 'leader') return Colors.amber;
    if (role == 'curator') return const Color(0xFF00BFA5);
    if (role == 'system') return Colors.blueAccent;
    return Colors.white54;
  }

  String _getRoleName(String role) {
    if (role == 'leader') return 'LIDER';
    if (role == 'curator') return 'CURADOR';
    if (role == 'system') return 'SISTEMA';
    return '';
  }
}
