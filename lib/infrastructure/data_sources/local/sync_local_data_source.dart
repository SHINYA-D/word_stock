import 'package:sqflite/sqflite.dart';
import 'package:word_stock/infrastructure/data_sources/sync_record.dart';
import 'database_helper.dart';
import 'local_date.dart';
import 'tables/flashcard_result_table.dart';
import 'tables/folder_table.dart';
import 'tables/settings_table.dart';
import 'tables/sync_meta_table.dart';
import 'tables/word_table.dart';

/// ローカルの 1 件と、未送信の変更があるか（syncStatus が pending か）。
typedef LocalSyncRow = ({SyncRecord record, bool pending});

/// 同期のために、4 つのデータのテーブルを [SyncRecord] として読み書きする。
///
/// SQLite の行と [SyncRecord] の変換（日時・真偽値）はここに閉じ込める。
class SyncLocalDataSource {
  SyncLocalDataSource(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<Database> get database => _dbHelper.database;

  static String tableOf(SyncEntity entity) => _specs[entity]!.table;

  static SyncEntity entityOf(String tableName) =>
      _specs.entries.firstWhere((e) => e.value.table == tableName).key;

  Future<LocalSyncRow?> find(
    DatabaseExecutor db,
    SyncEntity entity,
    String id, {
    required String userId,
  }) async {
    final spec = _specs[entity]!;
    final rows = await db.query(
      spec.table,
      where: '${spec.idColumn} = ? AND userId = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (record: _toRecord(entity, row), pending: row['syncStatus'] == 'pending');
  }

  /// [record] でローカルの行を置き換える。
  Future<void> put(
    DatabaseExecutor db,
    SyncRecord record, {
    required String userId,
    required bool pending,
  }) async {
    final spec = _specs[record.entity]!;
    final row = <String, Object?>{
      spec.idColumn: record.id,
      'userId': userId,
      'updatedAt': toDateColumn(record.updatedAt),
      'syncStatus': pending ? 'pending' : 'synced',
    };
    if (spec.hasDeletedAt) {
      row['deletedAt'] = toNullableDateColumn(record.deletedAt);
    }
    if (spec.parentColumn != null) row[spec.parentColumn!] = record.parentId;
    for (final field in spec.fields) {
      final value = record.fields[field];
      row[field] = switch (value) {
        DateTime() => toDateColumn(value),
        bool() => value ? 1 : 0,
        _ => value,
      };
    }
    await db.insert(spec.table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markSynced(DatabaseExecutor db, SyncEntity entity, String id) async {
    final spec = _specs[entity]!;
    await db.update(
      spec.table,
      {'syncStatus': 'synced'},
      where: '${spec.idColumn} = ?',
      whereArgs: [id],
    );
  }

  /// 論理削除する（deletedAt と updatedAt に [at] を入れ、pending にする）。
  Future<void> markDeleted(
    DatabaseExecutor db,
    SyncEntity entity,
    String id,
    DateTime at,
  ) async {
    final spec = _specs[entity]!;
    await db.update(
      spec.table,
      {
        'deletedAt': toDateColumn(at),
        'updatedAt': toDateColumn(at),
        'syncStatus': 'pending',
      },
      where: '${spec.idColumn} = ?',
      whereArgs: [id],
    );
  }

  /// フォルダがローカルで削除済みか（存在しなければ false）。
  Future<bool> isFolderDeleted(
    DatabaseExecutor db,
    String folderId, {
    required String userId,
  }) async {
    final rows = await db.query(
      FolderTable.tableName,
      columns: ['deletedAt'],
      where: 'id = ? AND userId = ?',
      whereArgs: [folderId, userId],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['deletedAt'] != null;
  }

  /// フォルダ配下の未削除のデータ（サブフォルダを再帰的にたどる）。
  /// 戻り値の各要素は、(種類, id, 単語なら親フォルダの id)。
  Future<List<({SyncEntity entity, String id, String? parentId})>>
      activeDescendants(
    DatabaseExecutor db,
    String folderId, {
    required String userId,
  }) async {
    final out = <({SyncEntity entity, String id, String? parentId})>[];
    final pending = [folderId];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final words = await db.query(
        WordTable.tableName,
        columns: ['id'],
        where: 'folderId = ? AND userId = ? AND deletedAt IS NULL',
        whereArgs: [current, userId],
      );
      for (final w in words) {
        out.add((entity: SyncEntity.word, id: w['id'] as String, parentId: current));
      }
      final results = await db.query(
        FlashcardResultTable.tableName,
        columns: ['id'],
        where: 'folderId = ? AND userId = ? AND deletedAt IS NULL',
        whereArgs: [current, userId],
      );
      for (final r in results) {
        out.add((entity: SyncEntity.flashcardResult, id: r['id'] as String, parentId: null));
      }
      final children = await db.query(
        FolderTable.tableName,
        columns: ['id'],
        where: 'parentFolderId = ? AND userId = ? AND deletedAt IS NULL',
        whereArgs: [current, userId],
      );
      for (final c in children) {
        final id = c['id'] as String;
        out.add((entity: SyncEntity.folder, id: id, parentId: null));
        pending.add(id);
      }
    }
    return out;
  }

  // ---- sync_meta ----

  Future<String?> readMeta(String key) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      SyncMetaTable.tableName,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> writeMeta(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      SyncMetaTable.tableName,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> readMetaDate(String key) async {
    final value = await readMeta(key);
    return value == null ? null : DateTime.parse(value).toUtc();
  }

  Future<void> writeMetaDate(String key, DateTime value) =>
      writeMeta(key, toDateColumn(value));

  SyncRecord _toRecord(SyncEntity entity, Map<String, Object?> row) {
    final spec = _specs[entity]!;
    final fields = <String, Object?>{};
    for (final field in spec.fields) {
      final value = row[field];
      if (spec.dateFields.contains(field)) {
        fields[field] = value == null ? null : fromDateColumn(value).toUtc();
      } else if (spec.boolFields.contains(field)) {
        fields[field] = value == 1;
      } else {
        fields[field] = value;
      }
    }
    return SyncRecord(
      entity: entity,
      id: row[spec.idColumn]! as String,
      parentId: spec.parentColumn == null ? null : row[spec.parentColumn] as String?,
      fields: fields,
      updatedAt: fromDateColumn(row['updatedAt']).toUtc(),
      deletedAt: spec.hasDeletedAt
          ? fromNullableDateColumn(row['deletedAt'])?.toUtc()
          : null,
    );
  }
}

class _TableSpec {
  const _TableSpec({
    required this.table,
    required this.fields,
    this.idColumn = 'id',
    this.parentColumn,
    this.dateFields = const {},
    this.boolFields = const {},
    this.hasDeletedAt = true,
  });

  final String table;
  final String idColumn;
  final String? parentColumn;

  /// updatedAt / deletedAt / userId / syncStatus / 親の列 以外の列
  final List<String> fields;
  final Set<String> dateFields;
  final Set<String> boolFields;
  final bool hasDeletedAt;
}

const _specs = <SyncEntity, _TableSpec>{
  SyncEntity.folder: _TableSpec(
    table: FolderTable.tableName,
    fields: ['name', 'parentFolderId', 'createdAt'],
    dateFields: {'createdAt'},
  ),
  SyncEntity.word: _TableSpec(
    table: WordTable.tableName,
    parentColumn: 'folderId',
    fields: ['front', 'back', 'createdAt'],
    dateFields: {'createdAt'},
  ),
  SyncEntity.flashcardResult: _TableSpec(
    table: FlashcardResultTable.tableName,
    fields: ['folderId', 'totalCount', 'correctCount', 'date'],
    dateFields: {'date'},
  ),
  SyncEntity.settings: _TableSpec(
    table: SettingsTable.tableName,
    idColumn: 'userId',
    fields: ['colorTheme', 'darkMode'],
    boolFields: {'darkMode'},
    hasDeletedAt: false,
  ),
};
