import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/features/community/domain/shared_image_model.dart';
import 'package:wumble/features/community/domain/shared_folder_repository.dart';
import 'package:wumble/core/services/storage_service.dart';

class SharedFolderRepositoryImpl implements SharedFolderRepository {
  final FirebaseFirestore _firestore;
  final StorageService _storageService;

  SharedFolderRepositoryImpl({
    FirebaseFirestore? firestore,
    required StorageService storageService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storageService = storageService;

  @override
  Future<List<SharedImage>> getImages(String communityId, {String? categoryId}) async {
    try {
      Query query = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('shared_images')
          .orderBy('createdAt', descending: true);

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => SharedImage.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    } catch (e) {
      print('Error getting shared images: $e');
      return [];
    }
  }

  @override
  Future<List<SharedFolderCategory>> getCategories(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('shared_folder_categories')
          .orderBy('order')
          .get();
      return snapshot.docs.map((doc) => SharedFolderCategory.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    } catch (e) {
      print('Error getting shared folder categories: $e');
      return [];
    }
  }

  @override
  Future<void> uploadImage({
    required String communityId,
    required String authorId,
    required File imageFile,
    String? title,
    String? categoryId,
  }) async {
    try {
      final imageUrl = await _storageService.uploadPostImage(
        imageFile,
        folder: 'communities/$communityId/shared_folder',
      );

      final imageId = DateTime.now().millisecondsSinceEpoch.toString();

      final sharedImage = SharedImage(
        id: imageId,
        communityId: communityId,
        authorId: authorId,
        imageUrl: imageUrl,
        title: title,
        categoryId: categoryId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('shared_images')
          .doc(imageId)
          .set(sharedImage.toMap());
    } catch (e) {
      print('Error uploading shared image: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteImage({required String communityId, required String imageId, required String imageUrl}) async {
    try {
      // 1. Delete from Storage
      await _storageService.deleteFileByUrl(imageUrl);

      // 2. Delete from Firestore
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('shared_images')
          .doc(imageId)
          .delete();
    } catch (e) {
      print('Error deleting shared image: $e');
      rethrow;
    }
  }

  @override
  Future<void> createCategory(SharedFolderCategory category) async {
    try {
      await _firestore
          .collection('communities')
          .doc(category.communityId)
          .collection('shared_folder_categories')
          .doc(category.id)
          .set(category.toMap());
    } catch (e) {
      print('Error creating shared folder category: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
     // Lógica similar a deleteImage
  }
}
