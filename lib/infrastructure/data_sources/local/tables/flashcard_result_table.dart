import 'package:sqflite/sqflite.dart';

class FlashcardResultTable {
  static const String tableName = 'flashcard_results';

  static Future<void> onCreate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        folderId TEXT NOT NULL,
        totalCount INTEGER NOT NULL,
        correctCount INTEGER NOT NULL,
        date TEXT NOT NULL,
        userId TEXT NOT NULL,
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
