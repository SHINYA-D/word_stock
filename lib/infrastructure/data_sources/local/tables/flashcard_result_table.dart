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
        syncStatus TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }
}
