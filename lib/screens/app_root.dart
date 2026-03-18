import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';
import '../widgets/splash_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isInitializing = true;
  bool _isLoggedIn = false;
  Student? _student;
  String? _internalUserId;

  List<StudyMaterial> _materials = [];
  List<Announcement> _announcements = [];
  List<FacultyContact> _faculty = [];
  EduSyncSettings _settings = AppDatabase.initial().settings;
  List<ClassSession> _classes = [];

  bool _isSyncing = false;
  List<AppNotification> _notifications = [];
  Set<String> _viewedAnnIds = {};
  bool _hasSyncedOnce = false;
  StreamSubscription<AppNotification>? _notifSub;
  RealtimeChannel? _chatChannel;
  String? _chatSectionId;
  RealtimeChannel? _announcementsChannel;
  RealtimeChannel? _materialsChannel;
  RealtimeChannel? _classesChannel;

  @override
  void initState() {
    super.initState();
    _notifSub = NotificationService.notifications.listen((n) {
      if (!mounted) return;
      setState(() {
        _notifications = [n, ..._notifications];
      });
    });
    _initAuth();
  }

  @override
  void dispose() {
    _stopRealtimeChannels();
    _stopChatRealtime();
    _notifSub?.cancel();
    super.dispose();
  }

  void _startRealtimeChannels(String section) {
    _stopRealtimeChannels();
    final client = SupabaseService.client;
    final sectionValue = section.toString();
    debugPrint("Starting Realtime Channels for Section: '$sectionValue'");

    _announcementsChannel = client.channel('realtime-announcements-$sectionValue')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'announcements',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'section',
          value: sectionValue,
        ),
        callback: (payload) {
          final ann = _announcementFromRecord(payload.newRecord);
          if (ann == null) return;
          _upsertAnnouncement(ann);
          if (_settings.notifications.announcementsEnabled) {
            NotificationService.notifySimple(
              title: 'New announcement',
              body: ann.title.isNotEmpty ? ann.title : 'A new announcement was posted.',
              type: 'announcement',
              showLocal: true,
            );
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'announcements',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'section',
          value: sectionValue,
        ),
        callback: (payload) {
          final id = payload.oldRecord['id']?.toString();
          if (id == null) return;
          setState(() {
            _announcements = _announcements.where((a) => a.id != id).toList();
          });
        },
      )
      ..subscribe((status, [error]) {
        debugPrint("Realtime Subscription Status (Announcements): $status ${error ?? ''}");
      });

    _materialsChannel = client.channel('realtime-materials-$sectionValue')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'materials',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'section',
          value: sectionValue,
        ),
        callback: (payload) {
          debugPrint("Materials Realtime Event Triggered: ${payload.eventType}");
          final material = _materialFromRecord(payload.newRecord);
          if (material == null) return;
          _upsertMaterial(material);
          if (_settings.notifications.newMaterials) {
            NotificationService.notifySimple(
              title: 'New material',
              body: material.name.isNotEmpty ? material.name : 'New material added.',
              type: 'material',
              showLocal: true,
            );
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'materials',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'section',
          value: sectionValue,
        ),
        callback: (payload) {
          final id = payload.oldRecord['id']?.toString();
          if (id == null) return;
          setState(() {
            _materials = _materials.where((m) => m.id != id).toList();
          });
        },
      )
      ..subscribe((status, [error]) {
        debugPrint("Realtime Subscription Status (Materials): $status ${error ?? ''}");
      });

    _classesChannel = client.channel('realtime-classes-$sectionValue')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'classes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'section',
          value: sectionValue,
        ),
        callback: (payload) {
          debugPrint("Schedule Realtime Insert Event Triggered");
          final session = _classFromRecord(payload.newRecord);
          if (session == null) return;
          _upsertClass(session);
          if (_settings.notifications.scheduleEnabled) {
            NotificationService.notifySimple(
              title: 'Schedule update',
              body: session.name.isNotEmpty ? session.name : 'Class schedule changed.',
              type: 'schedule',
              showLocal: true,
            );
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'classes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'section',
          value: sectionValue,
        ),
        callback: (payload) {
          debugPrint("Schedule Realtime Update Event Triggered");
          final session = _classFromRecord(payload.newRecord);
          if (session == null) return;
          _upsertClass(session);
          if (_settings.notifications.scheduleEnabled) {
            NotificationService.notifySimple(
              title: 'Schedule update',
              body: session.name.isNotEmpty ? session.name : 'Class schedule changed.',
              type: 'schedule',
              showLocal: true,
            );
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'classes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'section',
          value: sectionValue,
        ),
        callback: (payload) {
          debugPrint("Schedule Realtime Delete Event Triggered");
          final id = payload.oldRecord['id']?.toString();
          if (id == null) return;
          setState(() {
            _classes = _classes.where((c) => c.id != id).toList();
          });
        },
      )
      ..subscribe((status, [error]) {
        debugPrint("Realtime Subscription Status (Classes): $status ${error ?? ''}");
      });
  }

  void _stopRealtimeChannels() {
    final client = SupabaseService.client;
    if (_announcementsChannel != null) {
      client.removeChannel(_announcementsChannel!);
      _announcementsChannel = null;
    }
    if (_materialsChannel != null) {
      client.removeChannel(_materialsChannel!);
      _materialsChannel = null;
    }
    if (_classesChannel != null) {
      client.removeChannel(_classesChannel!);
      _classesChannel = null;
    }
  }

  Announcement? _announcementFromRecord(Map<String, dynamic> record) {
    if (record['id'] == null) return null;
    return Announcement(
      id: record['id'].toString(),
      title: record['title']?.toString() ?? '',
      content: record['content']?.toString() ?? '',
      timestamp: (record['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      authorName: record['author_name']?.toString() ?? 'Admin',
      authorId: record['author_id']?.toString() ?? '',
      section: record['section']?.toString() ?? '',
    );
  }

  StudyMaterial? _materialFromRecord(Map<String, dynamic> record) {
    if (record['id'] == null) return null;
    return StudyMaterial(
      id: record['id'].toString(),
      url: record['url']?.toString() ?? '',
      name: record['name']?.toString() ?? 'Unnamed',
      timestamp: (record['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      uploaderId: record['uploader_id']?.toString() ?? '',
      uploaderName: record['uploader_name']?.toString() ?? 'Unknown',
      isPublic: record['is_public'] == true,
      downloadCount: (record['download_count'] as num?)?.toInt() ?? 0,
      category: record['category']?.toString() ?? 'Resources',
      fileSize: record['file_size'],
      summary: record['summary'],
      section: record['section']?.toString() ?? '',
    );
  }

  ClassSession? _classFromRecord(Map<String, dynamic> record) {
    if (record['id'] == null) return null;
    final day = (record['day_of_week'] ?? record['dayOfWeek']) as num?;
    final timeStr = record['time']?.toString() ?? '08:00';
    final dayValue = day?.toInt() ?? 1;
    final isPermanent = record['is_permanent'] ?? true;
    final dateStr = record['date'];
    final date = dateStr != null ? DateTime.parse(dateStr) : null;

    DateTime startTime;
    if (isPermanent) {
      startTime = _getNextOccurrence(dayValue, timeStr);
    } else if (date != null) {
      final parts = timeStr.split(':');
      final hours = int.tryParse(parts[0]) ?? 0;
      final mins = int.tryParse(parts[1]) ?? 0;
      startTime = DateTime(date.year, date.month, date.day, hours, mins);
    } else {
      startTime = DateTime.now();
    }

    return ClassSession(
      id: record['id'].toString(),
      name: record['name']?.toString() ?? '',
      room: record['room']?.toString() ?? '',
      instructor: record['instructor']?.toString() ?? '',
      time: timeStr,
      status: record['status']?.toString() ?? 'upcoming',
      startTime: startTime,
      dayOfWeek: dayValue,
      section: record['section']?.toString() ?? '',
      isPermanent: isPermanent,
      date: date,
    );
  }

  void _upsertAnnouncement(Announcement ann) {
    setState(() {
      final exists = _announcements.any((a) => a.id == ann.id);
      _announcements = exists
          ? _announcements.map((a) => a.id == ann.id ? ann : a).toList()
          : [ann, ..._announcements];
    });
  }

  void _upsertMaterial(StudyMaterial material) {
    setState(() {
      final exists = _materials.any((m) => m.id == material.id);
      _materials = exists
          ? _materials.map((m) => m.id == material.id ? material : m).toList()
          : [material, ..._materials];
    });
  }

  void _upsertClass(ClassSession session) {
    setState(() {
      final exists = _classes.any((c) => c.id == session.id);
      final next = exists
          ? _classes.map((c) => c.id == session.id ? session : c).toList()
          : [..._classes, session];
      _classes = _mapClasses(next);
    });
  }

  Future<Student?> _refetchFullProfile(String userId) async {
    try {
      final client = SupabaseService.client;
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        return Student(
          name: data['name'] ?? 'Student',
          studentId: data['student_id'] ?? userId.substring(0, 8).toUpperCase(),
          section: data['section']?.toString() ?? 'GENERAL',
          isRepresentative: (data['is_representative'] ?? false) == true,
          batch: data['batch'] != null ? int.tryParse(data['batch'].toString()) : null,
        );
      }
    } catch (e) {
      debugPrint("Refetch Profile Error: $e");
    }
    return null;
  }

  Future<void> _startChatRealtime(String userId) async {
    final profile = await _refetchFullProfile(userId);
    if (profile == null) return;
    
    // Update global state if profile data changed (fixing consistency issues)
    if (_student == null || 
        _student!.section != profile.section || 
        _student!.isRepresentative != profile.isRepresentative ||
        _student!.studentId != profile.studentId) {
      debugPrint("Updating Student State from DB: ${profile.section}, Rep: ${profile.isRepresentative}");
      setState(() {
        _student = profile;
      });
      // Re-trigger sync for the correct section
      _syncData(profile.section, silent: true);
      _startRealtimeChannels(profile.section);
    }

    final sectionId = profile.section;
    if (_chatSectionId == sectionId && _chatChannel != null) return;

    _chatSectionId = sectionId;
    _stopChatRealtime();

    final client = SupabaseService.client;
    final channel = client.channel('realtime-chat-notif-$sectionId');
    _chatChannel = channel;

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'section',
        value: sectionId,
      ),
      callback: (payload) {
        debugPrint("Chat Realtime Insert Event Triggered");
        final m = payload.newRecord;
        final senderId = m['sender_id']?.toString();
        if (senderId == userId) return;
        final senderName = m['sender_name']?.toString() ?? 'Someone';
        final text = m['text']?.toString() ?? '';

        if (_settings.notifications.chatEnabled) {
          NotificationService.notifySimple(
            title: 'New message',
            body: text.isNotEmpty ? '$senderName: $text' : '$senderName sent a message.',
            type: 'chat',
            showLocal: true,
          );
        }
      },
    ).subscribe((status, [error]) {
      debugPrint("Realtime Subscription Status (Chat): $status ${error ?? ''}");
    });
  }

  void _stopChatRealtime() {
    if (_chatChannel != null) {
      SupabaseService.client.removeChannel(_chatChannel!);
      _chatChannel = null;
    }
  }

  DateTime _getNextOccurrence(int dayOfWeek, String timeStr) {
    final parts = timeStr.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final mins = int.tryParse(parts[1]) ?? 0;

    final now = DateTime.now();
    var result = DateTime(now.year, now.month, now.day, hours, mins);
    int targetWeekday = dayOfWeek == 0 ? 7 : dayOfWeek;
    int daysUntil = (targetWeekday - now.weekday + 7) % 7;
    if (daysUntil == 0 && result.isBefore(now)) {
      daysUntil = 7;
    }
    return result.add(Duration(days: daysUntil));
  }

  List<ClassSession> _mapClasses(List<ClassSession> raw) {
    final mapped = raw
        .map((c) {
          DateTime startTime;
          if (c.isPermanent) {
            startTime = _getNextOccurrence(c.dayOfWeek, c.time);
          } else if (c.date != null) {
            final parts = c.time.split(':');
            final hours = int.tryParse(parts[0]) ?? 0;
            final mins = int.tryParse(parts[1]) ?? 0;
            startTime = DateTime(c.date!.year, c.date!.month, c.date!.day, hours, mins);
          } else {
            startTime = DateTime.now();
          }
          
          return ClassSession(
            id: c.id,
            name: c.name,
            room: c.room,
            instructor: c.instructor,
            time: c.time,
            status: c.status,
            startTime: startTime,
            dayOfWeek: c.dayOfWeek,
            section: c.section,
            isPermanent: c.isPermanent,
            date: c.date,
          );
        })
        .toList();
    mapped.sort((a, b) => a.startTime.compareTo(b.startTime));
    return mapped;
  }

  Future<void> _syncData(String section, {bool silent = false}) async {
    if (!silent) setState(() => _isSyncing = true);
    try {
      // Proactively try to refresh profile data if possible
      if (_internalUserId != null) {
        final latestProfile = await _refetchFullProfile(_internalUserId!);
        if (latestProfile != null && _student != null) {
          if (latestProfile.section != _student!.section || 
              latestProfile.isRepresentative != _student!.isRepresentative) {
            setState(() => _student = latestProfile);
            section = latestProfile.section; // Use the updated section for the rest of the sync
          }
        }
      }

      final prevAnnouncements = List<Announcement>.from(_announcements);
      final prevMaterials = List<StudyMaterial>.from(_materials);
      final prevClasses = List<ClassSession>.from(_classes);
      final db = await DataService.fetchData(section);
      final nextClasses = _mapClasses(db.classes);

      if (_hasSyncedOnce) {
        final newAnnouncements = db.announcements.where(
          (a) => !prevAnnouncements.any((p) => p.id == a.id),
        );

        for (final ann in newAnnouncements) {
          if (_settings.notifications.announcementsEnabled) {
            NotificationService.notifySimple(
              title: 'New announcement',
              body: ann.title.isNotEmpty ? ann.title : 'A new announcement was posted.',
              type: 'announcement',
              showLocal: true,
            );
          }
        }

        if (_settings.notifications.newMaterials) {
          final newMaterials = db.materials.where(
            (m) => !prevMaterials.any((p) => p.id == m.id),
          );
          for (final mat in newMaterials) {
            NotificationService.notifySimple(
              title: 'New material',
              body: mat.name.isNotEmpty ? mat.name : 'New material added.',
              type: 'material',
              showLocal: true,
            );
          }
        }

        if (_settings.notifications.scheduleEnabled) {
          for (final next in nextClasses) {
            final previous = prevClasses.firstWhere(
              (c) => c.id == next.id,
              orElse: () => ClassSession(
                id: '',
                name: '',
                room: '',
                instructor: '',
                time: '',
                status: '',
                startTime: DateTime.now(),
                dayOfWeek: 0,
                section: '',
              ),
            );

            final isNew = previous.id.isEmpty;
            final isChanged = !isNew && (
              previous.name != next.name ||
              previous.time != next.time ||
              previous.status != next.status ||
              previous.room != next.room ||
              previous.instructor != next.instructor ||
              previous.dayOfWeek != next.dayOfWeek
            );

            if (isNew || isChanged) {
              NotificationService.notifySimple(
                title: 'Schedule update',
                body: next.name.isNotEmpty ? next.name : 'Class schedule changed.',
                type: 'schedule',
                showLocal: true,
              );
            }
          }
        }
      }

      setState(() {
        _announcements = db.announcements;
        _materials = db.materials;
        _faculty = db.faculty;
        _settings = db.settings;
        _classes = nextClasses;
      });
      _hasSyncedOnce = true;
    } catch (e) {
      // ignore
    } finally {
      if (!silent) setState(() => _isSyncing = false);
    }
  }

  Future<Student> _fetchProfile(String userId, Map<String, dynamic>? metadata) async {
    final sectionFromMetadata = (metadata?['section'] ?? 'GENERAL').toString().trim().toUpperCase();
    final nameFromMetadata = metadata?['full_name'] ?? metadata?['name'] ?? 'Student';
    final idFromMetadata = metadata?['student_id'] ?? userId.substring(0, 8).toUpperCase();
    final batchFromMetadata = metadata?['batch'] != null ? int.tryParse(metadata!['batch'].toString()) : null;
    final avatarFromMetadata = metadata?['avater_url']?.toString();

    final fallback = Student(
      name: nameFromMetadata,
      studentId: idFromMetadata,
      section: sectionFromMetadata,
      isRepresentative: false,
      batch: batchFromMetadata,
      avatarUrl: avatarFromMetadata,
    );

    try {
      final client = SupabaseService.client;
      // Use select() wildcard to avoid errors if specific columns (like batch/is_representative) are missing
      final data = await client
          .from('profiles')
          .select() 
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        final upserted = await client
            .from('profiles')
            .upsert({
              'id': userId,
              'name': nameFromMetadata,
              'student_id': idFromMetadata,
              'section': sectionFromMetadata,
              'batch': batchFromMetadata,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        return Student(
          name: upserted['name'] ?? fallback.name,
          studentId: upserted['student_id'] ?? fallback.studentId,
          section: upserted['section'] ?? fallback.section,
          isRepresentative: (upserted['is_representative'] ?? false) == true,
          batch: upserted['batch'] != null ? int.tryParse(upserted['batch'].toString()) : fallback.batch,
          avatarUrl: upserted['avater_url'],
        );
      }

      final rawSection = data['section'];
      final sectionValue = rawSection == null ? fallback.section : rawSection.toString();

      return Student(
        name: data['name'] ?? fallback.name,
        studentId: data['student_id'] ?? fallback.studentId,
        section: sectionValue,
        isRepresentative: (data['is_representative'] ?? false) == true,
        batch: data['batch'] != null ? int.tryParse(data['batch'].toString()) : fallback.batch,
        avatarUrl: data['avater_url'],
      );
    } catch (e) {
      debugPrint("Profile Fetch Error: $e");
      return fallback;
    }
  }

  Future<void> _completeLogin(dynamic session) async {
    final user = session.user;
    setState(() {
      _internalUserId = user.id;
    });
    final profile = await _fetchProfile(user.id, user.userMetadata);
    setState(() {
      _student = profile;
      _isLoggedIn = true;
    });
    await _syncData(profile.section, silent: true);
    await NotificationService.registerDeviceToken(
      userId: user.id,
      section: profile.section,
    );
    await _startChatRealtime(user.id);
    _startRealtimeChannels(profile.section);
  }

  Future<void> _initAuth() async {
    try {
      final client = SupabaseService.client;
      final session = client.auth.currentSession;
      if (session?.user != null) {
        await _completeLogin(session);
      }
      // Check for app updates
      _checkAppUpdate();
    } catch (_) {
      // ignore
    } finally {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _isInitializing = false);
      });
    }
  }

  Future<void> _logout() async {
    try {
      final client = SupabaseService.client;
      await client.auth.signOut();
    } catch (_) {
      // ignore
    } finally {
      _stopRealtimeChannels();
      _stopChatRealtime();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('edusync_db_v1');
      setState(() {
        _student = null;
        _internalUserId = null;
        _isLoggedIn = false;
        _materials = [];
        _announcements = [];
        _faculty = [];
        _classes = [];
        _notifications = [];
        _viewedAnnIds = {};
      });
    }
  }

  Future<void> _handleAddAnnouncement(Announcement ann) async {
    setState(() => _announcements = [ann, ..._announcements]);
    if (_student != null) {
      final sectionId = _student!.section;
      await DataService.addAnnouncement(ann, sectionId);
      
      // Trigger Push Notification for Announcement
      try {
        await SupabaseService.client.functions.invoke(
          'send_push',
          body: {
            'section': sectionId,
            'title': '📢 New Announcement',
            'body': ann.title.isNotEmpty ? ann.title : 'Details inside',
            'type': 'announcement',
            'data': {
              'id': ann.id,
              'announcementTitle': ann.title,
              'section': sectionId,
            },
          },
        );
        debugPrint('Announcement Push Sent Successfully');
      } catch (e) {
        debugPrint('Announcement Push Error: $e');
      }
    }
  }

  Future<void> _handleDeleteAnnouncement(String id) async {
    setState(() => _announcements = _announcements.where((a) => a.id != id).toList());
    await DataService.removeFromCollection('announcements', id);
  }

  Future<void> _handleAddClass(ClassSession classData) async {
    if (_student == null) return;
    final sectionId = _student!.section;
    setState(() => _classes = _mapClasses([..._classes, classData]));
    await DataService.addClassSession(classData, sectionId);

    // Trigger Push Notification for Schedule
    try {
      await SupabaseService.client.functions.invoke(
        'send_push',
        body: {
          'section': sectionId,
          'title': '🗓️ Schedule Update',
          'body': 'A new class "${classData.name}" has been added.',
          'type': 'schedule',
          'data': {
            'id': classData.id,
            'section': sectionId,
          },
        },
      );
    } catch (_) {}
  }

  Future<void> _handleUpdateClass(String id, Map<String, dynamic> updates) async {
    if (_student == null) return;
    final target = _classes.firstWhere((c) => c.id == id, orElse: () => _classes.first);
    final updated = ClassSession(
      id: target.id,
      name: updates['name'] ?? target.name,
      room: updates['room'] ?? target.room,
      instructor: updates['instructor'] ?? target.instructor,
      time: updates['time'] ?? target.time,
      status: updates['status'] ?? target.status,
      dayOfWeek: updates['dayOfWeek'] ?? target.dayOfWeek,
      startTime: (updates['isPermanent'] ?? target.isPermanent)
          ? _getNextOccurrence(
              updates['dayOfWeek'] ?? target.dayOfWeek,
              updates['time'] ?? target.time,
            )
          : (updates['date'] ?? target.date ?? DateTime.now()),
      section: target.section,
      isPermanent: updates['isPermanent'] ?? target.isPermanent,
      date: updates['date'] ?? target.date,
    );

    setState(() {
      _classes = _classes.map((c) => c.id == id ? updated : c).toList();
    });

    await DataService.addClassSession(updated, _student!.section);

    // Trigger Push Notification for Update
    try {
      await SupabaseService.client.functions.invoke(
        'send_push',
        body: {
          'section': _student!.section,
          'title': '📝 Class Updated',
          'body': 'The class "${updated.name}" has been updated.',
          'type': 'schedule',
          'data': {'id': updated.id},
        },
      );
    } catch (_) {}
  }

  Future<void> _handleCancelClass(String id) async {
    if (_student == null) return;
    final target = _classes.firstWhere((c) => c.id == id, orElse: () => _classes.first);
    final newStatus = target.status == 'cancelled' ? 'upcoming' : 'cancelled';
    final updated = ClassSession(
      id: target.id,
      name: target.name,
      room: target.room,
      instructor: target.instructor,
      time: target.time,
      status: newStatus,
      startTime: target.startTime,
      dayOfWeek: target.dayOfWeek,
      section: target.section,
      isPermanent: target.isPermanent,
      date: target.date,
    );

    setState(() {
      _classes = _classes.map((c) => c.id == id ? updated : c).toList();
    });

    await DataService.addClassSession(updated, _student!.section);

    // Trigger Push Notification for Cancellation
    try {
      await SupabaseService.client.functions.invoke(
        'send_push',
        body: {
          'section': _student!.section,
          'title': '⚠️ Class ${newStatus.toUpperCase()}',
          'body': 'The class "${updated.name}" is now $newStatus.',
          'type': 'schedule',
          'data': {'id': updated.id},
        },
      );
    } catch (_) {}
  }

  Future<void> _handleDeleteClass(String id) async {
    setState(() {
      _classes = _classes.where((c) => c.id != id).toList();
    });
    await DataService.removeFromCollection('classes', id);
  }

  Future<void> _handleAddFaculty(FacultyContact faculty) async {
    if (_student == null) return;
    setState(() => _faculty = [..._faculty, faculty]);
    await DataService.addFaculty(faculty, _student!.section);
  }

  Future<void> _handleAddMaterial(StudyMaterial material) async {
    setState(() => _materials = [material, ..._materials]);
    if (_student != null) {
      final sectionId = _student!.section;
      await DataService.addMaterial(material, sectionId);

      // Trigger Push Notification for Material
      try {
        await SupabaseService.client.functions.invoke(
          'send_push',
          body: {
            'section': sectionId,
            'title': '📚 New Study Material',
            'body': 'New resource: ${material.name}',
            'type': 'material',
            'data': {
              'id': material.id,
              'section': sectionId,
            },
          },
        );
      } catch (_) {}
    }
  }

  Future<void> _handleDeleteMaterial(String id) async {
    setState(() => _materials = _materials.where((m) => m.id != id).toList());
    await DataService.removeFromCollection('materials', id);
  }

  void _handleDownloadMaterial(String id) {
    setState(() {
      _materials = _materials
          .map((m) => m.id == id ? StudyMaterial(
                id: m.id,
                url: m.url,
                name: m.name,
                timestamp: m.timestamp,
                uploaderId: m.uploaderId,
                uploaderName: m.uploaderName,
                isPublic: m.isPublic,
                downloadCount: m.downloadCount + 1,
                category: m.category,
                fileSize: m.fileSize,
                summary: m.summary,
                section: m.section,
              ) : m)
          .toList();
    });
  }

  void _updateSettings(EduSyncSettings newSettings) {
    setState(() => _settings = newSettings);
    DataService.updateSettings(newSettings);
    NotificationService.updateSettings(newSettings.notifications);
  }

  Future<void> _toggleFacultyVisibility() async {
    final newValue = !_settings.facultyVisible;
    final updated = EduSyncSettings(
      notifications: _settings.notifications,
      sync: _settings.sync,
      appearance: _settings.appearance,
      facultyVisible: newValue,
    );
    setState(() => _settings = updated);
    
    // Persist specifically to the key used for override
    await DataService.setFacultyVisibility(newValue);
    // Also update generic object just in case
    await DataService.updateSettings(updated);
    NotificationService.updateSettings(updated.notifications);
  }

  Future<void> _checkAppUpdate() async {
    try {
      final update = await UpdateService.checkUpdate();
      if (update == null || !mounted) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final isForced = UpdateService.isForcedUpdate(currentVersion, update.minVersion);

      _showUpdateDialog(update, isForced);
    } catch (_) {
      // ignore
    }
  }

  void _showUpdateDialog(AppUpdateInfo update, bool isForced) {
    showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (context) => WillPopScope(
        onWillPop: () async => !isForced,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isForced ? Icons.system_update_rounded : Icons.update_rounded,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Text(isForced ? 'Update Required' : 'New Update Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version (${update.latestVersion}) is available. Please update to enjoy the latest features and fixes.',
                style: const TextStyle(fontSize: 14),
              ),
              if (update.releaseNotes != null && update.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('What\'s new:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(update.releaseNotes!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
          ),
          actions: [
            if (!isForced)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final url = Uri.parse(update.updateUrl);
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  // Fallback for cases where direct external launch fails
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const SplashScreen();
    if (!_isLoggedIn) {
      return LoginScreen(onLogin: _completeLogin);
    }

    return MainScreen(
      student: _student!,
      internalUserId: _internalUserId!,
      materials: _materials,
      announcements: _announcements,
      faculty: _faculty,
      settings: _settings,
      classes: _classes,
      notifications: _notifications,
      viewedAnnIds: _viewedAnnIds,
      isSyncing: _isSyncing,
      onLogout: _logout,
      onAddAnnouncement: _handleAddAnnouncement,
      onDeleteAnnouncement: _handleDeleteAnnouncement,
      onAddClass: _handleAddClass,
      onUpdateClass: _handleUpdateClass,
      onCancelClass: _handleCancelClass,
      onDeleteClass: _handleDeleteClass,
      onAddFaculty: _handleAddFaculty,
      onAddMaterial: _handleAddMaterial,
      onDeleteMaterial: _handleDeleteMaterial,
      onDownloadMaterial: _handleDownloadMaterial,
      onUpdateSettings: _updateSettings,
      onMarkAnnouncementsViewed: (ids) => setState(() => _viewedAnnIds.addAll(ids)),
      onClearNotifications: () => setState(() => _notifications = []),
      onMarkNotificationRead: (id) => setState(() {
        _notifications = _notifications.map((n) => n.id == id ? AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          read: true,
          type: n.type,
        ) : n).toList();
      }),
      onToggleFacultyVisibility: _toggleFacultyVisibility,
    );
  }
}
