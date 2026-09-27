import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'database_helper.dart';
import 'local_date.dart';
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
      'date': toDateColumn(result.date),
      'userId': userId,
      'updatedAt': toDateColumn(result.updatedAt),
      'deletedAt': null,
      'syncStatus': syncStatus,
    };
  }

  FlashcardResult _toFlashcardResult(Map<String, dynamic> row) {
    return FlashcardResult(
      id: row['id'] as String,
      folderId: row['folderId'] as String,
      totalCount: row['totalCount'] as int,
      correctCount: row['correctCount'] as int,
      date: fromDateColumn(row['date']),
      updatedAt: fromDateColumn(row['updatedAt']),
    );
  }

  Future<void> insert(
    FlashcardResult result, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await save(db, result, userId: userId, syncStatus: syncStatus);
  }

  /// 未削除の成績を返す。
  Future<List<FlashcardResult>> findByUserId(
    String userId, {
    String? folderId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      FlashcardResultTable.tableName,
      where: folderId != null
          ? 'userId = ? AND folderId = ? AND deletedAt IS NULL'
          : 'userId = ? AND deletedAt IS NULL',
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
    await save(db, result, userId: userId);
  }

  // ---- トランザクション内で使う操作（Transaction / Database のどちらも渡せる） ----

  /// フォルダの未削除の成績の id。
  Future<List<String>> findActiveIdsByFolder(
    DatabaseExecutor db,
    String folderId, {
    required String userId,
  }) async {
    final rows = await db.query(
      FlashcardResultTable.tableName,
      columns: ['id'],
      where: 'folderId = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [folderId, userId],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> save(
    DatabaseExecutor db,
    FlashcardResult result, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    await db.insert(
      FlashcardResultTable.tableName,
      _toRow(result, userId: userId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 論理削除する（deletedAt と updatedAt に [at] を入れ、pending にする）。
  Future<void> markDeleted(DatabaseExecutor db, String resultId, DateTime at) async {
    await db.update(
      FlashcardResultTable.tableName,
      {
        'deletedAt': toDateColumn(at),
        'updatedAt': toDateColumn(at),
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [resultId],
    );
  }
}
