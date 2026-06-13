import 'dart:io';
import 'package:wumble/features/community/domain/shared_image_model.dart';

abstract class SharedFolderRepository {
  Future<List<SharedImage>> getImages(String communityId, {String? categoryId});
  Future<List<SharedFolderCategory>> getCategories(String communityId);
  Future<void> uploadImage({
    required String communityId,
    required String authorId,
    required File imageFile,
    String? title,
    String? categoryId,
  });
  Future<void> deleteImage({required String communityId, required String imageId, required String imageUrl});
  Future<void> createCategory(SharedFolderCategory category);
  Future<void> deleteCategory(String categoryId);
}
