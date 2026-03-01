import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart';
import '../models/models.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize core services
      await SupabaseService.initialize();
      await NotificationService.initialize();

      // 2. Perform the background work
      // Example: Fetch latest announcements or check for new materials
      if (task == 'checkUpdatesTask') {
        await _checkNewUpdates();
      }

      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
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
}
