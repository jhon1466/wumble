import 'package:wumble/features/profile/domain/notification_model.dart';

abstract class NotificationRepository {
  /// Stream of total unread notification count for a user
  Stream<int> getUnreadCount(String userId);

  /// Stream of unread chat notification count for a user
  Stream<int> getUnreadChatCount(String userId);

  /// Mark all notifications for a specific chat room as read
  Future<void> markRoomNotificationsAsRead(String userId, String roomId);

  /// Mark a single notification as read
  Future<void> markAsRead(String userId, String notificationId);

  /// Delete a notification
  Future<void> deleteNotification(String userId, String notificationId);

  /// Get a stream of notifications
  Stream<List<ActivityNotification>> getNotifications(String userId, {int limit = 50});

  /// Clear all non-chat notifications
  Future<void> clearNotifications(String userId);

  /// Stream of unread counts per community
  Stream<Map<String, int>> getCommunityUnreadCounts(String userId);

  /// Mark all non-chat notifications as read for a user
  Future<void> markAllAsRead(String userId);
}
