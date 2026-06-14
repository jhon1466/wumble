import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:wumble/core/theme.dart';
import '../../domain/moderation_models.dart';

class SanctionDialog extends StatefulWidget {
  final String userId;
  final String? targetUsername;

  SanctionDialog({
    super.key,
    required this.userId,
    this.targetUsername,
  });

  @override
  State<SanctionDialog> createState() => _SanctionDialogState();
}

class _SanctionDialogState extends State<SanctionDialog> {
  SanctionType _selectedType = SanctionType.warning;
  final TextEditingController _reasonController = TextEditingController();
  int _banDurationDays = 1;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aplicar Sanción',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.targetUsername != null) ...[
              const SizedBox(height: 4),
              Text(
                'Objetivo: @${widget.targetUsername}',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'TIPO DE SANCIÓN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            _buildTypeSelector(),
            if (_selectedType == SanctionType.ban) ...[
              const SizedBox(height: 24),
              const Text(
                'DURACIÓN',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              _buildBanDurationSelector(),
            ],
            const SizedBox(height: 24),
            const Text(
              'MOTIVO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Explica la razón de la sanción...',
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('Cancelar')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getSanctionColor(_selectedType),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(tr('Aplicar'), style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      children: [
        _buildTypeOption(SanctionType.warning, 'Advertencia', Icons.warning_amber_rounded, Colors.orange),
        const SizedBox(height: 8),
        _buildTypeOption(SanctionType.strike, 'Falta (Strike)', Icons.gavel_rounded, Colors.redAccent),
        const SizedBox(height: 8),
        _buildTypeOption(SanctionType.ban, 'Expulsión (Ban)', Icons.block_rounded, Colors.black),
      ],
    );
  }

  Widget _buildTypeOption(SanctionType type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : null)),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBanDurationSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDurationChip(1, '1 Día'),
          const SizedBox(width: 8),
          _buildDurationChip(7, '7 Días'),
          const SizedBox(width: 8),
          _buildDurationChip(30, '1 Mes'),
          const SizedBox(width: 8),
          _buildDurationChip(365, 'Permanente'),
        ],
      ),
    );
  }

  Widget _buildDurationChip(int days, String label) {
    final isSelected = _banDurationDays == days;
    return GestureDetector(
      onTap: () => setState(() => _banDurationDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  void _handleApply() {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Por favor ingresa un motivo.'))));
      return;
    }

    final expiresAt = _selectedType == SanctionType.ban 
        ? DateTime.now().add(Duration(days: _banDurationDays)) 
        : null;

    final sanction = Sanction(
      id: '', // Will be generated by Firestore
      userId: widget.userId,
      adminId: 'mock_admin_id', // Should be current user
      type: _selectedType,
      reason: _reasonController.text.trim(),
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );

    Navigator.pop(context, sanction);
  }

  Color _getSanctionColor(SanctionType type) {
    switch (type) {
      case SanctionType.warning: return Colors.orange;
      case SanctionType.strike: return Colors.redAccent;
      case SanctionType.ban: return Colors.black;
    }
  }
}
