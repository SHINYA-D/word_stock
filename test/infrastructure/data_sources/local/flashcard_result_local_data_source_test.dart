import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/local_date.dart';

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late FlashcardResultLocalDataSource dataSource;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 他のテストファイルと同時実行された際にDBファイルのロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリを使う。
    final tempDir = await Directory.systemTemp.createTemp(
      'flashcard_result_local_data_source_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(FlashcardResultTable.tableName);
    dataSource = FlashcardResultLocalDataSource(dbHelper);
  });

  FlashcardResult makeResult(String id, String folderId) => FlashcardResult(
        id: id,
        folderId: folderId,
        totalCount: 10,
        correctCount: 7,
        date: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  group('delete', () {
    test('存在するレコードを削除した場合、そのレコードが取得できなくなる', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);

      await dataSource.delete('result-1');

      final results = await dataSource.findByUserId(userId);
      expect(results, isEmpty);
    });

    test('複数レコードが存在する場合、指定したIDのレコードのみが削除される', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      await dataSource.insert(makeResult('result-2', 'folder-1'),
          userId: userId);

      await dataSource.delete('result-1');

      final results = await dataSource.findByUserId(userId);
      expect(results.map((r) => r.id), ['result-2']);
    });

    test('存在しないIDを指定して削除しても例外が発生せず正常終了する', () async {
      await expectLater(
        dataSource.delete('not-exist'),
        completes,
      );
    });
  });

  group('insert / findByUserId (deleteの前提となる既存ロジックの確認)', () {
    test('userIdでフィルタして一覧取得できる', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      await dataSource.insert(makeResult('result-2', 'folder-1'),
          userId: 'other-user');

      final results = await dataSource.findByUserId(userId);
      expect(results.map((r) => r.id), ['result-1']);
    });

    test('folderIdを指定した場合、そのフォルダのレコードのみ取得できる', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      await dataSource.insert(makeResult('result-2', 'folder-2'),
          userId: userId);

      final results =
          await dataSource.findByUserId(userId, folderId: 'folder-1');
      expect(results.map((r) => r.id), ['result-1']);
    });
  });

  group('upsert', () {
    test('存在しないIDでupsertした場合、新規レコードとして挿入される', () async {
      await dataSource.upsert(makeResult('result-1', 'folder-1'),
          userId: userId);

      final results = await dataSource.findByUserId(userId);
      expect(results.map((r) => r.id), ['result-1']);
    });

    test('既存IDでupsertした場合、レコードが置き換えられる（重複せず1件のまま）', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);

      final updated = FlashcardResult(
        id: 'result-1',
        folderId: 'folder-1',
        totalCount: 20,
        correctCount: 15,
        date: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 2, 2),
      );
      await dataSource.upsert(updated, userId: userId);

      final results = await dataSource.findByUserId(userId);
      expect(results.length, 1);
      expect(results.first.totalCount, 20);
      expect(results.first.correctCount, 15);
      expect(results.first.updatedAt, DateTime(2024, 2, 2));
    });
  });

  group('日時の保存形式', () {
    test('insertした場合、DBに保存されるdate/updatedAtがUTCのISO8601文字列(末尾Z)になる',
        () async {
      await dataSource.insert(
        FlashcardResult(
          id: 'result-1',
          folderId: 'folder-1',
          totalCount: 10,
          correctCount: 7,
          date: DateTime(2024, 3, 5, 10, 30),
          updatedAt: DateTime(2024, 3, 6, 11, 45),
        ),
        userId: userId,
      );

      final db = await dbHelper.database;
      final rows = await db.query(
        FlashcardResultTable.tableName,
        where: 'id = ?',
        whereArgs: ['result-1'],
      );

      expect(rows.single['date'], endsWith('Z'));
      expect(rows.single['updatedAt'], endsWith('Z'));
    });

    test('Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      final db = await dbHelper.database;
      final legacyLocal = DateTime(2024, 3, 5, 10, 30);
      // 末尾Zを持たない旧バージョン1形式の文字列を直接書き込む。
      await db.update(
        FlashcardResultTable.tableName,
        {'date': legacyLocal.toIso8601String()},
        where: 'id = ?',
        whereArgs: ['result-1'],
      );

      final results = await dataSource.findByUserId(userId);

      expect(results.single.date, legacyLocal);
    });
  });

  group('findByUserId（削除済みの除外）', () {
    test('deletedAtが設定された成績が存在する場合、findByUserIdの結果に含まれない', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      await dataSource.insert(makeResult('result-2', 'folder-1'),
          userId: userId);
      final db = await dbHelper.database;
      await dataSource.markDeleted(db, 'result-1', DateTime(2024, 4, 1));

      final results = await dataSource.findByUserId(userId);

      expect(results.map((r) => r.id), ['result-2']);
    });

    test('folderIdを指定した場合でも、削除済みの成績は結果に含まれない', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      final db = await dbHelper.database;
      await dataSource.markDeleted(db, 'result-1', DateTime(2024, 4, 1));

      final results =
          await dataSource.findByUserId(userId, folderId: 'folder-1');

      expect(results, isEmpty);
    });
  });

  group('findActiveIdsByFolder', () {
    test('未削除の成績のみが存在する場合、それらのidが取得できる', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      await dataSource.insert(makeResult('result-2', 'folder-1'),
          userId: userId);
      final db = await dbHelper.database;
      await dataSource.markDeleted(db, 'result-2', DateTime(2024, 4, 1));

      final ids = await dataSource.findActiveIdsByFolder(
        db,
        'folder-1',
        userId: userId,
      );

      expect(ids, ['result-1']);
    });

    test('他ユーザーの成績が存在する場合、そのidは含まれない', () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: 'other-user');
      final db = await dbHelper.database;

      final ids = await dataSource.findActiveIdsByFolder(
        db,
        'folder-1',
        userId: userId,
      );

      expect(ids, isEmpty);
    });
  });

  group('save', () {
    test('未登録の成績をsaveした場合、新規レコードとして挿入される', () async {
      final db = await dbHelper.database;

      await dataSource.save(db, makeResult('result-1', 'folder-1'),
          userId: userId);

      final results = await dataSource.findByUserId(userId);
      expect(results.map((r) => r.id), ['result-1']);
    });

    test('既存IDの成績をsaveした場合、レコードが置き換えられる（重複せず1件のまま）', () async {
      final db = await dbHelper.database;
      await dataSource.save(db, makeResult('result-1', 'folder-1'),
          userId: userId);

      final updated = FlashcardResult(
        id: 'result-1',
        folderId: 'folder-1',
        totalCount: 30,
        correctCount: 25,
        date: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 3, 3),
      );
      await dataSource.save(db, updated, userId: userId);

      final results = await dataSource.findByUserId(userId);
      expect(results.length, 1);
      expect(results.first.totalCount, 30);
      expect(results.first.correctCount, 25);
    });
  });

  group('markDeleted', () {
    test('存在する成績をmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる',
        () async {
      await dataSource.insert(makeResult('result-1', 'folder-1'),
          userId: userId);
      final db = await dbHelper.database;
      final deletedAt = DateTime(2024, 4, 1, 9, 0);

      await dataSource.markDeleted(db, 'result-1', deletedAt);

      final rows = await db.query(
        FlashcardResultTable.tableName,
        where: 'id = ?',
        whereArgs: ['result-1'],
      );
      final row = rows.single;
      expect(row['syncStatus'], 'pending');
      expect(row['deletedAt'], toDateColumn(deletedAt));
      expect(row['updatedAt'], toDateColumn(deletedAt));
    });
  });
}
