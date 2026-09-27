import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'database_helper.dart';
import 'local_date.dart';
import 'tables/word_table.dart';

class WordLocalDataSource {
  WordLocalDataSource(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Map<String, dynamic> _toRow(
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) {
    return {
      'id': word.id,
      'front': word.front,
      'back': word.back,
      'folderId': folderId,
      'userId': userId,
      'createdAt': toDateColumn(word.createdAt),
      'updatedAt': toDateColumn(word.updatedAt),
      'deletedAt': null,
      'syncStatus': syncStatus,
    };
  }

  Word _toWord(Map<String, dynamic> row) {
    return Word(
      id: row['id'] as String,
      front: row['front'] as String,
      back: row['back'] as String,
      createdAt: fromDateColumn(row['createdAt']),
      updatedAt: fromDateColumn(row['updatedAt']),
    );
  }

  Future<void> insert(
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await save(db, word,
        userId: userId, folderId: folderId, syncStatus: syncStatus);
  }

  Future<void> update(
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      WordTable.tableName,
      _toRow(word, userId: userId, folderId: folderId, syncStatus: syncStatus),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<void> delete(String wordId) async {
    final db = await _dbHelper.database;
    await db.delete(
      WordTable.tableName,
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  /// 削除済みも含めて id で探す。
  Future<Word?> findById(String wordId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      WordTable.tableName,
      where: 'id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _toWord(rows.first);
  }

  /// フォルダの未削除の単語を返す。
  Future<List<Word>> findByFolderId(
    String folderId, {
    required String userId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      WordTable.tableName,
      where: 'folderId = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [folderId, userId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(_toWord).toList();
  }

  Future<void> upsert(
    Word word, {
    required String userId,
    required String folderId,
  }) async {
    final db = await _dbHelper.database;
    await save(db, word, userId: userId, folderId: folderId);
  }

  Future<void> deleteByFolderId(String folderId) async {
    final db = await _dbHelper.database;
    await db.delete(
      WordTable.tableName,
      where: 'folderId = ?',
      whereArgs: [folderId],
    );
  }

  // ---- トランザクション内で使う操作（Transaction / Database のどちらも渡せる） ----

  /// ユーザーの未削除の単語を id で探す。削除済み・他のユーザーのものは null。
  Future<Word?> findActive(
    DatabaseExecutor db,
    String wordId, {
    required String userId,
  }) async {
    final rows = await db.query(
      WordTable.tableName,
      where: 'id = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [wordId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _toWord(rows.first);
  }

  /// フォルダの未削除の単語の id。
  Future<List<String>> findActiveIdsByFolder(
    DatabaseExecutor db,
    String folderId, {
    required String userId,
  }) async {
    final rows = await db.query(
      WordTable.tableName,
      columns: ['id'],
      where: 'folderId = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [folderId, userId],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> save(
    DatabaseExecutor db,
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) async {
    await db.insert(
      WordTable.tableName,
      _toRow(word, userId: userId, folderId: folderId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 論理削除する（deletedAt と updatedAt に [at] を入れ、pending にする）。
  Future<void> markDeleted(DatabaseExecutor db, String wordId, DateTime at) async {
    await db.update(
      WordTable.tableName,
      {
        'deletedAt': toDateColumn(at),
        'updatedAt': toDateColumn(at),
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }
}
