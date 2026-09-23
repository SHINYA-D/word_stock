import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/repositories/flashcard_result_repository_impl.dart';

import '../../helpers/fake_infrastructure.dart';

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late FlashcardResultLocalDataSource flashcardResultLocal;
  late SyncQueueDataSource syncQueue;
  late FakeFirestoreDataSource fakeRemote;
  late FakeConnectivityMonitor fakeConnectivity;
  late FlashcardResultRepositoryImpl repository;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // DatabaseHelper は 'wordstock.db' という固定のファイル名を使うため、
    // 他のテストファイルと同時実行された際に同一パスを取り合ってロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリに切り替える。
    final tempDir = await Directory.systemTemp.createTemp(
      'flashcard_result_repository_impl_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(FlashcardResultTable.tableName);
    await db.delete(SyncQueueTable.tableName);

    flashcardResultLocal = FlashcardResultLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    fakeRemote = FakeFirestoreDataSource();
    fakeConnectivity = FakeConnectivityMonitor(online: true);

    repository = FlashcardResultRepositoryImpl(
      localDataSource: flashcardResultLocal,
      remoteDataSource: fakeRemote,
      syncQueueDataSource: syncQueue,
      dbHelper: dbHelper,
      connectivityMonitor: fakeConnectivity,
    );
  });

  FlashcardResult makeFlashcardResult(String id, String folderId) =>
      FlashcardResult(
        id: id,
        folderId: folderId,
        totalCount: 10,
        correctCount: 7,
        date: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  Future<void> insertRow(String id, String folderId) =>
      flashcardResultLocal.insert(
        makeFlashcardResult(id, folderId),
        userId: userId,
      );

  group('getFlashcardResults', () {
    test('データが存在する場合、Rightで成績一覧が返る', () async {
      await insertRow('result-1', 'folder-1');
      await insertRow('result-2', 'folder-1');

      final result = await repository.getFlashcardResults(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (list) => expect(list.map((e) => e.id).toSet(), {'result-1', 'result-2'}),
      );
    });

    test('folderIdを指定した場合、そのフォルダの成績のみ返る', () async {
      await insertRow('result-1', 'folder-1');
      await insertRow('result-2', 'folder-2');

      final result = await repository.getFlashcardResults(
        userId: userId,
        folderId: 'folder-1',
      );

      result.match(
        (_) => fail('Right が返るはず'),
        (list) => expect(list.map((e) => e.id), ['result-1']),
      );
    });

    test('該当データが無い場合、Rightで空リストが返る', () async {
      final result = await repository.getFlashcardResults(
        userId: userId,
        folderId: 'no-such-folder',
      );

      result.match(
        (_) => fail('Right が返るはず'),
        (list) => expect(list, isEmpty),
      );
    });

    test('ローカル取得中に例外が発生した場合、Failure.unknownが返る', () async {
      // テーブルを破壊して findByUserId 内のクエリを失敗させる。
      final db = await dbHelper.database;
      await db.execute('DROP TABLE ${FlashcardResultTable.tableName}');

      final result = await repository.getFlashcardResults(userId: userId);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );

      // 後続テストに影響しないようテーブルを復元する。
      await FlashcardResultTable.onCreate(db);
    });
  });

  group('saveFlashcardResult - オンライン時', () {
    test('保存が成功した場合、ローカルにsynced状態で保存されFirestoreにも書き込まれRightが返る', () async {
      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isRight(), isTrue);
      final saved = result.match((_) => null, (r) => r)!;
      expect(saved.folderId, 'folder-1');
      expect(saved.totalCount, 10);
      expect(saved.correctCount, 7);

      final localRows = await flashcardResultLocal.findByUserId(userId);
      expect(localRows.map((e) => e.id), [saved.id]);

      final db = await dbHelper.database;
      final rawRows = await db.query(
        FlashcardResultTable.tableName,
        where: 'id = ?',
        whereArgs: [saved.id],
      );
      expect(rawRows.single['syncStatus'], 'synced');

      expect(fakeRemote.writtenFlashcardResults.map((e) => e.result.id), [saved.id]);
      expect(fakeRemote.writtenFlashcardResults.single.userId, userId);

      // オンライン時はキューに登録されない。
      expect(await syncQueue.count(), 0);
    });

    test('FirebaseExceptionのcodeがunavailableの場合、Failure.networkが返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
      );

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseExceptionのcodeがnetwork-request-failedの場合、Failure.networkが返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'network-request-failed',
      );

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseExceptionのcodeがその他でmessageがある場合、Failure.unknown(message)が返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'permission denied message',
      );

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      result.match(
        (failure) => expect(
          failure,
          const Failure.unknown('permission denied message'),
        ),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseExceptionのmessageがnullの場合、Failure.unknown(code)が返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
      );

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      result.match(
        (failure) => expect(
          failure,
          const Failure.unknown('permission-denied'),
        ),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseException以外の例外が発生した場合、Failure.unknownが返る', () async {
      fakeRemote.exceptionToThrow = Exception('boom');

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('saveFlashcardResult - オフライン時', () {
    setUp(() {
      fakeConnectivity.setOnline(false);
    });

    test(
        '保存した場合、ローカルにpending状態で保存されsync_queueにcreate登録されRightが返り、'
        'Firestoreへは書き込まれない', () async {
      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isRight(), isTrue);
      final saved = result.match((_) => null, (r) => r)!;

      final db = await dbHelper.database;
      final rawRows = await db.query(
        FlashcardResultTable.tableName,
        where: 'id = ?',
        whereArgs: [saved.id],
      );
      expect(rawRows.single['syncStatus'], 'pending');

      final queueRows = await db.query(
        SyncQueueTable.tableName,
        where: 'table_name = ? AND record_id = ? AND operation = ?',
        whereArgs: [FlashcardResultTable.tableName, saved.id, 'create'],
      );
      expect(queueRows, hasLength(1));

      expect(fakeRemote.writtenFlashcardResults, isEmpty);
    });

    test('sync_queueのpayloadに保存内容が正しく記録される', () async {
      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );
      final saved = result.match((_) => null, (r) => r)!;

      final db = await dbHelper.database;
      final queueRows = await db.query(
        SyncQueueTable.tableName,
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [FlashcardResultTable.tableName, saved.id],
      );
      final payload =
          jsonDecode(queueRows.single['payload'] as String) as Map<String, dynamic>;

      expect(payload['folderId'], 'folder-1');
      expect(payload['totalCount'], 10);
      expect(payload['correctCount'], 7);
      expect(payload['date'], saved.date.toIso8601String());
      expect(payload['updatedAt'], saved.updatedAt.toIso8601String());
    });

    test('トランザクション内で例外が発生した場合、Failure.unknownが返りロールバックされ何も保存されない', () async {
      // sync_queue テーブルを破壊し、トランザクション後半の enqueueInTransaction を失敗させる。
      final db = await dbHelper.database;
      await db.execute('DROP TABLE ${SyncQueueTable.tableName}');

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'folder-1',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );

      // トランザクションがロールバックされ、flashcard_results への insert も残らない。
      final rows = await flashcardResultLocal.findByUserId(userId);
      expect(rows, isEmpty);

      // 後続テストに影響しないようテーブルを復元する。
      await SyncQueueTable.onCreate(db);
    });
  });
}
