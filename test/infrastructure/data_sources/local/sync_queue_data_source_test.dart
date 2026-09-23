import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SyncQueueDataSource dataSource;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 他のテストファイルと同時実行された際にDBファイルのロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリを使う。
    final tempDir = await Directory.systemTemp.createTemp(
      'sync_queue_data_source_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(SyncQueueTable.tableName);
    await db.delete(FolderTable.tableName);
    dataSource = SyncQueueDataSource(dbHelper);
  });

  Future<List<Map<String, dynamic>>> rawSyncQueueRows() async {
    final db = await dbHelper.database;
    return db.query(SyncQueueTable.tableName);
  }

  group('enqueue', () {
    test('payloadを指定した場合、JSON文字列としてpayload列に保存される', () async {
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-1',
        parentId: 'parent-1',
        payload: {'name': 'テストフォルダ'},
      );

      final rows = await rawSyncQueueRows();
      expect(rows, hasLength(1));
      expect(rows.first['operation'], 'insert');
      expect(rows.first['table_name'], 'folders');
      expect(rows.first['record_id'], 'folder-1');
      expect(rows.first['parent_id'], 'parent-1');
      expect(rows.first['payload'], '{"name":"テストフォルダ"}');
      expect(rows.first['created_at'], isNotNull);
    });

    test('parentId・payloadを指定しない場合、それぞれnullで保存される', () async {
      await dataSource.enqueue(
        operation: 'delete',
        tableName: 'words',
        recordId: 'word-1',
      );

      final rows = await rawSyncQueueRows();
      expect(rows, hasLength(1));
      expect(rows.first['parent_id'], isNull);
      expect(rows.first['payload'], isNull);
    });

    test('複数回enqueueした場合、件数分レコードが積み上がる', () async {
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-1',
      );
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-2',
      );

      expect(await dataSource.count(), 2);
    });

    test('同一エンティティ（同じrecordId）に対して複数回enqueueした場合、重複して両方登録される', () async {
      await dataSource.enqueue(
        operation: 'update',
        tableName: 'folders',
        recordId: 'folder-1',
      );
      await dataSource.enqueue(
        operation: 'update',
        tableName: 'folders',
        recordId: 'folder-1',
      );

      final rows = await rawSyncQueueRows();
      expect(rows.map((r) => r['record_id']), ['folder-1', 'folder-1']);
    });
  });

  group('enqueueInTransaction', () {
    test('データ書き込みと同一トランザクション内で成功した場合、両方コミットされる', () async {
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await txn.insert(FolderTable.tableName, {
          'id': 'folder-1',
          'name': 'フォルダ1',
          'parentFolderId': null,
          'userId': 'user-1',
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
          'syncStatus': 'pending',
        });
        await dataSource.enqueueInTransaction(
          txn,
          operation: 'insert',
          tableName: 'folders',
          recordId: 'folder-1',
          payload: {'name': 'フォルダ1'},
        );
      });

      final folders = await db.query(FolderTable.tableName);
      final queueRows = await rawSyncQueueRows();
      expect(folders, hasLength(1));
      expect(queueRows, hasLength(1));
      expect(queueRows.first['payload'], '{"name":"フォルダ1"}');
    });

    test('トランザクション途中で例外が発生してロールバックした場合、'
        'データ書き込みとキュー登録の両方が取り消される', () async {
      final db = await dbHelper.database;

      await expectLater(
        db.transaction((txn) async {
          await txn.insert(FolderTable.tableName, {
            'id': 'folder-err',
            'name': 'ロールバック対象',
            'parentFolderId': null,
            'userId': 'user-1',
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
            'syncStatus': 'pending',
          });
          await dataSource.enqueueInTransaction(
            txn,
            operation: 'insert',
            tableName: 'folders',
            recordId: 'folder-err',
          );
          throw Exception('意図的な失敗');
        }),
        throwsException,
      );

      final folders = await db.query(FolderTable.tableName);
      final queueRows = await rawSyncQueueRows();
      expect(folders, isEmpty);
      expect(queueRows, isEmpty);
    });
  });

  group('getAll', () {
    test('キューが空の場合、空リストが返る', () async {
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('複数件登録されている場合、created_atの古い順（登録順）に取得できる', () async {
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-1',
      );
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-2',
      );
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-3',
      );

      final result = await dataSource.getAll();
      expect(
        result.map((r) => r['record_id']),
        ['folder-1', 'folder-2', 'folder-3'],
      );
    });
  });

  group('delete', () {
    test('存在するidを削除した場合、キューから取り除かれる', () async {
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-1',
      );
      final rows = await dataSource.getAll();
      final id = rows.first['id'] as int;

      await dataSource.delete(id);

      expect(await dataSource.getAll(), isEmpty);
    });

    test('複数件ある場合、指定したidのレコードのみ削除される', () async {
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-1',
      );
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-2',
      );
      final rows = await dataSource.getAll();
      final firstId = rows.first['id'] as int;

      await dataSource.delete(firstId);

      final remaining = await dataSource.getAll();
      expect(remaining.map((r) => r['record_id']), ['folder-2']);
    });

    test('存在しないidを削除しても例外が発生せず正常終了する', () async {
      await expectLater(dataSource.delete(9999), completes);
    });
  });

  group('count', () {
    test('キューが空の場合、0が返る', () async {
      expect(await dataSource.count(), 0);
    });

    test('複数件登録されている場合、その件数が返る', () async {
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-1',
      );
      await dataSource.enqueue(
        operation: 'insert',
        tableName: 'folders',
        recordId: 'folder-2',
      );

      expect(await dataSource.count(), 2);
    });
  });
}
