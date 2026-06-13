import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/feed_repository.dart';
import '../../domain/post_model.dart';
import '../../domain/category_model.dart';

// ──────────────────────────────────────────────
// Events
// ──────────────────────────────────────────────
abstract class CommunityFeedEvent {}

class LoadCommunityFeed extends CommunityFeedEvent {
  final String communityId;
  final String sortMode; // 'recent' | 'popular'
  final String? categoryId;
  final bool? isFeatured;
  LoadCommunityFeed(
    this.communityId, {
    this.sortMode = 'recent',
    this.categoryId,
    this.isFeatured,
  });
}

class LoadMoreCommunityFeed extends CommunityFeedEvent {
  final String communityId;
  LoadMoreCommunityFeed(this.communityId);
}

class RefreshCommunityFeed extends CommunityFeedEvent {
  final String communityId;
  RefreshCommunityFeed(this.communityId);
}

class LoadCategories extends CommunityFeedEvent {
  final String communityId;
  LoadCategories(this.communityId);
}

class CommunityFeedPostDeleted extends CommunityFeedEvent {
  final String postId;
  CommunityFeedPostDeleted(this.postId);
}

// ──────────────────────────────────────────────
// Estados
// ──────────────────────────────────────────────
abstract class CommunityFeedState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CommunityFeedInitial extends CommunityFeedState {}

class CommunityFeedLoading extends CommunityFeedState {}

class CommunityFeedLoaded extends CommunityFeedState {
  final List<Post> posts;
  final String sortMode;
  final bool hasMore;
  final String? nextCursor;
  final List<PostCategory> categories;
  final String? selectedCategoryId;
  final bool? onlyFeatured;

  CommunityFeedLoaded(
    this.posts, {
    this.sortMode = 'recent',
    this.hasMore = false,
    this.nextCursor,
    this.categories = const [],
    this.selectedCategoryId,
    this.onlyFeatured,
  });

  @override
  List<Object?> get props => [
        posts,
        sortMode,
        hasMore,
        nextCursor,
        categories,
        selectedCategoryId,
        onlyFeatured,
      ];

  CommunityFeedLoaded copyWith({
    List<Post>? posts,
    String? sortMode,
    bool? hasMore,
    String? nextCursor,
    List<PostCategory>? categories,
    String? selectedCategoryId,
    bool? onlyFeatured,
  }) {
    return CommunityFeedLoaded(
      posts ?? this.posts,
      sortMode: sortMode ?? this.sortMode,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      onlyFeatured: onlyFeatured ?? this.onlyFeatured,
    );
  }
}

/// Emitted while appending the next page. Carries current posts so the UI
/// can keep showing them while loading the next batch.
class CommunityFeedLoadingMore extends CommunityFeedState {
  final List<Post> currentPosts;
  final String sortMode;
  CommunityFeedLoadingMore(this.currentPosts, {this.sortMode = 'recent'});
}

class CommunityFeedError extends CommunityFeedState {
  final String message;
  CommunityFeedError(this.message);
}

// ──────────────────────────────────────────────
// Bloc
// ──────────────────────────────────────────────
class CommunityFeedBloc extends Bloc<CommunityFeedEvent, CommunityFeedState> {
  final FeedRepository _feedRepository;

  CommunityFeedBloc({required FeedRepository repository})
      : _feedRepository = repository,
        super(CommunityFeedInitial()) {
    on<LoadCommunityFeed>(_onLoadCommunityFeed);
    on<LoadMoreCommunityFeed>(_onLoadMoreCommunityFeed);
    on<RefreshCommunityFeed>(_onRefreshCommunityFeed);
    on<LoadCategories>(_onLoadCategories);
    on<CommunityFeedPostDeleted>(_onPostDeleted);
  }

