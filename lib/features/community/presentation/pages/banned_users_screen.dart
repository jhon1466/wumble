import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../../core/theme.dart';
import '../../domain/community_member_model.dart';
import '../../domain/community_repository.dart';
import '../../../../injection_container.dart' as di;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/user_avatar.dart';

class BannedUsersScreen extends StatefulWidget {
  final String communityId;
  final Color themeColor;

  BannedUsersScreen({
    super.key,
    required this.communityId,
    required this.themeColor,
  });

  @override
  State<BannedUsersScreen> createState() => _BannedUsersScreenState();
}

class _BannedUsersScreenState extends State<BannedUsersScreen> {
  final _repository = di.sl<CommunityRepository>();
  bool _isLoading = true;
  List<CommunityMember> _bannedMembers = [];

  @override
  void initState() {
    super.initState();
    _loadBannedMembers();
  }

  Future<void> _loadBannedMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _repository.getBannedMembers(widget.communityId);
      setState(() {
        _bannedMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar expulsados: $e')),
        );
      }
    }
  }

  Future<void> _unbanUser(CommunityMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('¿Permitir reingreso?'), style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que quieres levantar la expulsión de ${member.displayName ?? "este usuario"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('PERMITIR'), style: TextStyle(color: widget.themeColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.unbanMember(widget.communityId, member.userId);
        _loadBannedMembers(); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Acceso restaurado'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Wumbleheme.backgroundColor,
        title: Text(tr('Usuarios Expulsados'), style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bannedMembers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bannedMembers.length,
                  itemBuilder: (context, index) {
                    final member = _bannedMembers[index];
                    return _buildBannedItem(member);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text(
            'No hay usuarios expulsados',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBannedItem(CommunityMember member) {
    final isPermanent = member.banExpiresAt == null;
    final expiresText = isPermanent 
        ? 'Permanente' 
        : 'Expira: ${DateFormat('dd/MM/yyyy').format(member.banExpiresAt!)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatar(
          userId: member.userId,
          avatarUrl: member.avatarUrl ?? '',
          displayName: member.displayName ?? 'Usuario',
          radius: 20,
          communityId: widget.communityId,
          isClickable: false,
        ),
        title: Text(
          member.displayName ?? 'Usuario',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              expiresText,
              style: TextStyle(
                color: isPermanent ? Colors.redAccent : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _unbanUser(member),
          child: Text(tr('PERDONAR'), style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
