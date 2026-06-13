import 'dart:io';
import 'package:wumble/features/feed/domain/post_model.dart';
import 'package:wumble/features/feed/domain/draft_model.dart';
import 'package:wumble/features/feed/domain/post_comment_model.dart';
import 'package:wumble/features/feed/domain/quiz_model.dart';
import 'package:wumble/features/feed/domain/poll_model.dart';
import 'package:wumble/features/feed/domain/category_model.dart';

/// Result of a paginated feed request.
class FeedPage {
  final List<Post> posts;
  /// Opaque cursor to pass back for the next page.
  final String? nextCursor;
  final bool hasMore;

  const FeedPage({required this.posts, this.nextCursor, this.hasMore = false});
}

abstract class FeedRepository {
  Future<List<Post>> getGlobalFeed();
  Future<List<Post>> getCommunityIds(String communityId);
  Future<List<Post>> getCommunityPosts(String communityId);
  Future<List<Post>> getCommunityPostsPopular(String communityId);

  /// Paginated version — loads [limit] posts starting after [lastPostId].
  Future<FeedPage> getCommunityPostsPaginated(
    String communityId, {
    String? lastPostId,
    int limit = 20,
    String? categoryId,
    bool? isFeatured,
  });
  Future<FeedPage> getCommunityPostsPopularPaginated(
    String communityId, {
    String? lastPostId,
    int limit = 20,
    String? categoryId,
    bool? isFeatured,
  });

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
  });

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
  });

  // --- Drafts ---
  Future<List<PostDraft>> getUserDrafts(String userId);
  Future<void> saveDraft(String userId, PostDraft draft);
  Future<void> deleteDraft(String userId, String draftId);

  Future<List<Post>> getUserPosts(String userId, {String? communityId});

  // Interacciones con Posts
  Future<Post?> getPost(String postId);
  Future<void> likePost(String postId, String userId);
  Future<void> unlikePost(String postId, String userId);
  Future<bool> checkIfLiked(String postId, String userId);
  
  // Bookmarks (Guardados)
  Future<void> savePost(String postId, String userId);
  Future<void> unsavePost(String postId, String userId);
  Future<bool> checkIfSaved(String postId, String userId);
  Future<List<Post>> getSavedPosts(String userId);
  Future<void> reportPost(String postId, String userId, String reason);
  
  // Comentarios y Respuestas
  Future<void> addComment(String postId, PostComment comment);
  Future<void> addReply(String postId, String commentId, PostComment reply);
  Future<List<PostComment>> getComments(String postId);
  Future<void> deleteComment(String postId, String commentId);
  Future<void> editComment(String postId, String commentId, String content);
  Future<void> deleteReply(String postId, String commentId, String replyId);
  Future<void> editReply(String postId, String commentId, String replyId, String content);
  Future<void> reactToComment(String postId, String commentId, String userId, String reaction);

  // Gestión de Posts (Delete & Update)
  Future<void> deletePost(String postId);
  Future<void> updatePost(Post post);

  // --- Quizzes ---
  Future<void> createQuiz(Quiz quiz);
  Future<List<Quiz>> getCommunityQuizzes(String communityId);
  Future<void> deleteQuiz(String quizId);
  Future<void> updateQuiz(Quiz quiz);
  Future<void> submitQuizAttempt(QuizAttempt attempt);
  Future<List<QuizAttempt>> getQuizLeaderboard(String quizId);

  // --- Polls ---
  Future<void> createPoll(Poll poll);
  Future<List<Poll>> getCommunityPolls(String communityId);
  Future<void> deletePoll(String pollId);
  Future<void> updatePoll(Poll poll);
  Future<void> voteInPoll(String pollId, String optionId, String userId);
  Future<PollVote?> getUserPollVote(String pollId, String userId);
  Future<List<Post>> searchPosts(String query, {List<String>? communityIds});

  // --- Discovery & Categories ---
  Future<List<PostCategory>> getCategories(String communityId);
  Future<void> createCategory(String communityId, PostCategory category);
  Future<void> updateCategory(String communityId, PostCategory category);
  Future<void> deleteCategory(String communityId, String categoryId);
  
  Future<void> setPostFeatured(String postId, bool isFeatured);
  Future<void> setPostPinned(String postId, bool isPinned);

  // --- Integrated Polls in Posts ---
  Future<void> voteInPost(String postId, String optionId, String userId);
  Future<String?> getUserPostVote(String postId, String userId);
}

