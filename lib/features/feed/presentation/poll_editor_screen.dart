import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../../core/theme.dart';

class PollEditorScreen extends StatefulWidget {
  PollEditorScreen({super.key});

  @override
  State<PollEditorScreen> createState() => _PollEditorScreenState();
}

class _PollEditorScreenState extends State<PollEditorScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  void _addOption() {
    if (_optionControllers.length < 5) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('Nueva Encuesta')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('¡Encuesta publicada con éxito!'))),
              );
            },
            child: Text(
              tr('Publicar'),
              style: TextStyle(
                color: Wumbleheme.accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Field
            TextField(
              controller: _questionController,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: tr('Haz una pregunta...'),
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
            Divider(color: Colors.white10),
            SizedBox(height: 16),
            
            Text(
              tr('Opciones de respuesta'),
              style: TextStyle(color: Wumbleheme.textSecondary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Poll Options
            ..._optionControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Wumbleheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Center(
                        child: Text(
                          (idx + 1).toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          hintText: 'Opción ${idx + 1}',
                          filled: true,
                          fillColor: Wumbleheme.surfaceColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _removeOption(idx),
                      ),
                  ],
                ),
              );
            }).toList(),
            
            // Add Option Button
            if (_optionControllers.length < 5)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, color: Wumbleheme.accentColor),
                label: Text(tr('Añadir opción'), style: TextStyle(color: Wumbleheme.accentColor)),
              ),
              
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            
            // Duration and Settings
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined, color: Wumbleheme.textSecondary),
              title: Text(tr('Duración de la encuesta')),
              trailing: Text(tr('30 días'), style: TextStyle(color: Wumbleheme.accentColor)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
