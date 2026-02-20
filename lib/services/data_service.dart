import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';

class DataService {
  static const String _storageKey = 'edusync_db_v1';

  static dynamic _coerceSectionValue(String section) {
    final parsed = int.tryParse(section);
    return parsed ?? section;
  }

  static String generateId() {
    // Simple UUID-like generator
    final random = Random();
    String s4() => (random.nextInt(65536).toRadixString(16).padLeft(4, '0'));
    return '${s4()}${s4()}-${s4()}-${s4()}-${s4()}-${s4()}${s4()}${s4()}';
  }

  static Future<AppDatabase> getLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored == null) return AppDatabase.initial();

      final parsed = jsonDecode(stored);
      return AppDatabase.fromJson(parsed);
    } catch (e) {
      print("Error reading local data: $e");
      return AppDatabase.initial();
    }
  }

  static Future<void> saveLocalData(AppDatabase data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data.toJson()));
  }

  static Future<AppDatabase> fetchData(String section) async {
    final local = await getLocalData();
    final sectionValue = _coerceSectionValue(section);
    // If Supabase is not initialized or available, return local data
    // Assuming SupabaseService.client throws or handles initialization check
    
    try {
      final client = SupabaseService.client;
      
      // Helper for safe fetching
      Future<List<Map<String, dynamic>>?> safeFetch(String table, PostgrestTransformBuilder query) async {
        try {
          final response = await query;
          return List<Map<String, dynamic>>.from(response as List);
        } catch (e) {
          print("Supabase: Could not fetch from table $table: $e");
          return null;
        }
      }

      final results = await Future.wait([
        safeFetch('materials', client.from('materials').select().eq('section', sectionValue).order('timestamp', ascending: false)),
        safeFetch('announcements', client.from('announcements').select().eq('section', sectionValue).order('timestamp', ascending: false)),
        safeFetch('classes', client.from('classes').select().eq('section', sectionValue)),
        safeFetch('faculty', client.from('faculty').select().filter('section', 'eq', sectionValue)),
        safeFetch('class_settings', client.from('class_settings').select()),
      ]);

      final materialsRaw = results[0];
      final announcementsRaw = results[1];
      final classesRaw = results[2];
      final facultyRaw = results[3];
      final settingsRawList = results[4];

      final materials = materialsRaw != null
          ? materialsRaw.map((m) => StudyMaterial(
              id: m['id'].toString(),
              url: m['url'] ?? '',
              name: m['name'] ?? 'Unnamed',
              timestamp: (m['timestamp'] as num).toInt(),
              uploaderId: m['uploader_id'] ?? '',
              uploaderName: m['uploader_name'] ?? 'Unknown',
              isPublic: m['is_public'] ?? true,
              downloadCount: (m['download_count'] as num?)?.toInt() ?? 0,
              category: m['category'] ?? 'Resources',
              fileSize: m['file_size'],
              summary: m['summary'],
              section: (m['section'] ?? section).toString(),
            )).toList()
          : local.materials;

      final announcements = announcementsRaw != null
          ? announcementsRaw.map((a) => Announcement(
              id: a['id'].toString(),
              title: a['title'] ?? '',
              content: a['content'] ?? '',
              timestamp: (a['timestamp'] as num).toInt(),
              authorName: a['author_name'] ?? 'Admin',
              authorId: a['author_id'] ?? '',
              section: (a['section'] ?? section).toString(),
            )).toList()
          : local.announcements;

      final classes = classesRaw != null
          ? classesRaw.map((c) {
             final dayOfWeek = (c['day_of_week'] as num?)?.toInt() ?? 1;
             final timeStr = c['time'] ?? '08:00';
             return ClassSession(
              id: c['id'].toString(),
              name: c['name'] ?? '',
              room: c['room'] ?? '',
              instructor: c['instructor'] ?? '',
              time: timeStr,
              status: c['status'] ?? 'upcoming',
              startTime: _getNextOccurrence(dayOfWeek, timeStr),
              dayOfWeek: dayOfWeek,
              section: (c['section'] ?? section).toString(),
            );
          }).toList()
          : local.classes;

      final faculty = facultyRaw != null
          ? facultyRaw.map((f) => FacultyContact(
              id: f['id'].toString(),
              name: f['name'] ?? '',
              role: f['role'] ?? '',
              avatar: f['avatar'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(f['name'] ?? 'U')}&background=137fec&color=fff',
              phoneNumber: f['phone_number'] ?? f['phoneNumber'],
              email: f['email'],
              section: f['section']?.toString(),
            )).toList()
          : local.faculty;

      EduSyncSettings settings = local.settings;
      bool? remoteFacultyVisible;

      if (settingsRawList != null && settingsRawList.isNotEmpty) {
        try {
          final settingsEntry = settingsRawList.firstWhere(
            (s) => s['key'] == 'app_settings',
            orElse: () => <String, dynamic>{},
          );
          
          if (settingsEntry.isNotEmpty && settingsEntry['value'] != null) {
              final val = settingsEntry['value'];
              final Map<String, dynamic> jsonMap = val is String ? jsonDecode(val) : val;
              settings = EduSyncSettings.fromJson(jsonMap);
          }

          // Check for faculty_visible key (overrides app_settings json if present as separate key)
          final facultyVisEntry = settingsRawList.firstWhere(
            (s) => s['key'] == 'faculty_visible',
            orElse: () => {'value': 1},
          );
          final val = facultyVisEntry['value'];
           // Handle boolean or string 'true'/'false'
          if (val is bool) {
            remoteFacultyVisible = val;
          } else if (val is String) {
            remoteFacultyVisible = val.toLowerCase() == 'true';
          }
                } catch (e) {
          print("Error parsing settings: $e");
        }
      }

      final freshData = AppDatabase(
        materials: materials,
        announcements: announcements,
        classes: classes,
        faculty: faculty,
        settings: remoteFacultyVisible != null 
            ? EduSyncSettings(
                notifications: settings.notifications,
                sync: settings.sync,
                appearance: settings.appearance,
                facultyVisible: remoteFacultyVisible,
              )
            : settings,
        lastSync: DateTime.now().millisecondsSinceEpoch,
      );

      await saveLocalData(freshData);
      return freshData;

    } catch (error) {
       print("General Sync Failure: $error");
       return local;
    }
  }

  static DateTime _getNextOccurrence(int dayOfWeek, String timeStr) {
    // 0=Sun, 1=Mon, ..., 6=Sat in JS
    // In Dart DateTime: 1=Mon, 7=Sun.
    // Assuming the DB stores JS style (0-6) or ISO (1-7)? 
    // React code: const currentDay = now.getDay(); // 0-6
    // Let's assume input dayOfWeek is 0-6 (Sun-Sat) to match React logic typically.
    
    // Parse time
    final parts = timeStr.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final mins = int.tryParse(parts[1]) ?? 0;

    final now = DateTime.now();
    var result = DateTime(now.year, now.month, now.day, hours, mins);
    
    // Adjust logic for Dart's DateTime.weekday (1=Mon ... 7=Sun)
    // If input is 0-6 (Sun-Sat), let's convert to 1-7
    // JS: 0=Sun, 1=Mon ... 6=Sat
    // Dart: 7=Sun, 1=Mon ... 6=Sat
    int targetWeekday = dayOfWeek == 0 ? 7 : dayOfWeek; 

    // Calculate days until
    int daysUntil = (targetWeekday - now.weekday + 7) % 7;
    
    // React Logic: if (daysUntil === 0 && result < now) daysUntil = 7;
    if (daysUntil == 0 && result.isBefore(now)) {
      daysUntil = 7;
    }
    
    return result.add(Duration(days: daysUntil));
  }

  // --- Collection Mutations ---

  static Future<void> addMaterial(StudyMaterial material, String section) async {
    await _appendToCollection('materials', material.toJson(), section, (json) => StudyMaterial.fromJson(json), material.id);
  }

  static Future<void> addAnnouncement(Announcement announcement, String section) async {
    await _appendToCollection('announcements', announcement.toJson(), section, (json) => Announcement.fromJson(json), announcement.id);
  }
  
  static Future<void> addClassSession(ClassSession session, String section) async {
     await _appendToCollection('classes', session.toJson(), section, (json) => ClassSession.fromJson(json), session.id);
  }

  static Future<void> addFaculty(FacultyContact faculty, String section) async {
    await _appendToCollection('faculty', faculty.toJson(), section, (json) => FacultyContact.fromJson(json), faculty.id);
  }

  static Future<void> removeFromCollection(String tableName, String id) async {
    final local = await getLocalData();

    if (tableName == 'materials') {
      local.materials.removeWhere((m) => m.id == id);
    } else if (tableName == 'announcements') {
      local.announcements.removeWhere((a) => a.id == id);
    } else if (tableName == 'classes') {
      local.classes.removeWhere((c) => c.id == id);
    } else if (tableName == 'faculty') {
      local.faculty.removeWhere((f) => f.id == id);
    }

    await saveLocalData(local);

    try {
      final client = SupabaseService.client;
      await client.from(tableName).delete().eq('id', id);
    } catch (e) {
      print('Supabase delete error for [$tableName]: $e');
    }
  }

  static Future<void> _appendToCollection(String tableName, Map<String, dynamic> itemJson, String section, Function fromJson, String itemId) async {
     // 1. Update Local
    final local = await getLocalData();
    final itemWithSection = Map<String, dynamic>.from(itemJson);
    itemWithSection['section'] = section;

    // Reflection-ish approach for updating specific list in AppDatabase is hard in Dart without copyWith or Maps.
    // Easier to decode, modify map, encode.
    // Or just manually handle each type. 
    // Let's manually handle each type in public methods (like addMaterial) and use this for DB push.
    
    // For local update, we actually need to update the specific list in AppDatabase.
    // Since we are refetching often, maybe optimistic UI + background fetch is best.
    // But let's try to update local state.
    
    if (tableName == 'materials') {
        local.materials.removeWhere((m) => m.id == itemId);
        local.materials.insert(0, StudyMaterial.fromJson(itemWithSection));
    } else if (tableName == 'announcements') {
        local.announcements.removeWhere((a) => a.id == itemId);
        local.announcements.insert(0, Announcement.fromJson(itemWithSection));
    } else if (tableName == 'classes') {
        local.classes.removeWhere((c) => c.id == itemId);
        local.classes.add(ClassSession.fromJson(itemWithSection));
        // Sort classes logic might be needed here
    }

    await saveLocalData(local);

    // 2. Update Supabase
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;

    Map<String, dynamic> payload = {};
    
    if (tableName == 'materials') {
      payload = {
        'id': itemJson['id'],
        'url': itemJson['url'],
        'name': itemJson['name'],
        'timestamp': itemJson['timestamp'],
        'uploader_id': itemJson['uploaderId'],
        'uploader_name': itemJson['uploaderName'],
        'is_public': itemJson['isPublic'],
        'category': itemJson['category'],
        'file_size': itemJson['fileSize'],
        'summary': itemJson['summary'],
        'section': _coerceSectionValue(section),
        'user_id': userId,
      };
    } else if (tableName == 'announcements') {
      payload = {
        'id': itemJson['id'],
        'title': itemJson['title'],
        'content': itemJson['content'],
        'timestamp': itemJson['timestamp'],
        'author_name': itemJson['authorName'],
        'author_id': itemJson['authorId'],
        'section': _coerceSectionValue(section),
        'user_id': userId,
      };
    } else if (tableName == 'classes') {
        payload = {
            'id': itemJson['id'],
            'name': itemJson['name'],
            'room': itemJson['room'],
            'instructor': itemJson['instructor'],
            'time': itemJson['time'],
            'status': itemJson['status'] ?? 'upcoming',
            'day_of_week': itemJson['dayOfWeek'],
            'section': _coerceSectionValue(section),
            'user_id': userId,
        };
    }

    if (payload.isNotEmpty) {
      try {
        await client.from(tableName).upsert(payload);
      } catch (e) {
        print("Supabase persistence error for [$tableName]: $e");
      }
    }
  }

    static Future<void> updateSettings(EduSyncSettings newSettings) async {
    final local = await getLocalData();
    // Assuming we replace the whole settings object
    final updatedData = AppDatabase(
        materials: local.materials, 
        announcements: local.announcements, 
        classes: local.classes, 
        faculty: local.faculty, 
        settings: newSettings, 
        lastSync: local.lastSync
    );
    await saveLocalData(updatedData);

    try {
        final client = SupabaseService.client;
        final userId = client.auth.currentUser?.id;
        await client.from('class_settings').upsert({
            'key': 'app_settings',
            'value': newSettings.toJson(),
            'user_id': userId,
        });
    } catch (e) {
        print("Settings persist error: $e");
    }
  }

  static Future<void> setFacultyVisibility(bool visible) async {
    try {
      final client = SupabaseService.client;
      await client.from('class_settings').upsert({
        'key': 'faculty_visible',
        'value': visible.toString(), // Store as string 'true'/'false' or check backend type. Fetch handles both bool can string.
        // Assuming no 'user_id' needed for shared, or auth user id is enough trigger
        'user_id': client.auth.currentUser?.id, 
      });
    } catch (e) {
      print("Faculty visibility toggle error: $e");
    }
  }
}

