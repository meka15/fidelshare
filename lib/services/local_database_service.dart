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
    String path = join(await getDatabasesPath(), 'fidelshare_chat.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_messages(
        id TEXT PRIMARY KEY,
        role TEXT,
        sender_id TEXT,
        sender_name TEXT,
        text TEXT,
        timestamp INTEGER,
        section TEXT
      )
    ''');
    
    // Create index on section and timestamp
    await db.execute(
      'CREATE INDEX idx_chat_section_time ON chat_messages(section, timestamp DESC)'
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
          'text': msg.text,
          'timestamp': msg.timestamp,
          'section': msg.section,
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
        'text': msg.text,
        'timestamp': msg.timestamp,
        'section': msg.section,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getMessages(String section, {int? beforeTimestamp, int limit = 20}) async {
    final db = await database;
    String whereString = 'section = ?';
    List<dynamic> whereArgs = [section];

    if (beforeTimestamp != null) {
      whereString += ' AND timestamp < ?';
      whereArgs.add(beforeTimestamp);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((m) => ChatMessage(
      id: m['id'].toString(),
      role: m['role']?.toString() ?? 'user',
      senderId: m['sender_id']?.toString() ?? '',
      senderName: m['sender_name']?.toString() ?? 'Unknown',
      text: m['text']?.toString() ?? '',
      timestamp: m['timestamp'] as int,
      section: m['section']?.toString() ?? '',
    )).toList();
  }

  Future<int?> getLatestTimestamp(String section) async {
    final db = await database;
    final result = await db.query(
      'chat_messages',
      columns: ['timestamp'],
      where: 'section = ?',
      whereArgs: [section],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['timestamp'] as int?;
    }
    return null;
  }
}
