import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/core/services/storage_service.dart';
import 'package:wumble/core/utils/link_preview_helper.dart';
import 'package:wumble/core/domain/link_preview_data.dart';
import 'package:wumble/features/feed/domain/feed_repository.dart';
import 'package:wumble/features/feed/domain/post_model.dart';
import 'package:wumble/features/feed/domain/post_comment_model.dart';
import 'package:wumble/features/feed/domain/draft_model.dart';
import 'package:wumble/features/feed/domain/quiz_model.dart';
import 'package:wumble/features/feed/domain/poll_model.dart';
import 'package:wumble/features/feed/domain/category_model.dart';

class RealFeedRepositoryImpl implements FeedRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService;

  /// In-memory cursor cache: postId → DocumentSnapshot, used for pagination.
  final Map<String, DocumentSnapshot> _cursorCache = {};

  RealFeedRepositoryImpl({required StorageService storageService}) 
      : _storageService = storageService;

  @override
  Future<List<Post>> getGlobalFeed() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      
      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting global feed: $e');
      return [];
    }
  }

  @override
  Future<List<Post>> getCommunityIds(String communityId) async {
      return getCommunityPosts(communityId);
  }

  @override
  Future<List<Post>> getCommunityPosts(String communityId) async {
    try {
      const int defaultLimit = 30;
      final snapshot = await _firestore
          .collection('posts')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .limit(defaultLimit)
          .get();

      // Cache docs for use as pagination cursors
      for (final doc in snapshot.docs) {
        _cursorCache[doc.id] = doc;
      }

      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting community posts: $e');
       rethrow; 
    }
  }

  @override
  Future<FeedPage> getCommunityPostsPaginated(
    String communityId, {
    String? lastPostId,
    int limit = 20,
    String? categoryId,
    bool? isFeatured,
  }) async {
    try {
      Query query = _firestore
          .collection('posts')
          .where('communityId', isEqualTo: communityId);

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      if (isFeatured != null) {
        query = query.where('isFeatured', isEqualTo: isFeatured);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit + 1);

      if (lastPostId != null) {
        // Try cached cursor first; if not cached, fetch the document
        DocumentSnapshot? cursor = _cursorCache[lastPostId];
        if (cursor == null) {
          cursor = await _firestore.collection('posts').doc(lastPostId).get();
          if (cursor.exists) _cursorCache[lastPostId] = cursor;
        }
        if (cursor != null && cursor.exists) {
          query = query.startAfterDocument(cursor);
        }
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;
      final hasMore = docs.length > limit;
      final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

      for (final doc in pageDocs) {
        _cursorCache[doc.id] = doc;
      }

      return FeedPage(
        posts: pageDocs.map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList(),
        nextCursor: pageDocs.isNotEmpty ? pageDocs.last.id : null,
        hasMore: hasMore,
      );
    } catch (e) {
      print('Error getting paginated community posts: $e');
      rethrow;
    }
  }

  @override
  Future<FeedPage> getCommunityPostsPopularPaginated(
    String communityId, {
    String? lastPostId,
    int limit = 20,
    String? categoryId,
    bool? isFeatured,
  }) async {
    try {
      Query query = _firestore
          .collection('posts')
          .where('communityId', isEqualTo: communityId);

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      if (isFeatured != null) {
        query = query.where('isFeatured', isEqualTo: isFeatured);
      }

      query = query
          .orderBy('likesCount', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit + 1);

      if (lastPostId != null) {
        DocumentSnapshot? cursor = _cursorCache[lastPostId];
        if (cursor == null) {
          cursor = await _firestore.collection('posts').doc(lastPostId).get();
          if (cursor.exists) _cursorCache[lastPostId] = cursor;
        }
        if (cursor != null && cursor.exists) {
          query = query.startAfterDocument(cursor);
        }
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;
      final hasMore = docs.length > limit;
      final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

      for (final doc in pageDocs) {
        _cursorCache[doc.id] = doc;
      }

      return FeedPage(
        posts: pageDocs.map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList(),
        nextCursor: pageDocs.isNotEmpty ? pageDocs.last.id : null,
        hasMore: hasMore,
      );
    } catch (e) {
      print('Error getting popular paginated posts: $e');
      // Fallback to recent paginated
      return getCommunityPostsPaginated(
        communityId, 
        lastPostId: lastPostId, 
        limit: limit, 
        categoryId: categoryId, 
        isFeatured: isFeatured,
      );
    }
  }

  @override
  Future<List<Post>> getCommunityPostsPopular(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('communityId', isEqualTo: communityId)
          .orderBy('likesCount', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting popular posts: $e');
      // Fallback: return recent posts if index not built yet
      return getCommunityPosts(communityId);
    }
  }

  @override
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
    try {
      List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        for (var image in images) {
           final url = await _storageService.uploadPostImage(image);
           imageUrls.add(url);
        }
      }
      
      String? backgroundImageUrlResult = backgroundImageUrl;
      if (backgroundImage != null) {
          backgroundImageUrlResult = await _storageService.uploadPostImage(backgroundImage, folder: 'posts/backgrounds');
      }

      final List<Map<String, dynamic>> processedBlocks = [];
      if (blocks != null) {
        for (var block in blocks) {
          if (block['type'] == 'image' && block['file'] is File) {
             final url = await _storageService.uploadPostImage(block['file'] as File);
             processedBlocks.add({'type': 'image', 'value': url});
          } else {
             // For text blocks or already uploaded images, keep as is
             processedBlocks.add(block);
          }
        }
      }

      // --- AISLAMIENTO DE IDENTIDAD (CORRECCIÓN CRÍTICA) ---
      // Si el post es en una comunidad, intentamos obtener el perfil del miembro en esa comunidad.
      // Si no existe o es global, usamos el perfil global.
      String authorName = 'Usuario';
      String authorAvatarUrl = '';

      if (communityId.isNotEmpty) {
        final memberDoc = await _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(userId)
            .get();
        
        if (memberDoc.exists) {
          final memberData = memberDoc.data()!;
          authorName = memberData['displayName'] ?? memberData['username'] ?? 'Usuario';
          authorAvatarUrl = memberData['avatarUrl'] ?? '';
        }
      }

      // Fallback al perfil global si no tenemos datos de comunidad o si no se encontraron
      if (authorAvatarUrl.isEmpty || authorName == 'Usuario') {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        if (authorName == 'Usuario') {
          authorName = userData['displayName'] ?? userData['username'] ?? 'Usuario';
        }
        if (authorAvatarUrl.isEmpty) {
          authorAvatarUrl = userData['avatarUrl'] ?? '';
        }
      }

      final newPost = {
        'communityId': communityId,
        'authorId': userId,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'content': content,
        'images': imageUrls,
        if (title != null) 'title': title,
        if (backgroundImageUrlResult != null) 'backgroundImageUrl': backgroundImageUrlResult,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        'blocks': processedBlocks,
        'likesCount': 0,
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'type': stickerUrl != null 
            ? 'image' 
            : (imageUrls.isNotEmpty || processedBlocks.any((b) => b['type'] == 'image') ? 'image' : 'blog'),
        if (categoryId != null) 'categoryId': categoryId,
        'tags': tags ?? [], // NEW
        'stickerUrl': stickerUrl,
        'isFeatured': false,
        'pollOptions': pollOptions ?? [],
        'pollVotes': pollOptions != null ? { for (var item in pollOptions) item : 0 } : {},
        'pollTotalVotes': 0,
        if (pollOptions != null && pollDurationDays != null)
          'pollEndsAt': Timestamp.fromDate(DateTime.now().add(Duration(days: pollDurationDays))),
      };

      await _firestore.collection('posts').add(newPost);
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  @override
  Future<List<PostDraft>> getUserDrafts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('drafts')
          .orderBy('updatedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => PostDraft.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting user drafts: $e');
      return [];
    }
  }

  @override
  Future<void> saveDraft(String userId, PostDraft draft) async {
    try {
      final List<Map<String, dynamic>> processedBlocks = [];
      for (var block in draft.blocks) {
        if (block['type'] == 'image' && block['file'] is File) {
          final url = await _storageService.uploadPostImage(block['file'] as File, folder: 'drafts/images');
          processedBlocks.add({'type': 'image', 'value': url});
        } else {
          processedBlocks.add(block);
        }
      }

      String? backgroundUrl = draft.backgroundImageUrl;
      if (draft.backgroundImageFile != null) {
        backgroundUrl = await _storageService.uploadPostImage(draft.backgroundImageFile!, folder: 'drafts/backgrounds');
      }

      final data = draft.toMap();
      data['blocks'] = processedBlocks;
      data['backgroundImageUrl'] = backgroundUrl;
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (draft.id.isEmpty) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('drafts')
            .add(data);
      } else {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('drafts')
            .doc(draft.id)
            .set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error saving draft: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDraft(String userId, String draftId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('drafts')
          .doc(draftId)
          .delete();
    } catch (e) {
      print('Error deleting draft: $e');
      rethrow;
    }
  }

  @override
  Future<List<Post>> getUserPosts(String userId, {String? communityId}) async {
    try {
      Query query = _firestore.collection('posts').where('authorId', isEqualTo: userId);
      
      if (communityId != null) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final snapshot = await query.orderBy('createdAt', descending: true).get();
      
      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting user posts: $e');
      rethrow;
    }
  }

  @override
  Future<Post?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return Post.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting post: $e');
      return null;
    }
  }

  @override
  Future<void> likePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;
        
        final likeDoc = await transaction.get(likeRef);
        if (likeDoc.exists) return; // Already liked

        // Fetch user data for notification BEFORE any writes
        final authorId = postDoc.data()!['authorId'];
        final String? postCommunityId = postDoc.data()!['communityId'];
        Map<String, dynamic>? userData;
        Map<String, dynamic>? communityData;
        
        if (authorId != userId) {
           final userDoc = await transaction.get(_firestore.collection('users').doc(userId));
           userData = userDoc.data();
           
           if (postCommunityId != null) {
              final commDoc = await transaction.get(_firestore.collection('communities').doc(postCommunityId));
              communityData = commDoc.data();
           }
        }

        // Add like
        transaction.set(likeRef, {'userId': userId, 'createdAt': FieldValue.serverTimestamp()});
        
        // Update likes count
        final newCount = (postDoc.data()!['likesCount'] as int? ?? 0) + 1;
        transaction.update(postRef, {'likesCount': newCount});

        // Add notification
        if (authorId != userId) {
           final senderName = userData?['displayName'] ?? userData?['username'] ?? 'Usuario';
           final senderAvatar = userData?['avatarUrl'] ?? '';
           final commName = communityData != null ? communityData['name'] : null;
           final commAvatar = communityData != null ? communityData['imageUrl'] : null;

           final notifRef = _firestore.collection('users').doc(authorId).collection('notifications').doc();
           transaction.set(notifRef, {
             'title': commName != null ? 'Comunidad $commName' : 'Nuevo me gusta',
             'body': '$senderName le dio corazón a tu post.',
             'type': 'post_like',
             'senderId': userId,
             'senderName': senderName,
             'senderAvatarUrl': senderAvatar,
             'postId': postId,
             if (postCommunityId != null) 'communityId': postCommunityId,
             if (commName != null) 'communityName': commName,
             if (commAvatar != null) 'communityAvatarUrl': commAvatar,
             'createdAt': FieldValue.serverTimestamp(),
             'isRead': false,
           });
        }
      });
    } catch (e) {
      print('Error liking post: $e');
      rethrow;
    }
  }

  @override
  Future<void> unlikePost(String postId, String userId) async {
     try {
      final postRef = _firestore.collection('posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;
        
        final likeDoc = await transaction.get(likeRef);
        if (!likeDoc.exists) return; // Not liked

        // Remove like
        transaction.delete(likeRef);
        
        // Update likes count
        var newCount = (postDoc.data()!['likesCount'] as int? ?? 0) - 1;
        if (newCount < 0) newCount = 0;
        transaction.update(postRef, {'likesCount': newCount});
      });
    } catch (e) {
      print('Error unliking post: $e');
      rethrow;
    }
  }

  // --- Quizzes ---

  @override
  Future<void> createQuiz(Quiz quiz) async {
    try {
      await _firestore.collection('quizzes').doc(quiz.id).set(quiz.toMap());
    } catch (e) {
      print('Error creating quiz: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteQuiz(String quizId) async {
    try {
      final quizDoc = await _firestore.collection('quizzes').doc(quizId).get();
      if (!quizDoc.exists) return;
      
      final quizData = quizDoc.data()!;
      if (quizData['imageUrl'] != null && quizData['imageUrl'].toString().isNotEmpty) {
        await _storageService.deleteFileByUrl(quizData['imageUrl']);
      }

      // Delete the quiz
      await _firestore.collection('quizzes').doc(quizId).delete();
      
      // Note: In a production app, we'd also delete quiz_attempts, 
      // but for now we'll keep it simple or use a cloud function.
    } catch (e) {
      print('Error deleting quiz: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateQuiz(Quiz quiz) async {
    try {
      await _firestore.collection('quizzes').doc(quiz.id).update(quiz.toMap());
    } catch (e) {
      print('Error updating quiz: $e');
      rethrow;
    }
  }

  @override
  Future<List<Quiz>> getCommunityQuizzes(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('quizzes')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Quiz.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error getting quizzes: $e');
      return [];
    }
  }

  @override
  Future<void> submitQuizAttempt(QuizAttempt attempt) async {
    try {
      await _firestore.collection('quiz_attempts').add(attempt.toMap());
      // Increment play count
      await _firestore.collection('quizzes').doc(attempt.quizId).update({
        'playCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error submitting quiz attempt: $e');
      rethrow;
    }
  }

  @override
  Future<List<QuizAttempt>> getQuizLeaderboard(String quizId) async {
    try {
      final snapshot = await _firestore
          .collection('quiz_attempts')
          .where('quizId', isEqualTo: quizId)
          .orderBy('score', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => QuizAttempt.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error getting quiz leaderboard: $e');
      return [];
    }
  }

  // --- Polls ---

  @override
  Future<void> createPoll(Poll poll) async {
    try {
      await _firestore.collection('polls').doc(poll.id).set(poll.toMap());
    } catch (e) {
      print('Error creating poll: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePoll(String pollId) async {
    try {
      // Polls don't have images in this model, so just delete the doc
      await _firestore.collection('polls').doc(pollId).delete();
      // Votes are in a subcollection, usually need to delete them as well if we want clean data
    } catch (e) {
      print('Error deleting poll: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePoll(Poll poll) async {
    try {
      await _firestore.collection('polls').doc(poll.id).update(poll.toMap());
    } catch (size) {
      print('Error updating poll: $size');
      rethrow;
    }
  }

  @override
  Future<List<Poll>> getCommunityPolls(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('polls')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Poll.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error getting polls: $e');
      return [];
    }
  }

  @override
  Future<void> voteInPoll(String pollId, String optionId, String userId) async {
    try {
      final pollRef = _firestore.collection('polls').doc(pollId);
      final voteRef = pollRef.collection('votes').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final pollDoc = await transaction.get(pollRef);
        final voteDoc = await transaction.get(voteRef);

        if (!pollDoc.exists) return;
        if (voteDoc.exists) return; // Already voted

        final pollData = pollDoc.data()!;
        final options = List<Map<String, dynamic>>.from(pollData['options']);
        final optionIndex = options.indexWhere((o) => o['id'] == optionId);

        if (optionIndex == -1) return;

        options[optionIndex]['voteCount'] = (options[optionIndex]['voteCount'] ?? 0) + 1;

        transaction.update(pollRef, {
          'options': options,
          'totalVotes': FieldValue.increment(1),
        });

        transaction.set(voteRef, {
          'userId': userId,
          'pollId': pollId,
          'optionId': optionId,
          'votedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('Error voting in poll: $e');
      rethrow;
    }
  }

  @override
  Future<PollVote?> getUserPollVote(String pollId, String userId) async {
    try {
      final doc = await _firestore.collection('polls').doc(pollId).collection('votes').doc(userId).get();
      if (doc.exists) {
        return PollVote.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user poll vote: $e');
      return null;
    }
  }

  @override
  Future<bool> checkIfLiked(String postId, String userId) async {
    try {
      final likeDoc = await _firestore.collection('posts').doc(postId).collection('likes').doc(userId).get();
      return likeDoc.exists;
    } catch (e) {
      print('Error checking like: $e');
      return false;
    }
  }

  @override
  Future<void> addComment(String postId, PostComment comment) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final commentRef = postRef.collection('comments').doc();
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        // Fetch community data for notification BEFORE writes
        final authorId = postDoc.data()!['authorId'];
        final String? postCommunityId = postDoc.data()!['communityId'];
        Map<String, dynamic>? communityData;
        
        if (authorId != comment.authorId && postCommunityId != null) {
            final commDoc = await transaction.get(_firestore.collection('communities').doc(postCommunityId));
            communityData = commDoc.data();
        }

        // --- LINK PREVIEW DETECTION ---
        LinkPreviewData? linkPreview;
        if (comment.content.isNotEmpty) {
          final firstUrl = LinkPreviewHelper.extractFirstUrl(comment.content);
          if (firstUrl != null) {
            linkPreview = await LinkPreviewHelper.fetchMetadata(firstUrl);
          }
        }

        final commentMap = comment.toMap();
        if (linkPreview != null) {
          commentMap['linkPreview'] = linkPreview.toMap();
        }

        transaction.set(commentRef, commentMap);
        
        // Update comments count
        final newCount = (postDoc.data()!['commentsCount'] as int? ?? 0) + 1;
        transaction.update(postRef, {'commentsCount': newCount});

        // Add notification
        if (authorId != comment.authorId) {
           final commName = communityData != null ? communityData['name'] : null;
           final commAvatar = communityData != null ? communityData['imageUrl'] : null;

           final notifRef = _firestore.collection('users').doc(authorId).collection('notifications').doc();
           transaction.set(notifRef, {
             'title': commName != null ? 'Comunidad $commName' : 'Nuevo comentario',
             'body': '${comment.authorName} comentó en tu post: "${comment.content}"',
             'type': 'post_comment',
             'senderId': comment.authorId,
             'senderName': comment.authorName,
             'senderAvatarUrl': comment.authorAvatarUrl,
             'postId': postId,
             'commentId': commentRef.id,
             if (postCommunityId != null) 'communityId': postCommunityId,
             if (commName != null) 'communityName': commName,
             if (commAvatar != null) 'communityAvatarUrl': commAvatar,
             'createdAt': FieldValue.serverTimestamp(),
             'isRead': false,
           });
        }
      });
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  @override
  Future<void> addReply(String postId, String commentId, PostComment reply) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final commentRef = postRef.collection('comments').doc(commentId);
      
      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) return;

        // Fetch community data for notification BEFORE writes
        final commentAuthorId = commentDoc.data()!['authorId'];
        
        Map<String, dynamic>? communityData;
        String? postCommunityId;
        if (commentAuthorId != reply.authorId) {
            final postDoc = await transaction.get(postRef);
            postCommunityId = postDoc.exists ? postDoc.data()!['communityId'] : null;
            if (postCommunityId != null) {
                final commDoc = await transaction.get(_firestore.collection('communities').doc(postCommunityId));
                communityData = commDoc.data();
            }
        }

        // --- LINK PREVIEW DETECTION ---
        LinkPreviewData? linkPreview;
        if (reply.content.isNotEmpty) {
          final firstUrl = LinkPreviewHelper.extractFirstUrl(reply.content);
          if (firstUrl != null) {
            linkPreview = await LinkPreviewHelper.fetchMetadata(firstUrl);
          }
        }

        final replyMap = reply.toMap();
        if (linkPreview != null) {
          replyMap['linkPreview'] = linkPreview.toMap();
        }

        transaction.update(commentRef, {
          'replies': FieldValue.arrayUnion([replyMap])
        });

        // Add notification
        if (commentAuthorId != reply.authorId) {
           final commName = communityData != null ? communityData['name'] : null;
           final commAvatar = communityData != null ? communityData['imageUrl'] : null;

           final notifRef = _firestore.collection('users').doc(commentAuthorId).collection('notifications').doc();
           transaction.set(notifRef, {
             'title': commName != null ? 'Comunidad $commName' : 'Nueva respuesta',
             'body': '${reply.authorName} respondió a tu comentario.',
             'type': 'comment_reply',
             'senderId': reply.authorId,
             'senderName': reply.authorName,
             'senderAvatarUrl': reply.authorAvatarUrl,
             'postId': postId,
             'commentId': commentId,
             if (postCommunityId != null) 'communityId': postCommunityId,
             if (commName != null) 'communityName': commName,
             if (commAvatar != null) 'communityAvatarUrl': commAvatar,
             'createdAt': FieldValue.serverTimestamp(),
             'isRead': false,
           });
        }
      });
    } catch (e) {
      print('Error adding reply: $e');
      rethrow;
    }
  }

  @override
  Future<List<PostComment>> getComments(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => PostComment.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final commentRef = postRef.collection('comments').doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        final commentDoc = await transaction.get(commentRef);

        if (commentDoc.exists) {
          transaction.delete(commentRef);
          if (postDoc.exists) {
            final currentCount = postDoc.data()?['commentsCount'] as int? ?? 0;
            transaction.update(postRef, {'commentsCount': currentCount > 0 ? currentCount - 1 : 0});
          }
        }
      });
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  @override
  Future<void> editComment(String postId, String commentId, String content) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(commentId);
        final commentSnapshot = await transaction.get(commentRef);
        if (!commentSnapshot.exists) return;

        final commentData = commentSnapshot.data()!;
        final currentLinkPreview = commentData['linkPreview'] != null 
            ? LinkPreviewData.fromMap(commentData['linkPreview']) 
            : null;

        // --- LINK PREVIEW DETECTION IN EDIT ---
        LinkPreviewData? linkPreview;
        final firstUrl = LinkPreviewHelper.extractFirstUrl(content);
        if (firstUrl != null) {
          if (currentLinkPreview?.url != firstUrl) {
            linkPreview = await LinkPreviewHelper.fetchMetadata(firstUrl);
          } else {
            linkPreview = currentLinkPreview;
          }
        }

        transaction.update(commentRef, {
          'content': content,
          'linkPreview': linkPreview?.toMap() ?? FieldValue.delete(),
        });
      });
    } catch (e) {
      print('Error editing comment: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteReply(String postId, String commentId, String replyId) async {
    // In our current system, replies are objects in an array. 
    // Usually, we'd store them with unique IDs to delete easily.
    // If replyId is passed, we'll filter the array.
    try {
      final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(commentId);
      
      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) return;

        final List<dynamic> replies = List.from(commentDoc.data()?['replies'] ?? []);
        // Assuming 'id' field was added/exists or we match by some other property.
        // Let's assume we find it by ID if it has one.
        replies.removeWhere((r) => r['id'] == replyId);

        transaction.update(commentRef, {'replies': replies});
      });
    } catch (e) {
      print('Error deleting reply: $e');
      rethrow;
    }
  }

  @override
  Future<void> editReply(String postId, String commentId, String replyId, String content) async {
    try {
      final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(commentId);
      
      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) return;

        final List<dynamic> replies = List.from(commentDoc.data()?['replies'] ?? []);
        final replyIdx = replies.indexWhere((r) => r['id'] == replyId);

        if (replyIdx != -1) {
          final replyMap = Map<String, dynamic>.from(replies[replyIdx]);
          final currentLinkPreview = replyMap['linkPreview'] != null 
              ? LinkPreviewData.fromMap(replyMap['linkPreview']) 
              : null;

          // --- LINK PREVIEW DETECTION IN EDIT ---
          LinkPreviewData? linkPreview;
          final firstUrl = LinkPreviewHelper.extractFirstUrl(content);
          if (firstUrl != null) {
            if (currentLinkPreview?.url != firstUrl) {
              linkPreview = await LinkPreviewHelper.fetchMetadata(firstUrl);
            } else {
              linkPreview = currentLinkPreview;
            }
          }

          replyMap['content'] = content;
          if (linkPreview != null) {
            replyMap['linkPreview'] = linkPreview.toMap();
          } else {
            replyMap.remove('linkPreview');
          }

          replies[replyIdx] = replyMap;
          transaction.update(commentRef, {'replies': replies});
        }
      });
    } catch (e) {
      print('Error editing reply: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      // 1. Get the post data to find storage URLs
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;
      final postData = postDoc.data()!;

      // 2. Identify all storage URLs to delete
      final List<String> urlsToDelete = [];
      
      // Images list
      if (postData['images'] is List) {
        urlsToDelete.addAll(List<String>.from(postData['images']));
      }
      
      // Background
      if (postData['backgroundImageUrl'] != null) {
        urlsToDelete.add(postData['backgroundImageUrl'] as String);
      }
      
      // Blocks images
      if (postData['blocks'] is List) {
        final blocks = postData['blocks'] as List;
        for (var block in blocks) {
          if (block is Map && block['type'] == 'image' && block['value'] is String) {
            urlsToDelete.add(block['value'] as String);
          }
        }
      }

      // 3. Delete files from Storage
      for (var url in urlsToDelete) {
        try {
          await _storageService.deleteFileByUrl(url);
        } catch (e) {
          print('Error deleting file from storage: $url - $e');
          // Continue even if one file fails
        }
      }

      // 4. Delete subcollections (Comments and Likes)
      // Note: Small subcollections can be deleted this way. For massive ones, a cloud function is better.
      final comments = await _firestore.collection('posts').doc(postId).collection('comments').get();
      for (var doc in comments.docs) {
        await doc.reference.delete();
      }

      final likes = await _firestore.collection('posts').doc(postId).collection('likes').get();
      for (var doc in likes.docs) {
        await doc.reference.delete();
      }

      // 5. Delete the main doc
      await _firestore.collection('posts').doc(postId).delete();
      
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePost(Post post) async {
    try {
      await _firestore.collection('posts').doc(post.id).update(post.toMap());
    } catch (e) {
      print('Error updating post: $e');
      rethrow;
    }
  }

  @override
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
  }) async {
    try {
      // 1. Upload new images if any
      List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        for (var image in images) {
           final url = await _storageService.uploadPostImage(image);
           imageUrls.add(url);
        }
      }
      
      // 2. Upload new background if any, or use provided URL
      String? backgroundImageUrlResult = backgroundImageUrl; // Initialize with existing URL if provided
      if (backgroundImage != null) {
          backgroundImageUrlResult = await _storageService.uploadPostImage(backgroundImage, folder: 'posts/backgrounds');
      }

      // 3. Process blocks (upload new images, keep existing URLs)
      final List<Map<String, dynamic>> processedBlocks = [];
      if (blocks != null) {
        for (var block in blocks) {
          if (block['type'] == 'image') {
            if (block['file'] is File) {
               final url = await _storageService.uploadPostImage(block['file'] as File);
               processedBlocks.add({'type': 'image', 'value': url});
            } else if (block['value'] != null) {
               // Keep existing URL
               processedBlocks.add({'type': 'image', 'value': block['value']});
            }
          } else {
             processedBlocks.add(block);
          }
        }
      }

      final updateData = {
        'content': content,
        if (imageUrls.isNotEmpty) 'images': imageUrls, // Note: This might overwrite existing images if not handled carefully. 
        // In the current block-based system, images are mostly in blocks.
        if (title != null) 'title': title,
        if (backgroundImageUrlResult != null) 'backgroundImageUrl': backgroundImageUrlResult,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        'blocks': processedBlocks,
        if (categoryId != null) 'categoryId': categoryId,
        'tags': tags ?? [], // NEW
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('posts').doc(postId).update(updateData);
    } catch (e) {
      print('Error editing post: $e');
      rethrow;
    }
  }

  @override
  Future<List<Post>> searchPosts(String query, {List<String>? communityIds}) async {
    try {
      Query<Map<String, dynamic>> queryRef = _firestore.collection('posts');

      // Si se proporcionan IDs de comunidad, filtramos por ellos
      if (communityIds != null && communityIds.isNotEmpty) {
        // Firestore limit for 'whereIn' is 30.
        final limitedIds = communityIds.take(30).toList();
        queryRef = queryRef.where('communityId', whereIn: limitedIds);
      }

      final snapshot = await queryRef
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }

  @override
  Future<void> savePost(String postId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_posts')
          .doc(postId)
          .set({
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving post: $e');
      rethrow;
    }
  }

  @override
  Future<void> unsavePost(String postId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_posts')
          .doc(postId)
          .delete();
    } catch (e) {
      print('Error unsaving post: $e');
      rethrow;
    }
  }

  @override
  Future<bool> checkIfSaved(String postId, String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_posts')
          .doc(postId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking if saved: $e');
      return false;
    }
  }

  @override
  Future<List<Post>> getSavedPosts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_posts')
          .orderBy('savedAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final postIds = snapshot.docs.map((doc) => doc.id).toList();
      
      // Fetch posts in chunks of 10 (Firestore limit for whereIn is 30, but 10 is safer for performance)
      List<Post> savedPosts = [];
      for (var i = 0; i < postIds.length; i += 10) {
        final chunk = postIds.sublist(i, i + 10 > postIds.length ? postIds.length : i + 10);
        final postsSnapshot = await _firestore
            .collection('posts')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        
        savedPosts.addAll(postsSnapshot.docs.map((doc) => Post.fromMap(doc.data(), doc.id)));
      }

      // Sort by savedAt order (the whereIn query doesn't preserve order)
      savedPosts.sort((a, b) {
        final aIdx = postIds.indexOf(a.id);
        final bIdx = postIds.indexOf(b.id);
        return aIdx.compareTo(bIdx);
      });

      return savedPosts;
    } catch (e) {
      print('Error getting saved posts: $e');
      return [];
    }
  }

  @override
  Future<void> reportPost(String postId, String userId, String reason) async {
    try {
      await _firestore.collection('reports').add({
        'type': 'post',
        'targetId': postId,
        'reporterId': userId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Error reporting post: $e');
      rethrow;
    }
  }
  @override
  Future<List<PostCategory>> getCategories(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('categories')
          .orderBy('order')
          .get();
      return snapshot.docs.map((doc) => PostCategory.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  @override
  Future<void> createCategory(String communityId, PostCategory category) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('categories')
          .doc(category.id)
          .set(category.toMap());
    } catch (e) {
      print('Error creating category: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateCategory(String communityId, PostCategory category) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('categories')
          .doc(category.id)
          .update(category.toMap());
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(String communityId, String categoryId) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('categories')
          .doc(categoryId)
          .delete();
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  @override
  Future<void> setPostFeatured(String postId, bool isFeatured) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isFeatured': isFeatured,
        'featuredAt': isFeatured ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      print('Error setting post featured: $e');
      rethrow;
    }
  }

  @override
  Future<void> setPostPinned(String postId, bool isPinned) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isPinned': isPinned,
        'pinnedAt': isPinned ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      print('Error setting post pinned: $e');
      rethrow;
    }
  }

  @override
  Future<void> reactToComment(String postId, String commentId, String userId, String reaction) async {
    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(commentRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final reactionsMap = Map<String, dynamic>.from(data['reactions'] ?? {});
      
      String? previousReaction;
      reactionsMap.forEach((key, value) {
        if ((value as List).contains(userId)) {
          previousReaction = key;
        }
      });

      final prevReaction = previousReaction;
      if (prevReaction != null) {
        List<String> userIds = List<String>.from(reactionsMap[prevReaction]!);
        userIds.remove(userId);
        if (userIds.isEmpty) {
          reactionsMap.remove(prevReaction);
        } else {
          reactionsMap[prevReaction] = userIds;
        }
      }

      if (previousReaction != reaction) {
        List<String> userIds = List<String>.from(reactionsMap[reaction] ?? []);
        userIds.add(userId);
        reactionsMap[reaction] = userIds;

        // --- ADD NOTIFICATION ---
        final authorId = data['authorId'] as String;
        if (authorId != userId) {
          final notifRef = _firestore.collection('users').doc(authorId).collection('notifications').doc();
          transaction.set(notifRef, {
            'type': 'post_comment', // Re-use post_comment or similar type that leads to the post
            'title': 'Nueva reacción',
            'body': 'A alguien le gustó tu comentario con $reaction',
            'senderId': userId,
            'postId': postId,
            'commentId': commentId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      transaction.update(commentRef, {'reactions': reactionsMap});
    });
  }

  @override
  Future<void> voteInPost(String postId, String optionId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final voteRef = postRef.collection('votes').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        final voteDoc = await transaction.get(voteRef);

        if (!postDoc.exists) return;
        if (voteDoc.exists) return; // Already voted

        final postData = postDoc.data()!;
        final Map<String, dynamic> pollVotes = Map<String, dynamic>.from(postData['pollVotes'] ?? {});
        
        if (!pollVotes.containsKey(optionId)) return;

        pollVotes[optionId] = (pollVotes[optionId] ?? 0) + 1;

        transaction.update(postRef, {
          'pollVotes': pollVotes,
          'pollTotalVotes': FieldValue.increment(1),
        });

        transaction.set(voteRef, {
          'userId': userId,
          'postId': postId,
          'optionId': optionId,
          'votedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('Error voting in post: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getUserPostVote(String postId, String userId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).collection('votes').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['optionId'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user post vote: $e');
      return null;
    }
  }
}
