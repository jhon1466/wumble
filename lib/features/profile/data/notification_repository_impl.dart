import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/notification_model.dart';
import '../domain/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final filtered = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['type'] != 'chat';
          }).toList();
          debugPrint('NotificationRepo: Total unread docs: ${snapshot.docs.length}, Filtered (non-chat): ${filtered.length}');
          return filtered.length;
        });
  }

  @override
  Stream<int> getUnreadChatCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'chat')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Future<void> markRoomNotificationsAsRead(String userId, String roomId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('roomId', isEqualTo: roomId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  @override
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  @override
  Stream<List<ActivityNotification>> getNotifications(String userId, {int limit = 50}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityNotification.fromMap(doc.data(), doc.id))
            .where((notif) => notif.type != 'chat')
            .toList());
  }

  @override
  Future<void> clearNotifications(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final type = doc.data()['type'];
      if (type != 'chat') {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  @override
  Stream<Map<String, int>> getCommunityUnreadCounts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final Map<String, int> counts = {};
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final String? communityId = data['communityId'];
            if (communityId != null && communityId.isNotEmpty) {
              counts[communityId] = (counts[communityId] ?? 0) + 1;
            }
          }
          return counts;
        });
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      if (doc.data()['type'] != 'chat') {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
