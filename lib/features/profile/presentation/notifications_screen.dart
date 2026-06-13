import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme.dart';
import '../domain/notification_model.dart';
import '../domain/notification_repository.dart';
import '../../../core/services/notification_helper.dart';
import '../../../injection_container.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<ActivityNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchNotifications();
    
    // Automatically mark all as read when entering the screen
    sl<NotificationRepository>().markAllAsRead(widget.userId);
  }

  Future<List<ActivityNotification>> _fetchNotifications() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get()
        .then((snapshot) => snapshot.docs
            .map((doc) => ActivityNotification.fromMap(doc.data(), doc.id))
            .where((notif) => notif.type != 'chat')
            .toList());
  }

  void _refresh() {
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: const Text('Borrar todo', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que quieres borrar todas las notificaciones?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('notifications')
            .get()
            .then((snapshot) {
              final batch = FirebaseFirestore.instance.batch();
              for (var doc in snapshot.docs) {
                if (doc.data()['type'] != 'chat') {
                  batch.delete(doc.reference);
                }
              }
              return batch.commit();
            });
        _refresh();
      } catch (e) {
        debugPrint('Error clearing notifications: $e');
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  String _timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 1) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Ahora';
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'post_like':
      case 'comment_like':
        return Icons.favorite;
      case 'post_comment':
      case 'comment_reply':
        return Icons.chat_bubble;
      case 'wall':
        return Icons.note_alt;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'post_like':
      case 'comment_like':
        return Colors.redAccent;
      case 'post_comment':
      case 'comment_reply':
        return Colors.blueAccent;
      case 'follow':
        return Wumbleheme.secondaryColor;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Wumbleheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
            tooltip: 'Borrar todo',
            onPressed: _clearAll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Actualizar',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe_left, size: 16, color: Wumbleheme.secondaryColor.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'Desliza hacia la izquierda para eliminar',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ActivityNotification>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error cargando notificaciones',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sin nuevas notificaciones',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: notifications.length,
                  padding: EdgeInsets.zero,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return Dismissible(
                      key: Key(notif.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        _deleteNotification(notif.id);
                        setState(() {
                          notifications.removeAt(index);
                        });
                      },
                      child: InkWell(
                        onTap: () {
                          if (!notif.isRead) {
                            _markAsRead(notif.id);
                          }
                          NotificationNavigator.navigate(context, notif.toMap());
                        },
                        child: Container(
                          color: notif.isRead ? Colors.transparent : Colors.white.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  UserAvatar(
                                    userId: notif.senderId,
                                    avatarUrl: notif.senderAvatarUrl,
                                    displayName: notif.senderName,
                                    radius: 24,
                                    communityId: notif.communityId,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Wumbleheme.backgroundColor,
                                      child: notif.communityAvatarUrl != null && notif.communityAvatarUrl!.isNotEmpty
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl: notif.communityAvatarUrl!,
                                                width: 18,
                                                height: 18,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Icon(
                                              _getIconForType(notif.type),
                                              size: 12,
                                              color: _getColorForType(notif.type),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (notif.communityName != null) ...[
                                      Text(
                                        notif.communityName!,
                                        style: const TextStyle(
                                          color: Wumbleheme.secondaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        children: [
                                          TextSpan(
                                            text: '${notif.senderName} ',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(
                                            text: notif.body.replaceFirst('${notif.senderName} ', ''),
                                            style: TextStyle(
                                              color: notif.isRead ? Colors.white60 : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeAgo(notif.createdAt),
                                      style: TextStyle(
                                        color: notif.isRead ? Colors.white38 : Wumbleheme.secondaryColor,
                                        fontSize: 12,
                                        fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
