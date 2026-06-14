import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/media_helper.dart';
import '../../../../core/theme.dart';

class BlogEditorScreen extends StatefulWidget {
  BlogEditorScreen({super.key});

  @override
  State<BlogEditorScreen> createState() => _BlogEditorScreenState();
}

class _BlogEditorScreenState extends State<BlogEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedImageUrl;

  Future<void> _pickBlogImage() async {
    final image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() {
        _selectedImageUrl = image.path; 
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imagen de portada optimizada al 70%: ${image.name}')),
      );
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
        title: Text(tr('Crear Blog')),
        actions: [
          TextButton(
            onPressed: () {
              // Logic to publish will go here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('¡Blog publicado con éxito!'))),
              );
            },
            child: Text(
              'Publicar',
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
            // Image Picker Placeholder
            GestureDetector(
              onTap: _pickBlogImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Wumbleheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                  image: _selectedImageUrl != null
                      ? DecorationImage(
                          image: FileImage(File(_selectedImageUrl!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImageUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: Wumbleheme.textSecondary),
                          SizedBox(height: 8),
                          Text(tr('Añadir imagen de portada'), style: TextStyle(color: Wumbleheme.textSecondary)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title Field
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Título del blog...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
            const Divider(color: Colors.white10),
            
            // Content Field
            TextField(
              controller: _contentController,
              maxLines: null,
              style: const TextStyle(fontSize: 16, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Escribe algo increíble...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          border: const Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.format_bold), onPressed: () {}),
            IconButton(icon: const Icon(Icons.format_italic), onPressed: () {}),
            IconButton(icon: const Icon(Icons.format_underlined), onPressed: () {}),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: _pickBlogImage,
            ),
            IconButton(icon: const Icon(Icons.local_offer_outlined), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
