import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import '../../injection_container.dart' as di;
import '../../features/profile/domain/profile_repository.dart';
import '../../features/profile/domain/user_model.dart';
import '../../features/chat/domain/chat_repository.dart';
import '../../features/chat/domain/chat_model.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'notification_helper.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Global log to see when a new isolate loads this file
final int _isolateId = DateTime.now().millisecondsSinceEpoch;
void _logIsolate(String msg) => print("[Isolate $_isolateId] $msg");

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _logIsolate("--- FCM BACKGROUND HANDLER ---");
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  
  // We don't necessarily need to initialize local notifications here 
  // if we are just calling a static method that uses the plugin.
  // But let's see if NOT doing it avoids the "duplicate isolate" warning.
  print("Handling message: ${message.messageId}");
  
  if (message.data.containsKey('roomId')) {
    await NotificationService.processAndShowNotification(message);
  }
}
// Removed the local top-level function as it's now in background_handler.dart

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? navigatorKey;
  static String? currentChatRoomId;
  static Map<String, dynamic>? _pendingPayload;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    // 1. Request Permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await ensureLocalNotificationsInitialized();

    // 2. Handle Foreground FCM Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("--- FOREGROUND FCM MESSAGE ---");
      final roomId = message.data['roomId'];
      // Skip if we are already in this chat room
      if (currentChatRoomId != null && roomId == currentChatRoomId) {
        print("Skipping foreground notification: User is in the room $roomId");
        return;
      }
      
      if (message.data.containsKey('roomId')) {
        processAndShowNotification(message);
      }
    });

    // 3. Handle Background Tap (App in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("--- FCM MESSAGE OPENED APP ---");
      _handleNotificationTap(message.data);
    });

    // 4. Handle Cold Start (Terminated state)
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print("--- FCM INITIAL MESSAGE FOUND ---");
      _pendingPayload = initialMessage.data;
    }

    final NotificationAppLaunchDetails? details = await _localNotifications.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp && details.notificationResponse?.payload != null) {
      print("--- LOCAL NOTIFICATION LAUNCH FOUND ---");
      try {
        _pendingPayload = jsonDecode(details.notificationResponse!.payload!);
      } catch (e) {
        print("Error decoding launch payload: $e");
      }
    }

    // 5. Register Background Handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static void handlePendingNotification(BuildContext context) {
    if (_pendingPayload != null) {
      print("Processing pending notification payload...");
      final data = Map<String, dynamic>.from(_pendingPayload!);
      _pendingPayload = null;
      NotificationNavigator.navigate(context, data);
    }
  }

  static Future<void> ensureLocalNotificationsInitialized() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleNotificationTap(jsonDecode(response.payload!));
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    
    print("Local Notifications Initialized.");
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (navigatorKey == null) {
      _pendingPayload = data;
      return;
    }
    final context = navigatorKey!.currentContext;
    if (context == null) {
      print("Navigator context not ready, storing as pending payload.");
      _pendingPayload = data;
      return;
    }
    
    NotificationNavigator.navigate(context, data);
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }


  static Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final http.Response response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print("Error downloading notification bytes: $e");
      return null;
    }
  }

  static Future<Uint8List?> _circleCrop(Uint8List bytes) async {
    try {
      print("--- CIRCLE CROP START ---");
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        print("Circle crop failed: could not decode image");
        return bytes;
      }
      
      print("Original size: ${image.width}x${image.height}");
      
      // Ensure we have an alpha channel for transparency
      if (image.numChannels < 4) {
        image = image.convert(numChannels: 4);
      }
      
      // 1. Resize to a manageable square size (e.g., 256x256)
      image = img.copyResizeCropSquare(image, size: 256);
      
      // 2. Apply circle mask
      final img.Image circularImage = img.copyCropCircle(image);
      
      final Uint8List result = Uint8List.fromList(img.encodePng(circularImage));
      print("Circle crop success. Result size: ${result.length} bytes (256x256)");
      return result;
    } catch (e, stack) {
      print("Error cropping avatar to circle: $e\n$stack");
      return bytes;
    }
  }

  static Future<void> processAndShowNotification(RemoteMessage message) async {
    _logIsolate("--- processAndShowNotification START ---");
    final data = message.data;
    final notification = message.notification;
    final String? roomId = data['roomId'];
    final String? senderAvatarUrl = data['senderAvatarUrl'];
    final String? senderName = data['senderName'] ?? data['title'] ?? notification?.title ?? 'Usuario';
    final String? rawSenderName = data['senderName'];
    String? text = data['text'] ?? data['content'] ?? data['message'] ?? data['body'] ?? notification?.body ?? 'Has recibido un mensaje';
    
    // Strip redundant "Sender: " from the beginning of the text to avoid duplication in MessagingStyle
    // We check both the resolved senderName and the raw senderName from metadata
    if (text != null) {
      if (rawSenderName != null && text!.startsWith('$rawSenderName: ')) {
        text = text!.substring('$rawSenderName: '.length);
      } else if (senderName != null && text!.startsWith('$senderName: ')) {
        text = text!.substring('$senderName: '.length);
      }
    }
    
    final int notificationId = roomId?.hashCode ?? notification?.hashCode ?? 0;

    print("Showing notification ID: $notificationId, Tag: $roomId");
    final String encodedPayload = jsonEncode(data);

    Uint8List? senderIconBytes;
    String? resolvedAvatarUrl = senderAvatarUrl;

    // --- FALLBACK LOGIC ---
    // If URL is missing or download fails, try to fetch from Firestore
    if (resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty) {
      _logIsolate("Avatar URL missing in payload. Attempting Firestore fallback for sender: ${data['senderId']}");
      final senderId = data['senderId'];
      if (senderId != null) {
        try {
          // We use the direct Firestore instance as we might be in a background isolate
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
          if (userDoc.exists) {
            resolvedAvatarUrl = userDoc.data()?['avatarUrl'];
            _logIsolate("Firestore fallback success: $resolvedAvatarUrl");
          }
        } catch (e) {
          _logIsolate("Firestore fallback failed: $e");
        }
      }
    }

    if (resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty) {
      final rawBytes = await _downloadBytes(resolvedAvatarUrl);
      if (rawBytes != null) {
        senderIconBytes = await _circleCrop(rawBytes);
      }
    }

    final person = Person(
      name: senderName,
      key: data['senderId'] ?? 'unknown',
      icon: senderIconBytes != null ? ByteArrayAndroidIcon(senderIconBytes) : null,
    );

    await _localNotifications.show(
      notificationId,
      senderName,
      text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          tag: roomId,
          styleInformation: MessagingStyleInformation(
            person,
            messages: [
              Message(
                text!,
                DateTime.now(),
                person,
              ),
            ],
            groupConversation: roomId != null, // Treat all as group if roomId present
            conversationTitle: data['roomTitle'] ?? data['title'],
          ),
        ),
      ),
      payload: encodedPayload,
    );
  }


  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  static Future<void> scheduleBirthdayNotification(DateTime birthday) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      
      // Fecha para este año a las 9:00 AM
      var scheduledDate = tz.TZDateTime(tz.local, now.year, birthday.month, birthday.day, 9, 0);
      
      // Si ya pasó este año, programar para el próximo
      if (scheduledDate.isBefore(now)) {
        scheduledDate = tz.TZDateTime(tz.local, now.year + 1, birthday.month, birthday.day, 9, 0);
      }

      await _localNotifications.zonedSchedule(
        888, // ID único para cumpleaños
        '¡Feliz Cumpleaños! 🎉',
        '¡De parte de toda la comunidad Wumble te deseamos lo mejor! Entra para celebrarlo. ✨',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime, // Repetir cada año
      );
      
      print("Notificación de cumpleaños programada para: $scheduledDate");
    } catch (e) {
      print("Error al programar notificación de cumpleaños: $e");
    }
  }
}
