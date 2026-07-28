import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'database_helper.dart';
import 'tables/flashcard_result_table.dart';

class FlashcardResultLocalDataSource {
  FlashcardResultLocalDataSource(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Map<String, dynamic> _toRow(
    FlashcardResult result, {
    required String userId,
    String syncStatus = 'synced',
  }) {
    return {
      'id': result.id,
      'folderId': result.folderId,
      'totalCount': result.totalCount,
      'correctCount': result.correctCount,
      'date': result.date.toIso8601String(),
      'userId': userId,
      'updatedAt': result.updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  FlashcardResult _toFlashcardResult(Map<String, dynamic> row) {
    return FlashcardResult(
      id: row['id'] as String,
      folderId: row['folderId'] as String,
      totalCount: row['totalCount'] as int,
      correctCount: row['correctCount'] as int,
      date: DateTime.parse(row['date'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<void> insert(
    FlashcardResult result, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      FlashcardResultTable.tableName,
      _toRow(result, userId: userId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FlashcardResult>> findByUserId(
    String userId, {
    String? folderId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      FlashcardResultTable.tableName,
      where: folderId != null
          ? 'userId = ? AND folderId = ?'
          : 'userId = ?',
      whereArgs: folderId != null ? [userId, folderId] : [userId],
      orderBy: 'date DESC',
    );
    return rows.map(_toFlashcardResult).toList();
  }

  Future<void> delete(String resultId) async {
    final db = await _dbHelper.database;
    await db.delete(
      FlashcardResultTable.tableName,
      where: 'id = ?',
      whereArgs: [resultId],
    );
  }

  Future<void> upsert(FlashcardResult result, {required String userId}) async {
    final db = await _dbHelper.database;
    await db.insert(
      FlashcardResultTable.tableName,
      _toRow(result, userId: userId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
