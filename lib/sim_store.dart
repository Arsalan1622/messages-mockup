import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local-only store for simulated messages. Nothing here ever leaves the
/// phone: no network, no SMS provider writes, no sending.
class SimStore {
  SimStore._();
  static final SimStore instance = SimStore._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'simulated_messages.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE simulated_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            address TEXT NOT NULL,
            display_name TEXT,
            body TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<ChatMessage>> getAll() async {
    final db = await _database;
    final rows = await db.query('simulated_messages', orderBy: 'timestamp DESC');
    return rows.map((r) => ChatMessage(
          address: r['address'] as String,
          displayName: r['display_name'] as String?,
          body: r['body'] as String,
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int),
          isSent: false,
          isRead: (r['is_read'] as int) == 1,
          isSimulated: true,
          simId: r['id'] as int,
        ))
        .toList();
  }

  Future<int> insert({
    required String address,
    String? displayName,
    required String body,
    required DateTime timestamp,
  }) async {
    final db = await _database;
    return db.insert('simulated_messages', {
      'address': address.trim(),
      'display_name': (displayName == null || displayName.trim().isEmpty)
          ? null
          : displayName.trim(),
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'is_read': 0,
    });
  }

  /// Mark every simulated message in a conversation read (when opened).
  Future<void> markConversationRead(String address) async {
    final db = await _database;
    await db.update(
      'simulated_messages',
      {'is_read': 1},
      where: 'address = ?',
      whereArgs: [address.trim()],
    );
  }

  Future<void> deleteMessage(int simId) async {
    final db = await _database;
    await db.delete('simulated_messages', where: 'id = ?', whereArgs: [simId]);
  }

  /// Delete all simulated messages for one address. Returns how many were
  /// removed. Real SMS are never touched.
  Future<int> deleteConversation(String address) async {
    final db = await _database;
    return db.delete(
      'simulated_messages',
      where: 'address = ?',
      whereArgs: [address.trim()],
    );
  }

  /// Tiny key-value store (first-run flag etc.).
  Future<String?> getMeta(String key) async {
    final db = await _database;
    final rows = await db.query('meta',
        columns: ['value'], where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await _database;
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
