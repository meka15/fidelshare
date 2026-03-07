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
        // Run checks in parallel
        await Future.wait([
          _checkNewUpdates(),
          _syncMissedMessages(),
          _checkUpcomingClasses(),
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

      int newCount = 0;
      for (var msg in messages) {
        // We only notify for messages from others (role: 'model') 
        // that haven't been seen in our local DB yet.
        final exists = await localDb.getMessages(msg.section, limit: 50); 
        if (!exists.any((e) => e.id == msg.id) && msg.role == 'model') {
          await NotificationService.showLocalNotification(
            title: msg.senderName,
            body: msg.text,
          );
          newCount++;
        }
      }
      
      await localDb.insertMessages(messages);
      debugPrint("Background Sync: ${messages.length} messages synced, $newCount new notifications.");
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

Future<void> _checkUpcomingClasses() async {
  try {
    // We fetch classes from local DB to see what's coming
    final db = await DataService.getLocalData();
    final now = DateTime.now();
    
    for (var session in db.classes) {
      if (session.status == 'cancelled') continue;
      
      // Calculate next occurrence
      final startTime = session.startTime;
      final diff = startTime.difference(now);
      
      // If a class is starting in the next 20 minutes (and we are checking every 15)
      if (diff.inMinutes > 0 && diff.inMinutes <= 20) {
        NotificationService.showLocalNotification(
          title: 'Class Starting Soon!',
          body: '${session.name} starts in ${diff.inMinutes} mins at ${session.room}',
        );
      }
    }
  } catch (e) {
    debugPrint("Background Class Check Error: $e");
  }
}
