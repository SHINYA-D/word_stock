import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/infrastructure/data_sources/sync_record.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_meta_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';

void main() {
  const userId = 'user-1';
  const otherUserId = 'other-user';

  late DatabaseHelper dbHelper;
  late SyncLocalDataSource dataSource;
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 他のテストファイルと同時実行された際にDBファイルのロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリを使う。
    final tempDir = await Directory.systemTemp.createTemp(
      'sync_local_data_source_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    db = await dbHelper.database;
    for (final t in [
      FolderTable.tableName,
      WordTable.tableName,
      FlashcardResultTable.tableName,
      SettingsTable.tableName,
      SyncMetaTable.tableName,
    ]) {
      await db.delete(t);
    }
    dataSource = SyncLocalDataSource(dbHelper);
  });

  Future<void> putFolder(
    String id, {
    String owner = userId,
    String? parentFolderId,
    bool pending = false,
  }) =>
      dataSource.put(
        db,
        SyncRecord(
          entity: SyncEntity.folder,
          id: id,
          fields: {
            'name': 'folder-$id',
            'parentFolderId': parentFolderId,
            'createdAt': DateTime.utc(2024, 1, 1),
          },
          updatedAt: DateTime.utc(2024, 1, 1),
        ),
        userId: owner,
        pending: pending,
      );

  Future<void> putWord(
    String id, {
    required String folderId,
    String owner = userId,
    bool pending = false,
  }) =>
      dataSource.put(
        db,
        SyncRecord(
          entity: SyncEntity.word,
          id: id,
          parentId: folderId,
          fields: {
            'front': 'front-$id',
            'back': 'back-$id',
            'createdAt': DateTime.utc(2024, 1, 1),
          },
          updatedAt: DateTime.utc(2024, 1, 1),
        ),
        userId: owner,
        pending: pending,
      );

  Future<void> putResult(
    String id, {
    required String folderId,
    String owner = userId,
    bool pending = false,
  }) =>
      dataSource.put(
        db,
        SyncRecord(
          entity: SyncEntity.flashcardResult,
          id: id,
          fields: {
            'folderId': folderId,
            'totalCount': 10,
            'correctCount': 7,
            'date': DateTime.utc(2024, 1, 1),
          },
          updatedAt: DateTime.utc(2024, 1, 1),
        ),
        userId: owner,
        pending: pending,
      );

  group('put / find', () {
    test('folderのレコードをputした場合、findでname/parentFolderId/createdAtが復元される',
        () async {
      final record = SyncRecord(
        entity: SyncEntity.folder,
        id: 'folder-1',
        fields: {
          'name': 'Folder A',
          'parentFolderId': 'parent-1',
          'createdAt': DateTime.utc(2024, 1, 1, 10),
        },
        updatedAt: DateTime.utc(2024, 1, 2, 11),
      );

      await dataSource.put(db, record, userId: userId, pending: true);
      final found =
          await dataSource.find(db, SyncEntity.folder, 'folder-1', userId: userId);

      expect(found, isNotNull);
      expect(found!.pending, isTrue);
      expect(found.record.id, 'folder-1');
      expect(found.record.parentId, isNull);
      expect(found.record.fields['name'], 'Folder A');
      expect(found.record.fields['parentFolderId'], 'parent-1');
      expect(found.record.fields['createdAt'], DateTime.utc(2024, 1, 1, 10));
      expect(found.record.updatedAt, DateTime.utc(2024, 1, 2, 11));
      expect(found.record.deletedAt, isNull);
    });

    test('wordのレコードをputした場合、parentIdがfolderId列に入りfindで復元される', () async {
      final record = SyncRecord(
        entity: SyncEntity.word,
        id: 'word-1',
        parentId: 'folder-1',
        fields: {
          'front': 'apple',
          'back': 'りんご',
          'createdAt': DateTime.utc(2024, 1, 1),
        },
        updatedAt: DateTime.utc(2024, 1, 2),
      );

      await dataSource.put(db, record, userId: userId, pending: false);

      final rows = await db.query(WordTable.tableName);
      expect(rows.single['folderId'], 'folder-1');

      final found =
          await dataSource.find(db, SyncEntity.word, 'word-1', userId: userId);
      expect(found!.pending, isFalse);
      expect(found.record.parentId, 'folder-1');
      expect(found.record.fields['front'], 'apple');
      expect(found.record.fields['back'], 'りんご');
    });

    test('flashcardResultのレコードをputした場合、findで復元されparentIdはnullになる', () async {
      final record = SyncRecord(
        entity: SyncEntity.flashcardResult,
        id: 'result-1',
        fields: {
          'folderId': 'folder-1',
          'totalCount': 10,
          'correctCount': 7,
          'date': DateTime.utc(2024, 1, 5),
        },
        updatedAt: DateTime.utc(2024, 1, 6),
      );

      await dataSource.put(db, record, userId: userId, pending: true);
      final found = await dataSource.find(
        db,
        SyncEntity.flashcardResult,
        'result-1',
        userId: userId,
      );

      expect(found!.record.parentId, isNull);
      expect(found.record.fields['folderId'], 'folder-1');
      expect(found.record.fields['totalCount'], 10);
      expect(found.record.fields['correctCount'], 7);
      expect(found.record.fields['date'], DateTime.utc(2024, 1, 5));
    });

    test(
        'settingsのレコードをputした場合、darkModeがboolとして復元されdeletedAtは常にnullになる',
        () async {
      final record = SyncRecord(
        entity: SyncEntity.settings,
        id: userId,
        fields: {'colorTheme': 'teal', 'darkMode': true},
        updatedAt: DateTime.utc(2024, 1, 2),
      );

      await dataSource.put(db, record, userId: userId, pending: true);

      final rows = await db.query(SettingsTable.tableName);
      expect(rows.single['darkMode'], 1);

      final found =
          await dataSource.find(db, SyncEntity.settings, userId, userId: userId);
      expect(found!.record.fields['darkMode'], isTrue);
      expect(found.record.fields['colorTheme'], 'teal');
      expect(found.record.deletedAt, isNull);
    });

    test('settingsのレコードをputした場合、userId列にはput呼び出し時のuserId引数が入る（record.idではない）',
        () async {
      final record = SyncRecord(
        entity: SyncEntity.settings,
        id: 'record-id-not-used',
        fields: {'colorTheme': 'pink', 'darkMode': false},
        updatedAt: DateTime.utc(2024, 1, 2),
      );

      await dataSource.put(db, record, userId: userId, pending: true);

      final rows = await db.query(SettingsTable.tableName);
      expect(rows.single['userId'], userId);
    });

    test('pending:falseでputした場合、findのpendingがfalseになる', () async {
      await putFolder('folder-1', pending: false);

      final found =
          await dataSource.find(db, SyncEntity.folder, 'folder-1', userId: userId);

      expect(found!.pending, isFalse);
    });

    test('存在しないidをfindした場合、nullが返る', () async {
      final found = await dataSource.find(
        db,
        SyncEntity.folder,
        'not-exist',
        userId: userId,
      );

      expect(found, isNull);
    });

    test('他ユーザーが所有するレコードをfindした場合、nullが返る', () async {
      await putFolder('folder-1', owner: userId);

      final found = await dataSource.find(
        db,
        SyncEntity.folder,
        'folder-1',
        userId: otherUserId,
      );

      expect(found, isNull);
    });
  });

  group('markSynced', () {
    test('pendingなレコードをmarkSyncedした場合、findのpendingがfalseになる', () async {
      await putFolder('folder-1', pending: true);

      await dataSource.markSynced(db, SyncEntity.folder, 'folder-1');

      final found =
          await dataSource.find(db, SyncEntity.folder, 'folder-1', userId: userId);
      expect(found!.pending, isFalse);
    });
  });

  group('markDeleted', () {
    test('存在するレコードをmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる',
        () async {
      await putWord('word-1', folderId: 'folder-1', pending: false);
      final at = DateTime.utc(2024, 4, 1, 9, 0);

      await dataSource.markDeleted(db, SyncEntity.word, 'word-1', at);

      final found =
          await dataSource.find(db, SyncEntity.word, 'word-1', userId: userId);
      expect(found!.record.deletedAt, at);
      expect(found.record.updatedAt, at);
      expect(found.pending, isTrue);
    });
  });

  group('isFolderDeleted', () {
    test('deletedAtが設定されたフォルダの場合、trueが返る', () async {
      await putFolder('folder-1');
      await dataSource.markDeleted(
        db,
        SyncEntity.folder,
        'folder-1',
        DateTime.utc(2024, 1, 1),
      );

      final result =
          await dataSource.isFolderDeleted(db, 'folder-1', userId: userId);

      expect(result, isTrue);
    });

    test('未削除のフォルダの場合、falseが返る', () async {
      await putFolder('folder-1');

      final result =
          await dataSource.isFolderDeleted(db, 'folder-1', userId: userId);

      expect(result, isFalse);
    });

    test('存在しないフォルダIDの場合、falseが返る', () async {
      final result =
          await dataSource.isFolderDeleted(db, 'not-exist', userId: userId);

      expect(result, isFalse);
    });

    test('他ユーザーが所有する削除済みフォルダの場合、falseが返る', () async {
      await putFolder('folder-1', owner: otherUserId);
      await dataSource.markDeleted(
        db,
        SyncEntity.folder,
        'folder-1',
        DateTime.utc(2024, 1, 1),
      );

      final result =
          await dataSource.isFolderDeleted(db, 'folder-1', userId: userId);

      expect(result, isFalse);
    });
  });

  group('activeDescendants', () {
    test(
        '未削除の単語・成績・サブフォルダのみが再帰的に集められ、削除済み・他ユーザーのデータは含まれない',
        () async {
      // root 配下
      await putWord('w-root', folderId: 'root');
      await putWord('w-root-deleted', folderId: 'root');
      await dataSource.markDeleted(
          db, SyncEntity.word, 'w-root-deleted', DateTime.utc(2024, 1, 1));
      await putWord('w-other-user', folderId: 'root', owner: otherUserId);
      await putResult('r-root', folderId: 'root');
      await putResult('r-root-deleted', folderId: 'root');
      await dataSource.markDeleted(db, SyncEntity.flashcardResult,
          'r-root-deleted', DateTime.utc(2024, 1, 1));

      // 未削除のサブフォルダ c1 とその配下
      await putFolder('c1', parentFolderId: 'root');
      await putWord('w-c1', folderId: 'c1');

      // 削除済みのサブフォルダ c2 とその配下（配下ごと除外される）
      await putFolder('c2', parentFolderId: 'root');
      await dataSource.markDeleted(
          db, SyncEntity.folder, 'c2', DateTime.utc(2024, 1, 1));
      await putWord('w-c2', folderId: 'c2');

      final result =
          await dataSource.activeDescendants(db, 'root', userId: userId);

      expect(
        result,
        containsAll(<({SyncEntity entity, String id, String? parentId})>[
          (entity: SyncEntity.word, id: 'w-root', parentId: 'root'),
          (entity: SyncEntity.flashcardResult, id: 'r-root', parentId: null),
          (entity: SyncEntity.folder, id: 'c1', parentId: null),
          (entity: SyncEntity.word, id: 'w-c1', parentId: 'c1'),
        ]),
      );
      expect(result.length, 4);
    });

    test('配下にデータが無いフォルダの場合、空リストが返る', () async {
      final result =
          await dataSource.activeDescendants(db, 'empty-folder', userId: userId);

      expect(result, isEmpty);
    });
  });

  group('readMeta / writeMeta', () {
    test('未登録のkeyをreadMetaした場合、nullが返る', () async {
      expect(await dataSource.readMeta('foo'), isNull);
    });

    test('writeMetaで書き込んだ値がreadMetaで取得できる', () async {
      await dataSource.writeMeta('foo', 'bar');

      expect(await dataSource.readMeta('foo'), 'bar');
    });

    test('同じkeyでwriteMetaした場合、値が置き換わる（重複せず1件のまま）', () async {
      await dataSource.writeMeta('foo', 'bar');

      await dataSource.writeMeta('foo', 'baz');

      final rows = await db.query(SyncMetaTable.tableName);
      expect(rows.length, 1);
      expect(await dataSource.readMeta('foo'), 'baz');
    });
  });

  group('readMetaDate / writeMetaDate', () {
    test('writeMetaDateで書き込んだ日時が、readMetaDateでUTCのDateTimeとして取得できる', () async {
      final date = DateTime.utc(2024, 5, 6, 7, 8);

      await dataSource.writeMetaDate('cursor', date);
      final result = await dataSource.readMetaDate('cursor');

      expect(result, date);
    });

    test('未登録のkeyをreadMetaDateした場合、nullが返る', () async {
      expect(await dataSource.readMetaDate('not-exist'), isNull);
    });
  });

  group('tableOf / entityOf', () {
    test('全てのSyncEntityで、tableOfで得たテーブル名からentityOfが元のentityを返す', () {
      for (final entity in SyncEntity.values) {
        final table = SyncLocalDataSource.tableOf(entity);
        expect(SyncLocalDataSource.entityOf(table), entity);
      }
    });
  });
}
