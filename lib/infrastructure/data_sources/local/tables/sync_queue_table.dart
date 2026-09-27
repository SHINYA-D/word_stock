import 'package:sqflite/sqflite.dart';

class SyncQueueTable {
  static const String tableName = 'sync_queue';

  /// payload はバージョン1の名残（使わない）。送信時はローカルの最新の行を送る。
  static Future<void> onCreate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        parent_id TEXT,
        payload TEXT,
        created_at TEXT NOT NULL,
        user_id TEXT
      )
    ''');
  }

  /// バージョン1 → 2：キューの持ち主のユーザーを記録する列を追加する
  static Future<void> upgradeToV2(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE $tableName ADD COLUMN user_id TEXT');
  }
}