  Future<void> _onLoadCommunityFeed(
    LoadCommunityFeed event,
    Emitter<CommunityFeedState> emit,
  ) async {
    final List<PostCategory> currentCategories = (state is CommunityFeedLoaded) 
        ? (state as CommunityFeedLoaded).categories : [];
        
    emit(CommunityFeedLoading());
    try {
      final page = event.sortMode == 'popular'
          ? await _feedRepository.getCommunityPostsPopularPaginated(
              event.communityId,
              categoryId: event.categoryId,
              isFeatured: event.isFeatured,
            )
          : await _feedRepository.getCommunityPostsPaginated(
              event.communityId,
              categoryId: event.categoryId,
              isFeatured: event.isFeatured,
            );
            
      emit(CommunityFeedLoaded(
        page.posts,
        sortMode: event.sortMode,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        categories: currentCategories,
        selectedCategoryId: event.categoryId,
        onlyFeatured: event.isFeatured,
      ));

      // Auto-load categories if we don't have them
      if (currentCategories.isEmpty) {
        add(LoadCategories(event.communityId));
      }
    } catch (e) {
      emit(CommunityFeedError(e.toString()));
    }
  }

  Future<void> _onLoadMoreCommunityFeed(
    LoadMoreCommunityFeed event,
    Emitter<CommunityFeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CommunityFeedLoaded) return;
    if (!currentState.hasMore) return;

    emit(CommunityFeedLoadingMore(currentState.posts, sortMode: currentState.sortMode));
    try {
      final page = currentState.sortMode == 'popular'
          ? await _feedRepository.getCommunityPostsPopularPaginated(
              event.communityId,
              lastPostId: currentState.nextCursor,
              categoryId: currentState.selectedCategoryId,
              isFeatured: currentState.onlyFeatured,
            )
          : await _feedRepository.getCommunityPostsPaginated(
              event.communityId,
              lastPostId: currentState.nextCursor,
              categoryId: currentState.selectedCategoryId,
              isFeatured: currentState.onlyFeatured,
            );

      emit(currentState.copyWith(
        posts: [...currentState.posts, ...page.posts],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      ));
    } catch (e) {
      emit(currentState);
    }
  }

  Future<void> _onRefreshCommunityFeed(
    RefreshCommunityFeed event,
    Emitter<CommunityFeedState> emit,
  ) async {
    final String sortMode = (state is CommunityFeedLoaded) ? (state as CommunityFeedLoaded).sortMode : 'recent';
    final String? currentCategory = (state is CommunityFeedLoaded) ? (state as CommunityFeedLoaded).selectedCategoryId : null;
    final bool? currentFeatured = (state is CommunityFeedLoaded) ? (state as CommunityFeedLoaded).onlyFeatured : null;
    final List<PostCategory> currentCategories = (state is CommunityFeedLoaded) ? (state as CommunityFeedLoaded).categories : [];

    try {
      final page = sortMode == 'popular'
          ? await _feedRepository.getCommunityPostsPopularPaginated(
              event.communityId,
              categoryId: currentCategory,
              isFeatured: currentFeatured,
            )
          : await _feedRepository.getCommunityPostsPaginated(
              event.communityId,
              categoryId: currentCategory,
              isFeatured: currentFeatured,
            );

      emit(CommunityFeedLoaded(
        page.posts,
        sortMode: sortMode,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        categories: currentCategories,
        selectedCategoryId: currentCategory,
        onlyFeatured: currentFeatured,
      ));
    } catch (e) {
      emit(CommunityFeedError(e.toString()));
    }
  }

  Future<void> _onLoadCategories(LoadCategories event, Emitter<CommunityFeedState> emit) async {
    try {
      final categories = await _feedRepository.getCategories(event.communityId);
      if (state is CommunityFeedLoaded) {
        emit((state as CommunityFeedLoaded).copyWith(categories: categories));
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  void _onPostDeleted(CommunityFeedPostDeleted event, Emitter<CommunityFeedState> emit) {
    if (state is CommunityFeedLoaded) {
      final currentState = state as CommunityFeedLoaded;
      final updatedPosts = currentState.posts.where((p) => p.id != event.postId).toList();
      emit(currentState.copyWith(posts: updatedPosts));
    }
  }
}
