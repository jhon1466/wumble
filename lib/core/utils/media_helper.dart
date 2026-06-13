import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class MediaHelper {
  static final ImagePicker _picker = ImagePicker();
  static const double maxFileSizeMb = 5.0;
  static const int imageQuality = 70;

  /// Abre la galería y devuelve un XFile optimizado y COMPRIMIDO.
  /// Valida que el archivo no supere los 5MB (imágenes) u 8MB (animados).
  /// Si NO es GIF o WebP, lo comprime automáticamente a ~80% de calidad y max 1024px.
  static Future<XFile?> pickImageWithOptimization(BuildContext context) async {
    debugPrint('MediaHelper: Iniciando pickImage...');
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        debugPrint('MediaHelper: El usuario canceló la selección.');
        return null;
      }

      debugPrint('MediaHelper: Archivo seleccionado: ${image.path}');
      final extension = image.path.contains('.') 
          ? image.path.split('.').last.toLowerCase()
          : '';
      final isGif = extension == 'gif';
      final isWebp = extension == 'webp';
      
      debugPrint('MediaHelper: Extensión: $extension, isGif: $isGif, isWebp: $isWebp');
      
      final double limit = (isGif || isWebp) ? 8.0 : maxFileSizeMb;
      final int originalSizeInBytes = await image.length();
      final double originalSizeInMb = originalSizeInBytes / (1024 * 1024);
      
      // Aviso para GIFs pesados (>2MB)
      if (isGif && originalSizeInMb > 2.0) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text('⚠️ GIF Pesado Detectado', style: TextStyle(fontWeight: FontWeight.bold)),
                   Text('Este archivo pesa ${originalSizeInMb.toStringAsFixed(1)}MB. La subida tardará un poco.'),
                 ],
               ),
               duration: const Duration(seconds: 4),
               backgroundColor: Colors.orange.shade800,
             ),
           );
        }
      }

      // Bloqueo para archivos que superan el límite
      if (originalSizeInMb > limit) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (isGif || isWebp)
                  ? 'El archivo animado es demasiado pesado (${originalSizeInMb.toStringAsFixed(1)}MB). Máximo 8MB.'
                  : 'La imagen es demasiado pesada (${originalSizeInMb.toStringAsFixed(1)}MB). Máximo ${maxFileSizeMb}MB.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return null;
      }

      // --- COMPRESIÓN AUTOMÁTICA ---
      if (!isGif && !isWebp) {
        debugPrint('MediaHelper: Comprimiendo imagen...');
        final String compressedPath = await compressImage(image.path);
        
        // Verificamos ahorro
        final compressedFile = File(compressedPath);
        final compressedSizeInBytes = await compressedFile.length();
        final ahorro = (1 - (compressedSizeInBytes / originalSizeInBytes)) * 100;
        
        debugPrint('MediaHelper: Compresión finalizada. Ahorro: ${ahorro.toStringAsFixed(1)}%');
        return XFile(compressedPath);
      }

      debugPrint('MediaHelper: Selección completada con éxito (Sin compresión por ser animado).');
      return image;
    } catch (e, stack) {
      debugPrint('MediaHelper: ❌ ERROR CRÍTICO: $e');
      debugPrint('Stack: $stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
      return null;
    }
  }

  /// Método para validar un archivo ya seleccionado
  static Future<bool> isSizeValid(XFile file) async {
    final extension = file.path.split('.').last.toLowerCase();
    final int sizeInBytes = await file.length();
    final double sizeInMb = sizeInBytes / (1024 * 1024);
    final double limit = (extension == 'gif') ? 10.0 : maxFileSizeMb;
    return sizeInMb <= limit;
  }

  /// Comprime una imagen antes de subirla (excluye GIFs y WebPs)
  static Future<String> compressImage(String path) async {
    final extension = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    
    // No comprimimos GIFs ni WebPs porque pierden la animación
    if (extension == 'gif' || extension == 'webp') return path;

    try {
      final dir = await getTemporaryDirectory();
      // Mantenemos la extensión original para preservar transparencia (PNG)
      final targetExtension = extension == 'png' ? 'png' : 'jpg';
      final targetPath = '${dir.absolute.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.$targetExtension';

      final result = await FlutterImageCompress.compressAndGetFile(
        path,
        targetPath,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
        format: extension == 'png' ? CompressFormat.png : CompressFormat.jpeg,
      );

      if (result == null) return path;

      // Solo devolvemos la comprimida si realmente es más pequeña o similar
      final originalSize = await File(path).length();
      final compressedSize = await File(result.path).length();
      
      if (compressedSize >= originalSize) {
        debugPrint('MediaHelper: La imagen comprimida es igual o mayor. Usando original.');
        return path;
      }

      return result.path;
    } catch (e) {
      debugPrint('MediaHelper: Error al comprimir imagen: $e');
      return path; // Fallback al original si falla la compresión
    }
  }

  /// Helper para comprimir un objeto File directamente
  static Future<File> compressFile(File file) async {
    final path = await compressImage(file.path);
    return File(path);
  }
}
