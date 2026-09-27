import 'package:sqflite/sqflite.dart';

class FolderTable {
  static const String tableName = 'folders';

  static Future<void> onCreate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parentFolderId TEXT,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT,
        syncStatus TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  /// バージョン1 → 2：論理削除の列を追加する
  static Future<void> upgradeToV2(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE $tableName ADD COLUMN deletedAt TEXT');
  }
}
