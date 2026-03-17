import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'fidelshare_chat_v5.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE chat_messages ADD COLUMN is_edited INTEGER DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE chat_messages ADD COLUMN seen_by TEXT DEFAULT "[]"');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE chat_messages ADD COLUMN group_id TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE chat_messages ADD COLUMN sender_avatar_url TEXT');
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_messages(
        id TEXT PRIMARY KEY,
        role TEXT,
        sender_id TEXT,
        sender_name TEXT,
        sender_avatar_url TEXT,
        text TEXT,
        timestamp INTEGER,
        section TEXT,
        group_id TEXT,
        is_edited INTEGER DEFAULT 0,
        seen_by TEXT DEFAULT "[]"
      )
    ''');
    
    // Create index on section and timestamp
    await db.execute(
      'CREATE INDEX idx_chat_section_time ON chat_messages(section, timestamp DESC)'
    );
    await db.execute(
      'CREATE INDEX idx_chat_group_time ON chat_messages(group_id, timestamp DESC)'
    );
  }

  Future<void> insertMessages(List<ChatMessage> messages) async {
    final db = await database;
    Batch batch = db.batch();
    for (var msg in messages) {
      batch.insert(
        'chat_messages',
        {
          'id': msg.id,
          'role': msg.role,
          'sender_id': msg.senderId,
          'sender_name': msg.senderName,
          'sender_avatar_url': msg.senderAvatarUrl,
          'text': msg.text,
          'timestamp': msg.timestamp,
          'section': msg.section,
          'group_id': msg.groupId,
          'is_edited': msg.isEdited ? 1 : 0,
          'seen_by': jsonEncode(msg.seenBy),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertMessage(ChatMessage msg) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      {
        'id': msg.id,
        'role': msg.role,
        'sender_id': msg.senderId,
        'sender_name': msg.senderName,
        'sender_avatar_url': msg.senderAvatarUrl,
        'text': msg.text,
        'timestamp': msg.timestamp,
        'section': msg.section,
        'group_id': msg.groupId,
        'is_edited': msg.isEdited ? 1 : 0,
        'seen_by': jsonEncode(msg.seenBy),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getMessages(String section, {int? beforeTimestamp, int limit = 20}) async {
    return _getMessages(where: 'section = ?', whereArgs: [section], beforeTimestamp: beforeTimestamp, limit: limit);
  }

  Future<List<ChatMessage>> getGroupMessages(String groupId, {int? beforeTimestamp, int limit = 20}) async {
    return _getMessages(where: 'group_id = ?', whereArgs: [groupId], beforeTimestamp: beforeTimestamp, limit: limit);
  }

  Future<List<ChatMessage>> _getMessages({required String where, required List<dynamic> whereArgs, int? beforeTimestamp, int limit = 20}) async {
    final db = await database;
    String whereString = where;
    List<dynamic> args = List.from(whereArgs);

    if (beforeTimestamp != null) {
      whereString += ' AND timestamp < ?';
      args.add(beforeTimestamp);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: whereString,
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((m) => ChatMessage(
      id: m['id'].toString(),
      role: m['role']?.toString() ?? 'user',
      senderId: m['sender_id']?.toString() ?? '',
      senderName: m['sender_name']?.toString() ?? 'Unknown',
      senderAvatarUrl: m['sender_avatar_url']?.toString(),
      text: m['text']?.toString() ?? '',
      timestamp: m['timestamp'] as int,
      section: m['section']?.toString(),
      groupId: m['group_id']?.toString(),
      isEdited: (m['is_edited'] as int? ?? 0) == 1,
      seenBy: m['seen_by'] != null 
          ? List<Map<String, String>>.from(
              (jsonDecode(m['seen_by']) as List).map((e) => Map<String, String>.from(e)))
          : [],
    )).toList();
  }

  Future<int?> getLatestTimestamp(String section) async {
    return _getLatestTimestamp('section = ?', [section]);
  }

  Future<int?> getLatestGroupTimestamp(String groupId) async {
    return _getLatestTimestamp('group_id = ?', [groupId]);
  }

  Future<int?> _getLatestTimestamp(String where, List<dynamic> whereArgs) async {
    final db = await database;
    final result = await db.query(
      'chat_messages',
      columns: ['timestamp'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['timestamp'] as int?;
    }
    return null;
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMessage(String id, String newText) async {
    final db = await database;
    await db.update(
      'chat_messages',
      {
        'text': newText,
        'is_edited': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMessageReceipts(String id, List<Map<String, String>> seenBy) async {
    final db = await database;
    await db.update(
      'chat_messages',
      {'seen_by': jsonEncode(seenBy)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
