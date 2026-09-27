import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/local_date.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/repositories/folder_repository_impl.dart';

import '../../helpers/fake_infrastructure.dart';

/// ローカルへの保存で例外を投げる（FLD-C03, FLD-U05）。
class ThrowingSaveFolderLocalDataSource extends FolderLocalDataSource {
  ThrowingSaveFolderLocalDataSource(DatabaseHelper dbHelper) : super(dbHelper);

  @override
  Future<void> save(
    DatabaseExecutor db,
    Folder folder, {
    required String userId,
    String syncStatus = 'synced',
  }) {
    throw Exception('save failed');
  }
}

/// ローカルの読み取りで例外を投げる（FLD-R04）。
class ThrowingFindByUserIdFolderLocalDataSource extends FolderLocalDataSource {
  ThrowingFindByUserIdFolderLocalDataSource(DatabaseHelper dbHelper)
      : super(dbHelper);

  @override
  Future<List<Folder>> findByUserId(String userId,
      {String? parentFolderId}) {
    throw Exception('read failed');
  }
}

/// 配下の単語の論理削除（保存）で例外を投げる（FLD-X07）。
class ThrowingMarkDeletedWordLocalDataSource extends WordLocalDataSource {
  ThrowingMarkDeletedWordLocalDataSource(DatabaseHelper dbHelper)
      : super(dbHelper);

  @override
  Future<void> markDeleted(DatabaseExecutor db, String wordId, DateTime at) {
    throw Exception('markDeleted failed');
  }
}

