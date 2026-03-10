import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';
import 'supabase_service.dart';
import 'local_database_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase Background Handler: Firebase initialized OK");
  } catch (e) {
    debugPrint("Firebase Background Handler: Firebase init FAILED: $e");
    // If Firebase fails to init, we can still show the notification via
    // the notification payload that FCM delivers automatically.
    return;
  }
  
  try {
    await dotenv.load(fileName: "assets/.env");
    debugPrint("Firebase Background Handler: Env loaded, Supabase key present: ${dotenv.get('SUPABASE_ANON_KEY').isNotEmpty}");
  } catch (e) {
    debugPrint("Firebase Background Handler: dotenv load failed: $e");
  }
  
  // Initialize Supabase if needed for background sync
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint("Firebase Background Handler: Supabase init failed: $e");
  }

  debugPrint("Firebase Background Handler: message data = ${message.data}");
  debugPrint("Firebase Background Handler: notification = ${message.notification?.title} / ${message.notification?.body}");

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
      debugPrint("Firebase Background Handler: Message saved to local DB");
    } catch (e) {
      debugPrint("Background Data Sync Error: $e");
    }
  }

  // FCM automatically shows the notification UI when in background
  // if the message contains a "notification" payload (which our Edge Function sends).
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings();
  const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
  await plugin.initialize(const InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
    linux: linuxSettings,
  ));

  const channel = AndroidNotificationChannel(
    'fidel_alerts_v1',
    'FidelShare Alerts',
    description: 'Important updates and messages',
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
      'fidel_alerts_v1',
      'FidelShare Alerts',
      channelDescription: 'Important updates and messages',
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
    
    // 1. Always init local notifications (doesn't need internet/Firebase)
    try {
      await _initLocalNotifications();
    } catch (e) {
      debugPrint("Local Notification Init Error: $e");
    }
    
    // 2. Init Firebase (Needs internet for first run, or stored config)
    try {
      await Firebase.initializeApp();
      
      if (!isBackground) {
        await _requestPermissions();

        try {
          final token = await FirebaseMessaging.instance.getToken();
          debugPrint('FCM Token (this device): $token');
        } catch (e) {
          debugPrint('FCM Token Error: $e');
        }
      }

      // onBackgroundMessage is already called in main.dart
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
    } catch (e) {
      debugPrint("Firebase Messaging Init Error: $e");
      // Keep going, at least local notifications will work
    }

    debugPrint("Notification Service: Initialization complete. Firebase active: ${!isBackground}");
    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint("Firebase Messaging Permission Status: ${settings.authorizationStatus}");

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
    await _local.initialize(const InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      linux: linuxSettings,
    ));

    const channel = AndroidNotificationChannel(
      'fidel_alerts_v1',
      'FidelShare Alerts',
      description: 'Important updates and messages',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
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
    try {
      debugPrint("Showing Local Notification: $title - $body");
      
      const androidDetails = AndroidNotificationDetails(
        'fidel_alerts_v1',
        'FidelShare Alerts',
        channelDescription: 'Important updates and messages',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        showWhen: true,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: true, // This helps with popups on some devices
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(
          defaultActionName: 'Open',
        ),
      );

      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
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
    try {
      await client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'section': section,
        'platform': Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
      debugPrint("FCM Token successfully saved to Supabase!");
    } catch (e) {
      debugPrint("Failed to save FCM Token to Supabase: $e");
    }
  }
}
