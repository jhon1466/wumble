import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/core/widgets/user_badge_widget.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberManagementScreen extends StatefulWidget {
  final String communityId;
  final Color themeColor;

  const MemberManagementScreen({
    super.key, 
    required this.communityId,
    required this.themeColor,
  });

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final List<CommunityMember> _members = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final _repository = di.sl<CommunityRepository>();

  @override
  void initState() {
    super.initState();
    _loadMoreMembers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMembers();
    }
  }

  Future<void> _loadMoreMembers() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final result = await _repository.getCommunityMembersPaginated(
        widget.communityId,
        lastDocument: _lastDoc,
        limit: 20,
      );

      final List<CommunityMember> newMembers = result['members'] as List<CommunityMember>;
      final DocumentSnapshot? nextDoc = result['lastDocument'] as DocumentSnapshot?;

      if (mounted) {
        setState(() {
          _members.addAll(newMembers);
          _lastDoc = nextDoc;
          _hasMore = newMembers.length == 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading members: $e');
    }
  }

  void _refreshMembers() {
    setState(() {
      _members.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    _loadMoreMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Wumbleheme.backgroundColor,
        title: Text(tr('Gestionar Miembros')),
        elevation: 0,
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemExtent: 81.0, // 80.0 height + 1.0 divider
        cacheExtent: 1000,
        padding: const EdgeInsets.all(16),
        itemCount: _members.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _members.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final member = _members[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMemberTile(member),
              const Divider(color: Colors.white10, height: 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMemberTile(CommunityMember member) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(
        userId: member.userId,
        avatarUrl: member.avatarUrl ?? '',
        displayName: member.displayName,
        radius: 25,
        communityId: widget.communityId,
        isAnimated: false,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              member.displayName ?? 'Usuario',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          UserBadgeWidget(
            level: member.level,
            role: member.role,
            titles: member.titles,
            fontSize: 9,
            showTitles: false, // Don't show titles here to keep it clean, or show below?
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CommunityMember.getRoleTitle(member.role).toUpperCase(),
            style: TextStyle(
              color: CommunityMember.getRoleColor(member.role, Colors.white38),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          if (member.titles.isNotEmpty) ...[
            const SizedBox(height: 4),
            UserBadgeWidget(
              level: member.level,
              titles: member.titles,
              role: 'member', // Only show titles here
              fontSize: 8,
              showTitles: true,
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white60),
        onPressed: () => _showMemberOptions(member),
      ),
    );
  }

  void _showMemberOptions(CommunityMember member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 20),
          _buildOption(
            icon: Icons.admin_panel_settings_rounded,
            title: tr('Cambiar Rol'),
            onTap: () {
              Navigator.pop(context);
              _showRolePicker(member);
            },
          ),
          _buildOption(
            icon: Icons.title_rounded,
            title: tr('Editar Etiquetas'),
            onTap: () {
              Navigator.pop(context);
              _showTitlesEditor(member);
            },
          ),
          _buildOption(
            icon: Icons.person_off_rounded,
            title: tr('Expulsar Miembro'),
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              _showExpulsionOptions(member);
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption({required IconData icon, required String title, required VoidCallback onTap, Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  void _showRolePicker(CommunityMember member) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Seleccionar Rol'), style: TextStyle(color: Colors.white)),
        children: ['member', 'curator', 'leader'].map((role) => SimpleDialogOption(
          onPressed: () async {
            await _repository.updateMemberRole(widget.communityId, member.userId, role);
            Navigator.pop(context);
            _refreshMembers();
          },
          child: Text(CommunityMember.getRoleTitle(role).toUpperCase(), style: TextStyle(color: Colors.white70)),
        )).toList(),
      ),
    );
  }

  void _showTitlesEditor(CommunityMember member) {
    final List<CommunityLabel> currentLabels = List.from(member.titles);
    final titleController = TextEditingController();
    Color selectedColor = widget.themeColor;

    final List<Color> labelPresets = [
      widget.themeColor,
      Color(0xFFF44336), // Red
      Color(0xFFE91E63), // Pink
      Color(0xFF9C27B0), // Purple
      Color(0xFF2196F3), // Blue
      Color(0xFF00BCD4), // Cyan
      Color(0xFF4CAF50), // Green
      Color(0xFFFFEB3B), // Yellow
      Color(0xFFFF9800), // Orange
      Color(0xFF607D8B), // Blue Grey
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Wumbleheme.surfaceColor,
          title: Text('Etiquetas: ${member.displayName}', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentLabels.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(tr('Sin etiquetas asignadas'), style: TextStyle(color: Colors.white38)),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentLabels.map((l) {
                      final lColor = l.colorValue != null ? Color(l.colorValue!) : widget.themeColor;
                      return Chip(
                        label: Text(l.text, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: lColor.withOpacity(0.2),
                        side: BorderSide(color: lColor.withOpacity(0.5)),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                        onDeleted: () {
                          setDialogState(() => currentLabels.remove(l));
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),
                
                // Color Picker
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: labelPresets.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final color = labelPresets[index];
                      final isSelected = selectedColor.value == color.value;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: tr('Nueva etiqueta...'),
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add_circle, color: selectedColor),
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          setDialogState(() {
                            currentLabels.add(CommunityLabel(
                              text: titleController.text.trim(),
                              colorValue: selectedColor.value,
                            ));
                            titleController.clear();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
            TextButton(
              onPressed: () async {
                await _repository.updateMemberTitles(widget.communityId, member.userId, currentLabels.map((l) => l.toFirestore()).toList() as List<dynamic>);
                if (mounted) {
                  Navigator.pop(context);
                  _refreshMembers();
                }
              },
              child: Text(tr('GUARDAR'), style: TextStyle(color: widget.themeColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpulsionOptions(CommunityMember member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              tr('OPCIONES DE EXPULSIÓN'),
              style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Expulsar a: ${member.displayName}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            _buildExpulsionTile(
              title: tr('Solo Expulsar'),
              subtitle: 'El usuario es removido pero puede volver a unirse.',
              icon: Icons.exit_to_app_rounded,
              color: Colors.white,
              onTap: () => _handleExpulsion(member, type: 'kick'),
            ),
            _buildExpulsionTile(
              title: tr('Falta: 24 Horas'),
              subtitle: 'Expulsión y baneo temporal por 1 día.',
              icon: Icons.history_rounded,
              color: Colors.orangeAccent,
              onTap: () => _handleExpulsion(member, type: 'ban_24h'),
            ),
            _buildExpulsionTile(
              title: tr('Falta: 72 Horas'),
              subtitle: 'Expulsión y baneo temporal por 3 días.',
              icon: Icons.timer_rounded,
              color: Colors.deepOrangeAccent,
              onTap: () => _handleExpulsion(member, type: 'ban_72h'),
            ),
            _buildExpulsionTile(
              title: tr('Baneo Permanente'),
              subtitle: 'Expulsión definitiva de la comunidad.',
              icon: Icons.gavel_rounded,
              color: Colors.redAccent,
              onTap: () => _handleExpulsion(member, type: 'ban_perm'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildExpulsionTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: color.withOpacity(0.5), fontSize: 12)),
    );
  }

  Future<void> _handleExpulsion(CommunityMember member, {required String type}) async {
    Navigator.pop(context); // Close sheet
    
    String successMsg = '';
    DateTime? banExpiration;

    switch (type) {
      case 'kick':
        successMsg = 'Usuario expulsado correctamente';
        break;
      case 'ban_24h':
        banExpiration = DateTime.now().add(const Duration(hours: 24));
        successMsg = 'Usuario sancionado por 24 horas';
        break;
      case 'ban_72h':
        banExpiration = DateTime.now().add(const Duration(hours: 72));
        successMsg = 'Usuario sancionado por 72 horas';
        break;
      case 'ban_perm':
        successMsg = 'Usuario baneado permanentemente';
        break;
    }

    final moderatorId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      if (type == 'kick') {
        await _repository.kickMember(widget.communityId, member.userId);
      } else {
        await _repository.banMember(widget.communityId, member.userId, moderatorId, expiresAt: banExpiration);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
        _refreshMembers(); // Sync list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
