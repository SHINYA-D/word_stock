import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'database_helper.dart';
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
      'createdAt': folder.createdAt.toIso8601String(),
      'updatedAt': folder.updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  Folder _toFolder(Map<String, dynamic> row) {
    return Folder(
      id: row['id'] as String,
      name: row['name'] as String,
      parentFolderId: row['parentFolderId'] as String?,
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<void> insert(
    Folder folder, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      FolderTable.tableName,
      _toRow(folder, userId: userId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  Future<List<Folder>> findByUserId(
    String userId, {
    String? parentFolderId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      FolderTable.tableName,
      where: parentFolderId != null
          ? 'userId = ? AND parentFolderId = ?'
          : 'userId = ? AND parentFolderId IS NULL',
      whereArgs: parentFolderId != null ? [userId, parentFolderId] : [userId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(_toFolder).toList();
  }

  Future<void> upsert(Folder folder, {required String userId}) async {
    final db = await _dbHelper.database;
    await db.insert(
      FolderTable.tableName,
      _toRow(folder, userId: userId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
