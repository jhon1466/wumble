import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/features/feed/domain/feed_repository.dart';
import 'package:wumble/features/feed/domain/draft_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';

// States
abstract class CreatePostState {}

class CreatePostInitial extends CreatePostState {}

class CreatePostLoading extends CreatePostState {}

class CreatePostSuccess extends CreatePostState {}

class CreatePostFailure extends CreatePostState {
  final String error;
  CreatePostFailure(this.error);
}

class DraftsLoading extends CreatePostState {}

class DraftsLoaded extends CreatePostState {
  final List<PostDraft> drafts;
  DraftsLoaded(this.drafts);
}

class DraftOperationSuccess extends CreatePostState {}

// Cubit
class CreatePostCubit extends Cubit<CreatePostState> {
  final FeedRepository _feedRepository;
  final CommunityRepository _communityRepository;

  CreatePostCubit({
    required FeedRepository repository,
    required CommunityRepository communityRepository,
  })  : _feedRepository = repository,
        _communityRepository = communityRepository,
        super(CreatePostInitial());

  Future<void> createPost({
    required String communityId,
    required String content,
    required String userId,
    List<File>? images,
    String? title,
    String? backgroundColor,
    File? backgroundImage,
    String? backgroundImageUrl,
    List<Map<String, dynamic>>? blocks,
    String? categoryId,
    List<String>? tags, // NEW
    String? stickerUrl,
    List<String>? pollOptions,
    int? pollDurationDays,
  }) async {
    emit(CreatePostLoading());
    try {
      await _feedRepository.createPost(
        communityId: communityId,
        content: content,
        userId: userId,
        images: images,
        title: title,
        backgroundColor: backgroundColor,
        backgroundImage: backgroundImage,
        backgroundImageUrl: backgroundImageUrl,
        blocks: blocks,
        categoryId: categoryId,
        tags: tags, // NEW
        stickerUrl: stickerUrl,
        pollOptions: pollOptions,
        pollDurationDays: pollDurationDays,
      );
      // Reward reputation: +20 for a new post
      await _communityRepository.addReputation(communityId, userId, 20);
      emit(CreatePostSuccess());
    } catch (e) {
      emit(CreatePostFailure(e.toString()));
    }
  }

  Future<void> deletePost(String postId) async {
    emit(CreatePostLoading());
    try {
      await _feedRepository.deletePost(postId);
      emit(CreatePostSuccess());
    } catch (e) {
      emit(CreatePostFailure(e.toString()));
    }
  }

  Future<void> editPost({
    required String postId,
    required String content,
    List<File>? images,
    String? title,
    String? backgroundColor,
    File? backgroundImage,
    String? backgroundImageUrl,
    List<Map<String, dynamic>>? blocks,
    String? categoryId,
    List<String>? tags, // NEW
    String? stickerUrl,
  }) async {
    emit(CreatePostLoading());
    try {
      await _feedRepository.editPost(
        postId: postId,
        content: content,
        images: images,
        title: title,
        backgroundColor: backgroundColor,
        backgroundImage: backgroundImage,
        backgroundImageUrl: backgroundImageUrl,
        blocks: blocks,
        categoryId: categoryId,
        tags: tags, // NEW
      );
      emit(CreatePostSuccess());
    } catch (e) {
      emit(CreatePostFailure(e.toString()));
    }
  }

  Future<void> saveDraft(String userId, PostDraft draft) async {
    emit(DraftsLoading());
    try {
      await _feedRepository.saveDraft(userId, draft);
      emit(DraftOperationSuccess());
    } catch (e) {
      emit(CreatePostFailure(e.toString()));
    }
  }

  Future<void> loadDrafts(String userId) async {
    emit(DraftsLoading());
    try {
      final drafts = await _feedRepository.getUserDrafts(userId);
      emit(DraftsLoaded(drafts));
    } catch (e) {
      emit(CreatePostFailure(e.toString()));
    }
  }

  Future<void> deleteDraft(String userId, String draftId) async {
    emit(DraftsLoading());
    try {
      await _feedRepository.deleteDraft(userId, draftId);
      final drafts = await _feedRepository.getUserDrafts(userId);
      emit(DraftsLoaded(drafts));
    } catch (e) {
      emit(CreatePostFailure(e.toString()));
    }
  }
}
