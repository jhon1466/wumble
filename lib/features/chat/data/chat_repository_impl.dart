import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../domain/chat_model.dart';
import '../data/bot_service.dart';
import '../domain/chat_repository.dart';
import '../../profile/domain/user_model.dart';
import '../../../core/utils/link_preview_helper.dart';
import '../../../core/domain/link_preview_data.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BotService _botService = BotService();

  @override
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());
  }

  @override
  Stream<ChatRoom?> getChatRoom(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .snapshots()
        .map((doc) => doc.exists ? ChatRoom.fromFirestore(doc) : null);
  }

  @override
  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(30) // Load only last 30 messages — saves massive reads on old chats
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  @override
  Future<List<ChatMessage>> getMessagesBefore(
    String chatRoomId, {
    required DateTime beforeTimestamp,
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .endBefore([Timestamp.fromDate(beforeTimestamp)])
          .limitToLast(limit)
          .get();
      return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading older messages: $e');
      return [];
    }
  }

  /// In-memory cache for chatRoom data — avoids a .get() on every sendMessage
  final Map<String, bool> _isPublicCache = {};
  final Map<String, Map<String, dynamic>> _roomDataCache = {};
  
  /// In-memory cache for favorite stickers — avoids Firestore reads on every StickerSelector build
  final Map<String, List<String>> _favoriteStickersCache = {};

  @override
  Future<void> sendMessage(String chatRoomId, ChatMessage message) async {
    final batch = _firestore.batch();
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final msgRef = roomRef.collection('messages').doc();
    
    // --- LINK PREVIEW DETECTION ---
    LinkPreviewData? linkPreview;
    if (message.text != null && message.text!.isNotEmpty) {
      final firstUrl = LinkPreviewHelper.extractFirstUrl(message.text!);
      if (firstUrl != null) {
        linkPreview = await LinkPreviewHelper.fetchMetadata(firstUrl);
      }
    }

    final messageData = message.toFirestore();
    if (linkPreview != null) {
      messageData['linkPreview'] = linkPreview.toMap();
    }

    batch.set(msgRef, messageData);

    // Use cached room data if available — avoids a Firestore read on EVERY message
    Map<String, dynamic> roomData;
    if (_roomDataCache.containsKey(chatRoomId)) {
      roomData = _roomDataCache[chatRoomId]!;
    } else {
      final roomDoc = await roomRef.get();
      roomData = (roomDoc.data() as Map<String, dynamic>?) ?? {};
      _roomDataCache[chatRoomId] = roomData; // Cache for subsequent messages
    }

    String senderName = message.senderName ?? 'Usuario';
    String senderAvatar = message.senderAvatarUrl ?? '';
    
    // --- GUARANTEED AVATAR FALLBACK ---
    if (senderAvatar.isEmpty) {
      senderAvatar = FirebaseAuth.instance.currentUser?.photoURL ?? '';
    }

    if (!_isPublicCache.containsKey(chatRoomId)) {
      _isPublicCache[chatRoomId] = (roomData['isPublic'] ?? false) as bool;
      if (_isPublicCache[chatRoomId] == true) {
        final roomTitle = roomData['title'] ?? 'Sala';
        senderName = '[$roomTitle] $senderName';
      }
    } else if (_isPublicCache[chatRoomId] == true) {
      senderName = '[Chat] $senderName';
    }

    final List<String> participants = List<String>.from(roomData['participants'] ?? []);
    final Map<String, int> unreadCounts = Map<String, int>.from(roomData['unreadCounts'] ?? {});
    final isPublic = roomData['isPublic'] ?? false;
    final bool isOneOnOne = roomData['privateChatKey'] != null;
    final roomTitle = roomData['title'] ?? (isPublic ? 'Sala' : 'Chat');

    for (final participantId in participants) {
      if (participantId != message.senderId && !participantId.startsWith('BOT_')) {
        // Increment unread count for all participants (optimized for non-saturated groups)
        if (participants.length <= 100) {
          unreadCounts[participantId] = (unreadCounts[participantId] ?? 0) + 1;
        }

        final notifRef = _firestore.collection('users').doc(participantId).collection('notifications').doc();
        
        final isReplyToThisUser = message.replyToUserId == participantId;
        final notifTitle = isReplyToThisUser ? 'Nueva respuesta' : (isPublic ? roomTitle : 'Nuevo mensaje');
        final notifBody = isReplyToThisUser 
            ? '${message.senderName} respondió a tu mensaje'
            : (message.text ?? (message.type == MessageType.image ? 'Imagen' : message.type == MessageType.sticker ? 'Sticker' : 'Audio'));

        batch.set(notifRef, {
          'id': notifRef.id,
          'type': 'chat',
          'title': notifTitle,
          'body': notifBody,
          'senderId': message.senderId,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatar,
          'roomId': chatRoomId,
          'isPublic': isPublic,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    }



    batch.update(roomRef, {
      'lastMessage': message.text ?? (message.type == MessageType.image ? 'Imagen' : message.type == MessageType.sticker ? 'Sticker' : 'Audio'),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': message.senderId,
      'lastSenderName': senderName,
      'lastSenderAvatar': senderAvatar,
      'unreadCounts': unreadCounts,
    });

    await batch.commit();

    // --- INTEGRACIÓN DE BOTS ---
    if (message.text != null && !message.senderId.startsWith('BOT_')) {
      try {
        final data = roomData;
        final communityId = (data['communityId'] ?? '') as String;
        
        if (communityId.isEmpty) {
          debugPrint('ChatRepository: No communityId found for room $chatRoomId. Skipping bots.');
          return;
        }
        
        debugPrint('ChatRepository: Processing bots for community: "$communityId" in room: $chatRoomId');
        
        // Fetch last 10 messages for context (excluding current)
        List<ChatMessage>? context;
        try {
          final contextSnapshot = await _firestore
              .collection('chatRooms')
              .doc(chatRoomId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(11)
              .get();
          
          context = contextSnapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .where((m) => m.id != msgRef.id)
              .toList()
              .reversed
              .toList();
        } catch (e) {
          debugPrint('ChatRepository: Error fetching context: $e');
        }

        // Check if this message is a reply to a bot
        String? replyToBotId;
        if (message.replyToId != null && context != null) {
          try {
            final repliedMsg = context.firstWhere((m) => m.id == message.replyToId);
            if (repliedMsg.senderId.startsWith('BOT_')) {
              replyToBotId = repliedMsg.senderId;
              debugPrint('ChatRepository: Detected reply to bot: $replyToBotId');
            }
          } catch (_) {
             // Replied message not in the last 10 messages context
          }
        }

        final botResponse = await _botService.processMessage(
          message.text!, 
          message.senderId, 
          communityId, 
          context: context,
          replyToBotId: replyToBotId,
        );
        
        if (botResponse != null) {
          debugPrint('ChatRepository: Bot match found! Sender: ${botResponse.senderName}');
          // Delay response to feel more natural and avoid immediate recursion issues
          Future.delayed(const Duration(milliseconds: 600), () {
            sendMessage(chatRoomId, botResponse);
          });
        } else {
          debugPrint('ChatRepository: No bot matched the message.');
        }
      } catch (e) {
        debugPrint('Error en el servicio de bots: $e');
      }
    }
  }

  @override
  Future<ChatRoom> createPublicChat({
    required String communityId,
    required String creatorId,
    required String title,
    required String description,
    required String imageUrl,
    required String creatorName,
    required String creatorAvatar,
    bool isPublic = true,
    String? backgroundImageUrl,
    String? bannerUrl, // NEW
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc();
    
    final room = ChatRoom(
      id: roomRef.id,
      participants: [creatorId],
      participantNames: {creatorId: creatorName},
      participantAvatars: {creatorId: creatorAvatar},
      lastMessage: 'Sala de chat creada',
      lastMessageTime: DateTime.now(),
      lastSenderId: creatorId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      communityId: communityId,
      isPublic: isPublic,
      creatorId: creatorId,
      backgroundImageUrl: backgroundImageUrl,
      bannerUrl: bannerUrl, // NEW
    );

    await roomRef.set(room.toFirestore());
    return room;
  }

  @override
  Future<void> joinPublicChat({
    required String chatRoomId,
    required String userId,
    required String username,
    required String userAvatar,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final List<String> bannedUserIds = List<String>.from(data['bannedUserIds'] ?? []);
      
      if (bannedUserIds.contains(userId)) {
        throw Exception('Has sido expulsado de este chat.');
      }

      final List<String> participants = List<String>.from(data['participants'] ?? []);
      
      if (!participants.contains(userId)) {
        participants.add(userId);
        
        transaction.update(roomRef, {
          'participants': participants,
          'participantNames.$userId': username,
          'participantAvatars.$userId': userAvatar,
        });
      }
    });

    // --- TRIGGER BOT EVENT: onJoin ---
    try {
      final roomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (roomDoc.exists) {
        final communityId = (roomDoc.data()?['communityId'] ?? '') as String;
        final botResponse = await _botService.processEvent('onJoin', userId, communityId);
        if (botResponse != null) {
          Future.delayed(const Duration(milliseconds: 1000), () => sendMessage(chatRoomId, botResponse));
        }
      }
    } catch (e) {
      debugPrint('Error triggering onJoin bot event: $e');
    }
  }

  @override
  Stream<List<ChatRoom>> getPublicChats(String communityId, {String? userId}) {
    final publicStream = _firestore
        .collection('chatRooms')
        .where('communityId', isEqualTo: communityId)
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());

    if (userId == null) {
      return publicStream.map((rooms) {
        rooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        return rooms;
      });
    }

    final privateStream = _firestore
        .collection('chatRooms')
        .where('communityId', isEqualTo: communityId)
        .where('isPublic', isEqualTo: false)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());

    // Import RxDart via prefix if needed, or assume it's available. 
    // Usually, we'd add 'import 'package:rxdart/rxdart.dart';' at the top.
    return Rx.combineLatest2<List<ChatRoom>, List<ChatRoom>, List<ChatRoom>>(
      publicStream,
      privateStream,
      (public, private) {
        final combined = [...public, ...private];
        final seenIds = <String>{};
        final unique = combined.where((room) => seenIds.add(room.id)).toList();
        unique.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        return unique;
      },
    );
  }

  @override
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final msgRef = roomRef.collection('messages').doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final msgDoc = await transaction.get(msgRef);
      if (!msgDoc.exists) return;

      final roomDoc = await transaction.get(roomRef);
      if (!roomDoc.exists) return;

      final deletedMsg = ChatMessage.fromFirestore(msgDoc);
      final roomData = roomDoc.data()!;
      
      // Delete the message
      transaction.delete(msgRef);

      // Check if this was the last message by comparing timestamps or IDs
      // Note: Comparing by ID is safer if they were sent at the exact same millisecond
      final isLastMessage = roomData['lastMessageTime'] != null && 
          (deletedMsg.timestamp.millisecondsSinceEpoch == (roomData['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch);

      if (isLastMessage) {
        // Find the new last message
        final latestMessages = await roomRef.collection('messages')
            .where(FieldPath.documentId, isNotEqualTo: messageId)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (latestMessages.docs.isNotEmpty) {
          final newLastMsg = ChatMessage.fromFirestore(latestMessages.docs.first);
          
          String senderName = newLastMsg.senderName ?? 'Usuario';
          if (_isPublicCache[chatRoomId] == true) {
            senderName = '[Chat] $senderName';
          }

          transaction.update(roomRef, {
            'lastMessage': newLastMsg.text ?? (newLastMsg.type == MessageType.image ? 'Imagen' : newLastMsg.type == MessageType.sticker ? 'Sticker' : 'Audio'),
            'lastMessageTime': Timestamp.fromDate(newLastMsg.timestamp),
            'lastSenderId': newLastMsg.senderId,
            'lastSenderName': senderName,
            'lastSenderAvatar': newLastMsg.senderAvatarUrl,
          });
        } else {
          // No messages left
          transaction.update(roomRef, {
            'lastMessage': '',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': null,
            'lastSenderName': null,
            'lastSenderAvatar': null,
          });
        }
      }
    });
  }

  @override
  Future<void> editMessage(String chatRoomId, String messageId, String newText) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final msgRef = roomRef.collection('messages').doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final msgDoc = await transaction.get(msgRef);
      if (!msgDoc.exists) return;

      final roomDoc = await transaction.get(roomRef);
      if (!roomDoc.exists) return;

      final message = ChatMessage.fromFirestore(msgDoc);
      final roomData = roomDoc.data()!;

      // --- LINK PREVIEW DETECTION IN EDIT ---
      LinkPreviewData? linkPreview;
      final firstUrl = LinkPreviewHelper.extractFirstUrl(newText);
      if (firstUrl != null) {
        // Only fetch if the URL has changed or it didn't have a preview
        if (message.linkPreview?.url != firstUrl) {
          linkPreview = await LinkPreviewHelper.fetchMetadata(firstUrl);
        } else {
          linkPreview = message.linkPreview;
        }
      }

      // Update message
      transaction.update(msgRef, {
        'text': newText,
        'isEdited': true,
        'linkPreview': linkPreview?.toMap() ?? FieldValue.delete(),
      });

      // Update room metadata if it was the last message
      final isLastMessage = roomData['lastMessageTime'] != null && 
          (message.timestamp.millisecondsSinceEpoch == (roomData['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch);

      if (isLastMessage) {
        transaction.update(roomRef, {
          'lastMessage': newText,
        });
      }
    });
  }

  @override
  Future<void> clearChat(String chatRoomId) async {
    final messages = await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .get();
    
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    
    // Reset lastMessage
    batch.update(
      _firestore.collection('chatRooms').doc(chatRoomId),
      {'lastMessage': '', 'lastMessageTime': FieldValue.serverTimestamp()},
    );
    
    await batch.commit();
  }

  @override
  Future<void> updateChatBackground(String chatRoomId, String? imageUrl) async {
    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .update({'backgroundImageUrl': imageUrl});
  }

  @override
  Future<ChatRoom> getOrCreateChatRoom({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
  }) async {
    // Determine the private chat key (deterministic)
    final participants = [currentUserId, otherUserId];
    participants.sort();
    final privateChatKey = participants.join('_');

    // 1. Try to fetch by DOV ID first (new standard)
    try {
      final doc = await _firestore.collection('chatRooms').doc(privateChatKey).get();
      if (doc.exists) {
        final room = ChatRoom.fromFirestore(doc);
        await _updateRoomMetadataIfNeeded(room, currentUserId, currentUserName, currentUserAvatar, otherUserId, otherUserName, otherUserAvatar);
        return room;
      }
    } catch (e) {
      debugPrint('Error fetching room by ID: $e');
    }

    // 2. Fallback: Search for existing chat room with this key via query (legacy compatibility)
    try {
      final query = await _firestore
          .collection('chatRooms')
          .where('privateChatKey', isEqualTo: privateChatKey)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final room = ChatRoom.fromFirestore(doc);
        await _updateRoomMetadataIfNeeded(room, currentUserId, currentUserName, currentUserAvatar, otherUserId, otherUserName, otherUserAvatar);
        return room;
      }
    } catch (e) {
      debugPrint('Error querying privateChatKey: $e');
      // If it's the specific failed-precondition, we know we need an index, but we'll try to proceed with ID-based creation
    }

    // --- PRIVACY CHECK ---
    bool isBot = otherUserId.startsWith('BOT_');
    String privacy = 'everyone';
    
    try {
      if (!isBot) {
        final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (otherUserDoc.exists) {
          privacy = otherUserDoc.data()?['chatInvitePrivacy'] ?? 'everyone';
        }
      }
    } catch (e) {
      debugPrint('Privacy check failed, assuming everyone: $e');
    }
    
    if (privacy == 'nobody') {
      throw Exception('Este usuario ha desactivado las invitaciones a chats privados.');
    }
    
    if (privacy == 'members') {
      try {
        final isFollowerDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .collection('followers')
            .doc(currentUserId)
            .get();
            
        if (!isFollowerDoc.exists) {
          throw Exception('Solo los seguidores de este usuario pueden invitarle a chats privados.');
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('Solo los seguidores')) rethrow;
        debugPrint('Follower check failed: $e');
      }
    }

    // No existing room found — create one using privateChatKey as ID
    final newRoom = ChatRoom(
      id: privateChatKey,
      participants: [currentUserId, otherUserId],
      participantNames: {
        currentUserId: currentUserName,
        otherUserId: otherUserName,
      },
      participantAvatars: {
        currentUserId: currentUserAvatar,
        otherUserId: otherUserAvatar,
      },
      lastMessage: '',
      lastMessageTime: DateTime.now(),
      lastSenderId: '',
      privateChatKey: privateChatKey,
      invitationStatus: isBot ? 'accepted' : 'pending',
      inviterId: currentUserId,
    );

    await _firestore.collection('chatRooms').doc(privateChatKey).set(newRoom.toFirestore());
    return newRoom;
  }

  Future<void> _updateRoomMetadataIfNeeded(
    ChatRoom room,
    String currentUserId,
    String currentUserName,
    String currentUserAvatar,
    String otherUserId,
    String otherUserName,
    String otherUserAvatar,
  ) async {
    Map<String, dynamic> metadataUpdates = {};
    
    if (room.participantNames[currentUserId] != currentUserName || 
        room.participantAvatars[currentUserId] != currentUserAvatar) {
      metadataUpdates['participantNames.$currentUserId'] = currentUserName;
      metadataUpdates['participantAvatars.$currentUserId'] = currentUserAvatar;
    }

    if (room.participantNames[otherUserId] != otherUserName || 
        room.participantAvatars[otherUserId] != otherUserAvatar) {
      metadataUpdates['participantNames.$otherUserId'] = otherUserName;
      metadataUpdates['participantAvatars.$otherUserId'] = otherUserAvatar;
    }
    
    // If a participant was removed, re-add them
    if (!room.participants.contains(currentUserId) || !room.participants.contains(otherUserId)) {
      final List<String> newParticipants = List.from(room.participants);
      if (!newParticipants.contains(currentUserId)) newParticipants.add(currentUserId);
      if (!newParticipants.contains(otherUserId)) newParticipants.add(otherUserId);
      
      metadataUpdates['participants'] = newParticipants;
      metadataUpdates['invitationStatus'] = 'pending';
      metadataUpdates['inviterId'] = currentUserId;
    }

    if (metadataUpdates.isNotEmpty) {
      await _firestore.collection('chatRooms').doc(room.id).update(metadataUpdates);
    }
  }

  @override
  Future<void> leaveChat(String chatRoomId, String userId, String username) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final roomDoc = await roomRef.get();

    if (!roomDoc.exists) return;

    final room = ChatRoom.fromFirestore(roomDoc);
    
    // Remove user ID from participants list
    final updatedParticipants = List<String>.from(room.participants)..remove(userId);
    
    // Remove user info from maps
    final updatedNames = Map<String, String>.from(room.participantNames)..remove(userId);
    final updatedAvatars = Map<String, String>.from(room.participantAvatars)..remove(userId);

    // If no participants left, delete the room
    if (updatedParticipants.isEmpty) {
      await deleteChatRoom(chatRoomId);
      return;
    }

    final batch = _firestore.batch();
    
    // Update room
    batch.update(roomRef, {
      'participants': updatedParticipants,
      'participantNames': updatedNames,
      'participantAvatars': updatedAvatars,
    });
    
    // Add system message if it's a 1:1 chat (privateChatKey exists)
    if (room.privateChatKey != null) {
      final sysMessageRef = roomRef.collection('messages').doc();
      final sysMessage = ChatMessage(
        id: sysMessageRef.id,
        senderId: 'system',
        type: MessageType.system,
        text: '$username abandonó la conversación.',
        timestamp: DateTime.now(),
      );
      batch.set(sysMessageRef, sysMessage.toFirestore());
      batch.update(roomRef, {
        'lastMessage': '$username abandonó la conversación.',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': 'system',
      });
    }

    await batch.commit();

    // --- TRIGGER BOT EVENT: onLeave ---
    try {
      if (room.communityId != null) {
        final botResponse = await _botService.processEvent('onLeave', userId, room.communityId!);
        if (botResponse != null) {
          Future.delayed(const Duration(milliseconds: 1000), () => sendMessage(chatRoomId, botResponse));
        }
      }
    } catch (e) {
      debugPrint('Error triggering onLeave bot event: $e');
    }
  }

  @override
  Future<void> acceptChatRequest(String chatRoomId, String userId, String username) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final batch = _firestore.batch();

    batch.update(roomRef, {
      'invitationStatus': 'accepted',
    });

    final sysMessageRef = roomRef.collection('messages').doc();
    final sysMessage = ChatMessage(
      id: sysMessageRef.id,
      senderId: 'system',
      type: MessageType.system,
      text: '$username se unió a la conversación.',
      timestamp: DateTime.now(),
    );

    batch.set(sysMessageRef, sysMessage.toFirestore());
    batch.update(roomRef, {
      'lastMessage': '$username se unió a la conversación.',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': 'system',
    });

    await batch.commit();
  }

  @override
  Future<void> rejectChatRequest(String chatRoomId, String userId) async {
    // For a rejection, we can simply delete the chat room to clean up
    await deleteChatRoom(chatRoomId);
  }

  @override
  Future<void> updateChatRoom(
    String chatRoomId, {
    String? title,
    String? description,
    String? imageUrl,
    String? bannerUrl, // NEW
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (bannerUrl != null) updates['bannerUrl'] = bannerUrl; // NEW

    if (updates.isNotEmpty) {
      await _firestore.collection('chatRooms').doc(chatRoomId).update(updates);
    }
  }

  @override
  Future<void> deleteChatRoom(String chatRoomId) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    
    // Delete all messages in the room
    final messages = await roomRef.collection('messages').get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete live session data if exists
    final liveSession = await roomRef.collection('live').get();
    for (final doc in liveSession.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete the room document itself
    batch.delete(roomRef);
    
    await batch.commit();
  }

  @override
  Stream<LiveSession?> getLiveSession(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('live')
        .doc('session')
        .snapshots()
        .map((doc) => doc.exists ? LiveSession.fromFirestore(doc) : null);
  }

  @override
  Future<void> startLiveSession({
    required String chatRoomId,
    required String hostId,
    required String hostName,
    required String hostAvatar,
  }) async {
    final host = LiveParticipant(
      userId: hostId,
      username: hostName,
      avatarUrl: hostAvatar,
      role: 'host',
      isMicOn: true,
      isSpeaking: false,
    );

    final session = LiveSession(
      chatRoomId: chatRoomId,
      isActive: true,
      hostId: hostId,
      participants: [host],
      startedAt: DateTime.now(),
    );

    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('live')
        .doc('session')
        .set(session.toFirestore());
  }

  @override
  Future<void> endLiveSession(String chatRoomId) async {
    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('live')
        .doc('session')
        .update({
      'isActive': false,
      'participants': [],
    });
  }

  @override
  Future<void> joinLiveSession(String chatRoomId, LiveParticipant participant) async {
    // We fetch current session to ensure we don't duplicate participants
    final docRef = _firestore.collection('chatRooms').doc(chatRoomId).collection('live').doc('session');
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final session = LiveSession.fromFirestore(snapshot);
      // Create a growable list
      final participants = List<LiveParticipant>.from(session.participants);
      
      // Remove if already exists (to avoid duplicates)
      participants.removeWhere((p) => p.userId == participant.userId);
      
      // Force Mic ON for joiner
      final p = participant.copyWith(isMicOn: true);
      participants.add(p);
      
      transaction.update(docRef, {
        'participants': participants.map((p) => p.toMap()).toList(),
      });
    });
  }

  @override
  Future<void> leaveLiveSession(String chatRoomId, String userId) async {
    final docRef = _firestore.collection('chatRooms').doc(chatRoomId).collection('live').doc('session');
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final session = LiveSession.fromFirestore(snapshot);
      final participants = session.participants;
      
      participants.removeWhere((p) => p.userId == userId);
      
      transaction.update(docRef, {
        'participants': participants.map((p) => p.toMap()).toList(),
      });
    });
  }

  @override
  Future<void> updateParticipantStatus(
    String chatRoomId,
    String userId, {
    bool? isMicOn,
    bool? isSpeaking,
    String? role,
  }) async {
    final docRef = _firestore.collection('chatRooms').doc(chatRoomId).collection('live').doc('session');
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final session = LiveSession.fromFirestore(snapshot);
      final participants = List<LiveParticipant>.from(session.participants);
      final index = participants.indexWhere((p) => p.userId == userId);
      
      if (index != -1) {
        final p = participants[index];
        participants[index] = LiveParticipant(
          userId: p.userId,
          username: p.username,
          avatarUrl: p.avatarUrl,
          role: role ?? p.role,
          isMicOn: isMicOn ?? p.isMicOn,
          isSpeaking: isSpeaking ?? p.isSpeaking,
        );
        
        transaction.update(docRef, {
          'participants': participants.map((p) => p.toMap()).toList(),
        });
      }
    });
  }

  @override
  Future<List<String>> getFavoriteStickers(String userId) async {
    // Check in-memory cache first
    if (_favoriteStickersCache.containsKey(userId)) {
      return _favoriteStickersCache[userId]!;
    }

    // One-time read — stickers don't change in real-time while user is in the chat
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favoriteStickers')
        .orderBy('addedAt', descending: true)
        .get();
    
    final stickers = snapshot.docs.map((doc) => doc.data()['url'] as String).toList();
    
    // Save to cache
    _favoriteStickersCache[userId] = stickers;
    
    return stickers;
  }

  @override
  Future<void> addStickerToFavorites(String userId, String stickerUrl) async {
    final String docId = stickerUrl.hashCode.toString();
    final favoritesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favoriteStickers');

    // Check if it already exists (to avoid counting it as new)
    final existingDoc = await favoritesRef.doc(docId).get();
    if (!existingDoc.exists) {
      final snapshot = await favoritesRef.count().get();
      if (snapshot.count != null && snapshot.count! >= 100) {
        throw Exception('ALCANZADO_LIMITE_STICKERS');
      }
    }

    await favoritesRef.doc(docId).set({
      'url': stickerUrl,
      'addedAt': FieldValue.serverTimestamp(),
    });

    // Update in-memory cache
    if (_favoriteStickersCache.containsKey(userId)) {
      if (!_favoriteStickersCache[userId]!.contains(stickerUrl)) {
        _favoriteStickersCache[userId]!.insert(0, stickerUrl);
      }
    }
  }

  @override
  Future<void> removeStickerFromFavorites(String userId, String stickerUrl) async {
    final String docId = stickerUrl.hashCode.toString();
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('favoriteStickers')
        .doc(docId)
        .delete();

    // Update in-memory cache
    if (_favoriteStickersCache.containsKey(userId)) {
      _favoriteStickersCache[userId]!.remove(stickerUrl);
    }
  }

  @override
  Future<void> updateTypingStatus(String chatRoomId, String userId, String username, bool isTyping) async {
    final ref = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('typing')
        .doc(userId);

    if (isTyping) {
      await ref.set({
        'username': username,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Stream<List<TypingUser>> getTypingUsers(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
          // Recompute threshold on EVERY emission so stale docs are filtered out
          // even if Firestore never receives the delete (e.g. user killed the app)
          final threshold = DateTime.now().subtract(const Duration(seconds: 10));
          return snapshot.docs
              .where((doc) {
                final ts = doc.data()['timestamp'];
                if (ts == null) return false;
                final dt = (ts as Timestamp?)?.toDate();
                if (dt == null) return false;
                return dt.isAfter(threshold);
              })
              .map((doc) => TypingUser.fromFirestore(doc.data(), doc.id))
              .toList();
        });
  }

  @override
  Future<void> appointCurator(String chatRoomId, String userId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'curatorIds': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Future<void> removeCurator(String chatRoomId, String userId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'curatorIds': FieldValue.arrayRemove([userId]),
    });
  }

  @override
  Future<void> banUserFromChat(String chatRoomId, String userId) async {
    final batch = _firestore.batch();
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    
    batch.update(roomRef, {
      'bannedUserIds': FieldValue.arrayUnion([userId]),
      'participants': FieldValue.arrayRemove([userId]),
    });
    
    await batch.commit();
  }

  @override
  Future<void> unbanUserFromChat(String chatRoomId, String userId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'bannedUserIds': FieldValue.arrayRemove([userId]),
    });
  }

  @override
  Future<void> toggleChatRoomLock(String chatRoomId, bool isClosed) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'isClosed': isClosed,
    });
  }

  @override
  Future<void> inviteMemberToChat(String chatRoomId, UserProfile user) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    
    // 1. Update participants and metadata
    await roomRef.update({
      'participants': FieldValue.arrayUnion([user.id]),
      'participantNames.${user.id}': user.displayName,
      'participantAvatars.${user.id}': user.avatarUrl,
    });

    // 2. Send system message
    final systemMessage = ChatMessage(
      id: '',
      senderId: 'SYSTEM',
      senderName: 'Sistema',
      text: '${user.displayName} se ha unido al chat.',
      type: MessageType.system,
      timestamp: DateTime.now(),
    );
    await sendMessage(chatRoomId, systemMessage);
  }

  @override
  Future<void> reactToMessage(String chatRoomId, String messageId, String userId, String reaction) async {
    final messageRef = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(messageRef);
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
      }

      transaction.update(messageRef, {'reactions': reactionsMap});

      // --- ADD NOTIFICATION ---
      final targetUserId = data['senderId'] as String;
      if (previousReaction != reaction && targetUserId != userId && !targetUserId.startsWith('BOT_')) {
        final notifRef = _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('notifications')
            .doc();

        // Get reactor info
        final reactorDoc = await transaction.get(_firestore.collection('users').doc(userId));
        final reactorData = reactorDoc.data() ?? {};
        final reactorName = reactorData['displayName'] ?? reactorData['username'] ?? 'Un usuario';
        final reactorAvatar = reactorData['avatarUrl'] ?? '';

        transaction.set(notifRef, {
          'id': notifRef.id,
          'type': 'chat_reaction',
          'title': 'Nueva reacción',
          'body': '$reactorName ha reaccionado a tu mensaje con $reaction',
          'senderId': userId,
          'senderName': reactorName,
          'senderAvatarUrl': reactorAvatar,
          'roomId': chatRoomId,
          'messageId': messageId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }  @override
  Future<void> markChatAsRead(String chatRoomId, String userId) async {
    try {
      final roomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!roomDoc.exists) return;
      
      final roomData = roomDoc.data() ?? {};
      
      // Update unread count for the user in Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      final Map<String, dynamic> updates = {
        'unreadCounts.$userId': 0,
        'lastReadTimes.$userId': FieldValue.serverTimestamp(),
        'participantPrivacy.$userId': {
          'showReadReceipts': userData['showReadReceipts'] ?? true,
          'showOnlineStatus': userData['showOnlineStatus'] ?? true,
        },
      };

      await _firestore.collection('chatRooms').doc(chatRoomId).update(updates);
    } catch (e) {
      debugPrint('Error marking chat as read: $e');
    }
  }

}