/// キューへの登録で例外を投げる（FLD-C04, FLD-U08）。
class ThrowingEnqueueSyncQueueDataSource extends SyncQueueDataSource {
  ThrowingEnqueueSyncQueueDataSource(DatabaseHelper dbHelper) : super(dbHelper);

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
  late WordLocalDataSource wordLocal;
  late FlashcardResultLocalDataSource flashcardResultLocal;
  late SyncQueueDataSource syncQueue;
  late int onLocalChangedCallCount;

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
    onLocalChangedCallCount = 0;
  });

  FolderRepositoryImpl buildRepository({
    FolderLocalDataSource? localDataSource,
    WordLocalDataSource? wordLocalDataSource,
    FlashcardResultLocalDataSource? flashcardResultLocalDataSource,
    SyncQueueDataSource? syncQueueDataSource,
  }) {
    return FolderRepositoryImpl(
      localDataSource: localDataSource ?? folderLocal,
      wordLocalDataSource: wordLocalDataSource ?? wordLocal,
      flashcardResultLocalDataSource:
          flashcardResultLocalDataSource ?? flashcardResultLocal,
      syncQueueDataSource: syncQueueDataSource ?? syncQueue,
      dbHelper: dbHelper,
      onLocalChanged: () => onLocalChangedCallCount++,
    );
  }

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

  FlashcardResult makeFlashcardResult(String id, String folderId) =>
      FlashcardResult(
        id: id,
        folderId: folderId,
        totalCount: 10,
        correctCount: 8,
        date: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  Future<void> insertFolder(
    String id, {
    String? parentFolderId,
    String forUserId = userId,
  }) =>
      folderLocal.insert(
        makeFolder(id, parentFolderId: parentFolderId),
        userId: forUserId,
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

  Future<Map<String, dynamic>?> folderRow(String id) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      FolderTable.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> wordRow(String id) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      WordTable.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> flashcardResultRow(String id) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      FlashcardResultTable.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  group('getFolders', () {
    test(
        'ローカルに未削除のフォルダ「A」「B」と削除済みのフォルダ「C」がある場合、'
        '戻り値がRightで「A」「B」を含み「C」を含まない [FLD-R01]', () async {
      final repository = buildRepository();
      await insertFolder('A');
      await insertFolder('B');
      await insertFolder('C');
      final db = await dbHelper.database;
      await folderLocal.markDeleted(db, 'C', DateTime.now());

      final result = await repository.getFolders(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (folders) {
          final ids = folders.map((f) => f.id).toSet();
          expect(ids.contains('A'), isTrue);
          expect(ids.contains('B'), isTrue);
          expect(ids.contains('C'), isFalse);
        },
      );
    });

    test(
        'ローカルにUのフォルダ「A」とユーザーVのフォルダ「D」がある場合、'
        '戻り値がRightで「A」を含み「D」を含まない [FLD-R02]', () async {
      final repository = buildRepository();
      await insertFolder('A');
      await insertFolder('D', forUserId: otherUserId);

      final result = await repository.getFolders(userId: userId);

      result.match(
        (_) => fail('Right が返るはず'),
        (folders) {
          final ids = folders.map((f) => f.id).toSet();
          expect(ids.contains('A'), isTrue);
          expect(ids.contains('D'), isFalse);
        },
      );
    });

    test('オフラインで、ローカルにフォルダ「A」がある場合、戻り値がRightで「A」を含む [FLD-R03]',
        () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline(); // オフライン状態を明示するだけで、結果には影響しない
      await insertFolder('A');

      final result = await repository.getFolders(userId: userId);

      result.match(
        (_) => fail('Right が返るはず'),
        (folders) => expect(folders.map((f) => f.id), contains('A')),
      );
    });

    test('ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [FLD-R04]',
        () async {
      final repository = buildRepository(
        localDataSource: ThrowingFindByUserIdFolderLocalDataSource(dbHelper),
      );

      final result = await repository.getFolders(userId: userId);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('createFolder', () {
    test(
        'オンラインで、名前「A」で登録した場合、戻り値がRightで名前が「A」、createdAtとupdatedAtが等しい。'
        'その後のgetFoldersに「A」が含まれる。キューが1件増える [FLD-C01]', () async {
      final repository = buildRepository();

      final result = await repository.createFolder(userId: userId, name: 'A');

      expect(result.isRight(), isTrue);
      final folder =
          result.match((_) => fail('Right が返るはず'), (f) => f);
      expect(folder.name, 'A');
      expect(folder.createdAt, folder.updatedAt);

      final after = await repository.getFolders(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (folders) => expect(folders.map((f) => f.id), contains(folder.id)),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'オフラインで、名前「A」で登録した場合、戻り値がRightで名前が「A」。'
        'その後のgetFoldersに「A」が含まれる。キューが1件増える [FLD-C02]', () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();

      final result = await repository.createFolder(userId: userId, name: 'A');

      expect(result.isRight(), isTrue);
      final folder =
          result.match((_) => fail('Right が返るはず'), (f) => f);
      expect(folder.name, 'A');

      final after = await repository.getFolders(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (folders) => expect(folders.map((f) => f.id), contains(folder.id)),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'ローカルへのフォルダの保存が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetFoldersに登録しようとしたフォルダが含まれない。キューの件数が変わらない [FLD-C03]',
        () async {
      final repository = buildRepository(
        localDataSource: ThrowingSaveFolderLocalDataSource(dbHelper),
      );

      final result = await repository.createFolder(userId: userId, name: 'A');

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await folderLocal.findByUserId(userId);
      expect(after.where((f) => f.name == 'A'), isEmpty);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        'フォルダの保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetFoldersに登録しようとしたフォルダが含まれない。キューの件数が変わらない [FLD-C04]',
        () async {
      final repository = buildRepository(
        syncQueueDataSource: ThrowingEnqueueSyncQueueDataSource(dbHelper),
      );

      final result = await repository.createFolder(userId: userId, name: 'A');

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await folderLocal.findByUserId(userId);
      expect(after.where((f) => f.name == 'A'), isEmpty);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('親フォルダGを指定して、名前「A」で登録した場合、戻り値がRightでparentFolderIdがGのid [FLD-C05]',
        () async {
      final repository = buildRepository();
      await insertFolder('G');

      final result = await repository.createFolder(
        userId: userId,
        name: 'A',
        parentFolderId: 'G',
      );

      result.match(
        (_) => fail('Right が返るはず'),
        (folder) => expect(folder.parentFolderId, 'G'),
      );
    });

    test('登録した直後（送信前）は、ローカルのそのフォルダのsyncStatusがpending、deletedAtがnull [FLD-C06]',
        () async {
      final repository = buildRepository();

      final result = await repository.createFolder(userId: userId, name: 'A');
      final folder = result.match((_) => fail('Right が返るはず'), (f) => f);

      final row = await folderRow(folder.id);
      expect(row, isNotNull);
      expect(row!['syncStatus'], 'pending');
      expect(row['deletedAt'], isNull);
    });

    test(
        '削除済みのフォルダGを親に指定して、名前「A」で登録した場合、'
        '戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-C07]', () async {
      final repository = buildRepository();
      await insertFolder('G');
      final db = await dbHelper.database;
      await folderLocal.markDeleted(db, 'G', DateTime.now());

      final result = await repository.createFolder(
        userId: userId,
        name: 'A',
        parentFolderId: 'G',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });
  });

  group('updateFolder', () {
    test(
        'オンラインで、ローカルのフォルダF（名前「A」）を名前「B」に編集した場合、'
        '戻り値がRightで名前が「B」、createdAtが編集前と等しく、updatedAtが編集前のupdatedAtより後。'
        'その後のgetFoldersのFの名前が「B」。キューが1件増える [FLD-U01]', () async {
      final repository = buildRepository();
      final createdAt = DateTime(2023, 5, 1);
      await folderLocal.insert(
        Folder(
          id: 'F',
          name: 'A',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        userId: userId,
      );

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'F',
        name: 'B',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (folder) {
          expect(folder.name, 'B');
          expect(folder.createdAt, createdAt);
          expect(folder.updatedAt.isAfter(createdAt), isTrue);
        },
      );
      final after = await repository.getFolders(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (folders) =>
            expect(folders.firstWhere((f) => f.id == 'F').name, 'B'),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'オフラインで、ローカルのフォルダF（名前「A」）を名前「B」に編集した場合、'
        '戻り値がRightで名前が「B」。その後のgetFoldersのFの名前が「B」。キューが1件増える [FLD-U02]',
        () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();
      await insertFolder('F');

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'F',
        name: 'B',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (folder) => expect(folder.name, 'B'),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('ローカルに存在しないidを指定して編集した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-U03]',
        () async {
      final repository = buildRepository();

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'not-exist',
        name: 'B',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        '削除済みのフォルダFを指定して編集した場合、戻り値がLeft(NotFoundFailure)。'
        'その後のgetFoldersにFが含まれない。キューの件数が変わらない [FLD-U04]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      final db = await dbHelper.database;
      await folderLocal.markDeleted(db, 'F', DateTime.now());

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'F',
        name: 'B',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      final after = await repository.getFolders(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (folders) => expect(folders.map((f) => f.id), isNot(contains('F'))),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        'ローカルのフォルダF（名前「A」）の編集で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetFoldersのFの名前が「A」のまま。キューの件数が変わらない [FLD-U05]', () async {
      await insertFolder('F');
      final repository = buildRepository(
        localDataSource: ThrowingSaveFolderLocalDataSource(dbHelper),
      );

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'F',
        name: 'B',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await folderLocal.findByUserId(userId);
      expect(after.firstWhere((f) => f.id == 'F').name, 'folder-F');
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        'ローカルのフォルダF（名前「A」）を、同じ名前「A」で編集した場合、'
        '戻り値がRightで、updatedAtが編集前のupdatedAtより後。キューが1件増える [FLD-U06]', () async {
      final repository = buildRepository();
      final createdAt = DateTime(2023, 5, 1);
      await folderLocal.insert(
        Folder(
          id: 'F',
          name: 'A',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        userId: userId,
      );

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'F',
        name: 'A',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (folder) => expect(folder.updatedAt.isAfter(createdAt), isTrue),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('ユーザーVのフォルダGのidを指定して、Uとして編集した場合、戻り値がLeft(NotFoundFailure)。Gの名前は変わらない [FLD-U07]',
        () async {
      final repository = buildRepository();
      await insertFolder('G', forUserId: otherUserId);

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'G',
        name: 'B',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      final row = await folderRow('G');
      expect(row!['name'], 'folder-G');
    });

    test(
        'ローカルのフォルダFの編集で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetFoldersのFの名前が編集前のまま [FLD-U08]', () async {
      await insertFolder('F');
      final repository = buildRepository(
        syncQueueDataSource: ThrowingEnqueueSyncQueueDataSource(dbHelper),
      );

      final result = await repository.updateFolder(
        userId: userId,
        folderId: 'F',
        name: 'B',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await repository.getFolders(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (folders) =>
            expect(folders.firstWhere((f) => f.id == 'F').name, 'folder-F'),
      );
    });
  });

  group('deleteFolder', () {
    test(
        'オンラインで、ローカルのフォルダF（配下なし）を削除した場合、戻り値がRight(unit)。'
        'その後のgetFoldersにFが含まれない。ローカルのFのdeletedAtが入り、'
        'updatedAtが削除前のupdatedAtより後。キューが1件増える [FLD-X01]', () async {
      final repository = buildRepository();
      final createdAt = DateTime(2023, 5, 1);
      await folderLocal.insert(
        Folder(
          id: 'F',
          name: 'A',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        userId: userId,
      );

      final result =
          await repository.deleteFolder(userId: userId, folderId: 'F');

      expect(result.isRight(), isTrue);
      final after = await repository.getFolders(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (folders) => expect(folders.map((f) => f.id), isNot(contains('F'))),
      );
      final row = await folderRow('F');
      expect(row!['deletedAt'], isNotNull);
      expect(fromDateColumn(row['updatedAt']).isAfter(createdAt), isTrue);
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'オフラインで、ローカルのフォルダF（配下なし）を削除した場合、戻り値がRight(unit)。'
        'その後のgetFoldersにFが含まれない。キューが1件増える [FLD-X02]', () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();
      await insertFolder('F');

      final result =
          await repository.deleteFolder(userId: userId, folderId: 'F');

      expect(result.isRight(), isTrue);
      final after = await repository.getFolders(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (folders) => expect(folders.map((f) => f.id), isNot(contains('F'))),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'フォルダFに子フォルダG、Gに単語W、Fに成績Rがある状態でFを削除した場合、戻り値がRight(unit)。'
        'ローカルのF・G・W・Rのdeletedatがすべて入る。getWords（G）にWが含まれない。'
        'getFlashcardResultsにRが含まれない。キューが4件（F・G・W・R）増える [FLD-X03]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertFolder('G', parentFolderId: 'F');
      await insertWord('W', 'G');
      await insertFlashcardResult('R', 'F');

      final result =
          await repository.deleteFolder(userId: userId, folderId: 'F');

      expect(result.isRight(), isTrue);
      for (final id in ['F', 'G']) {
        final row = await folderRow(id);
        expect(row!['deletedAt'], isNotNull);
      }
      expect((await wordRow('W'))!['deletedAt'], isNotNull);
      expect((await flashcardResultRow('R'))!['deletedAt'], isNotNull);
      expect(
        await wordLocal.findByFolderId('G', userId: userId),
        isEmpty,
      );
      expect(
        await flashcardResultLocal.findByUserId(userId, folderId: 'F'),
        isEmpty,
      );
      expect(await syncQueue.countByUser(userId), 4);
    });

    test('FLD-X03と同じ配下がある状態でFを削除した場合、ローカルのG・W・RのdeletedAtがFのdeletedAtと等しい [FLD-X04]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertFolder('G', parentFolderId: 'F');
      await insertWord('W', 'G');
      await insertFlashcardResult('R', 'F');

      await repository.deleteFolder(userId: userId, folderId: 'F');

      final fDeletedAt =
          fromDateColumn((await folderRow('F'))!['deletedAt']);
      final gDeletedAt =
          fromDateColumn((await folderRow('G'))!['deletedAt']);
      final wDeletedAt = fromDateColumn((await wordRow('W'))!['deletedAt']);
      final rDeletedAt =
          fromDateColumn((await flashcardResultRow('R'))!['deletedAt']);
      expect(gDeletedAt, fDeletedAt);
      expect(wDeletedAt, fDeletedAt);
      expect(rDeletedAt, fDeletedAt);
    });

    test('ローカルに存在しないidを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-X05]',
        () async {
      final repository = buildRepository();

      final result = await repository.deleteFolder(
        userId: userId,
        folderId: 'not-exist',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('削除済みのフォルダFを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-X06]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');
      final db = await dbHelper.database;
      await folderLocal.markDeleted(db, 'F', DateTime.now());

      final result =
          await repository.deleteFolder(userId: userId, folderId: 'F');

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        'FLD-X03と同じ配下がある状態でFを削除し、配下の単語Wの保存が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'ローカルのF・G・W・RのdeletedAtがすべてnullのまま。キューの件数が変わらない [FLD-X07]', () async {
      await insertFolder('F');
      await insertFolder('G', parentFolderId: 'F');
      await insertWord('W', 'G');
      await insertFlashcardResult('R', 'F');
      final repository = buildRepository(
        wordLocalDataSource: ThrowingMarkDeletedWordLocalDataSource(dbHelper),
      );

      final result =
          await repository.deleteFolder(userId: userId, folderId: 'F');

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      for (final id in ['F', 'G']) {
        expect((await folderRow(id))!['deletedAt'], isNull);
      }
      expect((await wordRow('W'))!['deletedAt'], isNull);
      expect((await flashcardResultRow('R'))!['deletedAt'], isNull);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('ユーザーVのフォルダGのidを指定して、Uとして削除した場合、戻り値がLeft(NotFoundFailure)。GのdeletedAtはnullのまま [FLD-X08]',
        () async {
      final repository = buildRepository();
      await insertFolder('G', forUserId: otherUserId);

      final result =
          await repository.deleteFolder(userId: userId, folderId: 'G');

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect((await folderRow('G'))!['deletedAt'], isNull);
    });

    test(
        '削除済みの子フォルダG（deletedAtがFの削除より前）を持つフォルダFを削除した場合、'
        'ローカルのGのdeletedAtが変わらない。キューが1件（F）増える [FLD-X09]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertFolder('G', parentFolderId: 'F');
      final earlierDeletedAt = DateTime(2024, 1, 2);
      final db = await dbHelper.database;
      await folderLocal.markDeleted(db, 'G', earlierDeletedAt);

      final result =
          await repository.deleteFolder(userId: userId, folderId: 'F');

      expect(result.isRight(), isTrue);
      final gRow = await folderRow('G');
      expect(fromDateColumn(gRow!['deletedAt']), earlierDeletedAt);
      expect(await syncQueue.countByUser(userId), 1);
    });
  });
}
