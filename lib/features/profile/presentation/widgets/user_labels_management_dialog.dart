import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';

class UserLabelsManagementDialog extends StatefulWidget {
  final UserProfile user;
  final String? communityId;
  final Function(List<CommunityLabel>) onUpdate;

  UserLabelsManagementDialog({
    super.key,
    required this.user,
    this.communityId,
    required this.onUpdate,
  });

  @override
  State<UserLabelsManagementDialog> createState() => _UserLabelsManagementDialogState();
}

class _UserLabelsManagementDialogState extends State<UserLabelsManagementDialog> {
  late List<CommunityLabel> _labels;

  @override
  void initState() {
    super.initState();
    _labels = List.from(widget.user.titles);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Wumbleheme.surfaceColor,
      title: Text(tr('Gestionar mis Etiquetas'), style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Text(
              tr('Arrastra para cambiar el orden o elimina las que ya no desees.'),
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.transparent, // Fix drag preview background
                ),
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _labels.removeAt(oldIndex);
                      _labels.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int i = 0; i < _labels.length; i++)
                      ListTile(
                        key: ValueKey('label_${_labels[i].text}_$i'),
                        leading: const Icon(Icons.drag_handle, color: Colors.white24),
                        title: Text(
                          _labels[i].text,
                          style: TextStyle(
                            color: _labels[i].colorValue != null ? Color(_labels[i].colorValue!) : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => setState(() => _labels.removeAt(i)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate(_labels);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Wumbleheme.secondaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(tr('GUARDAR ORDEN'), style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
