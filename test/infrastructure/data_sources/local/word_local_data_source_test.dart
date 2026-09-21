import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late WordLocalDataSource dataSource;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 他のテストファイルと同時実行された際にDBファイルのロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリを使う。
    final tempDir = await Directory.systemTemp.createTemp(
      'word_local_data_source_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(WordTable.tableName);
    dataSource = WordLocalDataSource(dbHelper);
  });

  Word makeWord(
    String id, {
    String front = 'front',
    String back = 'back',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Word(
        id: id,
        front: front,
        back: back,
        createdAt: createdAt ?? DateTime(2024, 1, 1, 10, 30),
        updatedAt: updatedAt ?? DateTime(2024, 1, 2, 11, 45),
      );

  group('insert', () {
    test('単語を挿入した場合、findByIdで同じ内容が取得できる', () async {
      final word = makeWord('word-1');

      await dataSource.insert(word, userId: userId, folderId: 'folder-1');

      final found = await dataSource.findById('word-1');
      expect(found, isNotNull);
      expect(found!.id, 'word-1');
      expect(found.front, 'front');
      expect(found.back, 'back');
    });

    test('createdAt/updatedAtがISO8601文字列で保存され、DateTimeとして往復変換される', () async {
      final createdAt = DateTime(2023, 5, 6, 7, 8, 9);
      final updatedAt = DateTime(2023, 6, 7, 8, 9, 10);
      final word =
          makeWord('word-1', createdAt: createdAt, updatedAt: updatedAt);

      await dataSource.insert(word, userId: userId, folderId: 'folder-1');

      final found = await dataSource.findById('word-1');
      expect(found!.createdAt, createdAt);
      expect(found.updatedAt, updatedAt);
    });

    test('syncStatusを省略した場合、synced として保存される', () async {
      final word = makeWord('word-1');

      await dataSource.insert(word, userId: userId, folderId: 'folder-1');

      final db = await dbHelper.database;
      final rows = await db.query(
        WordTable.tableName,
        where: 'id = ?',
        whereArgs: ['word-1'],
      );
      expect(rows.single['syncStatus'], 'synced');
    });

    test('syncStatusを指定した場合、指定した値で保存される', () async {
      final word = makeWord('word-1');

      await dataSource.insert(
        word,
        userId: userId,
        folderId: 'folder-1',
        syncStatus: 'pending',
      );

      final db = await dbHelper.database;
      final rows = await db.query(
        WordTable.tableName,
        where: 'id = ?',
        whereArgs: ['word-1'],
      );
      expect(rows.single['syncStatus'], 'pending');
    });

    test('同じIDで再度insertした場合、conflictAlgorithm.replaceにより上書きされる', () async {
      await dataSource.insert(
        makeWord('word-1', front: 'old-front'),
        userId: userId,
        folderId: 'folder-1',
      );

      await dataSource.insert(
        makeWord('word-1', front: 'new-front'),
        userId: userId,
        folderId: 'folder-1',
      );

      final db = await dbHelper.database;
      final rows = await db.query(
        WordTable.tableName,
        where: 'id = ?',
        whereArgs: ['word-1'],
      );
      expect(rows.length, 1);
      expect(rows.single['front'], 'new-front');
    });
  });

  group('update', () {
    test('既存レコードを更新した場合、findByIdで更新後の内容が取得できる', () async {
      await dataSource.insert(makeWord('word-1', front: 'old-front'),
          userId: userId, folderId: 'folder-1');

      await dataSource.update(
        makeWord('word-1', front: 'updated-front'),
        userId: userId,
        folderId: 'folder-1',
      );

      final found = await dataSource.findById('word-1');
      expect(found!.front, 'updated-front');
    });

    test('syncStatusを指定して更新した場合、指定した値で保存される', () async {
      await dataSource.insert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');

      await dataSource.update(
        makeWord('word-1'),
        userId: userId,
        folderId: 'folder-1',
        syncStatus: 'pending',
      );

      final db = await dbHelper.database;
      final rows = await db.query(
        WordTable.tableName,
        where: 'id = ?',
        whereArgs: ['word-1'],
      );
      expect(rows.single['syncStatus'], 'pending');
    });

    test('存在しないIDを指定して更新しても例外が発生せず正常終了する', () async {
      await expectLater(
        dataSource.update(
          makeWord('not-exist'),
          userId: userId,
          folderId: 'folder-1',
        ),
        completes,
      );
    });
  });

  group('delete', () {
    test('存在するレコードを削除した場合、そのレコードが取得できなくなる', () async {
      await dataSource.insert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');

      await dataSource.delete('word-1');

      final found = await dataSource.findById('word-1');
      expect(found, isNull);
    });

    test('複数レコードが存在する場合、指定したIDのレコードのみが削除される', () async {
      await dataSource.insert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');
      await dataSource.insert(makeWord('word-2'),
          userId: userId, folderId: 'folder-1');

      await dataSource.delete('word-1');

      final remaining = await dataSource.findByFolderId('folder-1', userId: userId);
      expect(remaining.map((w) => w.id), ['word-2']);
    });

    test('存在しないIDを指定して削除しても例外が発生せず正常終了する', () async {
      await expectLater(
        dataSource.delete('not-exist'),
        completes,
      );
    });
  });

  group('findById', () {
    test('存在するIDを指定した場合、該当する単語が取得できる', () async {
      await dataSource.insert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');

      final found = await dataSource.findById('word-1');

      expect(found, isNotNull);
      expect(found!.id, 'word-1');
    });

    test('存在しないIDを指定した場合、nullが返る', () async {
      final found = await dataSource.findById('not-exist');

      expect(found, isNull);
    });
  });

  group('findByFolderId', () {
    test('folderIdとuserIdの両方が一致するレコードのみ取得できる', () async {
      await dataSource.insert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');
      await dataSource.insert(makeWord('word-2'),
          userId: 'other-user', folderId: 'folder-1');
      await dataSource.insert(makeWord('word-3'),
          userId: userId, folderId: 'folder-2');

      final results =
          await dataSource.findByFolderId('folder-1', userId: userId);

      expect(results.map((w) => w.id), ['word-1']);
    });

    test('該当レコードが0件の場合、空リストが返る', () async {
      final results =
          await dataSource.findByFolderId('folder-1', userId: userId);

      expect(results, isEmpty);
    });

    test('複数件存在する場合、createdAt昇順で返る', () async {
      await dataSource.insert(
        makeWord('word-new', createdAt: DateTime(2024, 3, 1)),
        userId: userId,
        folderId: 'folder-1',
      );
      await dataSource.insert(
        makeWord('word-old', createdAt: DateTime(2024, 1, 1)),
        userId: userId,
        folderId: 'folder-1',
      );

      final results =
          await dataSource.findByFolderId('folder-1', userId: userId);

      expect(results.map((w) => w.id), ['word-old', 'word-new']);
    });
  });

  group('upsert', () {
    test('新規IDの場合、レコードが挿入される', () async {
      await dataSource.upsert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');

      final found = await dataSource.findById('word-1');
      expect(found, isNotNull);
    });

    test('既存IDの場合、レコードが上書きされる', () async {
      await dataSource.insert(makeWord('word-1', front: 'old-front'),
          userId: userId, folderId: 'folder-1');

      await dataSource.upsert(
        makeWord('word-1', front: 'new-front'),
        userId: userId,
        folderId: 'folder-1',
      );

      final found = await dataSource.findById('word-1');
      expect(found!.front, 'new-front');

      final db = await dbHelper.database;
      final rows = await db.query(
        WordTable.tableName,
        where: 'id = ?',
        whereArgs: ['word-1'],
      );
      expect(rows.length, 1);
    });

    test('syncStatusを指定しない場合、synced として保存される', () async {
      await dataSource.upsert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');

      final db = await dbHelper.database;
      final rows = await db.query(
        WordTable.tableName,
        where: 'id = ?',
        whereArgs: ['word-1'],
      );
      expect(rows.single['syncStatus'], 'synced');
    });
  });

  group('deleteByFolderId', () {
    test('指定したfolderIdのレコードが全て削除される', () async {
      await dataSource.insert(makeWord('word-1'),
          userId: userId, folderId: 'folder-1');
      await dataSource.insert(makeWord('word-2'),
          userId: userId, folderId: 'folder-1');
      await dataSource.insert(makeWord('word-3'),
          userId: userId, folderId: 'folder-2');

      await dataSource.deleteByFolderId('folder-1');

      final remainingInFolder1 =
          await dataSource.findByFolderId('folder-1', userId: userId);
      final remainingInFolder2 =
          await dataSource.findByFolderId('folder-2', userId: userId);
      expect(remainingInFolder1, isEmpty);
      expect(remainingInFolder2.map((w) => w.id), ['word-3']);
    });

    test('該当レコードが存在しない場合でも例外が発生せず正常終了する', () async {
      await expectLater(
        dataSource.deleteByFolderId('not-exist-folder'),
        completes,
      );
    });
  });
}
