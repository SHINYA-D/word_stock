import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late FolderLocalDataSource dataSource;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 他のテストファイルと同時実行された際にDBファイルのロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリを使う。
    final tempDir = await Directory.systemTemp.createTemp(
      'folder_local_data_source_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(FolderTable.tableName);
    dataSource = FolderLocalDataSource(dbHelper);
  });

  Folder makeFolder(
    String id, {
    String? parentFolderId,
    String name = 'フォルダ',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Folder(
        id: id,
        name: name,
        parentFolderId: parentFolderId,
        createdAt: createdAt ?? DateTime(2024, 1, 1),
        updatedAt: updatedAt ?? DateTime(2024, 1, 1),
      );

  group('insert / findById', () {
    test('フォルダをinsertした場合、findByIdでDateTimeがISO8601往復して取得できる', () async {
      final folder = makeFolder(
        'folder-1',
        createdAt: DateTime(2024, 3, 5, 10, 30),
        updatedAt: DateTime(2024, 3, 6, 11, 45),
      );
      await dataSource.insert(folder, userId: userId);

      final found = await dataSource.findById('folder-1');

      expect(found, isNotNull);
      expect(found!.id, 'folder-1');
      expect(found.createdAt, DateTime(2024, 3, 5, 10, 30));
      expect(found.updatedAt, DateTime(2024, 3, 6, 11, 45));
    });

    test('存在しないIDを指定した場合、findByIdはnullを返す', () async {
      final found = await dataSource.findById('not-exist');
      expect(found, isNull);
    });
  });

  group('update', () {
    test('既存フォルダを更新した場合、name等の変更内容が反映される', () async {
      await dataSource.insert(makeFolder('folder-1', name: '旧名'),
          userId: userId);

      final updated = makeFolder(
        'folder-1',
        name: '新名',
        updatedAt: DateTime(2024, 5, 1),
      );
      await dataSource.update(updated, userId: userId);

      final found = await dataSource.findById('folder-1');
      expect(found!.name, '新名');
      expect(found.updatedAt, DateTime(2024, 5, 1));
    });

    test('存在しないIDを指定して更新しても例外が発生せず正常終了する', () async {
      await expectLater(
        dataSource.update(makeFolder('not-exist'), userId: userId),
        completes,
      );
    });
  });

  group('delete', () {
    test('存在するフォルダを削除した場合、findByIdでnullになる', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);

      await dataSource.delete('folder-1');

      final found = await dataSource.findById('folder-1');
      expect(found, isNull);
    });
  });

  group('findByUserId', () {
    test('parentFolderIdを指定しない場合、ルート直下(NULL)のフォルダのみ取得できる', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      await dataSource.insert(
        makeFolder('folder-2', parentFolderId: 'folder-1'),
        userId: userId,
      );

      final results = await dataSource.findByUserId(userId);

      expect(results.map((f) => f.id), ['folder-1']);
    });

    test('parentFolderIdを指定した場合、その子フォルダのみ取得できる', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      await dataSource.insert(
        makeFolder('folder-2', parentFolderId: 'folder-1'),
        userId: userId,
      );
      await dataSource.insert(
        makeFolder('folder-3', parentFolderId: 'folder-1'),
        userId: 'other-user',
      );

      final results =
          await dataSource.findByUserId(userId, parentFolderId: 'folder-1');

      expect(results.map((f) => f.id), ['folder-2']);
    });
  });

  group('upsert', () {
    test('存在しないIDでupsertした場合、新規レコードとして挿入される', () async {
      await dataSource.upsert(makeFolder('folder-1'), userId: userId);

      final found = await dataSource.findById('folder-1');
      expect(found, isNotNull);
      expect(found!.id, 'folder-1');
    });

    test('既存IDでupsertした場合、レコードが置き換えられる（重複せず1件のまま）', () async {
      await dataSource.insert(makeFolder('folder-1', name: '旧名'),
          userId: userId);

      await dataSource.upsert(
        makeFolder('folder-1', name: '新名', updatedAt: DateTime(2024, 6, 1)),
        userId: userId,
      );

      final results = await dataSource.findByUserId(userId);
      expect(results.length, 1);
      expect(results.first.name, '新名');
      expect(results.first.updatedAt, DateTime(2024, 6, 1));
    });
  });

  group('日時の保存形式', () {
    test('insertした場合、DBに保存されるcreatedAt/updatedAtがUTCのISO8601文字列(末尾Z)になる',
        () async {
      await dataSource.insert(
        makeFolder(
          'folder-1',
          createdAt: DateTime(2024, 3, 5, 10, 30),
          updatedAt: DateTime(2024, 3, 6, 11, 45),
        ),
        userId: userId,
      );

      final db = await dbHelper.database;
      final rows = await db.query(
        FolderTable.tableName,
        where: 'id = ?',
        whereArgs: ['folder-1'],
      );

      expect(rows.single['createdAt'], endsWith('Z'));
      expect(rows.single['updatedAt'], endsWith('Z'));
    });

    test('Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      final db = await dbHelper.database;
      final legacyLocal = DateTime(2024, 3, 5, 10, 30);
      // 末尾Zを持たない旧バージョン1形式の文字列を直接書き込む。
      await db.update(
        FolderTable.tableName,
        {'createdAt': legacyLocal.toIso8601String()},
        where: 'id = ?',
        whereArgs: ['folder-1'],
      );

      final found = await dataSource.findById('folder-1');

      expect(found!.createdAt, legacyLocal);
    });
  });

  group('findById（削除済みを含む）', () {
    test('deletedAtが設定されたフォルダを指定した場合、findByIdは削除済みでも取得できる', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      final db = await dbHelper.database;
      await dataSource.markDeleted(db, 'folder-1', DateTime(2024, 4, 1));

      final found = await dataSource.findById('folder-1');

      expect(found, isNotNull);
      expect(found!.id, 'folder-1');
    });
  });

  group('findByUserId（削除済みの除外）', () {
    test('deletedAtが設定されたフォルダが存在する場合、findByUserIdの結果に含まれない', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      await dataSource.insert(makeFolder('folder-2'), userId: userId);
      final db = await dbHelper.database;
      await dataSource.markDeleted(db, 'folder-1', DateTime(2024, 4, 1));

      final results = await dataSource.findByUserId(userId);

      expect(results.map((f) => f.id), ['folder-2']);
    });
  });

  group('findActive', () {
    test('自ユーザーの未削除のフォルダを指定した場合、そのフォルダが取得できる', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      final db = await dbHelper.database;

      final found =
          await dataSource.findActive(db, 'folder-1', userId: userId);

      expect(found, isNotNull);
      expect(found!.id, 'folder-1');
    });

    test('削除済みのフォルダを指定した場合、findActiveはnullを返す', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      final db = await dbHelper.database;
      await dataSource.markDeleted(db, 'folder-1', DateTime(2024, 4, 1));

      final found =
          await dataSource.findActive(db, 'folder-1', userId: userId);

      expect(found, isNull);
    });

    test('他ユーザーのフォルダを指定した場合、findActiveはnullを返す', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: 'other-user');
      final db = await dbHelper.database;

      final found =
          await dataSource.findActive(db, 'folder-1', userId: userId);

      expect(found, isNull);
    });
  });

  group('findActiveChildIds', () {
    test('未削除の子フォルダのみが存在する場合、それらのidが取得できる', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      await dataSource.insert(
        makeFolder('folder-2', parentFolderId: 'folder-1'),
        userId: userId,
      );
      await dataSource.insert(
        makeFolder('folder-3', parentFolderId: 'folder-1'),
        userId: userId,
      );
      final db = await dbHelper.database;
      await dataSource.markDeleted(db, 'folder-3', DateTime(2024, 4, 1));

      final ids =
          await dataSource.findActiveChildIds(db, 'folder-1', userId: userId);

      expect(ids, ['folder-2']);
    });

    test('他ユーザーの子フォルダが存在する場合、そのidは含まれない', () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      await dataSource.insert(
        makeFolder('folder-2', parentFolderId: 'folder-1'),
        userId: 'other-user',
      );
      final db = await dbHelper.database;

      final ids =
          await dataSource.findActiveChildIds(db, 'folder-1', userId: userId);

      expect(ids, isEmpty);
    });
  });

  group('save', () {
    test('未登録のフォルダをsaveした場合、新規レコードとして挿入される', () async {
      final db = await dbHelper.database;

      await dataSource.save(db, makeFolder('folder-1'), userId: userId);

      final found = await dataSource.findById('folder-1');
      expect(found, isNotNull);
      expect(found!.id, 'folder-1');
    });

    test('既存IDのフォルダをsaveした場合、レコードが置き換えられる（重複せず1件のまま）', () async {
      final db = await dbHelper.database;
      await dataSource.save(db, makeFolder('folder-1', name: '旧名'),
          userId: userId);

      await dataSource.save(
        db,
        makeFolder('folder-1', name: '新名'),
        userId: userId,
      );

      final results = await dataSource.findByUserId(userId);
      expect(results.length, 1);
      expect(results.first.name, '新名');
    });
  });

  group('markDeleted', () {
    test('存在するフォルダをmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる',
        () async {
      await dataSource.insert(makeFolder('folder-1'), userId: userId);
      final db = await dbHelper.database;
      final deletedAt = DateTime(2024, 4, 1, 9, 0);

      await dataSource.markDeleted(db, 'folder-1', deletedAt);

      final rows = await db.query(
        FolderTable.tableName,
        where: 'id = ?',
        whereArgs: ['folder-1'],
      );
      final row = rows.single;
      expect(row['syncStatus'], 'pending');
      final found = await dataSource.findById('folder-1');
      expect(found!.updatedAt, deletedAt);
    });
  });
}
