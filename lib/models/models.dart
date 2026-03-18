enum AppTab {
  home,
  schedule,
  materials,
  chat,
  profile,
}

class Student {
  final String name;
  final String studentId;
  final bool isRepresentative;
  final String section;
  final int? batch;
  final String? avatarUrl;

  Student({
    required this.name,
    required this.studentId,
    required this.isRepresentative,
    required this.section,
    this.batch,
    this.avatarUrl,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      name: json['name'],
      studentId: json['studentId'],
      isRepresentative: json['isRepresentative'],
      section: json['section'],
      batch: json['batch'],
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'studentId': studentId,
      'isRepresentative': isRepresentative,
      'section': section,
      'batch': batch,
      'avatarUrl': avatarUrl,
    };
  }
}

class ClassSession {
  final String id;
  final String name;
  final String room;
  final String instructor;
  final String time;
  final String status; // 'completed' | 'ongoing' | 'upcoming' | 'cancelled'
  final DateTime startTime;
  final int dayOfWeek;
  final String section;
  final bool isPermanent;
  final DateTime? date;

  ClassSession({
    required this.id,
    required this.name,
    required this.room,
    required this.instructor,
    required this.time,
    required this.status,
    required this.startTime,
    required this.dayOfWeek,
    required this.section,
    this.isPermanent = true,
    this.date,
  });

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json['id'],
      name: json['name'],
      room: json['room'],
      instructor: json['instructor'],
      time: json['time'],
      status: json['status'],
      startTime: DateTime.parse(json['startTime']),
      dayOfWeek: json['dayOfWeek'],
      section: json['section'],
      isPermanent: json['isPermanent'] ?? true,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'room': room,
      'instructor': instructor,
      'time': time,
      'status': status,
      'startTime': startTime.toIso8601String(),
      'dayOfWeek': dayOfWeek,
      'section': section,
      'isPermanent': isPermanent,
      'date': date?.toIso8601String(),
    };
  }
}

class FacultyContact {
  final String id;
  final String name;
  final String role;
  final String avatar;
  final String? phoneNumber;
  final String? email;
  final String? section;
  final double averageRating;
  final int reviewCount;

  FacultyContact({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    this.phoneNumber,
    this.email,
    this.section,
    this.averageRating = 0.0,
    this.reviewCount = 0,
  });

  factory FacultyContact.fromJson(Map<String, dynamic> json) {
    return FacultyContact(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      avatar: json['avatar'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      section: json['section'],
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'avatar': avatar,
      'phoneNumber': phoneNumber,
      'email': email,
      'section': section,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
    };
  }
}

class StudyMaterial {
  final String id;
  final String url;
  final String name;
  final int timestamp;
  final String uploaderId;
  final String uploaderName;
  final bool isPublic;
  final int downloadCount;
  final String category;
  final String? fileSize;
  final String? summary;
  final String section;

  StudyMaterial({
    required this.id,
    required this.url,
    required this.name,
    required this.timestamp,
    required this.uploaderId,
    required this.uploaderName,
    required this.isPublic,
    required this.downloadCount,
    required this.category,
    this.fileSize,
    this.summary,
    required this.section,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      id: json['id'],
      url: json['url'],
      name: json['name'],
      timestamp: json['timestamp'],
      uploaderId: json['uploaderId'],
      uploaderName: json['uploaderName'],
      isPublic: json['isPublic'],
      downloadCount: json['downloadCount'],
      category: json['category'],
      fileSize: json['fileSize'],
      summary: json['summary'],
      section: json['section'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'timestamp': timestamp,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'isPublic': isPublic,
      'downloadCount': downloadCount,
      'category': category,
      'fileSize': fileSize,
      'summary': summary,
      'section': section,
    };
  }
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final int timestamp;
  final String authorName;
  final String authorId;
  final String section;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.authorName,
    required this.authorId,
    required this.section,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      timestamp: json['timestamp'],
      authorName: json['authorName'],
      authorId: json['authorId'],
      section: json['section'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': timestamp,
      'authorName': authorName,
      'authorId': authorId,
      'section': section,
    };
  }
}

class ChatMessage {
  final String id;
  final String role; // 'user' | 'model'
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final int timestamp;
  final String? section;
  final String? groupId;
  final bool isEdited;
  final List<Map<String, String>> seenBy;

