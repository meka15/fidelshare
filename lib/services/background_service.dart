import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart';
import 'local_database_service.dart';
import '../models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 0. Ensure Flutter binding is ready
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      // 1. Important: Background isolates need their own dotenv initialization
      await dotenv.load(fileName: "assets/.env");
      
      final url = SupabaseService.supabaseUrl;
      debugPrint("Background Task: Initializing Supabase with URL: $url");
      
      await SupabaseService.initialize();
      await NotificationService.initialize(isBackground: true);

      if (task == 'checkUpdatesTask' || task == Workmanager.iOSBackgroundTask) {
        // Run both checks in parallel like Telegram
        await Future.wait([
          _checkNewUpdates(),
          _syncMissedMessages(),
        ]);
      }

      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

Future<void> _syncMissedMessages() async {
  try {
    final client = SupabaseService.client;
    final localDb = LocalDatabaseService();
    
    // In a Telegram-like setup, we'd sync all relevant sections. 
    // Here we'll fetch recently created messages across all sections for the user
    final response = await client
        .from('chat_messages')
        .select()
        .order('timestamp', ascending: false)
        .limit(20);

    if (response != null && response is List) {
      final messages = response.map((m) => ChatMessage(
        id: m['id'].toString(),
        role: m['sender_id'] == client.auth.currentUser?.id ? 'user' : 'model',
        senderId: m['sender_id']?.toString() ?? '',
        senderName: m['sender_name']?.toString() ?? 'User',
        text: m['text']?.toString() ?? '',
        timestamp: m['timestamp'] as int,
        section: m['section']?.toString() ?? '',
      )).toList();

      await localDb.insertMessages(messages);
      debugPrint("Background Sync: ${messages.length} messages synced.");
    }
  } catch (e) {
    debugPrint("Background Message Sync Error: $e");
  }
}

Future<void> _checkNewUpdates() async {
  final client = SupabaseService.client;
  
  // Fetch latest announcement
  final response = await client
      .from('announcements')
      .select()
      .order('timestamp', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response != null) {
    final announcement = Announcement.fromJson(response);
    
    // In a real app, you'd compare this ID with the last seen ID stored in SharedPreferences
    // For this demonstration, we'll just show it to prove background tasks work
    NotificationService.notifySimple(
      title: 'Latest Announcement: ${announcement.title}',
      body: announcement.content,
      type: 'system',
      showLocal: true,
    );
  }
}

class BackgroundService {
  static const String checkUpdatesTask = 'checkUpdatesTask';

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "1",
      checkUpdatesTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> registerOneOffTask() async {
    await Workmanager().registerOneOffTask(
      "2",
      checkUpdatesTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
