import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'database_helper.dart';
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
      'createdAt': word.createdAt.toIso8601String(),
      'updatedAt': word.updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  Word _toWord(Map<String, dynamic> row) {
    return Word(
      id: row['id'] as String,
      front: row['front'] as String,
      back: row['back'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<void> insert(
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      WordTable.tableName,
      _toRow(word, userId: userId, folderId: folderId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  Future<List<Word>> findByFolderId(
    String folderId, {
    required String userId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      WordTable.tableName,
      where: 'folderId = ? AND userId = ?',
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
    await db.insert(
      WordTable.tableName,
      _toRow(word, userId: userId, folderId: folderId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteByFolderId(String folderId) async {
    final db = await _dbHelper.database;
    await db.delete(
      WordTable.tableName,
      where: 'folderId = ?',
      whereArgs: [folderId],
    );
  }
}
