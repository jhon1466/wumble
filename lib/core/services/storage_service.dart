import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../utils/media_helper.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// Subir una imagen a Firebase Storage y devolver la URL
  Future<String> uploadChatImage(File originalFile) async {
    try {
      // --- COMPRESIÓN DE SEGURIDAD ---
      final file = await MediaHelper.compressFile(originalFile);
      
      final extension = file.path.split('.').last.toLowerCase();
      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref().child('chats/images/$fileName');
      
      debugPrint('StorageService: Leyendo bytes del archivo...');
      final bytes = await file.readAsBytes();
      
      debugPrint('StorageService: Subiendo ${bytes.length} bytes a ${ref.fullPath}...');
      
      final metadata = SettableMetadata(
        contentType: extension == 'gif' ? 'image/gif' : 'image/jpeg',
      );

      final uploadTask = await ref.putData(bytes, metadata);
      debugPrint('StorageService: Tarea de subida completada.');
      
      final url = await uploadTask.ref.getDownloadURL();
      debugPrint('StorageService: URL obtenida: $url');
      return url;
    } catch (e) {
      debugPrint('StorageService: ❌ ERROR en uploadChatImage: $e');
      rethrow;
    }
  }

  /// Subir una imagen de post a Firebase Storage y devolver la URL
  Future<String> uploadPostImage(File originalFile, {String? folder}) async {
    try {
      // --- COMPRESIÓN DE SEGURIDAD ---
      final file = await MediaHelper.compressFile(originalFile);

      final extension = file.path.split('.').last.toLowerCase();
      final fileName = '${_uuid.v4()}.$extension';
      final path = folder ?? 'posts/images';
      final ref = _storage.ref().child('$path/$fileName');
      
      debugPrint('StorageService: Leyendo bytes del archivo para post...');
      final bytes = await file.readAsBytes();
      
      debugPrint('StorageService: Subiendo ${bytes.length} bytes a ${ref.fullPath}...');
      
      final metadata = SettableMetadata(
        contentType: extension == 'gif' ? 'image/gif' : 'image/jpeg',
      );

      final uploadTask = await ref.putData(bytes, metadata);
      debugPrint('StorageService: Tarea de subida completada.');
      
      final url = await uploadTask.ref.getDownloadURL();
      debugPrint('StorageService: URL obtenida: $url');
      return url;
    } catch (e) {
      debugPrint('StorageService: ❌ ERROR en uploadPostImage: $e');
      rethrow;
    }
  }

  /// Subir un audio a Firebase Storage y devolver la URL
  Future<String> uploadChatVoice(File file) async {
    try {
      final fileName = '${_uuid.v4()}.m4a';
      final ref = _storage.ref().child('chats/voice/$fileName');
      
      debugPrint('StorageService: Leyendo bytes del audio...');
      final bytes = await file.readAsBytes();
      
      debugPrint('StorageService: Subiendo ${bytes.length} bytes a ${ref.fullPath}...');
      
      final metadata = SettableMetadata(contentType: 'audio/m4a');
      final uploadTask = await ref.putData(bytes, metadata);
      
      final url = await uploadTask.ref.getDownloadURL();
      debugPrint('StorageService: Audio subido: $url');
      return url;
    } catch (e) {
      debugPrint('StorageService: ❌ ERROR en uploadChatVoice: $e');
      rethrow;
    }
  }

  /// Eliminar un archivo de Firebase Storage usando su URL de descarga
  Future<void> deleteFileByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      debugPrint('StorageService: Eliminando ${ref.fullPath}...');
      await ref.delete();
      debugPrint('StorageService: Archivo eliminado exitosamente.');
    } catch (e) {
      debugPrint('StorageService: ⚠️ Error al eliminar archivo: $e');
      // No relanzamos el error para que la eliminación del mensaje no falle
    }
  }
}
