import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/storage_service.dart';
import '../domain/wiki_model.dart';
import '../domain/wiki_comment_model.dart';
import '../domain/wiki_repository.dart';

class WikiRepositoryImpl implements WikiRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService;

  WikiRepositoryImpl({required StorageService storageService})
      : _storageService = storageService;

  @override
  Future<List<WikiPage>> getCommunityWikis(String communityId) async {
    try {
      final querySnapshot = await _firestore
          .collection('wikis')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return WikiPage.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Error getting wikis: $e');
    }
  }

  @override
  Future<void> createWiki(WikiPage wiki, {File? iconFile, File? coverFile}) async {
    try {
      String? iconUrl = wiki.iconUrl;
      String? coverUrl = wiki.coverUrl;

      // Upload images if provided
      if (iconFile != null) {
        iconUrl = await _storageService.uploadPostImage(
          iconFile,
          folder: 'wiki_icons/${wiki.communityId}',
        );
      }

      if (coverFile != null) {
        coverUrl = await _storageService.uploadPostImage(
          coverFile,
          folder: 'wiki_covers/${wiki.communityId}',
        );
      }

      // Process blocks for media
      final List<Map<String, dynamic>> processedBlocks = [];
      for (var block in wiki.blocks) {
        if (block['type'] == 'image' && block['file'] is File) {
          final url = await _storageService.uploadPostImage(
            block['file'] as File,
            folder: 'wiki_content/${wiki.communityId}',
          );
          processedBlocks.add({'type': 'image', 'value': url});
        } else {
          processedBlocks.add(block);
        }
      }

      final newWiki = wiki.copyWith(
        iconUrl: iconUrl,
        coverUrl: coverUrl,
        blocks: processedBlocks,
      );

      await _firestore.collection('wikis').doc(wiki.id).set(newWiki.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error creating wiki: $e');
    }
  }

  @override
  Future<void> updateWiki(WikiPage wiki, {File? iconFile, File? coverFile}) async {
    try {
      String? iconUrl = wiki.iconUrl;
      String? coverUrl = wiki.coverUrl;

      if (iconFile != null) {
        iconUrl = await _storageService.uploadPostImage(
          iconFile,
          folder: 'wiki_icons/${wiki.communityId}',
        );
      }

      if (coverFile != null) {
        coverUrl = await _storageService.uploadPostImage(
          coverFile,
          folder: 'wiki_covers/${wiki.communityId}',
        );
      }

      final List<Map<String, dynamic>> processedBlocks = [];
      for (var block in wiki.blocks) {
        if (block['type'] == 'image' && block['file'] is File) {
          final url = await _storageService.uploadPostImage(
            block['file'] as File,
            folder: 'wiki_content/${wiki.communityId}',
          );
          processedBlocks.add({'type': 'image', 'value': url});
        } else {
          processedBlocks.add(block);
        }
      }

      final updates = wiki.copyWith(
        iconUrl: iconUrl,
        coverUrl: coverUrl,
        blocks: processedBlocks,
      ).toMap();

      // Protect counters and metadata
      updates.remove('likesCount');
      updates.remove('commentsCount');
      updates.remove('createdAt');
      updates.remove('authorId');
      updates.remove('id');

      await _firestore.collection('wikis').doc(wiki.id).update(updates);
    } catch (e) {
      throw Exception('Error updating wiki: $e');
    }
  }

  @override
  Future<void> likeWiki(String wikiId, String userId) async {
    final wikiRef = _firestore.collection('wikis').doc(wikiId);
    final likeRef = wikiRef.collection('likes').doc(userId);

    debugPrint('WikiRepo: Intentando dar Like a la Wiki $wikiId por el usuario $userId');
    await _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      if (!likeSnapshot.exists) {
        debugPrint('WikiRepo: El like no existe, creándolo e incrementando contador.');
        transaction.set(likeRef, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(wikiRef, {
          'likesCount': FieldValue.increment(1),
        });

        // --- ADD NOTIFICATION ---
        final wikiSnapshot = await transaction.get(wikiRef);
        final wikiData = wikiSnapshot.data() as Map<String, dynamic>;
        final authorId = wikiData['authorId'] as String;

        if (authorId != userId) {
          final notifRef = _firestore.collection('users').doc(authorId).collection('notifications').doc();
          transaction.set(notifRef, {
            'type': 'wiki_like',
            'title': 'Nuevo Like',
            'body': 'A alguien le gustó tu Wiki: ${wikiData['title']}',
            'senderId': userId,
            'wikiId': wikiId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      } else {
        debugPrint('WikiRepo: El like ya existía, no se hace nada.');
      }
    });
  }

  @override
  Future<void> unlikeWiki(String wikiId, String userId) async {
    final wikiRef = _firestore.collection('wikis').doc(wikiId);
    final likeRef = wikiRef.collection('likes').doc(userId);

    debugPrint('WikiRepo: Intentando quitar Like de la Wiki $wikiId por el usuario $userId');
    await _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      if (likeSnapshot.exists) {
        debugPrint('WikiRepo: El like existe, eliminándolo y decrementando contador.');
        transaction.delete(likeRef);
        transaction.update(wikiRef, {
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        debugPrint('WikiRepo: El like no existía, no se hace nada.');
      }
    });
  }

  @override
  Future<bool> checkIfLiked(String wikiId, String userId) async {
    final likeSnapshot = await _firestore
        .collection('wikis')
        .doc(wikiId)
        .collection('likes')
        .doc(userId)
        .get();
    return likeSnapshot.exists;
  }

  @override
  Future<void> deleteWiki(String wikiId) async {
    try {
      await _firestore.collection('wikis').doc(wikiId).delete();
    } catch (e) {
      throw Exception('Error deleting wiki: $e');
    }
  }

  @override
  Future<List<WikiPage>> getUserWikis(String userId, {String? communityId}) async {
    try {
      Query query = _firestore.collection('wikis').where('authorId', isEqualTo: userId);
      
      if (communityId != null) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final snapshot = await query.orderBy('createdAt', descending: true).get();
      
      return snapshot.docs.map((doc) {
        return WikiPage.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Error getting user wikis: $e');
    }
  }

  @override
  Future<void> addWikiComment(String wikiId, WikiComment comment) async {
    final wikiRef = _firestore.collection('wikis').doc(wikiId);
    final commentRef = wikiRef.collection('comments').doc();

    await _firestore.runTransaction((transaction) async {
      final wikiSnapshot = await transaction.get(wikiRef);
      final wikiData = wikiSnapshot.data() as Map<String, dynamic>;
      final authorId = wikiData['authorId'] as String;

      transaction.set(commentRef, comment.copyWith(id: commentRef.id).toMap());
      transaction.update(wikiRef, {
        'commentsCount': FieldValue.increment(1),
      });

      // --- ADD NOTIFICATION ---
      if (authorId != comment.authorId) {
        final notifRef = _firestore.collection('users').doc(authorId).collection('notifications').doc();
        transaction.set(notifRef, {
          'type': 'wiki_comment',
          'title': 'Nuevo comentario',
          'body': '${comment.authorName} comentó en tu Wiki: ${wikiData['title']}',
          'senderId': comment.authorId,
          'senderName': comment.authorName,
          'senderAvatarUrl': comment.authorAvatarUrl,
          'wikiId': wikiId,
          'commentId': commentRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    });
  }

  @override
  Future<void> addWikiReply(String wikiId, String commentId, WikiComment reply) async {
    final commentRef = _firestore
        .collection('wikis')
        .doc(wikiId)
        .collection('comments')
        .doc(commentId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(commentRef);
      if (!snapshot.exists) return;

      final commentData = snapshot.data() as Map<String, dynamic>;
      final authorId = commentData['authorId'] as String;

      transaction.update(commentRef, {
        'replies': FieldValue.arrayUnion([reply.toMap()])
      });

      // --- ADD NOTIFICATION ---
      if (authorId != reply.authorId) {
        final notifRef = _firestore.collection('users').doc(authorId).collection('notifications').doc();
        transaction.set(notifRef, {
          'type': 'wiki_reply',
          'title': 'Nueva respuesta',
          'body': '${reply.authorName} respondió a tu comentario',
          'senderId': reply.authorId,
          'senderName': reply.authorName,
          'senderAvatarUrl': reply.authorAvatarUrl,
          'wikiId': wikiId,
          'commentId': commentId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    });
  }

  @override
  Future<List<WikiComment>> getWikiComments(String wikiId) async {
    final snapshot = await _firestore
        .collection('wikis')
        .doc(wikiId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => WikiComment.fromMap(doc.data(), doc.id)).toList();
  }

  @override
  Future<void> deleteWikiComment(String wikiId, String commentId) async {
    final wikiRef = _firestore.collection('wikis').doc(wikiId);
    final commentRef = wikiRef.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      transaction.delete(commentRef);
      transaction.update(wikiRef, {
        'commentsCount': FieldValue.increment(-1),
      });
    });
  }

  @override
  Future<void> deleteWikiReply(String wikiId, String commentId, WikiComment reply) async {
    final commentRef = _firestore
        .collection('wikis')
        .doc(wikiId)
        .collection('comments')
        .doc(commentId);
    
    await commentRef.update({
      'replies': FieldValue.arrayRemove([reply.toMap()])
    });
  }

  @override
  Future<void> updateWikiComment(String wikiId, WikiComment comment) async {
    try {
      await _firestore
          .collection('wikis')
          .doc(wikiId)
          .collection('comments')
          .doc(comment.id)
          .update(comment.toMap());
    } catch (e) {
      throw Exception('Error updating wiki comment: $e');
    }
  }

  @override
  Future<WikiPage> getWiki(String wikiId) async {
    debugPrint('WikiRepo: Obteniendo documento de Wiki $wikiId...');
    final doc = await _firestore.collection('wikis').doc(wikiId).get();
    if (!doc.exists) {
      debugPrint('WikiRepo: Error - Documento no encontrado.');
      throw Exception('Wiki not found');
    }
    final data = doc.data()!;
    debugPrint('WikiRepo: Documento encontrado. likesCount actual en Firestore: ${data['likesCount']}');
    return WikiPage.fromMap(data, doc.id);
  }

  @override
  Future<List<WikiPage>> getPendingSubmissions(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('wikis')
          .where('communityId', isEqualTo: communityId)
          .where('isApproved', isEqualTo: false)
          .where('isPendingReview', isEqualTo: true) // Necesitaremos un nuevo flag
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => WikiPage.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error getting pending wikis: $e');
      return [];
    }
  }

  @override
  Future<void> approveWiki(String wikiId) async {
    try {
      await _firestore.collection('wikis').doc(wikiId).update({
        'isApproved': true,
        'isPendingReview': false,
      });
    } catch (e) {
      print('Error approving wiki: $e');
      rethrow;
    }
  }

  @override
  Future<void> submitToCatalog(String wikiId) async {
    try {
      await _firestore.collection('wikis').doc(wikiId).update({
        'isPendingReview': true,
      });
    } catch (e) {
      print('Error submitting to catalog: $e');
      rethrow;
    }
  }

  @override
  Future<void> reactToWikiComment(String wikiId, String commentId, String userId, String reaction) async {
    final commentRef = _firestore
        .collection('wikis')
        .doc(wikiId)
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

      if (previousReaction != null) {
        final reactionKey = previousReaction!;
        List<String> userIds = List<String>.from(reactionsMap[reactionKey]!);
        userIds.remove(userId);
        if (userIds.isEmpty) {
          reactionsMap.remove(reactionKey);
        } else {
          reactionsMap[reactionKey] = userIds;
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
            'type': 'wiki_comment', // Re-use wiki_comment or similar
            'title': 'Nueva reacción',
            'body': 'A alguien le gustó tu comentario con $reaction',
            'senderId': userId,
            'wikiId': wikiId,
            'commentId': commentId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      transaction.update(commentRef, {'reactions': reactionsMap});
    });
  }
}
