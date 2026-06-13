import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:wumble/core/utils/media_helper.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';
import 'package:wumble/features/chat/domain/bubble_pack_model.dart';
import 'package:wumble/features/profile/domain/custom_frame_model.dart';
import 'package:wumble/core/utils/profile_manager.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? displayName,
    String? bio,
    String? avatarPath,
    String? bannerPath,
    String? backgroundPath,
    String? status,
    String? statusEmoji,
    bool? isOnline,
    bool? isProfileComplete,
    String? communityId,
    List<CommunityLabel>? titles,
    int? themeColorValue,
    List<String>? socialLinks,
    bool? showFollows,
    ChatBubbleStyle? chatBubbleStyle,
    String? wallPrivacy,
    String? chatInvitePrivacy,
    bool? isBot,
    DateTime? birthday,
    bool? syncToGlobal,
    double? bannerAlignmentY,
    void Function(double)? onProgress,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId != userId) {
      throw Exception('Autorización denegada: No puedes modificar el perfil de otro usuario.');
    }

    final Map<String, dynamic> updates = {};
    int totalFiles = 0;
    int filesUploaded = 0;

    if (avatarPath != null && avatarPath != "[DELETE]") totalFiles++;
    if (bannerPath != null && bannerPath != "[DELETE]") totalFiles++;
    if (backgroundPath != null && backgroundPath != "[DELETE]") totalFiles++;

    void updateProgress(double fileProgress) {
      if (onProgress != null && totalFiles > 0) {
        final totalProgress = (filesUploaded + fileProgress) / totalFiles;
        onProgress(totalProgress);
      }
    }

    if (username != null) {
      updates['username'] = username;
      updates['username_lowercase'] = username.toLowerCase();
    }
    if (displayName != null) {
      updates['displayName'] = displayName;
      updates['displayName_lowercase'] = displayName.toLowerCase();
    }
    if (bio != null) updates['bio'] = bio;
    if (status != null) updates['status'] = status;
    if (statusEmoji != null) updates['statusEmoji'] = statusEmoji;
    if (isOnline != null) updates['isOnline'] = isOnline;
    if (isProfileComplete != null) updates['isProfileComplete'] = isProfileComplete;
    if (titles != null) {
      updates['titles'] = titles.map((t) => t.toFirestore()).toList();
    }
    if (themeColorValue != null) updates['themeColorValue'] = themeColorValue;
    if (socialLinks != null) updates['socialLinks'] = socialLinks;
    if (showFollows != null) updates['showFollows'] = showFollows;
    if (chatBubbleStyle != null) updates['chatBubbleStyle'] = chatBubbleStyle.toMap();
    if (wallPrivacy != null) updates['wallPrivacy'] = wallPrivacy;
    if (chatInvitePrivacy != null) updates['chatInvitePrivacy'] = chatInvitePrivacy;
    if (isBot != null) updates['isBot'] = isBot;
    if (birthday != null) updates['birthday'] = birthday;
    if (bannerAlignmentY != null) updates['bannerAlignmentY'] = bannerAlignmentY;

    // --- DETERMINAR RUTAS DE STORAGE (AISLAMIENTO TOTAL) ---
    final String baseStoragePath = communityId == null 
        ? 'profiles/$userId' 
        : 'communities/$communityId/members/$userId';

    // Subir imágenes
    String? avatarUrl;
    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    if (avatarPath != null) {
      if (avatarPath == "[DELETE]") {
        updates['avatarUrl'] = "";
        avatarUrl = "";
      } else {
        avatarUrl = await _uploadFile(
          avatarPath, 
          '$baseStoragePath/avatar_$timestamp',
          onProgress: (p) => updateProgress(p),
        );
        updates['avatarUrl'] = avatarUrl;
        filesUploaded++;
      }
    }

    if (bannerPath != null) {
      if (bannerPath == "[DELETE]") {
        updates['bannerUrl'] = "";
      } else {
        updates['bannerUrl'] = await _uploadFile(
          bannerPath, 
          '$baseStoragePath/banner_$timestamp',
          onProgress: (p) => updateProgress(p),
        );
        filesUploaded++;
      }
    }

    if (backgroundPath != null) {
      if (backgroundPath == "[DELETE]") {
        updates['backgroundUrl'] = "";
      } else {
        updates['backgroundUrl'] = await _uploadFile(
          backgroundPath, 
          '$baseStoragePath/background_$timestamp',
          onProgress: (p) => updateProgress(p),
        );
        filesUploaded++;
      }
    }

    if (updates.isNotEmpty) {
      // --- SINCRONIZACIÓN GLOBAL ---
      // Ciertos campos (Conexiones, Tema, etc.) deben ser globales siempre.
      final Map<String, dynamic> globalUpdates = {};
      if (updates.containsKey('socialLinks')) globalUpdates['socialLinks'] = updates['socialLinks'];
      if (updates.containsKey('showFollows')) globalUpdates['showFollows'] = updates['showFollows'];
      
      if (communityId == null) {
        if (updates.containsKey('themeColorValue')) globalUpdates['themeColorValue'] = updates['themeColorValue'];
        if (updates.containsKey('chatBubbleStyle')) globalUpdates['chatBubbleStyle'] = updates['chatBubbleStyle'];
      }
      
      if (updates.containsKey('wallPrivacy')) globalUpdates['wallPrivacy'] = updates['wallPrivacy'];
      if (updates.containsKey('chatInvitePrivacy')) globalUpdates['chatInvitePrivacy'] = updates['chatInvitePrivacy'];
      if (updates.containsKey('isBot')) globalUpdates['isBot'] = updates['isBot'];
      
      if (globalUpdates.isNotEmpty) {
        debugPrint('ProfileRepo: Sincronizando datos globales (conexiones/tema)');
        await _firestore.collection('users').doc(userId).set(globalUpdates, SetOptions(merge: true));
      }

      if (communityId != null) {
        // ACTUALIZACIÓN DE MIEMBRO DE COMUNIDAD (Aislamiento Total)
        debugPrint('ProfileRepo: Actualizando perfil de miembro en comunidad $communityId');
        await _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(userId)
            .set(updates, SetOptions(merge: true));
            
        // Sincronizar datos denormalizados SOLO de esta comunidad
        if (updates.containsKey('displayName') || updates.containsKey('avatarUrl')) {
          await _updateDenormalizedProfileData(
            userId, 
            name: updates['displayName'], 
            avatar: updates['avatarUrl'],
            communityId: communityId,
          );
        }
      } else {
        // ACTUALIZACIÓN GLOBAL (Resto de campos)
        debugPrint('ProfileRepo: Actualizando perfil global completo');
        await _firestore.collection('users').doc(userId).set(updates, SetOptions(merge: true));
        
        // Sincronizar todos los datos (Global únicamente)
        if (updates.containsKey('username') || 
            updates.containsKey('displayName') || 
            updates.containsKey('avatarUrl')) {
          
          final String? newName = updates['displayName'] ?? updates['username'];
          final String? newAvatar = updates['avatarUrl'];
          
          // Sincronizar con Firebase Auth
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            if (newName != null) await currentUser.updateDisplayName(newName);
            if (newAvatar != null) await currentUser.updatePhotoURL(newAvatar);
            await currentUser.reload();
          }

          // Propagar cambios globalmente (pero NO a comunidades)
          await _updateDenormalizedProfileData(userId, name: newName, avatar: newAvatar);
        }
      }
      
      // Hook for instant UI synchronization (Singleton Manager)
      UserProfileManager.updateCache(userId, updates, communityId: communityId);
    }
  }

  Future<void> _updateDenormalizedProfileData(String userId, {String? name, String? avatar, String? communityId}) async {
    try {
      String syncName = name ?? '';
      String syncAvatar = avatar ?? '';
      String? syncFrame;

      // Fallback de seguridad si no vienen valores
      if (syncName.isEmpty || syncAvatar.isEmpty) {
        if (communityId != null) {
          final memberDoc = await _firestore
              .collection('communities')
              .doc(communityId)
              .collection('members')
              .doc(userId)
              .get();
          if (memberDoc.exists) {
            final data = memberDoc.data()!;
            if (syncName.isEmpty) syncName = data['displayName'] ?? 'Usuario';
            if (syncAvatar.isEmpty) syncAvatar = data['avatarUrl'] ?? '';
            syncFrame = data['avatarFrameUrl'];
          }
        } else {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            if (syncName.isEmpty) syncName = userData['displayName'] ?? userData['username'] ?? 'Usuario';
            if (syncAvatar.isEmpty) syncAvatar = userData['avatarUrl'] ?? '';
            syncFrame = userData['avatarFrameUrl'];
          }
        }
      }

      if (syncName.isEmpty) syncName = 'Usuario';

      debugPrint('ProfileRepo: Iniciando sincronización de datos para $userId (${communityId ?? "GLOBAL"})');

      // 1. Salas de Chat
      try {
        // Buscamos todas las salas donde participa el usuario
        Query roomsQuery = _firestore.collection('chatRooms').where('participants', arrayContains: userId);
        final roomsSnapshot = await roomsQuery.get();
        
        if (roomsSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in roomsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String? roomCommunityId = data['communityId'];

            // AISLAMIENTO POR CONTEXTO
            if (communityId != null) {
              // Sincronización de comunidad: solo si coincide el ID
              if (roomCommunityId != communityId) continue;
            } else {
              // Sincronización global: solo si no tiene comunidad vinculada
              if (roomCommunityId != null) continue;
            }

            final Map<String, dynamic> roomUpdates = {
              'participantNames.$userId': syncName,
              'participantAvatars.$userId': syncAvatar,
            };
            if (syncFrame != null) {
              roomUpdates['participantFrames.$userId'] = syncFrame;
            }

            batch.update(doc.reference, roomUpdates);
            count++;
            if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: ChatRooms sincronizados (${roomsSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando ChatRooms: $e');
      }

      // 2. Mensajes en Muro
      try {
        // Obtenemos todos los mensajes del remitente vía collectionGroup
        Query wallQuery = _firestore.collectionGroup('wallMessages').where('senderId', isEqualTo: userId);
        final wallSnapshot = await wallQuery.get();
        
        if (wallSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in wallSnapshot.docs) {
            // AISLAMIENTO POR RUTA (Resiliencia ante campos faltantes)
            final String path = doc.reference.path;
            
            if (communityId != null) {
              // Si sincronizamos COMUNIDAD, el mensaje debe estar en una ruta de ESA comunidad
              if (!path.contains('communities/$communityId/')) continue;
            } else {
              // Si sincronizamos GLOBAL, el mensaje NO debe pertenecer a ninguna comunidad
              if (path.contains('communities/')) continue;
            }

            final data = doc.data() as Map<String, dynamic>;
            Map<String, dynamic> wallUpdates = {};
            if (data['senderId'] == userId) {
              wallUpdates['senderName'] = syncName;
              wallUpdates['senderAvatar'] = syncAvatar;
              if (syncFrame != null) wallUpdates['senderAvatarFrame'] = syncFrame; // NEW
            }
            if (data.containsKey('replies')) {
              List<dynamic> replies = List.from(data['replies']);
              bool changed = false;
              for (var i = 0; i < replies.length; i++) {
                if (replies[i]['senderId'] == userId) {
                  replies[i]['senderName'] = syncName;
                  replies[i]['senderAvatar'] = syncAvatar;
                  if (syncFrame != null) replies[i]['senderAvatarFrame'] = syncFrame; // NEW
                  changed = true;
                }
              }
              if (changed) wallUpdates['replies'] = replies;
            }
            if (wallUpdates.isNotEmpty) {
              batch.update(doc.reference, wallUpdates);
              count++;
              if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
            }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: WallMessages sincronizados (${wallSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando WallMessages: $e');
      }

      // 3. Posts
      try {
        Query postsQuery = _firestore.collection('posts').where('authorId', isEqualTo: userId);
        
        // CORRECCIÓN CRÍTICA: Filtrado estricto por contexto
        if (communityId != null) {
          postsQuery = postsQuery.where('communityId', isEqualTo: communityId);
        } else {
          // Actualización GLOBAL solo afecta a posts globales
          postsQuery = postsQuery.where('communityId', isNull: true);
        }
        
        final postsSnapshot = await postsQuery.get();
        if (postsSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in postsSnapshot.docs) {
            batch.update(doc.reference, {
              'authorName': syncName,
              'authorAvatarUrl': syncAvatar,
              if (syncFrame != null) 'authorAvatarFrameUrl': syncFrame, // NEW
            });
            count++;
            if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: Posts sincronizados (${postsSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando Posts: $e');
      }

      // 4. Comentarios en Posts
      try {
        Query commentsQuery = _firestore.collectionGroup('comments').where('authorId', isEqualTo: userId);
        // Note: comments might need indexing for collectionGroup
        final commentsSnapshot = await commentsQuery.get();
        if (commentsSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in commentsSnapshot.docs) {
            // AISLAMIENTO POR RUTA (Resiliencia ante campos faltantes)
            final String path = doc.reference.path;
            if (communityId != null) {
              // Si sincronizamos COMUNIDAD, el mensaje debe estar en una ruta de ESA comunidad
              if (!path.contains('communities/$communityId/')) continue;
            } else {
              // Si sincronizamos GLOBAL, el mensaje NO debe pertenecer a ninguna comunidad
              if (path.contains('communities/')) continue;
            }

            final data = doc.data() as Map<String, dynamic>;
            Map<String, dynamic> commentUpdates = {};
            if (data['authorId'] == userId) {
              commentUpdates['authorName'] = syncName;
              commentUpdates['authorAvatarUrl'] = syncAvatar;
            }
            if (data.containsKey('replies')) {
              List<dynamic> replies = List.from(data['replies']);
              bool changed = false;
              for (var i = 0; i < replies.length; i++) {
                if (replies[i]['authorId'] == userId) {
                  replies[i]['authorName'] = syncName;
                  replies[i]['authorAvatarUrl'] = syncAvatar;
                  changed = true;
                }
              }
              if (changed) commentUpdates['replies'] = replies;
            }
            if (commentUpdates.isNotEmpty) {
              batch.update(doc.reference, commentUpdates);
              count++;
              if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
            }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: Comments sincronizados (${commentsSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando Comments (Check Firestore Indexes): $e');
      }

      // 5. Wikis
      try {
        Query wikisQuery = _firestore.collection('wikis').where('authorId', isEqualTo: userId);
        
        if (communityId != null) {
          wikisQuery = wikisQuery.where('communityId', isEqualTo: communityId);
        } else {
          wikisQuery = wikisQuery.where('communityId', isNull: true);
        }
        
        final wikisSnapshot = await wikisQuery.get();
        if (wikisSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in wikisSnapshot.docs) {
            batch.update(doc.reference, {
              'authorName': syncName,
              'authorAvatarUrl': syncAvatar,
              if (syncFrame != null) 'authorAvatarFrameUrl': syncFrame, // NEW
            });
            count++;
            if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: Wikis sincronizados (${wikisSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando Wikis: $e');
      }

      // 6. Quizzes
      try {
        Query quizQuery = _firestore.collection('quizzes').where('creatorId', isEqualTo: userId);
        
        if (communityId != null) {
          quizQuery = quizQuery.where('communityId', isEqualTo: communityId);
        } else {
          quizQuery = quizQuery.where('communityId', isNull: true);
        }
        
        final quizSnapshot = await quizQuery.get();
        if (quizSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in quizSnapshot.docs) {
            batch.update(doc.reference, {
              'creatorName': syncName,
              'creatorAvatarUrl': syncAvatar,
            });
            count++;
            if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: Quizzes sincronizados (${quizSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando Quizzes: $e');
      }

      // 7. Polls
      try {
        Query pollQuery = _firestore.collection('polls').where('creatorId', isEqualTo: userId);
        
        if (communityId != null) {
          pollQuery = pollQuery.where('communityId', isEqualTo: communityId);
        } else {
          pollQuery = pollQuery.where('communityId', isNull: true);
        }
        
        final pollSnapshot = await pollQuery.get();
        if (pollSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in pollSnapshot.docs) {
            batch.update(doc.reference, {
              'creatorName': syncName,
              'creatorAvatarUrl': syncAvatar,
            });
            count++;
            if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: Polls sincronizados (${pollSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando Polls: $e');
      }

      // 8. Quiz Attempts
      try {
        Query quizAttemptsQuery = _firestore.collectionGroup('quiz_attempts').where('userId', isEqualTo: userId);
        final quizAttemptsSnapshot = await quizAttemptsQuery.get();
        if (quizAttemptsSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          int count = 0;
          for (final doc in quizAttemptsSnapshot.docs) {
            // AISLAMIENTO POR RUTA (Si estuvieran dentro de comunidades)
            // O por campo si QuizAttempt tuviera communityId (pendiente)
            final String path = doc.reference.path;
            if (communityId != null) {
              if (!path.contains('communities/$communityId/')) continue;
            } else {
              if (path.contains('communities/')) continue;
            }

            batch.update(doc.reference, {
              'username': syncName,
              'userAvatarUrl': syncAvatar,
            });
            count++;
            if (count >= 400) { await batch.commit(); batch = _firestore.batch(); count = 0; }
          }
          if (count > 0) await batch.commit();
          debugPrint('ProfileRepo: QuizAttempts sincronizados (${quizAttemptsSnapshot.docs.length})');
        }
      } catch (e) {
        debugPrint('ProfileRepo: Error sincronizando QuizAttempts: $e');
      }



      debugPrint('ProfileRepo: ✅ Sincronización finalizada satisfactoriamente.');
    } catch (e) {
      debugPrint('ProfileRepo: ❌ Error crítico en sincronización: $e');
    }
  }

  @override
  Future<void> createProfile({required User user, String? username}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      // Create new profile
      final String finalUsername = username ?? user.email?.split('@')[0] ?? 'usuario_${DateTime.now().millisecondsSinceEpoch}';
      // Use Google displayName if available, otherwise fallback to username
      final String finalDisplayName = (user.displayName != null && user.displayName!.isNotEmpty) 
          ? user.displayName! 
          : finalUsername;

      final newUser = UserProfile(
        id: user.uid,
        username: finalUsername,
        displayName: finalDisplayName,
        avatarUrl: user.photoURL ?? '',
        bannerUrl: '',
        backgroundUrl: '',
        bio: '¡Hola! Soy nuevo en Wumble.',
        reputation: 0,
        level: 1,
        titles: [],
        followers: 0,
        following: 0,
        checkIns: 0,
        isOnline: true,
      );

      // Convert to Map manually
      await userDoc.set({
        'username': newUser.username,
        'username_lowercase': newUser.username.toLowerCase(),
        'displayName': newUser.displayName,
        'displayName_lowercase': newUser.displayName.toLowerCase(),
        'avatarUrl': newUser.avatarUrl,
        'bannerUrl': newUser.bannerUrl,
        'backgroundUrl': newUser.backgroundUrl,
        'bio': newUser.bio,
        'reputation': (newUser.reputation as num).toInt(),
        'level': (newUser.level as num).toInt(),
        'titles': newUser.titles,
        'followers': (newUser.followers as num).toInt(),
        'following': (newUser.following as num).toInt(),
        'checkIns': (newUser.checkIns as num).toInt(),
        'lastCheckIn': null,
        'checkInStreak': (newUser.checkInStreak as num).toInt(),
        'avatarFrameUrl': null,
        'ownedFrames': [],
        'isOnline': newUser.isOnline,
        'isProfileComplete': newUser.isProfileComplete,
        'socialLinks': newUser.socialLinks,
        'showFollows': newUser.showFollows,
        'status': null,
        'statusEmoji': null,
        'wallPrivacy': newUser.wallPrivacy,
        'chatInvitePrivacy': newUser.chatInvitePrivacy,
        'notifyMessages': true,
        'notifyLikes': true,
        'notifyFollowers': true,
        'notifyMentions': true,
        'showReadReceipts': true,
        'showOnlineStatus': true,
        'isBot': newUser.isBot,
        'email': newUser.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Profile exists, just ensure isOnline is true and backfill email if missing
      final Map<String, dynamic> backfill = {'isOnline': true};
      if (user.email != null && (snapshot.data()?['email'] == null)) {
        backfill['email'] = user.email;
      }
      await userDoc.update(backfill);
    }
  }

  @override
  Future<UserProfile?> getProfileByUsername(String username) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return UserProfile.fromMap(doc.data(), doc.id);
    } catch (e) {
      debugPrint('ProfileRepo: Error fetching by username: $e');
      return null;
    }
  }

  Future<String> _uploadFile(String originalPath, String refPath, {void Function(double)? onProgress}) async {
    // --- COMPRESIÓN DE SEGURIDAD ---
    final compressedPath = await MediaHelper.compressImage(originalPath);
    final file = File(compressedPath);
    
    final extension = file.path.split('.').last.toLowerCase();
    
    final metadata = SettableMetadata(
      contentType: extension == 'gif' ? 'image/gif' : 'image/jpeg',
    );

    try {
      debugPrint('ProfileRepo: Subiendo archivo a $refPath (ContentType: ${metadata.contentType})...');
      final ref = _storage.ref().child(refPath);
      final uploadTask = ref.putFile(file, metadata);
      
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        if (onProgress != null) onProgress(progress);
        debugPrint('ProfileRepo: Progreso ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('ProfileRepo: Subida exitosa. URL: $url');
      return url;
    } catch (e) {
      debugPrint('ProfileRepo: ❌ Error subiendo archivo: $e');
      rethrow;
    }
  }

  Future<void> _deleteFile(String refPath) async {
    try {
      final ref = _storage.ref().child(refPath);
      await ref.delete();
    } catch (e) {
      // Ignorar si el archivo no existe o hay error de permisos (ya se borró o no existía)
      print('Error al borrar archivo de Storage: $e');
    }
  }

  @override
  Stream<UserProfile> getUserProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        // Retornar un perfil por defecto si no existe el documento aún
        return UserProfile(
          id: userId,
          username: 'usuario',
          displayName: 'Usuario de Wumble',
          avatarUrl: '',
          bannerUrl: '',
          backgroundUrl: '',
          bio: '',
          reputation: 0,
          level: 1,
          titles: [],
          followers: 0,
          following: 0,
          checkIns: 0,
          coins: 0,
        );
      }
      return UserProfile.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    final searchTerm = query.toLowerCase();

    // 1. Search by lowercase username (Best match for new/migrated users)
    final usernameLowercaseWait = _firestore
        .collection('users')
        .where('username_lowercase', isGreaterThanOrEqualTo: searchTerm)
        .where('username_lowercase', isLessThanOrEqualTo: '$searchTerm\uf8ff')
        .limit(10)
        .get();

    // 2. Search by displayName_lowercase (Best match for names with special characters)
    final displayNameLowercaseWait = _firestore
        .collection('users')
        .where('displayName_lowercase', isGreaterThanOrEqualTo: searchTerm)
        .where('displayName_lowercase', isLessThanOrEqualTo: '$searchTerm\uf8ff')
        .limit(10)
        .get();

    // 3. Search by displayName (Legacy fallback + direct name search)
    // Note: This is case-sensitive for legacy users, but essential to find them.
    final displayNameWait = _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    // 4. Search by username (Legacy fallback)
    final usernameWait = _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    final results = await Future.wait([
      usernameLowercaseWait, 
      displayNameLowercaseWait,
      displayNameWait, 
      usernameWait
    ]);

    // Deduplicate results directly using a Map
    final Map<String, UserProfile> uniqueUsers = {};

    for (var snapshot in results) {
      for (var doc in snapshot.docs) {
        if (!uniqueUsers.containsKey(doc.id)) {
          final data = doc.data();
          uniqueUsers[doc.id] = UserProfile(
            id: doc.id,
            username: data['username'] ?? 'usuario',
            displayName: data['displayName'] ?? 'Usuario de Wumble',
            avatarUrl: data['avatarUrl'] ?? '',
            email: data['email'],
            bannerUrl: data['bannerUrl'] ?? '',
            backgroundUrl: data['backgroundUrl'] ?? '',
            bio: data['bio'] ?? '',
            reputation: (data['reputation'] as num?)?.toInt() ?? 0,
            level: (data['level'] as num?)?.toInt() ?? 1,
            titles: (data['titles'] as List<dynamic>?)?.map((t) => CommunityLabel.fromDynamic(t)).toList() ?? [],
            followers: (data['followers'] as num?)?.toInt() ?? 0,
            following: (data['following'] as num?)?.toInt() ?? 0,
            checkIns: (data['checkIns'] as num?)?.toInt() ?? 0,
            lastCheckIn: (data['lastCheckIn'] as Timestamp?)?.toDate(),
            checkInStreak: (data['checkInStreak'] as num?)?.toInt() ?? 0,
            avatarFrameUrl: data['avatarFrameUrl'],
            ownedFrames: List<String>.from(data['ownedFrames'] ?? []),
            coins: (data['coins'] as num?)?.toInt() ?? 0,
            status: data['status'],
            statusEmoji: data['statusEmoji'],
            isOnline: data['isOnline'] ?? false,
            isProfileComplete: data['isProfileComplete'] ?? false,
            joinedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            themeColorValue: data['themeColorValue'],
            socialLinks: List<String>.from(data['socialLinks'] ?? []),
            showFollows: data['showFollows'] ?? true,
            globalRole: data['globalRole'] ?? 'user',
            isBanned: data['isBanned'] ?? false,
            chatBubbleStyle: data['chatBubbleStyle'] != null ? ChatBubbleStyle.fromMap(data['chatBubbleStyle']) : null,
            wallPrivacy: data['wallPrivacy'] ?? 'everyone',
            chatInvitePrivacy: data['chatInvitePrivacy'] ?? 'everyone',
            notifyMessages: data['notifyMessages'] ?? true,
            notifyLikes: data['notifyLikes'] ?? true,
            notifyFollowers: data['notifyFollowers'] ?? true,
            notifyMentions: data['notifyMentions'] ?? true,
            showReadReceipts: data['showReadReceipts'] ?? true,
            showOnlineStatus: data['showOnlineStatus'] ?? true,
            blockedUserIds: List<String>.from(data['blockedUserIds'] ?? []),
          );
        }
      }
    }

    return uniqueUsers.values.toList();
  }

  @override
  Future<CommunityMember?> getMemberProfile(String communityId, String userId) async {
    final doc = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(userId)
        .get();
        
    if (!doc.exists) return null;
    return CommunityMember.fromFirestore(doc);
  }

  @override
  Stream<CommunityMember?> getMemberProfileStream(String communityId, String userId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? CommunityMember.fromFirestore(doc) : null);
  }

  @override
  Future<void> updateMemberProfile(CommunityMember member) async {
    await _firestore
        .collection('communities')
        .doc(member.communityId)
        .collection('members')
        .doc(member.userId)
        .set(member.toFirestore(), SetOptions(merge: true));
  }

  // ──── Follow System ────

  @override
  Future<void> followUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();

    // Add to current user's following
    batch.set(
      _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId),
      {'followedAt': timestamp},
    );

    // Add to target user's followers
    batch.set(
      _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId),
      {'followedAt': timestamp},
    );

    // Increment counters
    batch.update(
      _firestore.collection('users').doc(currentUserId),
      {'following': FieldValue.increment(1)},
    );
    batch.update(
      _firestore.collection('users').doc(targetUserId),
      {'followers': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  @override
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();

    // Remove from current user's following
    batch.delete(
      _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId),
    );

    // Remove from target user's followers
    batch.delete(
      _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId),
    );

    // Decrement counters
    batch.update(
      _firestore.collection('users').doc(currentUserId),
      {'following': FieldValue.increment(-1)},
    );
    batch.update(
      _firestore.collection('users').doc(targetUserId),
      {'followers': FieldValue.increment(-1)},
    );

    await batch.commit();
  }

  @override
  Stream<bool> isFollowing(String currentUserId, String targetUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.any((doc) => doc.id == targetUserId));
  }

  @override
  Stream<List<UserProfile>> getFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .asyncMap((snapshot) async {
      final futures = snapshot.docs.map((doc) => getUserProfile(doc.id).first);
      return (await Future.wait(futures)).toList();
    });
  }

  @override
  Stream<List<UserProfile>> getFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .asyncMap((snapshot) async {
      final futures = snapshot.docs.map((doc) => getUserProfile(doc.id).first);
      return (await Future.wait(futures)).toList();
    });
  }

  @override
  Future<PaginatedUsers> getFollowersPaginated(String userId, {int limit = 20, dynamic lastDoc}) async {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .orderBy('followedAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    final futures = snapshot.docs.map((doc) => getUserProfile(doc.id).first);
    final users = (await Future.wait(futures)).toList();
    
    return PaginatedUsers(
      users: users,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Future<PaginatedUsers> getFollowingPaginated(String userId, {int limit = 20, dynamic lastDoc}) async {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('followedAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    final futures = snapshot.docs.map((doc) => getUserProfile(doc.id).first);
    final users = (await Future.wait(futures)).toList();

    return PaginatedUsers(
      users: users,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  // ──── Notifications & Wall ────

  @override
  Future<void> syncFcmToken(String userId, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.toString(),
      });
      debugPrint('ProfileRepo: Token FCM sincronizado para $userId');
    } catch (e) {
      debugPrint('ProfileRepo: Error sincronizando token FCM: $e');
    }
  }

  @override
  Future<void> sendWallMessage(String targetUserId, WallMessage message, {String? communityId}) async {
    // 1. Obtener la privacidad del muro del destinatario
    final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
    if (!targetUserDoc.exists) throw Exception('El usuario destino no existe.');
    
    final privacy = targetUserDoc.data()?['wallPrivacy'] ?? 'everyone';
    
    if (privacy == 'nobody') {
      throw Exception('Este usuario ha desactivado los comentarios en su muro.');
    }
    
    if (privacy == 'members') {
      // Verificar si el remitente sigue al destinatario (o es seguidor, según convención Amino)
      // En Wumble, 'members' suele referirse a seguidores mutuos o seguidores.
      // Para simplificar, verificaremos si el remitente es un seguidor del destinatario.
      final isFollowerDoc = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(message.senderId)
          .get();
          
      if (!isFollowerDoc.exists && message.senderId != targetUserId) {
        throw Exception('Solo los seguidores de este usuario pueden comentar en su muro.');
      }
    }

    final ref = communityId == null
        ? _firestore.collection('users').doc(targetUserId).collection('wallMessages')
        : _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(targetUserId)
            .collection('wallMessages');
    
    // Asegurarnos de que el communityId se guarde en el documento para facilitar filtrados futuros
    final data = message.toFirestore();
    data['communityId'] = communityId;
            
    await ref.add(data);
  }

  @override
  Future<void> deleteWallMessage(String targetUserId, String messageId, {String? communityId}) async {
    final ref = communityId == null
        ? _firestore.collection('users').doc(targetUserId).collection('wallMessages').doc(messageId)
        : _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(targetUserId)
            .collection('wallMessages')
            .doc(messageId);
            
    await ref.delete();
  }


  @override
  Stream<List<WallMessage>> getWallMessages(String userId, {String? communityId}) {
    final query = communityId == null
        ? _firestore.collection('users').doc(userId).collection('wallMessages')
        : _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(userId)
            .collection('wallMessages');
            
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WallMessage.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<String> uploadWallImage(String userId, String path, {void Function(double progress)? onProgress}) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Compress the image before uploading
    final compressedPath = await MediaHelper.compressImage(path);

    return _uploadFile(
      compressedPath,
      'walls/$userId/$tempId',
      onProgress: (p) => onProgress?.call(p),
    );
  }

  @override
  Future<void> toggleWallMessageLike(String targetUserId, String messageId, String currentUserId, {String? communityId}) async {
    final docRef = communityId == null
        ? _firestore.collection('users').doc(targetUserId).collection('wallMessages').doc(messageId)
        : _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(targetUserId)
            .collection('wallMessages')
            .doc(messageId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final likes = List<String>.from(data['likes'] ?? []);

      if (likes.contains(currentUserId)) {
        likes.remove(currentUserId);
      } else {
        likes.add(currentUserId);
      }

      transaction.update(docRef, {'likes': likes});
    });
  }

  @override
  Future<void> addWallMessageReply(String targetUserId, String messageId, WallReply reply, {String? communityId}) async {
    final docRef = communityId == null
        ? _firestore.collection('users').doc(targetUserId).collection('wallMessages').doc(messageId)
        : _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(targetUserId)
            .collection('wallMessages')
            .doc(messageId);

    await docRef.update({
      'replies': FieldValue.arrayUnion([reply.toFirestore()])
    });
  }

  @override
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();
    
    // Add to blockedUserIds array
    batch.update(
      _firestore.collection('users').doc(currentUserId),
      {'blockedUserIds': FieldValue.arrayUnion([targetUserId])},
    );

    // Add to current user's blocked subcollection
    batch.set(
      _firestore.collection('users').doc(currentUserId).collection('blocked').doc(targetUserId),
      {'blockedAt': FieldValue.serverTimestamp()},
    );
    
    // Optional: Unfollow automatically when blocking
    batch.delete(
      _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId),
    );
    batch.delete(
      _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId),
    );
    
    await batch.commit();
  }

  @override
  Future<void> reportUser({
    required String reporterId,
    required String targetUserId,
    required String reason,
    String? communityId,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'targetId': targetUserId,
      'type': 'user',
      'reason': reason,
      'communityId': communityId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  @override
  Future<void> purchaseBubblePack(String userId, BubblePack pack) async {
    final docRef = _firestore.collection('users').doc(userId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Usuario no encontrado');

      final data = snapshot.data()!;
      
      // 1. Verificar saldo
      final currentCoins = (data['coins'] ?? 0) as int;
      if (currentCoins < pack.price) {
        throw Exception('Saldo insuficiente. Necesitas ${pack.price} monedas.');
      }

      final currentOwnedStyles = (data['ownedBubbleStyles'] as List<dynamic>?)
              ?.map((s) => ChatBubbleStyle.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [];

      // Combinar estilos sin duplicar por ID
      final newStyles = [...currentOwnedStyles];
      for (final style in pack.styles) {
        if (!newStyles.any((existing) => existing.id == style.id)) {
          newStyles.add(style);
        }
      }

      transaction.update(docRef, {
        'coins': FieldValue.increment(-pack.price),
        'ownedBubbleStyles': newStyles.map((s) => s.toMap()).toList(),
      });
    });
  }

  @override
  Future<void> publishWorkshopPack(BubblePack pack) async {
    final docRef = _firestore.collection('workshop_bubbles').doc(pack.id);
    
    List<ChatBubbleStyle> updatedStyles = [];
    for (var style in pack.styles) {
       String? bg = await _uploadOrnamentIfNeeded(style.id, 'bg', style.backgroundImageUrl);
       String? tl = await _uploadOrnamentIfNeeded(style.id, 'tl', style.topLeftOrnamentUrl);
       String? tr = await _uploadOrnamentIfNeeded(style.id, 'tr', style.topRightOrnamentUrl);
       String? bl = await _uploadOrnamentIfNeeded(style.id, 'bl', style.bottomLeftOrnamentUrl);
       String? br = await _uploadOrnamentIfNeeded(style.id, 'br', style.bottomRightOrnamentUrl);
       
       AdvancedBubbleConfig? updatedConfig = style.advancedConfig;
       if (updatedConfig != null) {
         List<BubbleLayer> updatedLayers = [];
         for (int i = 0; i < updatedConfig.layers.length; i++) {
           final layer = updatedConfig.layers[i];
           String? layerUrl = await _uploadOrnamentIfNeeded(style.id, 'layer_$i', layer.url);
           updatedLayers.add(layer.copyWith(url: layerUrl ?? layer.url));
         }
         updatedConfig = updatedConfig.copyWith(layers: updatedLayers);
       }

       updatedStyles.add(style.copyWith(
         backgroundImageUrl: bg ?? '',
         topLeftOrnamentUrl: tl ?? '',
         topRightOrnamentUrl: tr ?? '',
         bottomLeftOrnamentUrl: bl ?? '',
         bottomRightOrnamentUrl: br ?? '',
         advancedConfig: updatedConfig,
       ));
    }
    
    final updatedPack = BubblePack(
      id: pack.id,
      name: pack.name,
      description: pack.description,
      category: pack.category,
      price: pack.price,
      creatorId: pack.creatorId,
      isPublic: pack.isPublic,
      styles: updatedStyles,
    );

    await docRef.set(updatedPack.toMap());
  }

  Future<String?> _uploadOrnamentIfNeeded(String styleId, String corner, String? url) async {
    if (url == null || url.isEmpty || url.startsWith('http') || url.startsWith('assets/')) {
      return url;
    }
    
    final cleanPath = url.replaceFirst('file://', '');
    final file = File(cleanPath);
    if (!file.existsSync()) return url;

    try {
      final compressedFile = await MediaHelper.compressFile(file);
      final ext = file.path.split('.').last;
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('workshop_media').child('$styleId\_$corner\_$uniqueId.$ext');
      final uploadTask = await ref.putFile(compressedFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading ornament: $e');
      return url;
    }
  }

  @override
  Stream<List<BubblePack>> getWorkshopPacks() {
    return _firestore
        .collection('workshop_bubbles')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BubblePack.fromMap({'id': doc.id, ...doc.data()})).toList();
    });
  }

  // ──── Economy System ────

  @override
  Future<void> updateCoins(String userId, int amount) async {
    await _firestore.collection('users').doc(userId).set({
      'coins': FieldValue.increment(amount),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> donateCoins({
    required String senderId,
    required String receiverId,
    required int amount,
    String? postId,
    String? wikiId,
    String? communityId,
  }) async {
    if (senderId == receiverId) throw Exception('No puedes donarte a ti mismo.');
    if (amount <= 0) throw Exception('La cantidad de donación debe ser mayor a 0.');

    await _firestore.runTransaction((transaction) async {
      // 1. Obtener balance del remitente
      final senderDoc = await transaction.get(_firestore.collection('users').doc(senderId));
      if (!senderDoc.exists) throw Exception('Usuario remitente no encontrado.');
      
      final senderCoins = (senderDoc.data()?['coins'] ?? 0) as int;
      if (senderCoins < amount) throw Exception('Saldo insuficiente.');

      // 2. Descontar del remitente
      transaction.update(senderDoc.reference, {
        'coins': FieldValue.increment(-amount),
      });

      // 3. Sumar al destinatario
      transaction.update(_firestore.collection('users').doc(receiverId), {
        'coins': FieldValue.increment(amount),
      });

      // 4. Registrar la transacción
      final historyRef = _firestore.collection('economy_transactions').doc();
      transaction.set(historyRef, {
        'senderId': senderId,
        'receiverId': receiverId,
        'amount': amount,
        'postId': postId,
        'wikiId': wikiId,
        'communityId': communityId,
        'type': 'donation',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Crear notificación para el destinatario
      final notificationRef = _firestore
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .doc();

      final senderData = senderDoc.data();
      final senderName = senderData?['displayName'] ?? 'Un usuario';
      final senderAvatar = senderData?['avatarUrl'] ?? '';

      transaction.set(notificationRef, {
        'id': notificationRef.id,
        'type': 'donation',
        'title': '¡Has recibido una donación!',
        'body': '$senderName te ha enviado $amount monedas.',
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatar,
        'postId': postId,
        'wikiId': wikiId,
        'communityId': communityId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> updateEmail(String newEmail, String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    // Re-autenticación obligatoria para cambiar email
    final cred = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  @override
  Future<void> updatePassword(String oldPassword, String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    final cred = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> deleteAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    final userId = user.uid;
    final cred = EmailAuthProvider.credential(email: user.email!, password: password);
    
    await user.reauthenticateWithCredential(cred);
    
    // Borrar de Firestore primero (importante hacerlo antes que el Auth delete para evitar inconsistencias si Auth falla al final)
    await _firestore.collection('users').doc(userId).delete();
    
    // Borrar de Auth
    await user.delete();
  }

  @override
  Future<void> performCheckIn(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception('Usuario no encontrado');
      
      final data = snapshot.data()!;
      final lastCheckInTimestamp = data['lastCheckIn'] as Timestamp?;
      final DateTime now = DateTime.now();
      
      if (lastCheckInTimestamp != null) {
        final lastCheckIn = lastCheckInTimestamp.toDate();
        if (lastCheckIn.year == now.year && 
            lastCheckIn.month == now.month && 
            lastCheckIn.day == now.day) {
          return; // Already checked in today
        }
      }

      int newStreak = 1;
      if (lastCheckInTimestamp != null) {
        final lastCheckIn = lastCheckInTimestamp.toDate();
        final yesterday = now.subtract(const Duration(days: 1));
        if (lastCheckIn.year == yesterday.year && 
            lastCheckIn.month == yesterday.month && 
            lastCheckIn.day == yesterday.day) {
          newStreak = (data['checkInStreak'] ?? 0) + 1;
        }
      }

      transaction.update(userRef, {
        'checkIns': FieldValue.increment(1),
        'checkInStreak': newStreak,
        'lastCheckIn': FieldValue.serverTimestamp(),
        'reputation': FieldValue.increment(10), // +10 Rep
      });
    });
  }

  @override
  Future<void> purchaseFrame(String userId, String frameUrl, int price) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception('Usuario no encontrado');
      
      final data = snapshot.data()!;
      final int currentCoins = data['coins'] ?? 0;
      final List<String> ownedFrames = List<String>.from(data['ownedFrames'] ?? []);
      
      if (ownedFrames.contains(frameUrl)) {
        throw Exception('¡Ya tienes este marco en tu colección! ✨');
      }
      
      if (currentCoins < price) {
        throw Exception('No tienes suficientes Wumble Coins. 🪙');
      }
      
      transaction.update(userRef, {
        'coins': currentCoins - price,
        'ownedFrames': FieldValue.arrayUnion([frameUrl]),
      });
    });
  }

  @override
  Future<void> purchasePack(String userId, String packId) async {
    final packFramesQuery = await _firestore
        .collection('avatar_frames')
        .where('packId', isEqualTo: packId)
        .get();

    if (packFramesQuery.docs.isEmpty) {
      throw Exception('No se encontraron marcos para este pack. 😕');
    }

    final List<CustomAvatarFrame> packFrames = packFramesQuery.docs
        .map((doc) => CustomAvatarFrame.fromMap(doc.data(), doc.id))
        .toList();

    final int packPrice = packFrames.first.packPrice;
    final int packSize = packFrames.first.packSize;

    if (packPrice == 0 || packSize == 0) {
      throw Exception('Este no es un pack válido para compra conjunta. ❌');
    }

    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception('Usuario no encontrado');

      final data = userDoc.data()!;
      final int currentCoins = data['coins'] ?? 0;
      final List<String> ownedFrames = List<String>.from(data['ownedFrames'] ?? []);

      // Calculate how many frames from this pack the user already owns
      final ownedFromPack = packFrames.where((f) => ownedFrames.contains(f.id)).toList();
      
      if (ownedFromPack.length == packFrames.length) {
        throw Exception('¡Ya tienes el pack completo! ✨');
      }

      // Dynamic price: PackPrice - (OwnedCount * (PackPrice / PackSize))
      // Or simply: MissingCount * IndividualPrice
      final int missingCount = packFrames.length - ownedFromPack.length;
      final int individualPrice = (packPrice / packSize).ceil();
      final int finalPrice = missingCount * individualPrice;

      if (currentCoins < finalPrice) {
        throw Exception('No tienes suficientes Wumble Coins para completar el pack. 🪙');
      }

      final List<String> newFrameIds = packFrames.map((f) => f.id).toList();

      transaction.update(userRef, {
        'coins': currentCoins - finalPrice,
        'ownedFrames': FieldValue.arrayUnion(newFrameIds),
      });
    });
  }

  @override
  Future<void> equipFrame(String userId, String? frameUrl) async {
    await _firestore.collection('users').doc(userId).update({
      'avatarFrameUrl': frameUrl,
    });
    
    // Instant UI sync
    UserProfileManager.updateCache(userId, {'avatarFrameUrl': frameUrl});
  }

  // ──── Settings ────

  @override
  Future<void> updateSettings(String userId, Map<String, dynamic> settings) async {
    await _firestore.collection('users').doc(userId).update(settings);
  }

  @override
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    await _firestore.collection('users').doc(currentUserId).update({
      'blockedUserIds': FieldValue.arrayRemove([targetUserId]),
    });
  }

  @override
  Stream<List<UserProfile>> getBlockedUsers(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((doc) async {
      final data = doc.data();
      if (data == null) return <UserProfile>[];
      final ids = List<String>.from(data['blockedUserIds'] ?? []);
      if (ids.isEmpty) return <UserProfile>[];
      final futures = ids.map((id) => getUserProfile(id).first);
      return (await Future.wait(futures)).toList();
    });
  }
}
