import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';

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
}
