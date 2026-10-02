import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/repositories/flashcard_result_repository_impl.dart';

import '../../helpers/fake_infrastructure.dart';

/// ローカルへの成績の保存で例外を投げる（FRS-C03）。
class ThrowingSaveFlashcardResultLocalDataSource extends FlashcardResultLocalDataSource {
  ThrowingSaveFlashcardResultLocalDataSource(super.dbHelper);

  @override
  Future<void> save(
    DatabaseExecutor db,
    FlashcardResult result, {
    required String userId,
    String syncStatus = 'synced',
  }) {
    throw Exception('save failed');
  }
}

/// ローカルの読み取りで例外を投げる（FRS-R04）。
class ThrowingFindByUserIdFlashcardResultLocalDataSource extends FlashcardResultLocalDataSource {
  ThrowingFindByUserIdFlashcardResultLocalDataSource(super.dbHelper);

  @override
  Future<List<FlashcardResult>> findByUserId(
    String userId, {
    String? folderId,
  }) {
    throw Exception('read failed');
  }
}

/// キューへの登録で例外を投げる（FRS-C04）。
class ThrowingEnqueueSyncQueueDataSource extends SyncQueueDataSource {
  ThrowingEnqueueSyncQueueDataSource(super.dbHelper);

  @override
  Future<void> enqueueInTransaction(
    DatabaseExecutor txn, {
    required String operation,
    required String tableName,
    required String recordId,
    required String userId,
    String? parentId,
  }) {
    throw Exception('enqueue failed');
  }
}

