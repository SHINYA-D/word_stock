import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';

void main() {
  const userId = 'user-1';
  const otherUserId = 'user-2';

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
    return db.query(SyncQueueTable.tableName, orderBy: 'id ASC');
  }

  group('enqueue', () {
    test('パラメータを指定してenqueueした場合、operation・tableName・recordId・userId・'
        'parentId・created_atがそのままキューに保存される', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
        parentId: 'parent-1',
      );

      final rows = await rawSyncQueueRows();
      expect(rows, hasLength(1));
      expect(rows.first['operation'], 'upsert');
      expect(rows.first['table_name'], 'folders');
      expect(rows.first['record_id'], 'folder-1');
      expect(rows.first['user_id'], userId);
      expect(rows.first['parent_id'], 'parent-1');
      expect(rows.first['created_at'], isNotNull);
    });

    test('parentIdを指定しない場合、nullで保存される', () async {
      await dataSource.enqueue(
        operation: 'delete',
        tableName: 'words',
        recordId: 'word-1',
        userId: userId,
      );

      final rows = await rawSyncQueueRows();
      expect(rows, hasLength(1));
      expect(rows.first['parent_id'], isNull);
    });

    test('複数回enqueueした場合、件数分レコードが積み上がる', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-2',
        userId: userId,
      );

      expect(await dataSource.count(), 2);
    });

    test('同一エンティティ（同じrecordId）に対して複数回enqueueした場合、重複して両方登録される', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
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
          'userId': userId,
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
          'syncStatus': 'pending',
        });
        await dataSource.enqueueInTransaction(
          txn,
          operation: 'upsert',
          tableName: 'folders',
          recordId: 'folder-1',
          userId: userId,
        );
      });

      final folders = await db.query(FolderTable.tableName);
      final queueRows = await rawSyncQueueRows();
      expect(folders, hasLength(1));
      expect(queueRows, hasLength(1));
      expect(queueRows.first['record_id'], 'folder-1');
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
            'userId': userId,
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
            'syncStatus': 'pending',
          });
          await dataSource.enqueueInTransaction(
            txn,
            operation: 'upsert',
            tableName: 'folders',
            recordId: 'folder-err',
            userId: userId,
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

  group('getByUser', () {
    test('複数件登録されている場合、積んだ順（id昇順）でそのユーザーの項目だけが取得できる', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-2',
        userId: otherUserId,
      );
      await dataSource.enqueue(
        operation: 'delete',
        tableName: 'words',
        recordId: 'word-1',
        userId: userId,
        parentId: 'folder-1',
      );

      final result = await dataSource.getByUser(userId);

      expect(result.map((r) => r.recordId), ['folder-1', 'word-1']);
      expect(result.map((r) => r.operation), ['upsert', 'delete']);
      expect(result.last.tableName, 'words');
      expect(result.last.parentId, 'folder-1');
    });

    test('該当ユーザーの項目が無い場合、空リストが返る', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: otherUserId,
      );

      final result = await dataSource.getByUser(userId);
      expect(result, isEmpty);
    });

    test('取得したcreatedAtがUTCのDateTimeとして返る', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );

      final result = await dataSource.getByUser(userId);
      expect(result.single.createdAt.isUtc, isTrue);
    });
  });

  group('getAll', () {
    test('キューが空の場合、空リストが返る', () async {
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('複数件登録されている場合、積んだ順（id昇順）で全ユーザー分取得できる', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-2',
        userId: otherUserId,
      );

      final result = await dataSource.getAll();
      expect(
        result.map((r) => r['record_id']),
        ['folder-1', 'folder-2'],
      );
    });
  });

  group('delete', () {
    test('存在するidを削除した場合、キューから取り除かれる', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      final rows = await dataSource.getAll();
      final id = rows.first['id'] as int;

      await dataSource.delete(id);

      expect(await dataSource.getAll(), isEmpty);
    });

    test('複数件ある場合、指定したidのレコードのみ削除される', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-2',
        userId: userId,
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

    test('トランザクションを渡して削除した場合、そのトランザクション内で削除される', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      final id = (await dataSource.getAll()).first['id'] as int;
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await dataSource.delete(id, txn);
      });

      expect(await dataSource.getAll(), isEmpty);
    });
  });

  group('deleteForRecord', () {
    test('同じテーブル・レコードを指す項目が複数ある場合、まとめて削除される', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-2',
        userId: userId,
      );
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await dataSource.deleteForRecord(txn, 'folders', 'folder-1');
      });

      final remaining = await dataSource.getAll();
      expect(remaining.map((r) => r['record_id']), ['folder-2']);
    });

    test('該当するレコードの項目が無い場合、他の項目は削除されない', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await dataSource.deleteForRecord(txn, 'folders', 'not-exist');
      });

      expect(await dataSource.count(), 1);
    });
  });

  group('hasItemsForRecord', () {
    test('指定したテーブル・レコードの項目が残っている場合、trueが返る', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      final db = await dbHelper.database;

      final result = await db.transaction((txn) async {
        return dataSource.hasItemsForRecord(txn, 'folders', 'folder-1');
      });

      expect(result, isTrue);
    });

    test('指定したテーブル・レコードの項目が無い場合、falseが返る', () async {
      final db = await dbHelper.database;

      final result = await db.transaction((txn) async {
        return dataSource.hasItemsForRecord(txn, 'folders', 'folder-1');
      });

      expect(result, isFalse);
    });
  });

  group('count / countByUser', () {
    test('キューが空の場合、countは0が返る', () async {
      expect(await dataSource.count(), 0);
    });

    test('複数件登録されている場合、countはその件数が返る', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-2',
        userId: otherUserId,
      );

      expect(await dataSource.count(), 2);
    });

    test('countByUserは他ユーザーの項目を含まず、指定したユーザーの件数だけが返る', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-2',
        userId: userId,
      );
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-3',
        userId: otherUserId,
      );

      expect(await dataSource.countByUser(userId), 2);
    });

    test('該当ユーザーの項目が無い場合、countByUserは0が返る', () async {
      await dataSource.enqueue(
        operation: 'upsert',
        tableName: 'folders',
        recordId: 'folder-1',
        userId: otherUserId,
      );

      expect(await dataSource.countByUser(userId), 0);
    });
  });
}
