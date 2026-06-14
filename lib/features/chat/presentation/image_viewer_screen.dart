import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme.dart';

class ImageViewerScreen extends StatefulWidget {
  final String imageUrl;

  ImageViewerScreen({super.key, required this.imageUrl});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    try {
      // Check for permission
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Dio().download(widget.imageUrl, path);
      
      await Gal.putImage(path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Imagen guardada en la galería'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isDownloading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _isDownloading ? null : _downloadImage,
          ),
        ],
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          clipBehavior: Clip.none,
          panEnabled: true,
          scaleEnabled: true,
          child: Center(
            child: OptimizedImage(imageUrl: widget.imageUrl),
          ),
        ),
      ),
    );
  }
}

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  OptimizedImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(child: CircularProgressIndicator(color: Colors.white24));
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: Colors.white24, size: 50),
              SizedBox(height: 10),
              Text(tr('No se pudo cargar la imagen'), style: TextStyle(color: Colors.white38)),
            ],
          ),
        );
      },
    );
  }
}