void main() {
  const userId = 'user-1';
  const otherUserId = 'user-2';

  late DatabaseHelper dbHelper;
  late FolderLocalDataSource folderLocal;
  late FlashcardResultLocalDataSource resultLocal;
  late SyncQueueDataSource syncQueue;
  late int onLocalChangedCallCount;

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
    // テスト間でDBの中身が混ざらないよう、毎回まっさらなDBファイルを使う。
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(FolderTable.tableName);
    await db.delete(FlashcardResultTable.tableName);
    await db.delete(SyncQueueTable.tableName);

    folderLocal = FolderLocalDataSource(dbHelper);
    resultLocal = FlashcardResultLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    onLocalChangedCallCount = 0;
  });

  FlashcardResultRepositoryImpl buildRepository({
    FlashcardResultLocalDataSource? localDataSource,
    FolderLocalDataSource? folderLocalDataSource,
    SyncQueueDataSource? syncQueueDataSource,
  }) {
    return FlashcardResultRepositoryImpl(
      localDataSource: localDataSource ?? resultLocal,
      folderLocalDataSource: folderLocalDataSource ?? folderLocal,
      syncQueueDataSource: syncQueueDataSource ?? syncQueue,
      dbHelper: dbHelper,
      onLocalChanged: () => onLocalChangedCallCount++,
    );
  }

  Folder makeFolder(String id) => Folder(
        id: id,
        name: 'folder-$id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  Future<void> insertFolder(String id, {String forUserId = userId}) =>
      folderLocal.insert(makeFolder(id), userId: forUserId);

  FlashcardResult makeResult(
    String id,
    String folderId, {
    int totalCount = 10,
    int correctCount = 7,
    DateTime? date,
  }) =>
      FlashcardResult(
        id: id,
        folderId: folderId,
        totalCount: totalCount,
        correctCount: correctCount,
        date: date ?? DateTime(2024, 1, 1),
        updatedAt: date ?? DateTime(2024, 1, 1),
      );

  Future<void> insertResult(
    String id,
    String folderId, {
    String forUserId = userId,
  }) =>
      resultLocal.insert(makeResult(id, folderId), userId: forUserId);

  Future<Map<String, dynamic>?> resultRow(String id) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      FlashcardResultTable.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  group('getFlashcardResults', () {
    test(
        'ローカルに未削除の成績「R1」「R2」と削除済みの成績「R3」がある場合、'
        '戻り値がRightで「R1」「R2」を含み「R3」を含まない [FRS-R01]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertResult('R1', 'F');
      await insertResult('R2', 'F');
      await insertResult('R3', 'F');
      final db = await dbHelper.database;
      await resultLocal.markDeleted(db, 'R3', DateTime.now());

      final result = await repository.getFlashcardResults(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (results) {
          final ids = results.map((r) => r.id).toSet();
          expect(ids.contains('R1'), isTrue);
          expect(ids.contains('R2'), isTrue);
          expect(ids.contains('R3'), isFalse);
        },
      );
    });

    test(
        'ローカルにUの成績「R1」と、ユーザーVの成績「R4」がある場合、'
        '戻り値がRightで「R1」を含み「R4」を含まない [FRS-R02]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertResult('R1', 'F');
      await insertResult('R4', 'F', forUserId: otherUserId);

      final result = await repository.getFlashcardResults(userId: userId);

      result.match(
        (_) => fail('Right が返るはず'),
        (results) {
          final ids = results.map((r) => r.id).toSet();
          expect(ids.contains('R1'), isTrue);
          expect(ids.contains('R4'), isFalse);
        },
      );
    });

    test('オフラインで、ローカルに成績「R1」がある場合、戻り値がRightで「R1」を含む [FRS-R03]', () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline(); // オフライン状態を明示するだけで、結果には影響しない
      await insertFolder('F');
      await insertResult('R1', 'F');

      final result = await repository.getFlashcardResults(userId: userId);

      result.match(
        (_) => fail('Right が返るはず'),
        (results) => expect(results.map((r) => r.id), contains('R1')),
      );
    });

    test('ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [FRS-R04]', () async {
      final repository = buildRepository(
        localDataSource: ThrowingFindByUserIdFlashcardResultLocalDataSource(dbHelper),
      );

      final result = await repository.getFlashcardResults(userId: userId);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
    });

    test(
        'フォルダFの成績「R1」と、別のフォルダGの成績「R2」がある場合、'
        '戻り値がRightで「R1」「R2」の両方を含む [FRS-R05]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertFolder('G');
      await insertResult('R1', 'F');
      await insertResult('R2', 'G');

      final result = await repository.getFlashcardResults(userId: userId);

      result.match(
        (_) => fail('Right が返るはず'),
        (results) {
          final ids = results.map((r) => r.id).toSet();
          expect(ids.contains('R1'), isTrue);
          expect(ids.contains('R2'), isTrue);
        },
      );
    });
  });

  group('saveFlashcardResult', () {
    test(
        'オンラインで、フォルダFに問題数10・正解数7で登録した場合、戻り値がRightでフォルダF・問題数10・正解数7、'
        'dateとupdatedAtが等しい。その後のgetFlashcardResultsに含まれる。キューが1件増える [FRS-C01]', () async {
      final repository = buildRepository();
      await insertFolder('F');

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'F',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isRight(), isTrue);
      final saved = result.match((_) => fail('Right が返るはず'), (r) => r);
      expect(saved.folderId, 'F');
      expect(saved.totalCount, 10);
      expect(saved.correctCount, 7);
      expect(saved.date, saved.updatedAt);

      final after = await repository.getFlashcardResults(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (results) => expect(results.map((r) => r.id), contains(saved.id)),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'オフラインで、フォルダFに問題数10・正解数7で登録した場合、戻り値がRight。'
        'その後のgetFlashcardResultsに含まれる。キューが1件増える [FRS-C02]', () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();
      await insertFolder('F');

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'F',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isRight(), isTrue);
      final saved = result.match((_) => fail('Right が返るはず'), (r) => r);
      final after = await repository.getFlashcardResults(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (results) => expect(results.map((r) => r.id), contains(saved.id)),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'ローカルへの成績の保存が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetFlashcardResultsに含まれない。キューの件数が変わらない [FRS-C03]', () async {
      await insertFolder('F');
      final repository = buildRepository(
        localDataSource: ThrowingSaveFlashcardResultLocalDataSource(dbHelper),
      );

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'F',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await resultLocal.findByUserId(userId);
      expect(after, isEmpty);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        '成績の保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetFlashcardResultsに含まれない。キューの件数が変わらない [FRS-C04]', () async {
      await insertFolder('F');
      final repository = buildRepository(
        syncQueueDataSource: ThrowingEnqueueSyncQueueDataSource(dbHelper),
      );

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'F',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await resultLocal.findByUserId(userId);
      expect(after, isEmpty);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('登録した直後（送信前）は、ローカルのその成績のsyncStatusがpending、deletedAtがnull [FRS-C05]', () async {
      final repository = buildRepository();
      await insertFolder('F');

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'F',
        totalCount: 10,
        correctCount: 7,
      );
      final saved = result.match((_) => fail('Right が返るはず'), (r) => r);

      final row = await resultRow(saved.id);
      expect(row, isNotNull);
      expect(row!['syncStatus'], 'pending');
      expect(row['deletedAt'], isNull);
    });

    test(
        'フォルダFに問題数10・正解数7で2回登録した場合、戻り値のidが2回で異なる。'
        'その後のgetFlashcardResultsに2件とも含まれる。キューが2件増える [FRS-C06]', () async {
      final repository = buildRepository();
      await insertFolder('F');

      final result1 = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'F',
        totalCount: 10,
        correctCount: 7,
      );
      final result2 = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'F',
        totalCount: 10,
        correctCount: 7,
      );

      final saved1 = result1.match((_) => fail('Right が返るはず'), (r) => r);
      final saved2 = result2.match((_) => fail('Right が返るはず'), (r) => r);
      expect(saved1.id, isNot(saved2.id));

      final after = await repository.getFlashcardResults(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (results) {
          final ids = results.map((r) => r.id).toSet();
          expect(ids.contains(saved1.id), isTrue);
          expect(ids.contains(saved2.id), isTrue);
        },
      );
      expect(await syncQueue.countByUser(userId), 2);
    });

    test('削除済みのフォルダGを指定して登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FRS-C07]', () async {
      final repository = buildRepository();
      await insertFolder('G');
      final db = await dbHelper.database;
      await folderLocal.markDeleted(db, 'G', DateTime.now());

      final result = await repository.saveFlashcardResult(
        userId: userId,
        folderId: 'G',
        totalCount: 10,
        correctCount: 7,
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });
  });
}
