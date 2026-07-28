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
  static const int _dbVersion = 1;

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
}