  ChatMessage({
    required this.id,
    required this.role,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    required this.timestamp,
    this.section,
    this.groupId,
    this.isEdited = false,
    this.seenBy = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      role: json['role'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderAvatarUrl: json['senderAvatarUrl'],
      text: json['text'],
      timestamp: json['timestamp'],
      section: json['section'],
      groupId: json['groupId'],
      isEdited: json['isEdited'] ?? false,
      seenBy: json['seenBy'] != null 
          ? List<Map<String, String>>.from(
              (json['seenBy'] as List).map((e) => Map<String, String>.from(e)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'text': text,
      'timestamp': timestamp,
      'section': section,
      'groupId': groupId,
      'isEdited': isEdited,
      'seenBy': seenBy,
    };
  }
}

class ChatGroup {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final int createdAt;
  final List<String> members;
  final String? avatarUrl;
  final bool isPublic;

  ChatGroup({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    this.avatarUrl,
    this.isPublic = false,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdBy: json['createdBy'] ?? json['created_by'],
      createdAt: json['createdAt'] ?? (json['created_at'] != null ? DateTime.parse(json['created_at']).millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch),
      members: json['members'] != null ? List<String>.from(json['members']) : [],
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      isPublic: json['isPublic'] ?? json['is_public'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'members': members,
      'avatarUrl': avatarUrl,
      'isPublic': isPublic,
    };
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final int timestamp;
  final bool read;
  final String type; // 'class' | 'material' | 'system'

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.read,
    required this.type,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      timestamp: json['timestamp'],
      read: json['read'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'read': read,
      'type': type,
    };
  }
}

class NotificationSettings {
  final bool upcomingClasses;
  final bool newMaterials;
  final bool chatEnabled;
  final bool announcementsEnabled;
  final bool scheduleEnabled;
  final bool fingerprintEnabled;

  NotificationSettings({
    required this.upcomingClasses,
    required this.newMaterials,
    required this.chatEnabled,
    required this.announcementsEnabled,
    required this.scheduleEnabled,
    required this.fingerprintEnabled,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      upcomingClasses: json['upcomingClasses'] ?? true,
      newMaterials: json['newMaterials'] ?? true,
      chatEnabled: json['chatEnabled'] ?? true,
      announcementsEnabled: json['announcementsEnabled'] ?? true,
      scheduleEnabled: json['scheduleEnabled'] ?? true,
      fingerprintEnabled: json['fingerprintEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'upcomingClasses': upcomingClasses,
      'newMaterials': newMaterials,
      'chatEnabled': chatEnabled,
      'announcementsEnabled': announcementsEnabled,
      'scheduleEnabled': scheduleEnabled,
      'fingerprintEnabled': fingerprintEnabled,
    };
  }
}

class EduSyncSettings {
  final NotificationSettings notifications;
  final SyncSettings sync;
  final AppearanceSettings? appearance;
  final bool facultyVisible;

  EduSyncSettings({
    required this.notifications,
    required this.sync,
    this.appearance,
    this.facultyVisible = true,
  });

  factory EduSyncSettings.fromJson(Map<String, dynamic> json) {
    return EduSyncSettings(
      notifications: NotificationSettings.fromJson(json['notifications']),
      sync: SyncSettings.fromJson(json['sync']),
      appearance: json['appearance'] != null
          ? AppearanceSettings.fromJson(json['appearance'])
          : null,
      facultyVisible: json['facultyVisible'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications': notifications.toJson(),
      'sync': sync.toJson(),
      'appearance': appearance?.toJson(),
      'facultyVisible': facultyVisible,
    };
  }
}

class SyncSettings {
  final String cloudProvider; // 'supabase' | 'local'
  final int? lastSync;

  SyncSettings({
    required this.cloudProvider,
    this.lastSync,
  });

  factory SyncSettings.fromJson(Map<String, dynamic> json) {
    return SyncSettings(
      cloudProvider: json['cloudProvider'],
      lastSync: json['lastSync'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cloudProvider': cloudProvider,
      'lastSync': lastSync,
    };
  }
}

class AppearanceSettings {
  final String theme; // 'light' | 'dark' | 'system'

  AppearanceSettings({required this.theme});

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(theme: json['theme']);
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
    };
  }
}
