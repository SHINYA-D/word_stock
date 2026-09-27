import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'local_date.dart';
import 'tables/sync_queue_table.dart';

/// キューの 1 項目。変更の中身は持たず、どのデータが変わったかだけを持つ。
class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.operation,
    required this.tableName,
    required this.recordId,
    required this.createdAt,
    this.parentId,
  });

  final int id;

  /// `upsert` / `delete`。送信する内容はローカルの最新の行で決まるので、
  /// 使うのは行が残っていないバージョン1の削除を送るときだけ。
  final String operation;
  final String tableName;
  final String recordId;
  final String? parentId;
  final DateTime createdAt;
}

class SyncQueueDataSource {
  SyncQueueDataSource(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Map<String, Object?> _toRow({
    required String operation,
    required String tableName,
    required String recordId,
    required String userId,
    String? parentId,
  }) {
    return {
      'operation': operation,
      'table_name': tableName,
      'record_id': recordId,
      'parent_id': parentId,
      'user_id': userId,
      'created_at': toDateColumn(DateTime.now()),
    };
  }

  /// キューに追加（単体使用時）
  Future<void> enqueue({
    required String operation,
    required String tableName,
    required String recordId,
    required String userId,
    String? parentId,
  }) async {
    final db = await _dbHelper.database;
    await enqueueInTransaction(
      db,
      operation: operation,
      tableName: tableName,
      recordId: recordId,
      userId: userId,
      parentId: parentId,
    );
  }

  /// トランザクション内でキューに追加（データ書き込みと同時実行時に使用）
  Future<void> enqueueInTransaction(
    DatabaseExecutor txn, {
    required String operation,
    required String tableName,
    required String recordId,
    required String userId,
    String? parentId,
  }) async {
    await txn.insert(
      SyncQueueTable.tableName,
      _toRow(
        operation: operation,
        tableName: tableName,
        recordId: recordId,
        userId: userId,
        parentId: parentId,
      ),
    );
  }

  /// キューから積んだ順に全件取得
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _dbHelper.database;
    return await db.query(SyncQueueTable.tableName, orderBy: 'id ASC');
  }

  /// ユーザーの項目を積んだ順に取得
  Future<List<SyncQueueItem>> getByUser(String userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      SyncQueueTable.tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );
    return rows
        .map((r) => SyncQueueItem(
              id: r['id'] as int,
              operation: r['operation'] as String,
              tableName: r['table_name'] as String,
              recordId: r['record_id'] as String,
              parentId: r['parent_id'] as String?,
              createdAt: fromDateColumn(r['created_at']).toUtc(),
            ))
        .toList();
  }

  /// 特定のキューを削除（同期成功時）
  Future<void> delete(int id, [DatabaseExecutor? txn]) async {
    final db = txn ?? await _dbHelper.database;
    await db.delete(
      SyncQueueTable.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// あるデータを指す項目をすべて削除（リモートの変更が勝ったとき）
  Future<void> deleteForRecord(
    DatabaseExecutor txn,
    String tableName,
    String recordId,
  ) async {
    await txn.delete(
      SyncQueueTable.tableName,
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );
  }

  /// あるデータを指す項目が残っているか
  Future<bool> hasItemsForRecord(
    DatabaseExecutor txn,
    String tableName,
    String recordId,
  ) async {
    final rows = await txn.query(
      SyncQueueTable.tableName,
      columns: ['id'],
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// キュー件数を取得
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${SyncQueueTable.tableName}',
    );
    return result.first['count'] as int;
  }

  /// ユーザーの未送信の件数
  Future<int> countByUser(String userId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${SyncQueueTable.tableName} '
      'WHERE user_id = ?',
      [userId],
    );
    return result.first['count'] as int;
  }
}
