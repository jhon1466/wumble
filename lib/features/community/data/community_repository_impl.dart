import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/join_request_model.dart';
import 'package:wumble/features/community/domain/reputation_service.dart';
import 'package:wumble/features/chat/domain/bot_framework.dart';
import 'package:wumble/features/moderation/domain/moderation_models.dart';
import 'package:wumble/features/community/domain/navigation_tab_model.dart';
import 'package:wumble/core/utils/media_helper.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CommunityRepositoryImpl({
    FirebaseFirestore? firestore, 
    FirebaseStorage? storage
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  // Cache fields
  List<Community>? _cachedFeatured;
  DateTime? _lastFeaturedFetch;
  
  List<Community>? _cachedDiscover;
  DateTime? _lastDiscoverFetch;
  
  final Map<String, List<Community>> _userCommunitiesCache = {};
  final Map<String, DateTime> _lastUserCommunitiesFetch = {};

  @override
  Future<Community> createCommunity(Community community, File? icon, File? banner, File? background) async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        await user.getIdToken(true).timeout(const Duration(seconds: 10));
      } catch (e) {
      }
    }

    String iconUrl = community.iconUrl;
    String bannerUrl = community.bannerUrl;
    String backgroundUrl = community.backgroundUrl;

    try {
      // 1. Upload Images if present
      if (icon != null && await icon.exists()) {
        try {
          final compressedIcon = await MediaHelper.compressFile(icon);
          final ref = _storage.ref().child('communities/${community.id}/icon.jpg');
          await ref.putFile(compressedIcon).timeout(const Duration(seconds: 30));
          iconUrl = await ref.getDownloadURL();
        } catch (e) {
        }
      }

      if (banner != null && await banner.exists()) {
        try {
          final compressedBanner = await MediaHelper.compressFile(banner);
          final ref = _storage.ref().child('communities/${community.id}/banner.jpg');
          await ref.putFile(compressedBanner).timeout(const Duration(seconds: 30));
          bannerUrl = await ref.getDownloadURL();
        } catch (e) {
        }
      }

      if (background != null && await background.exists()) {
        try {
          final compressedBg = await MediaHelper.compressFile(background);
          final ref = _storage.ref().child('communities/${community.id}/background.jpg');
          await ref.putFile(compressedBg).timeout(const Duration(seconds: 30));
          backgroundUrl = await ref.getDownloadURL();
        } catch (e) {
        }
      }

      // 2. Update Community object with new URLs
      final newCommunity = community.copyWith(
        iconUrl: iconUrl,
        bannerUrl: bannerUrl,
        backgroundUrl: backgroundUrl,
      );

      // 3. Save to Firestore
      
      // Batch write to ensure both community and member are created 
      final batch = _firestore.batch();
      final commRef = _firestore.collection('communities').doc(community.id);
      
      batch.set(commRef, newCommunity.toMap());
      
      if (user != null) {
        // Obtenemos los datos globales del usuario para crear su perfil en la comunidad
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        final displayName = userData['displayName'] ?? userData['username'] ?? 'Usuario';
        final avatarUrl = userData['avatarUrl'] ?? '';
        final showOnlineStatus = userData['showOnlineStatus'] ?? true;

        final memberRef = commRef.collection('members').doc(user.uid);
        batch.set(memberRef, {
          'userId': user.uid,
          'communityId': community.id,
          'displayName': displayName,
          'avatarUrl': avatarUrl,
          'role': 'leader',
          'level': 1,
          'reputation': 0,
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'checkInCount': 1,
          'showOnlineStatus': showOnlineStatus,
        });
      }

      await batch.commit().timeout(const Duration(seconds: 30));
      
      return newCommunity;
          
    } on FirebaseException catch (e) {
      throw Exception('Firebase Error [${e.code}]: ${e.message}');
    } catch (e) {
      throw Exception('Error creating community: $e');
    }
  }

  @override
  Future<Community?> getCommunity(String communityId) async {
    try {
      final doc = await _firestore.collection('communities').doc(communityId).get();
      if (!doc.exists) return null;
      return Community.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Error fetching community: $e');
    }
  }

  @override
  Future<Community?> getCommunityByHandle(String handle) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .where('handle', isEqualTo: handle)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return Community.fromMap(doc.data(), doc.id);
    } catch (e) {
      debugPrint('CommunityRepo: Error fetching by handle: $e');
      return null;
    }
  }

  @override
  Stream<Community?> getCommunityStream(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return Community.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Future<List<Community>> getCommunities() async {
    // Cache for 5 minutes
    if (_cachedDiscover != null && _lastDiscoverFetch != null &&
        DateTime.now().difference(_lastDiscoverFetch!).inMinutes < 5) {
      debugPrint('ProfileRepo: Usando caché para descubrir');
      return _cachedDiscover!;
    }

    try {
      debugPrint('ProfileRepo: Cargando descubrir de Firestore');
      final snapshot = await _firestore
          .collection('communities')
          .where('membersCount', isGreaterThan: 0)
          .orderBy('membersCount', descending: true)
          .limit(40)
          .get();

      final communities = snapshot.docs
          .map((doc) => Community.fromMap(doc.data(), doc.id))
          .where((community) => community.privacy != 'private')
          .take(20)
          .toList();

      _cachedDiscover = communities;
      _lastDiscoverFetch = DateTime.now();

      return communities;
    } catch (e) {
      throw Exception('Error fetching communities: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getCommunitiesPaginated({String? category, dynamic lastDocument, int limit = 20}) async {
    try {
      Query query = _firestore.collection('communities')
          .where('membersCount', isGreaterThan: 0);

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('membersCount', descending: true);

      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final communities = snapshot.docs
          .map((doc) => Community.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((community) => community.privacy != 'private')
          .toList();

      return {
        'communities': communities,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      throw Exception('Error fetching communities paginated: $e');
    }
  }

  @override
  Future<List<Community>> getTrendingCommunities() async {
    try {
      // For now, trending is simply most members, but excluding the very top featured ones maybe? 
      // Let's just take top 10 as "Trending" for now.
      final snapshot = await _firestore
          .collection('communities')
          .where('membersCount', isGreaterThan: 0)
          .orderBy('membersCount', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => Community.fromMap(doc.data(), doc.id))
          .where((community) => community.privacy != 'private')
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Community>> getNewCommunities() async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .orderBy('createdAt', descending: true) 
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => Community.fromMap(doc.data(), doc.id))
          .where((community) => community.privacy != 'private')
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Community>> searchCommunities(String query) async {
    try {
      final searchTerm = query.toLowerCase();
      // Capitalized variant (e.g., "anime" -> "Anime") for common naming convention
      final capitalizedTerm = query.isNotEmpty 
          ? query[0].toUpperCase() + query.substring(1).toLowerCase()
          : query;

      // 1. Case-insensitive search via name_lowercase field (new communities)
      final lowercaseSearch = _firestore
          .collection('communities')
          .where('name_lowercase', isGreaterThanOrEqualTo: searchTerm)
          .where('name_lowercase', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .get();

      // 2. Legacy: exact query as typed
      final exactSearch = _firestore
          .collection('communities')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      // 3. Legacy: capitalized first letter (covers "Anime", "Gaming", etc.)
      final capitalizedSearch = _firestore
          .collection('communities')
          .where('name', isGreaterThanOrEqualTo: capitalizedTerm)
          .where('name', isLessThanOrEqualTo: '$capitalizedTerm\uf8ff')
          .get();

      final results = await Future.wait([lowercaseSearch, exactSearch, capitalizedSearch]);

      // Deduplicate by document ID
      final Map<String, Community> uniqueCommunities = {};
      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          if (!uniqueCommunities.containsKey(doc.id)) {
            final community = Community.fromMap(doc.data(), doc.id);
            if (community.privacy != 'private' && community.membersCount > 0) {
              uniqueCommunities[doc.id] = community;
            }
          }
        }
      }

      return uniqueCommunities.values.toList();
    } catch (e) {
      throw Exception('Error searching communities: $e');
    }
  }
  
  @override
  Future<List<Community>> getCommunitiesByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .where('category', isEqualTo: category)
          .orderBy('membersCount', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Community.fromMap(doc.data(), doc.id))
          .where((community) => community.privacy != 'private' && community.membersCount > 0)
          .toList();
    } catch (e) {
      throw Exception('Error fetching communities by category: $e');
    }
  }

  @override
  Future<List<Community>> getFeaturedCommunities() async {
    // Cache for 5 minutes
    if (_cachedFeatured != null && _lastFeaturedFetch != null &&
        DateTime.now().difference(_lastFeaturedFetch!).inMinutes < 5) {
      return _cachedFeatured!;
    }

    try {
      final snapshot = await _firestore
          .collection('communities')
          .where('isFeatured', isEqualTo: true)
          .get();

      final communities = snapshot.docs
          .map((doc) => Community.fromMap(doc.data(), doc.id))
          .where((community) => community.privacy != 'private' && community.membersCount > 0)
          .toList();
      
      communities.sort((a, b) => b.membersCount.compareTo(a.membersCount));
      
      _cachedFeatured = communities.take(10).toList();
      _lastFeaturedFetch = DateTime.now();
      
      return _cachedFeatured!;
    } catch (e) {
      return _cachedFeatured ?? [];
    }
  }

  @override
  Future<List<Community>> getUserCommunities(String userId) async {
    // Cache for 5 minutes
    if (_userCommunitiesCache.containsKey(userId)) {
      final lastFetch = _lastUserCommunitiesFetch[userId];
      if (lastFetch != null && DateTime.now().difference(lastFetch).inMinutes < 5) {
        debugPrint('ProfileRepo: Usando caché para comunidades del usuario');
        return _userCommunitiesCache[userId]!;
      }
    }

    try {
      final snapshot = await _firestore
          .collectionGroup('members')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final communityIds = snapshot.docs.map((doc) => doc.reference.parent.parent!.id).toList();
      
      final List<Community> userCommunities = [];
      
      final List<List<String>> chunks = [];
      for (var i = 0; i < communityIds.length; i += 10) {
        chunks.add(communityIds.sublist(i, i + 10 > communityIds.length ? communityIds.length : i + 10));
      }

      final responses = await Future.wait(chunks.map((chunk) => 
        _firestore.collection('communities').where(FieldPath.documentId, whereIn: chunk).get()
      ));

      for (var commSnapshot in responses) {
        userCommunities.addAll(commSnapshot.docs.map((doc) => Community.fromMap(doc.data(), doc.id)));
      }

      _userCommunitiesCache[userId] = userCommunities;
      _lastUserCommunitiesFetch[userId] = DateTime.now();

      return userCommunities;
    } catch (e) {
      throw Exception('Error fetching user communities: $e');
    }
  }

  @override
  Future<void> joinCommunityWithInvite(String inviteCode, String userId) async {
    // To be implemented or handled by a separate service
    throw UnimplementedError('joinCommunityWithInvite not implemented');
  }

  @override
  Future<void> joinCommunity(String communityId, String userId) async {
    try {
      // Validar privacidad de la comunidad antes de unirse directamente
      final commDoc = await _firestore.collection('communities').doc(communityId).get();
      if (commDoc.exists) {
        final privacy = commDoc.data()?['privacy'] ?? 'open';
        if (privacy != 'open') {
          throw Exception('PRIVACY_RESTRICTED');
        }
      }

      await _firestore.runTransaction((transaction) async {
        final communityRef = _firestore.collection('communities').doc(communityId);
        final memberRef = communityRef.collection('members').doc(userId);
        
        final memberSnapshot = await transaction.get(memberRef);
        if (memberSnapshot.exists) {
          return; // Already a member
        }

        // Fetch user data from global profile to populate initial community member profile
        final userSnapshot = await transaction.get(_firestore.collection('users').doc(userId));
        final userData = userSnapshot.data() ?? {};
        
        // Use global profile data as starting point to avoid "Usuario" generic name
        final String initialName = userData['displayName'] ?? userData['username'] ?? 'Usuario';
        final String initialAvatar = userData['avatarUrl'] ?? '';
        final bool showOnlineStatus = userData['showOnlineStatus'] ?? true;

        final newMember = {
          'userId': userId,
          'communityId': communityId,
          'displayName': initialName,
          'avatarUrl': initialAvatar,
          'role': 'member',
          'level': 1,
          'reputation': 0,
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(), // Mark active on join
          'checkInCount': 1,
          'isBanned': false,
          'banExpiresAt': null,
          'showOnlineStatus': showOnlineStatus,
        };

        transaction.set(memberRef, newMember);
        transaction.update(communityRef, {
          'membersCount': FieldValue.increment(1),
        });
      });
    } catch (e) {
      throw Exception('Error joining community: $e');
    }
  }

  @override
  Future<void> leaveCommunity(String communityId, String userId) async {
    if (communityId.isEmpty) throw Exception('Validation: communityId is empty in leaveCommunity');
    if (userId.isEmpty) throw Exception('Validation: userId is empty in leaveCommunity');

    try {
      // 1. Fetch member data to clean up Storage
      DocumentSnapshot<Map<String, dynamic>> memberDoc;
      try {
        memberDoc = await _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(userId)
            .get();
      } catch (e) {
        throw Exception('Step 1 (Fetch member) failed: $e');
      }

      if (!memberDoc.exists) return;

      final memberData = memberDoc.data()!;
      final avatarUrl = memberData['avatarUrl'] as String?;

      // 2. Delete posts by this user in this community
      try {
        final postsSnapshot = await _firestore
            .collection('posts')
            .where('communityId', isEqualTo: communityId)
            .where('authorId', isEqualTo: userId)
            .get();

        for (var doc in postsSnapshot.docs) {
          final postData = doc.data();
          final List<String> images = List<String>.from(postData['images'] ?? []);
          for (var imageUrl in images) {
            try { await _storage.refFromURL(imageUrl).delete(); } catch(e){}
          }
          await doc.reference.delete();
        }
      } catch(e) { throw Exception('Step 2 (Delete posts) failed: $e'); }

      // 2.5 Delete individual wall messages
      try {
        final wallSnapshot = await _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(userId)
            .collection('wallMessages')
            .get();
            
        for (var doc in wallSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch(e) { throw Exception('Step 2.5 (Delete wall) failed: $e'); }

      // 2.7 Delete wikis by this user in this community
      try {
        final wikisSnapshot = await _firestore
            .collection('wikis')
            .where('communityId', isEqualTo: communityId)
            .where('authorId', isEqualTo: userId)
            .get();

        for (var doc in wikisSnapshot.docs) {
          final wikiData = doc.data();
          if (wikiData['iconUrl'] != null && (wikiData['iconUrl'] as String).isNotEmpty) {
            try { await _storage.refFromURL(wikiData['iconUrl']).delete(); } catch(e){}
          }
          if (wikiData['coverUrl'] != null && (wikiData['coverUrl'] as String).isNotEmpty) {
            try { await _storage.refFromURL(wikiData['coverUrl']).delete(); } catch(e){}
          }
          await doc.reference.delete();
        }
      } catch(e) { throw Exception('Step 2.7 (Delete wikis) failed: $e'); }

      // 3. Delete member document and check for last human
      bool shouldDeleteCommunity = false;
      try {
        await _firestore.runTransaction((transaction) async {
          final communityRef = _firestore.collection('communities').doc(communityId);
          final memberRef = communityRef.collection('members').doc(userId);

          // Get community count
          final communitySnap = await transaction.get(communityRef);
          final currentCount = (communitySnap.data()?['membersCount'] ?? 0) as int;

          // Check if there are other human members OR just the current one
          // We can't easily query within transaction, so we'll check outside if the count is small
          // Or just trust currentCount. If currentCount is 1, it's definitely the last member.
          
          if (currentCount <= 1) {
            shouldDeleteCommunity = true;
          } else {
            // Also check for bot-only remainders if count is small (e.g. 2 members: user + bot)
            // We'll perform a separate query after the transaction or just before
            // To keep it safe, if count is 1, delete. 
            // If count > 1, we might need a separate check for humans.
          }

          transaction.delete(memberRef);
          transaction.update(communityRef, {
            'membersCount': FieldValue.increment(-1),
          });
        });

        // Extra check for Bot-only communities if we didn't already decide to delete
        if (!shouldDeleteCommunity) {
           // We'll check if any other NON-BOT members exist
           final otherHumans = await _firestore
              .collection('communities')
              .doc(communityId)
              .collection('members')
              .where('isBot', isEqualTo: false)
              .where(FieldPath.documentId, isNotEqualTo: userId)
              .limit(1)
              .get();
           
           if (otherHumans.docs.isEmpty) {
             shouldDeleteCommunity = true;
           }
        }

        if (shouldDeleteCommunity) {
          debugPrint('CLEANUP: Community $communityId has no more humans. Deleting...');
          await deleteCommunity(communityId);
          return; // Skip rest of cleanup as deleteCommunity handles it
        }
      } catch(e) { 
        debugPrint('CLEANUP: leaveCommunity step 3 warning: $e');
        // If it failed because community already gone or something, just continue
      }

      // 4. Delete community-specific avatar from Storage
      if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.contains('community_members')) {
        try {
          await _storage.refFromURL(avatarUrl).delete();
        } catch (e) {
        }
      }

      // 5. CLEAN UP CHATS
      try {
        final chatsSnapshot = await _firestore
            .collection('chatRooms')
            .where('communityId', isEqualTo: communityId)
            .where('participants', arrayContains: userId)
            .get();
            
        final writeBatch = _firestore.batch();
        
        for (var chatDoc in chatsSnapshot.docs) {
          final chatData = chatDoc.data();
          final List<String> participants = List<String>.from(chatData['participants'] ?? []);
          
          participants.remove(userId);
          
          if (participants.isEmpty) {
            writeBatch.delete(chatDoc.reference);
          } else {
            writeBatch.update(chatDoc.reference, {
              'participants': participants,
              'participantNames.$userId': FieldValue.delete(),
              'participantAvatars.$userId': FieldValue.delete(),
              'participantAvatarFrames.$userId': FieldValue.delete(),
            });
          }
        }
        
        await writeBatch.commit();
      } catch (e) {
        debugPrint('Step 5 (Chat cleanup) failed: $e');
      }
    } catch (e) {
      throw Exception('Error leaving community and cleaning data: $e');
    }
  }

  @override
  Future<void> deleteCommunity(String communityId) async {
    try {
      // 1. Get community data for assets
      final communityDoc = await _firestore.collection('communities').doc(communityId).get();
      if (!communityDoc.exists) return;
      
      final communityData = communityDoc.data()!;
      final iconUrl = communityData['iconUrl'] as String?;
      final bannerUrl = communityData['bannerUrl'] as String?;
      final backgroundUrl = communityData['backgroundUrl'] as String?;

      // 2. Delete ALL posts of the community
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('communityId', isEqualTo: communityId)
          .get();

      for (var doc in postsSnapshot.docs) {
        final postData = doc.data();
        final List<String> images = List<String>.from(postData['images'] ?? []);
        for (var imageUrl in images) {
          try {
            await _storage.refFromURL(imageUrl).delete();
          } catch (e) {
          }
        }
        await doc.reference.delete();
      }

      // 2.5 Delete ALL wikis
      final wikisSnapshot = await _firestore
          .collection('wikis')
          .where('communityId', isEqualTo: communityId)
          .get();
      for (var doc in wikisSnapshot.docs) {
        final wikiData = doc.data();
        if (wikiData['iconUrl'] != null && (wikiData['iconUrl'] as String).isNotEmpty) {
          try { await _storage.refFromURL(wikiData['iconUrl']).delete(); } catch(e){}
        }
        if (wikiData['coverUrl'] != null && (wikiData['coverUrl'] as String).isNotEmpty) {
          try { await _storage.refFromURL(wikiData['coverUrl']).delete(); } catch(e){}
        }
        await doc.reference.delete();
      }

      // 2.7 Delete ALL public chat rooms
      final chatsSnapshot = await _firestore
          .collection('chatRooms')
          .where('communityId', isEqualTo: communityId)
          .get();
      for (var doc in chatsSnapshot.docs) {
        final messages = await doc.reference.collection('messages').get();
        for (var m in messages.docs) await m.reference.delete();
        await doc.reference.delete();
      }

      // 3. Delete ALL members and their avatars
      final membersSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .get();

      for (var doc in membersSnapshot.docs) {
        final memberData = doc.data();
        final avatarUrl = memberData['avatarUrl'] as String?;

        // 3.5 Delete member's wall messages
        final wallSnapshot = await doc.reference.collection('wallMessages').get();
        for (var w in wallSnapshot.docs) await w.reference.delete();

        if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.contains('community_members')) {
          try {
            await _storage.refFromURL(avatarUrl).delete();
          } catch (e) {
          }
        }
        await doc.reference.delete();
      }

      // 4. Delete community assets from Storage
      final assets = [iconUrl, bannerUrl, backgroundUrl];
      for (var assetUrl in assets) {
        if (assetUrl != null && assetUrl.isNotEmpty) {
          try {
            await _storage.refFromURL(assetUrl).delete();
          } catch (e) {
          }
        }
      }

      // 5. Delete the community document
      await _firestore.collection('communities').doc(communityId).delete();

    } catch (e) {
      throw Exception('Error deleting community and all data: $e');
    }
  }

  @override
  Future<bool> isMember(String communityId, String userId) async {
    try {
      final doc = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      throw Exception('Error checking membership: $e');
    }
  }

  @override
  Future<List<CommunityMember>> getCommunityLeaderboard(String communityId, String type) async {
    try {
      Query query = _firestore.collection('communities').doc(communityId).collection('members')
          .where('isBanned', isEqualTo: false);

      if (type == '24h') {
        query = query.orderBy('onlineMinutes24h', descending: true).limit(100);
      } else if (type == '7d') {
        query = query.orderBy('onlineMinutes7d', descending: true).limit(100);
      } else {
        // allTime / Hall of Fame
        query = query.orderBy('reputation', descending: true).limit(100);
      }

      final querySnapshot = await query.get();
      final members = querySnapshot.docs.map((doc) => CommunityMember.fromFirestore(doc)).toList();
      return await _attachFrames(members);
    } catch (e) {
      throw Exception('Error getting leaderboard: $e');
    }
  }


  @override
  Future<void> updateMemberPresence(String communityId, String userId) async {
    try {
      final memberRef = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId);
      
      await memberRef.update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  @override
  Future<void> updateCommunity(String communityId, Map<String, dynamic> data, File? icon, File? banner, File? background) async {
    try {
      final updates = Map<String, dynamic>.from(data);

      if (icon != null) {
        final compressedIcon = await MediaHelper.compressFile(icon);
        final ref = _storage.ref().child('community_icons/$communityId.jpg');
        await ref.putFile(compressedIcon);
        updates['iconUrl'] = await ref.getDownloadURL();
      }

      if (banner != null) {
        final compressedBanner = await MediaHelper.compressFile(banner);
        final ref = _storage.ref().child('community_banners/$communityId.jpg');
        await ref.putFile(compressedBanner);
        updates['bannerUrl'] = await ref.getDownloadURL();
      }

      if (background != null) {
        final compressedBg = await MediaHelper.compressFile(background);
        final ref = _storage.ref().child('community_backgrounds/$communityId.jpg');
        await ref.putFile(compressedBg);
        updates['backgroundUrl'] = await ref.getDownloadURL();
      }

      // Auto-sync name_lowercase for case-insensitive search
      if (updates.containsKey('name')) {
        updates['name_lowercase'] = (updates['name'] as String).toLowerCase();
      }

      await _firestore.collection('communities').doc(communityId).update(updates);
    } catch (e) {
      throw Exception('Error updating community: $e');
    }
  }

  @override
  Future<List<CommunityMember>> getCommunityMembers(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .where('isBanned', isEqualTo: false)
          .limit(100)
          .get();
      
      final members = snapshot.docs
          .map((doc) => CommunityMember.fromFirestore(doc))
          .toList();
          
      return await _attachFrames(members);
    } catch (e) {
      throw Exception('Error fetching members: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getCommunityMembersPaginated(String communityId, {dynamic lastDocument, int limit = 20}) async {
    try {
      Query query = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members');

      // Normal member list query
      query = query.where('isBanned', isEqualTo: false).orderBy('joinedAt', descending: true);
      query = query.limit(limit);

      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      
      final members = snapshot.docs.map((doc) => CommunityMember.fromFirestore(doc)).toList();
      final enrichedMembers = await _attachFrames(members);
      final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return {
        'members': enrichedMembers,
        'lastDocument': newLastDoc,
      };
    } catch (e) {
      throw Exception('Error fetching paginated members: $e');
    }
  }

  @override
  Future<List<CommunityMember>> searchCommunityMembers(String communityId, String query) async {
    try {
      final searchTerm = query.toLowerCase();
      
      // Fetch members and filter locally for case-insensitive search
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .where('isBanned', isEqualTo: false)
          .limit(200)
          .get();
      
      final members = snapshot.docs
          .map((doc) => CommunityMember.fromFirestore(doc))
          .where((m) => (m.displayName ?? '').toLowerCase().contains(searchTerm))
          .take(50)
          .toList();
          
      return await _attachFrames(members);
    } catch (e) {
      throw Exception('Error searching members: $e');
    }
  }

  @override
  Future<void> updateMemberRole(String communityId, String userId, String newRole) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update({'role': newRole});
    } catch (e) {
      throw Exception('Error updating role: $e');
    }
  }

  @override
  Future<void> kickMember(String communityId, String userId) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .delete();
      
      await _firestore.collection('communities').doc(communityId).update({
        'membersCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Error kicking member: $e');
    }
  }

  @override
  Future<void> warnMember(String communityId, String userId, String reason, String moderatorId) async {
    try {
      final warningRef = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .collection('warnings')
          .doc();
      
      final sanctionDoc = {
        'userId': userId,
        'communityId': communityId,
        'adminId': moderatorId,
        'type': 'warning',
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await warningRef.set(sanctionDoc);

      // Update a counter or last warning in the member doc
      final memberRef = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId);
          
      await memberRef.update({
        'lastWarningAt': FieldValue.serverTimestamp(),
      });

      // Send a system notification to the user
      final notifRef = _firestore.collection('users').doc(userId).collection('notifications');
      final communityDoc = await _firestore.collection('communities').doc(communityId).get();
      final commName = communityDoc.data()?['name'] ?? 'la comunidad';

      await notifRef.add({
        'type': 'warning',
        'title': 'Advertencia Oficial',
        'body': 'Has recibido una advertencia en $commName por: $reason',
        'communityId': communityId,
        'communityName': commName,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

    } catch (e) {
      throw Exception('Error warning member: $e');
    }
  }

  @override
  Future<void> banMember(String communityId, String userId, String moderatorId, {DateTime? expiresAt}) async {
    try {
      final memberRef = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId);

      await memberRef.update({
        'isBanned': true,
        'banExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      });

      // Registrar la sanción en el historial del miembro
      final sanctionsRef = memberRef.collection('warnings');
      final type = expiresAt != null ? 'strike' : 'ban';
      final reason = expiresAt != null 
          ? 'Expulsión temporal (${expiresAt.difference(DateTime.now()).inHours}h)'
          : 'Baneo permanente de la comunidad';

      await sanctionsRef.add({
        'userId': userId,
        'adminId': moderatorId,
        'type': type,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'isActive': true,
      });
    } catch (e) {
      throw Exception('Error banning member: $e');
    }
  }

  @override
  Stream<List<Sanction>> getMemberSanctions(String communityId, String userId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(userId)
        .collection('warnings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Sanction.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> unbanMember(String communityId, String userId) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update({
        'isBanned': false,
        'banExpiresAt': null,
      });
    } catch (e) {
      throw Exception('Error unbanning member: $e');
    }
  }

  @override
  Future<List<CommunityMember>> getBannedMembers(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .where('isBanned', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => CommunityMember.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error getting banned members: $e');
    }
  }

  Future<List<CommunityMember>> _attachFrames(List<CommunityMember> members) async {
    if (members.isEmpty) return members;
    
    final missingFrameIds = members
        .where((m) => !m.isBot && m.userId != 'system_secure_guard' && (m.avatarFrameUrl == null || m.avatarFrameUrl!.isEmpty))
        .map((m) => m.userId)
        .toSet()
        .toList();

    if (missingFrameIds.isEmpty) return members;

    try {
      // Process in small batches if needed, but for 20-50 users parallel get() is usually fine
      final Map<String, String> frameMap = {};
      
      final profileSnapshots = await Future.wait(missingFrameIds.map((id) => 
        _firestore.collection('users').doc(id).get()
      ));

      for (var doc in profileSnapshots) {
        if (doc.exists) {
          final frame = doc.data()?['avatarFrameUrl'] as String?;
          if (frame != null && frame.isNotEmpty) {
            frameMap[doc.id] = frame;
          }
        }
      }

      return members.map((m) {
        final frame = frameMap[m.userId];
        if (frame != null) {
          return m.copyWith(avatarFrameUrl: frame);
        }
        return m;
      }).toList();
    } catch (e) {
      debugPrint('Error attaching frames: $e');
      return members;
    }
  }

  @override
  Future<void> migrateMemberBanData(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .get();

      final batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('isBanned')) {
          batch.update(doc.reference, {
            'isBanned': false,
            'banExpiresAt': null,
          });
          count++;
          // Firestore batches have a limit of 500 operations
          if (count >= 500) break; 
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Error migrating member data: $e');
    }
  }

  @override
  Future<void> updateLevelTitles(String communityId, Map<String, String> titles) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'levelTitles': titles,
      });
    } catch (e) {
      throw Exception('Error updating level titles: $e');
    }
  }

  @override
  Future<void> updateMemberProfile(String communityId, String userId, Map<String, dynamic> data, File? avatar) async {
    try {
      final updates = Map<String, dynamic>.from(data);

      if (avatar != null) {
        final compressedAvatar = await MediaHelper.compressFile(avatar);
        final ref = _storage.ref().child('community_members/$communityId/$userId/avatar.jpg');
        await ref.putFile(compressedAvatar);
        updates['avatarUrl'] = await ref.getDownloadURL();
      }

      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update(updates);
    } catch (e) {
      throw Exception('Error updating member profile: $e');
    }
  }

  @override
  Future<void> requestJoinCommunity(String communityId, String userId, {String message = ''}) async {
    try {
      final docRef = _firestore.collection('communities').doc(communityId).collection('joinRequests').doc(userId);
      final request = JoinRequest(
        id: userId,
        userId: userId,
        communityId: communityId,
        message: message,
        requestedAt: DateTime.now(),
      );
      
      await docRef.set(request.toMap());

      // Send notification to leaders (fallback to creator)
      final communityDoc = await _firestore.collection('communities').doc(communityId).get();
      if (communityDoc.exists) {
        final creatorId = communityDoc.data()?['creatorId'] as String?;
        if (creatorId != null && creatorId.isNotEmpty) {
          final userInfo = await _firestore.collection('users').doc(userId).get();
          final username = userInfo.data()?['displayName'] ?? userInfo.data()?['username'] ?? 'Un usuario';
          final commName = communityDoc.data()?['name'] ?? 'tu comunidad';
          
          await _firestore.collection('users').doc(creatorId).collection('notifications').add({
            'type': 'join_request',
            'title': 'Solicitud de Ingreso',
            'body': '$username quiere unirse a $commName',
            'senderId': userId,
            'senderName': username,
            'senderAvatarUrl': userInfo.data()?['avatarUrl'] ?? '',
            'communityId': communityId,
            'communityName': commName,
            'communityAvatarUrl': communityDoc.data()?['imageUrl'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }
    } catch (e) {
      throw Exception('Error requesting to join community: $e');
    }
  }

  @override
  Future<List<dynamic>> getJoinRequests(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('joinRequests')
          .orderBy('requestedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => JoinRequest.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Error getting join requests: $e');
    }
  }

  @override
  Future<void> approveJoinRequest(String communityId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final communityRef = _firestore.collection('communities').doc(communityId);
        final memberRef = communityRef.collection('members').doc(userId);
        final requestRef = communityRef.collection('joinRequests').doc(userId);
        
        final memberSnapshot = await transaction.get(memberRef);
        if (memberSnapshot.exists) {
          transaction.delete(requestRef);
          return; // Already a member
        }

        // Fetch user data
        final userSnapshot = await transaction.get(_firestore.collection('users').doc(userId));
        final userData = userSnapshot.data() ?? {};
        
        final String initialName = userData['displayName'] ?? userData['username'] ?? 'Usuario';
        final String initialAvatar = userData['avatarUrl'] ?? '';

        final newMember = {
          'userId': userId,
          'communityId': communityId,
          'displayName': initialName,
          'avatarUrl': initialAvatar,
          'role': 'member',
          'level': 1,
          'reputation': 0,
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'checkInCount': 1,
          'isBanned': false,
          'banExpiresAt': null,
        };

        transaction.set(memberRef, newMember);
        transaction.update(communityRef, {
          'membersCount': FieldValue.increment(1),
        });
        transaction.delete(requestRef);
      });

      // Send approval notification to the user
      final communityDoc = await _firestore.collection('communities').doc(communityId).get();
      final commName = communityDoc.data()?['name'] ?? 'la comunidad';
      
      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'type': 'join_approved',
        'title': '¡Solicitud Aprobada!',
        'body': 'Tu solicitud para unirte a $commName ha sido aceptada.',
        'communityId': communityId,
        'communityName': commName,
        'communityAvatarUrl': communityDoc.data()?['imageUrl'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

    } catch (e) {
      throw Exception('Error approving join request: $e');
    }
  }

  @override
  Future<void> denyJoinRequest(String communityId, String userId) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('joinRequests')
          .doc(userId)
          .delete();
    } catch (e) {
      throw Exception('Error denying join request: $e');
    }
  }

  @override
  Future<bool> hasPendingRequest(String communityId, String userId) async {
    try {
      final doc = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('joinRequests')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> addReputation(String communityId, String userId, int amount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final memberRef = _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(userId);

        final doc = await transaction.get(memberRef);
        if (!doc.exists) return;

        final currentRep = doc.data()?['reputation'] ?? 0;
        final newRep = currentRep + amount;
        final newLevel = ReputationService.getLevel(newRep);

        transaction.update(memberRef, {
          'reputation': newRep,
          'level': newLevel,
          'lastActive': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
    }
  }

  @override
  Future<int> checkIn(String communityId, String userId) async {
    final int result = await _firestore.runTransaction<int>((transaction) async {
      final memberRef = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId);
      final userRef = _firestore.collection('users').doc(userId);

      final doc = await transaction.get(memberRef);
      if (!doc.exists) throw Exception('No eres miembro de esta comunidad');

      final data = doc.data()!;
      final lastCheckIn = (data['lastCheckIn'] as Timestamp?)?.toDate();
      final now = DateTime.now();

      if (lastCheckIn != null &&
          lastCheckIn.year == now.year &&
          lastCheckIn.month == now.month &&
          lastCheckIn.day == now.day) {
        throw Exception('Ya has realizado tu check-in hoy');
      }

      final currentRep = data['reputation'] ?? 0;
      const int rewardRep = 15;
      final int newRep = currentRep + rewardRep;
      final int newLevel = ReputationService.getLevel(newRep);

      // Random points (Coins) between 1 and 100
      final int randomCoins = Random().nextInt(100) + 1;

      transaction.update(memberRef, {
        'reputation': newRep,
        'level': newLevel,
        'lastCheckIn': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'checkInCount': (data['checkInCount'] ?? 0) + 1,
      });

      // Update global coins
      transaction.update(userRef, {
        'coins': FieldValue.increment(randomCoins),
      });

      return randomCoins;
    });
    return result;
  }

  @override
  Future<void> updateMemberTitles(String communityId, String userId, List<dynamic> titles) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update({'titles': titles});
    } catch (e) {
      throw Exception('Error updating member titles: $e');
    }
  }
  @override
  Future<CommunityMember?> getMemberProfile(String communityId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .get();
      
      if (!snapshot.exists) return null;
      return CommunityMember.fromFirestore(snapshot);
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<List<BotConfig>> getCommunityBots(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('bots')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BotConfig.fromFirestore(doc)).toList());
  }

  @override
  Future<List<BotConfig>> getCommunityBotsFuture(String communityId) async {
    final snapshot = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('bots')
        .get();
    return snapshot.docs.map((doc) => BotConfig.fromFirestore(doc)).toList();
  }

  @override
  Future<void> createBot(String communityId, BotConfig bot) async {
    final batch = _firestore.batch();
    
    // 1. Save to bots collection
    final botRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('bots')
        .doc(bot.id);
    batch.set(botRef, bot.toFirestore());
    
    // 2. Sync to members collection to ensure visibility in member list and correct profile
    final memberRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(bot.id); // Assuming bot.id is the same as userId
        
    batch.set(memberRef, {
      'userId': bot.id,
      'communityId': communityId,
      'displayName': bot.name,
      'avatarUrl': bot.avatarUrl,
      'isBot': true,
      'role': 'member',
      'level': 1,
      'reputation': 0,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'isBanned': false,
    }, SetOptions(merge: true));
    
    await batch.commit();
  }

  @override
  Future<void> updateBot(String communityId, BotConfig bot) async {
    final batch = _firestore.batch();
    
    // 1. Update bots collection
    final botRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('bots')
        .doc(bot.id);
    batch.set(botRef, bot.toFirestore()); // Use set instead of update
    
    // 2. Update members collection
    final memberRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(bot.id);
        
    batch.set(memberRef, {
      'displayName': bot.name,
      'avatarUrl': bot.avatarUrl,
      'isBot': true,
      'isBanned': false,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    await batch.commit();
  }

  @override
  Future<void> deleteBot(String communityId, String botId) async {
    await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('bots')
        .doc(botId)
        .delete();
  }

  @override
  Future<void> toggleCommunityNotifications(String communityId, String userId, bool mute) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update({'isMuted': mute});
    } catch (e) {
      throw Exception('Error toggling notifications: $e');
    }
  }

  @override
  Future<void> updateNavigationTabs(String communityId, List<CommunityNavigationTab> tabs) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'navigationTabs': tabs.map((t) => t.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error updating navigation tabs: $e');
      rethrow;
    }
  }
}
