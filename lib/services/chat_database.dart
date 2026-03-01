import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

/// Local SQLite database for caching chat messages.
/// Indexed on section_id and timestamp for efficient paginated queries.
class ChatLocalDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'chat_messages.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chat_messages (
            id        TEXT PRIMARY KEY,
            sender_id TEXT NOT NULL,
            sender_name TEXT NOT NULL,
            text      TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            section_id INTEGER NOT NULL,
            role      TEXT NOT NULL DEFAULT 'user'
          )
        ''');
        // Composite index covers both section filtering and timestamp ordering.
        await db.execute(
          'CREATE INDEX idx_chat_section_ts ON chat_messages(section_id, timestamp DESC)',
        );
      },
    );
  }

  /// Returns the most recent [limit] messages for [sectionId], ordered oldest→newest.
  /// Pass [beforeTimestamp] to load older messages for pagination.
  static Future<List<ChatMessage>> getMessages(
    int sectionId, {
    int limit = 20,
    int? beforeTimestamp,
  }) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (beforeTimestamp != null) {
      rows = await db.query(
        'chat_messages',
        where: 'section_id = ? AND timestamp < ?',
        whereArgs: [sectionId, beforeTimestamp],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    } else {
      rows = await db.query(
        'chat_messages',
        where: 'section_id = ?',
        whereArgs: [sectionId],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    }
    // Reverse so messages are in ascending order (oldest first).
    return rows.reversed.map((r) => ChatMessage.fromDb(r)).toList();
  }

  /// Returns the timestamp of the newest locally stored message for [sectionId],
  /// or null if no messages are cached.
  static Future<int?> getLatestTimestamp(int sectionId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(timestamp) AS max_ts FROM chat_messages WHERE section_id = ?',
      [sectionId],
    );
    if (rows.isEmpty) return null;
    return rows.first['max_ts'] as int?;
  }

  /// Inserts [messages] into the local DB, ignoring duplicates by primary key.
  static Future<void> insertMessages(
    List<ChatMessage> messages,
    int sectionId,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final msg in messages) {
      batch.insert(
        'chat_messages',
        msg.toDb(sectionId),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }
}
