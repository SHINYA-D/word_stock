import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/test_result.dart';
import 'database_helper.dart';
import 'tables/test_result_table.dart';

class TestResultLocalDataSource {
  TestResultLocalDataSource(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Map<String, dynamic> _toRow(
    TestResult result, {
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

  TestResult _toTestResult(Map<String, dynamic> row) {
    return TestResult(
      id: row['id'] as String,
      folderId: row['folderId'] as String,
      totalCount: row['totalCount'] as int,
      correctCount: row['correctCount'] as int,
      date: DateTime.parse(row['date'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<void> insert(
    TestResult result, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      TestResultTable.tableName,
      _toRow(result, userId: userId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TestResult>> findByUserId(
    String userId, {
    String? folderId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      TestResultTable.tableName,
      where: folderId != null
          ? 'userId = ? AND folderId = ?'
          : 'userId = ?',
      whereArgs: folderId != null ? [userId, folderId] : [userId],
      orderBy: 'date DESC',
    );
    return rows.map(_toTestResult).toList();
  }

  Future<void> delete(String resultId) async {
    final db = await _dbHelper.database;
    await db.delete(
      TestResultTable.tableName,
      where: 'id = ?',
      whereArgs: [resultId],
    );
  }

  Future<void> upsert(TestResult result, {required String userId}) async {
    final db = await _dbHelper.database;
    await db.insert(
      TestResultTable.tableName,
      _toRow(result, userId: userId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
