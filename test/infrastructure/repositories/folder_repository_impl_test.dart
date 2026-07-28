import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/repositories/folder_repository_impl.dart';

import '../../helpers/fake_infrastructure.dart';

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late FolderLocalDataSource folderLocal;
  late WordLocalDataSource wordLocal;
  late FlashcardResultLocalDataSource flashcardResultLocal;
  late SyncQueueDataSource syncQueue;
  late FakeFirestoreDataSource fakeRemote;
  late FakeConnectivityMonitor fakeConnectivity;
  late FolderRepositoryImpl repository;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // DatabaseHelper は 'wordstock.db' という固定のファイル名を使うため、
    // 他のテストファイルと同時実行された際に同一パスを取り合ってロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリに切り替える。
    final tempDir = await Directory.systemTemp.createTemp(
      'folder_repository_impl_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    // テスト間でDBの中身が混ざらないよう、毎回まっさらなDBファイルを使う。
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(FolderTable.tableName);
    await db.delete(WordTable.tableName);
    await db.delete(FlashcardResultTable.tableName);
    await db.delete(SyncQueueTable.tableName);

    folderLocal = FolderLocalDataSource(dbHelper);
    wordLocal = WordLocalDataSource(dbHelper);
    flashcardResultLocal = FlashcardResultLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    fakeRemote = FakeFirestoreDataSource();
    fakeConnectivity = FakeConnectivityMonitor(online: true);

    repository = FolderRepositoryImpl(
      localDataSource: folderLocal,
      wordLocalDataSource: wordLocal,
      flashcardResultLocalDataSource: flashcardResultLocal,
      remoteDataSource: fakeRemote,
      syncQueueDataSource: syncQueue,
      dbHelper: dbHelper,
      connectivityMonitor: fakeConnectivity,
    );
  });

  Folder makeFolder(String id, {String? parentFolderId}) => Folder(
        id: id,
        name: 'folder-$id',
        parentFolderId: parentFolderId,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  Word makeWord(String id) => Word(
        id: id,
        front: 'front-$id',
        back: 'back-$id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  FlashcardResult makeFlashcardResult(String id, String folderId) => FlashcardResult(
        id: id,
        folderId: folderId,
        totalCount: 10,
        correctCount: 8,
        date: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  Future<void> insertFolder(String id, {String? parentFolderId}) =>
      folderLocal.insert(
        makeFolder(id, parentFolderId: parentFolderId),
        userId: userId,
      );

  Future<void> insertWord(String id, String folderId) => wordLocal.insert(
        makeWord(id),
        userId: userId,
        folderId: folderId,
      );

  Future<void> insertFlashcardResult(String id, String folderId) =>
      flashcardResultLocal.insert(
        makeFlashcardResult(id, folderId),
        userId: userId,
      );

  group('deleteFolder - オンライン時', () {
    test(
        '子フォルダ・単語・成績データを持たない単一フォルダを削除した場合、'
        'ローカルとリモートの両方からフォルダが削除される', () async {
      await insertFolder('root');

      final result = await repository.deleteFolder(
        userId: userId,
        folderId: 'root',
      );

      expect(result.isRight(), isTrue);
      expect(await folderLocal.findById('root'), isNull);
      expect(fakeRemote.deletedFolders, [
        (userId: userId, folderId: 'root'),
      ]);
    });

    test('フォルダ配下の単語がある場合、単語もローカル・リモートの両方から削除される', () async {
      await insertFolder('root');
      await insertWord('word-1', 'root');
      await insertWord('word-2', 'root');

      await repository.deleteFolder(userId: userId, folderId: 'root');

      expect(await wordLocal.findByFolderId('root', userId: userId), isEmpty);
      expect(fakeRemote.deletedWords, [
        (userId: userId, folderId: 'root', wordId: 'word-1'),
        (userId: userId, folderId: 'root', wordId: 'word-2'),
      ]);
    });

    test('フォルダ配下の成績データがある場合、成績データもローカル・リモートの両方から削除される', () async {
      await insertFolder('root');
      await insertFlashcardResult('result-1', 'root');

      await repository.deleteFolder(userId: userId, folderId: 'root');

      expect(
        await flashcardResultLocal.findByUserId(userId, folderId: 'root'),
        isEmpty,
      );
      expect(fakeRemote.deletedFlashcardResults, [
        (userId: userId, flashcardResultId: 'result-1'),
      ]);
    });

    test('サブフォルダが存在する場合、サブフォルダも再帰的に削除される', () async {
      await insertFolder('root');
      await insertFolder('child', parentFolderId: 'root');

      await repository.deleteFolder(userId: userId, folderId: 'root');

      expect(await folderLocal.findById('root'), isNull);
      expect(await folderLocal.findById('child'), isNull);
      expect(
        fakeRemote.deletedFolders.map((e) => e.folderId).toSet(),
        {'root', 'child'},
      );
    });

    test('孫フォルダまで存在する深いネストの場合も、すべての階層が再帰的に削除される', () async {
      await insertFolder('root');
      await insertFolder('child', parentFolderId: 'root');
      await insertFolder('grandchild', parentFolderId: 'child');
      await insertWord('word-1', 'grandchild');
      await insertFlashcardResult('result-1', 'grandchild');

      await repository.deleteFolder(userId: userId, folderId: 'root');

      expect(await folderLocal.findById('root'), isNull);
      expect(await folderLocal.findById('child'), isNull);
      expect(await folderLocal.findById('grandchild'), isNull);
      expect(
        await wordLocal.findByFolderId('grandchild', userId: userId),
        isEmpty,
      );
      expect(
        await flashcardResultLocal.findByUserId(userId, folderId: 'grandchild'),
        isEmpty,
      );
      expect(
        fakeRemote.deletedFolders.map((e) => e.folderId).toSet(),
        {'root', 'child', 'grandchild'},
      );
      expect(fakeRemote.deletedWords, [
        (userId: userId, folderId: 'grandchild', wordId: 'word-1'),
      ]);
      expect(fakeRemote.deletedFlashcardResults, [
        (userId: userId, flashcardResultId: 'result-1'),
      ]);
    });

    test('兄弟フォルダが存在する場合、削除対象ではない兄弟フォルダは削除されない', () async {
      await insertFolder('root');
      await insertFolder('child-a', parentFolderId: 'root');
      await insertFolder('sibling');

      await repository.deleteFolder(userId: userId, folderId: 'root');

      expect(await folderLocal.findById('sibling'), isNotNull);
      expect(
        fakeRemote.deletedFolders.map((e) => e.folderId).toSet(),
        {'root', 'child-a'},
      );
    });

    test('リモート削除でFirebaseExceptionが発生した場合、Failure.networkが返る', () async {
      await insertFolder('root');
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
      );

      final result = await repository.deleteFolder(
        userId: userId,
        folderId: 'root',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('deleteFolder - オフライン時', () {
    setUp(() {
      fakeConnectivity.setOnline(false);
    });

    Future<List<Map<String, dynamic>>> queueRowsFor(
      String tableName,
      String recordId,
    ) async {
      final db = await dbHelper.database;
      return db.query(
        SyncQueueTable.tableName,
        where: 'table_name = ? AND record_id = ? AND operation = ?',
        whereArgs: [tableName, recordId, 'delete'],
      );
    }

    test(
        '子フォルダ・単語・成績データを持たない単一フォルダを削除した場合、'
        'ローカルから削除されsync_queueにdelete登録される', () async {
      await insertFolder('root');

      final result = await repository.deleteFolder(
        userId: userId,
        folderId: 'root',
      );

      expect(result.isRight(), isTrue);
      expect(await folderLocal.findById('root'), isNull);
      expect(await queueRowsFor(FolderTable.tableName, 'root'), hasLength(1));
      expect(fakeRemote.deletedFolders, isEmpty);
    });

    test('フォルダ配下の単語・成績データがある場合、'
        'それらもローカルから削除されsync_queueにdelete登録される', () async {
      await insertFolder('root');
      await insertWord('word-1', 'root');
      await insertFlashcardResult('result-1', 'root');

      await repository.deleteFolder(userId: userId, folderId: 'root');

      expect(await wordLocal.findByFolderId('root', userId: userId), isEmpty);
      expect(
        await flashcardResultLocal.findByUserId(userId, folderId: 'root'),
        isEmpty,
      );
      expect(await queueRowsFor(WordTable.tableName, 'word-1'), hasLength(1));
      expect(
        await queueRowsFor(FlashcardResultTable.tableName, 'result-1'),
        hasLength(1),
      );
    });

    test('孫フォルダまで存在する深いネストの場合も、'
        'すべての階層が再帰的に削除されsync_queueに登録される', () async {
      await insertFolder('root');
      await insertFolder('child', parentFolderId: 'root');
      await insertFolder('grandchild', parentFolderId: 'child');
      await insertWord('word-1', 'grandchild');

      await repository.deleteFolder(userId: userId, folderId: 'root');

      expect(await folderLocal.findById('root'), isNull);
      expect(await folderLocal.findById('child'), isNull);
      expect(await folderLocal.findById('grandchild'), isNull);
      expect(
        await wordLocal.findByFolderId('grandchild', userId: userId),
        isEmpty,
      );
      for (final id in ['root', 'child', 'grandchild']) {
        expect(await queueRowsFor(FolderTable.tableName, id), hasLength(1));
      }
      expect(await queueRowsFor(WordTable.tableName, 'word-1'), hasLength(1));
    });
  });
}
