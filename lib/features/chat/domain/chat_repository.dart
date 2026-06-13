import 'chat_model.dart';
import '../../profile/domain/user_model.dart';

abstract class ChatRepository {
  /// Stream of chat rooms the user participates in, ordered by last message time
  Stream<List<ChatRoom>> getChatRooms(String userId);

  /// Stream of a specific chat room
  Stream<ChatRoom?> getChatRoom(String chatRoomId);

  /// Stream of messages in a specific chat room, ordered by timestamp.
  /// Returns only the last 30 messages for efficiency.
  Stream<List<ChatMessage>> getMessages(String chatRoomId);

  /// One-time fetch of [limit] messages older than [beforeTimestamp].
  /// Used for scroll-up pagination to load chat history.
  Future<List<ChatMessage>> getMessagesBefore(
    String chatRoomId, {
    required DateTime beforeTimestamp,
    int limit = 30,
  });

  /// Send a message to a chat room
  Future<void> sendMessage(String chatRoomId, ChatMessage message);

  Stream<List<ChatRoom>> getPublicChats(String communityId, {String? userId});
  
  /// Create a group chat room (public or private)
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
  });

  /// Join a public chat room
  Future<void> joinPublicChat({
    required String chatRoomId,
    required String userId,
    required String username,
    required String userAvatar,
  });

  /// Delete a message from a chat room
  Future<void> deleteMessage(String chatRoomId, String messageId);

  /// Edit a text message in a chat room
  Future<void> editMessage(String chatRoomId, String messageId, String newText);
  
  /// Add or remove a reaction (emoji or sticker URL) to/from a message
  Future<void> reactToMessage(String chatRoomId, String messageId, String userId, String reaction);

  /// Clear all messages in a chat room
  Future<void> clearChat(String chatRoomId);

  /// Update the background image of a chat room
  Future<void> updateChatBackground(String chatRoomId, String? imageUrl);

  /// Get or create a 1:1 chat room between two users
  Future<ChatRoom> getOrCreateChatRoom({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
  });

  /// Invite a member to a group chat room
  Future<void> inviteMemberToChat(String chatRoomId, UserProfile user);

  /// Delete a chat room and all its content
  Future<void> deleteChatRoom(String chatRoomId);

  /// Leave a chat room (1:1 or group). For 1:1, sends a system message.
  Future<void> leaveChat(String chatRoomId, String userId, String username);

  /// Accept a pending 1:1 chat request
  Future<void> acceptChatRequest(String chatRoomId, String userId, String username);

  /// Reject a pending 1:1 chat request
  Future<void> rejectChatRequest(String chatRoomId, String userId);

  /// Update chat room metadata
  Future<void> updateChatRoom(
    String chatRoomId, {
    String? title,
    String? description,
    String? imageUrl,
    String? bannerUrl, // NEW
  });

  /// ──── Live Session Methods ────

  /// Stream of the active Live session in a chat room
  Stream<LiveSession?> getLiveSession(String chatRoomId);

  /// Start a Live session
  Future<void> startLiveSession({
    required String chatRoomId,
    required String hostId,
    required String hostName,
    required String hostAvatar,
  });

  /// End a Live session
  Future<void> endLiveSession(String chatRoomId);

  /// Join an active Live session
  Future<void> joinLiveSession(String chatRoomId, LiveParticipant participant);

  /// Leave a Live session
  Future<void> leaveLiveSession(String chatRoomId, String userId);

  /// Update participant status (mic, speaking, role)
  Future<void> updateParticipantStatus(
    String chatRoomId,
    String userId, {
    bool? isMicOn,
    bool? isSpeaking,
    String? role,
  });

  /// ──── Sticker Management ────

  /// One-time fetch of user favorite stickers (no need for real-time updates)
  Future<List<String>> getFavoriteStickers(String userId);


  /// Add a sticker to favorites
  Future<void> addStickerToFavorites(String userId, String stickerUrl);

  /// Remove a sticker from favorites
  Future<void> removeStickerFromFavorites(String userId, String stickerUrl);

  /// ──── Typing Indicators ────

  /// Update user typing status
  Future<void> updateTypingStatus(String chatRoomId, String userId, String username, bool isTyping);

  /// Stream of users currently typing in a room
  Stream<List<TypingUser>> getTypingUsers(String chatRoomId);

  // ──── Moderation & Administration ────

  /// Appoint a user as curator (Owner only)
  Future<void> appointCurator(String chatRoomId, String userId);

  /// Remove a user from curators (Owner only)
  Future<void> removeCurator(String chatRoomId, String userId);

  /// Ban a user from the chat (Owner/Curator only)
  Future<void> banUserFromChat(String chatRoomId, String userId);

  /// Unban a user from the chat (Owner/Curator only)
  Future<void> unbanUserFromChat(String chatRoomId, String userId);

  /// Toggle the locked/closed status of a chat room (Owner/Moderator only)
  Future<void> toggleChatRoomLock(String chatRoomId, bool isClosed);

  /// Reset unread count for a user in a particular room
  Future<void> markChatAsRead(String chatRoomId, String userId);

}
