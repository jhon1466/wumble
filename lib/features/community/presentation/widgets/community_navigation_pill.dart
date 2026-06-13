import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/presentation/widgets/member_mini_profile.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import '../../domain/navigation_tab_model.dart';

/// Metadata for the dynamic create action per tab.
class _CreateAction {
  final IconData icon;
  final String label;
  final bool enabled;
  const _CreateAction({required this.icon, required this.label, this.enabled = true});
}

const _tabActions = <NavigationTabType, _CreateAction>{
  NavigationTabType.featured: _CreateAction(icon: Icons.edit_note_rounded,        label: 'Publicar'),
  NavigationTabType.recent:   _CreateAction(icon: Icons.edit_note_rounded,        label: 'Publicar'),
  NavigationTabType.chats:    _CreateAction(icon: Icons.chat_bubble_outline_rounded, label: 'Nuevo Chat'),
  NavigationTabType.leaderboard: _CreateAction(icon: Icons.emoji_events_outlined,    label: 'Líderes',  enabled: false),
  NavigationTabType.wikis:    _CreateAction(icon: Icons.menu_book_rounded,         label: 'Nueva Wiki'),
  NavigationTabType.quizzes:  _CreateAction(icon: Icons.quiz_outlined,             label: 'Crear Quiz'),
  NavigationTabType.sharedFolder: _CreateAction(icon: Icons.add_a_photo_rounded,       label: 'Subir Foto'),
  NavigationTabType.polls:    _CreateAction(icon: Icons.poll_outlined,             label: 'Nueva Encuesta'),
  NavigationTabType.category: _CreateAction(icon: Icons.edit_note_rounded,        label: 'Publicar'),
};

class CommunityNavigationPill extends StatelessWidget {
  final Color themeColor;
  final NavigationTabType activeTabType;          // ← Dynamic action label based on type
  final bool isMember;                            // ← NEW: Check if user is member

  final VoidCallback onMenuTap;
  final VoidCallback onMembersTap;
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;                  // ← NEW: Action for guests
  final VoidCallback onPlusTap;                  // ← NEW: Open multi-action menu

  const CommunityNavigationPill({
    super.key,
    required this.themeColor,
    required this.onMenuTap,
    required this.onMembersTap,
    required this.onCreateTap,
    required this.onJoinTap,
    required this.onPlusTap,
    required this.activeTabType,
    this.isMember = true,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final action = _tabActions[activeTabType] ??
        const _CreateAction(icon: Icons.add_circle_outline_rounded, label: 'Crear');

    final effectiveColor = action.enabled ? themeColor : Colors.white24;
    final effectiveTextColor = action.enabled ? Colors.white : Colors.white38;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding > 0 ? bottomPadding : 16),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),

                // 1. Menu Button (Always visible)
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: onMenuTap,
                ),

                if (isMember) ...[
                  GestureDetector(
                    onTap: onMembersTap,
                    child: const Text(
                      'Miembros',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),

                  // 2. Subtle divider
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white.withOpacity(0.1),
                  ),

                  // 3. Dynamic Create Button (right side - Member Only)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                    child: Material(
                      key: ValueKey(activeTabType),
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: action.enabled ? onCreateTap : null,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: effectiveColor.withOpacity(action.enabled ? 0.15 : 0.06),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: effectiveColor.withOpacity(action.enabled ? 0.4 : 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(action.icon, color: effectiveColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                action.label,
                                style: TextStyle(
                                  color: effectiveTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // 4. "+" Button (Multi-Action Menu)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPlusTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: effectiveColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: effectiveColor.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                             BoxShadow(
                               color: effectiveColor.withOpacity(0.15),
                               blurRadius: 8,
                               spreadRadius: 1,
                             ),
                          ],
                        ),
                        child: Icon(Icons.add_rounded, color: effectiveTextColor, size: 24),
                      ),
                    ),
                  ),
                ] else ...[
                  // 4. JOIN BUTTON (Alternative for non-members)
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onJoinTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: themeColor.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add_rounded, color: themeColor, size: 20),
                            const SizedBox(width: 10),
                            const Text(
                              'Unirte a esta comunidad',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

