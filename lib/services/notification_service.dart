import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';
import 'supabase_service.dart';
import 'local_database_service.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // 1. Silent sync: Save message to local database before showing notification
  if (message.data['type'] == 'chat' || message.data['type'] == 'message') {
    try {
      final localDb = LocalDatabaseService();
      final msg = ChatMessage(
        id: message.data['id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'model', // Typically identifying incoming messages
        senderId: message.data['senderId'] ?? '',
        senderName: message.data['senderName'] ?? 'FidelShare User',
        text: message.data['body'] ?? message.notification?.body ?? '',
        timestamp: int.tryParse(message.data['timestamp']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
        section: message.data['section'] ?? 'general',
      );
      await localDb.insertMessage(msg);
    } catch (e) {
      debugPrint("Background Data Sync Error: $e");
    }
  }

  // 2. Show the notification alert
  await _showBackgroundNotification(message);
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings();
  await plugin.initialize(const InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
  ));

  const channel = AndroidNotificationChannel(
    'updates',
    'Updates',
    description: 'Updates and messages',
    importance: Importance.max,
  );

  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Telegram-style: Use sender name as title if available
  final senderName = message.data['senderName']?.toString();
  final type = message.data['type']?.toString();
  
  String title = message.notification?.title ?? message.data['title']?.toString() ?? 'FidelShare';
  if (type == 'chat' || type == 'message') {
    if (senderName != null) {
      title = senderName;
    }
  }

  final body = message.notification?.body ?? message.data['body']?.toString() ?? '';

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'updates',
      'Updates',
      channelDescription: 'Updates and messages',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
  );
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static final StreamController<AppNotification> _controller =
      StreamController<AppNotification>.broadcast();
  static bool _initialized = false;
  static bool _tokenListenerAttached = false;

  static Stream<AppNotification> get notifications => _controller.stream;

  static Future<void> initialize({bool isBackground = false}) async {
    if (_initialized) return;
    await Firebase.initializeApp();
    await _initLocalNotifications();
    
    if (!isBackground) {
      await _requestPermissions();
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((message) {
      _handleMessage(message, showLocal: true);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message, showLocal: false);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage, showLocal: false);
    }

    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    await _local.initialize(const InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    ));

    const channel = AndroidNotificationChannel(
      'updates',
      'Updates',
      description: 'Updates and messages',
      importance: Importance.max,
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _handleMessage(RemoteMessage message, {required bool showLocal}) {
    final title = message.notification?.title ?? message.data['title']?.toString() ?? 'Update';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
    final type = message.data['type']?.toString() ?? 'general';

    final appNotification = AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      read: false,
      type: type,
    );

    _controller.add(appNotification);

    if (showLocal && (title.isNotEmpty || body.isNotEmpty)) {
      showLocalNotification(title: title, body: body);
    }
  }

  static Future<void> showLocalNotification({required String title, required String body}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'updates',
        'Updates',
        channelDescription: 'Updates and messages',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  static void notifySimple({
    required String title,
    required String body,
    String type = 'general',
    bool showLocal = false,
  }) {
    final appNotification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      read: false,
      type: type,
    );

    _controller.add(appNotification);

    if (showLocal) {
      showLocalNotification(title: title, body: body);
    }
  }

  static Future<void> registerDeviceToken({
    required String userId,
    required String section,
  }) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _upsertToken(token, userId, section);

      if (!_tokenListenerAttached) {
        _tokenListenerAttached = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          await _upsertToken(newToken, userId, section);
        });
      }
    } catch (_) {
      // ignore
    }
  }

  static Future<void> _upsertToken(String token, String userId, String section) async {
    final client = SupabaseService.client;
    await client.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'section': section,
      'platform': Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }
}
