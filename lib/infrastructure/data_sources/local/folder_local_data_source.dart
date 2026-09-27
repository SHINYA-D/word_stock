import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'database_helper.dart';
import 'local_date.dart';
import 'tables/folder_table.dart';

class FolderLocalDataSource {
  FolderLocalDataSource(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Map<String, dynamic> _toRow(
    Folder folder, {
    required String userId,
    String syncStatus = 'synced',
  }) {
    return {
      'id': folder.id,
      'name': folder.name,
      'parentFolderId': folder.parentFolderId,
      'userId': userId,
      'createdAt': toDateColumn(folder.createdAt),
      'updatedAt': toDateColumn(folder.updatedAt),
      'deletedAt': null,
      'syncStatus': syncStatus,
    };
  }

  Folder _toFolder(Map<String, dynamic> row) {
    return Folder(
      id: row['id'] as String,
      name: row['name'] as String,
      parentFolderId: row['parentFolderId'] as String?,
      createdAt: fromDateColumn(row['createdAt']),
      updatedAt: fromDateColumn(row['updatedAt']),
    );
  }

  Future<void> insert(
    Folder folder, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await save(db, folder, userId: userId, syncStatus: syncStatus);
  }

  Future<void> update(
    Folder folder, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      FolderTable.tableName,
      _toRow(folder, userId: userId, syncStatus: syncStatus),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> delete(String folderId) async {
    final db = await _dbHelper.database;
    await db.delete(
      FolderTable.tableName,
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  /// 削除済みも含めて id で探す。
  Future<Folder?> findById(String folderId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      FolderTable.tableName,
      where: 'id = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _toFolder(rows.first);
  }

  /// 未削除のフォルダを返す。
  Future<List<Folder>> findByUserId(
    String userId, {
    String? parentFolderId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      FolderTable.tableName,
      where: parentFolderId != null
          ? 'userId = ? AND parentFolderId = ? AND deletedAt IS NULL'
          : 'userId = ? AND parentFolderId IS NULL AND deletedAt IS NULL',
      whereArgs: parentFolderId != null ? [userId, parentFolderId] : [userId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(_toFolder).toList();
  }

  Future<void> upsert(Folder folder, {required String userId}) async {
    final db = await _dbHelper.database;
    await save(db, folder, userId: userId);
  }

  // ---- トランザクション内で使う操作（Transaction / Database のどちらも渡せる） ----

  /// ユーザーの未削除のフォルダを id で探す。削除済み・他のユーザーのものは null。
  Future<Folder?> findActive(
    DatabaseExecutor db,
    String folderId, {
    required String userId,
  }) async {
    final rows = await db.query(
      FolderTable.tableName,
      where: 'id = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [folderId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _toFolder(rows.first);
  }

  /// 未削除の子フォルダの id。
  Future<List<String>> findActiveChildIds(
    DatabaseExecutor db,
    String parentFolderId, {
    required String userId,
  }) async {
    final rows = await db.query(
      FolderTable.tableName,
      columns: ['id'],
      where: 'parentFolderId = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [parentFolderId, userId],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> save(
    DatabaseExecutor db,
    Folder folder, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    await db.insert(
      FolderTable.tableName,
      _toRow(folder, userId: userId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 論理削除する（deletedAt と updatedAt に [at] を入れ、pending にする）。
  Future<void> markDeleted(DatabaseExecutor db, String folderId, DateTime at) async {
    await db.update(
      FolderTable.tableName,
      {
        'deletedAt': toDateColumn(at),
        'updatedAt': toDateColumn(at),
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }
}
