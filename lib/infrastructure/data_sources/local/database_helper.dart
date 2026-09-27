import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'tables/folder_table.dart';
import 'tables/word_table.dart';
import 'tables/flashcard_result_table.dart';
import 'tables/settings_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/sync_meta_table.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String _dbName = 'wordstock.db';
  static const int _dbVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await FolderTable.onCreate(txn);
      await WordTable.onCreate(txn);
      await FlashcardResultTable.onCreate(txn);
      await SettingsTable.onCreate(txn);
      await SyncQueueTable.onCreate(txn);
      await SyncMetaTable.onCreate(txn);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await migrateToV2(db);
  }

  /// バージョン1 → 2 の移行。既存のデータは消さない。
  ///
  /// - 論理削除の列（deletedAt）とキューの持ち主（user_id）を追加する
  /// - キューの項目に、対象データの持ち主のユーザーを記録する
  /// - キューに変更が残っていないのに pending になっているデータを synced に直す
  /// - 端末の時計で記録していた旧い取得の基準を消す（次の取得はすべてのデータが対象になる）
  static Future<void> migrateToV2(DatabaseExecutor db) async {
    await FolderTable.upgradeToV2(db);
    await WordTable.upgradeToV2(db);
    await FlashcardResultTable.upgradeToV2(db);
    await SyncQueueTable.upgradeToV2(db);

    const queue = SyncQueueTable.tableName;
    for (final table in [
      FolderTable.tableName,
      WordTable.tableName,
      FlashcardResultTable.tableName,
    ]) {
      await db.execute('''
        UPDATE $queue SET user_id =
          (SELECT userId FROM $table WHERE $table.id = $queue.record_id)
        WHERE table_name = '$table' AND user_id IS NULL
      ''');
    }
    await db.execute('''
      UPDATE $queue SET user_id = record_id
      WHERE table_name = '${SettingsTable.tableName}' AND user_id IS NULL
    ''');
    // 旧実装は削除した行を物理的に消していたため、行から持ち主を引けない項目が残る。
    // 端末のユーザーが1人だけなら、その項目はそのユーザーのものとして引き継ぐ。
    final users = await db.rawQuery('''
      SELECT userId FROM ${FolderTable.tableName}
      UNION SELECT userId FROM ${WordTable.tableName}
      UNION SELECT userId FROM ${FlashcardResultTable.tableName}
      UNION SELECT userId FROM ${SettingsTable.tableName}
    ''');
    if (users.length == 1) {
      await db.update(
        queue,
        {'user_id': users.first['userId']},
        where: 'user_id IS NULL',
      );
    }

    for (final table in [
      FolderTable.tableName,
      WordTable.tableName,
      FlashcardResultTable.tableName,
    ]) {
      await db.execute('''
        UPDATE $table SET syncStatus = 'synced'
        WHERE syncStatus = 'pending' AND id NOT IN
          (SELECT record_id FROM $queue WHERE table_name = '$table')
      ''');
    }
    await db.execute('''
      UPDATE ${SettingsTable.tableName} SET syncStatus = 'synced'
      WHERE syncStatus = 'pending' AND userId NOT IN
        (SELECT record_id FROM $queue
         WHERE table_name = '${SettingsTable.tableName}')
    ''');

    await db.delete(
      SyncMetaTable.tableName,
      where: 'key = ?',
      whereArgs: ['lastSyncedAt'],
    );
  }
}