class AppDatabase {
  final List<StudyMaterial> materials;
  final List<Announcement> announcements;
  final List<ClassSession> classes;
  final List<FacultyContact> faculty;
  final EduSyncSettings settings;
  final int? lastSync;

  AppDatabase({
    required this.materials,
    required this.announcements,
    required this.classes,
    required this.faculty,
    required this.settings,
    this.lastSync,
  });

  factory AppDatabase.initial() {
    return AppDatabase(
      materials: [],
      announcements: [],
      classes: [],
      faculty: [],
      settings: EduSyncSettings(
        notifications: NotificationSettings(
          upcomingClasses: true, 
          newMaterials: true, 
          fingerprintEnabled: false
        ), 
        sync: SyncSettings(cloudProvider: 'supabase'),
        appearance: AppearanceSettings(theme: 'light'),
      ),
    );
  }

  factory AppDatabase.fromJson(Map<String, dynamic> json) {
    return AppDatabase(
      materials: (json['materials'] as List?)?.map((e) => StudyMaterial.fromJson(e)).toList() ?? [],
      announcements: (json['announcements'] as List?)?.map((e) => Announcement.fromJson(e)).toList() ?? [],
      classes: (json['classes'] as List?)?.map((e) => ClassSession.fromJson(e)).toList() ?? [],
      faculty: (json['faculty'] as List?)?.map((e) => FacultyContact.fromJson(e)).toList() ?? [],
      settings: json['settings'] != null ? EduSyncSettings.fromJson(json['settings']) : AppDatabase.initial().settings,
      lastSync: json['lastSync'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'materials': materials.map((e) => e.toJson()).toList(),
      'announcements': announcements.map((e) => e.toJson()).toList(),
      'classes': classes.map((e) => e.toJson()).toList(),
      'faculty': faculty.map((e) => e.toJson()).toList(),
      'settings': settings.toJson(),
      'lastSync': lastSync,
    };
  }
}
