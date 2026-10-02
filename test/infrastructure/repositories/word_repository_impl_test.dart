import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/local_date.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/repositories/word_repository_impl.dart';

import '../../helpers/fake_infrastructure.dart';

/// ローカルへの単語の保存で例外を投げる（WRD-C03, WRD-U05）。
class ThrowingSaveWordLocalDataSource extends WordLocalDataSource {
  ThrowingSaveWordLocalDataSource(super.dbHelper);

  @override
  Future<void> save(
    DatabaseExecutor db,
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) {
    throw Exception('save failed');
  }
}

/// ローカルの読み取りで例外を投げる（WRD-R05）。
class ThrowingFindByFolderIdWordLocalDataSource extends WordLocalDataSource {
  ThrowingFindByFolderIdWordLocalDataSource(super.dbHelper);

  @override
  Future<List<Word>> findByFolderId(
    String folderId, {
    required String userId,
  }) {
    throw Exception('read failed');
  }
}

/// 単語の論理削除（保存）で例外を投げる（WRD-X05）。
class ThrowingMarkDeletedWordLocalDataSource extends WordLocalDataSource {
  ThrowingMarkDeletedWordLocalDataSource(super.dbHelper);

  @override
  Future<void> markDeleted(DatabaseExecutor db, String wordId, DateTime at) {
    throw Exception('markDeleted failed');
  }
}

/// キューへの登録で例外を投げる（WRD-C04, WRD-U08, WRD-X07）。
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
  late WordLocalDataSource wordLocal;
  late SyncQueueDataSource syncQueue;
  late int onLocalChangedCallCount;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // DatabaseHelper は 'wordstock.db' という固定のファイル名を使うため、
    // 他のテストファイルと同時実行された際に同一パスを取り合ってロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリに切り替える。
    final tempDir = await Directory.systemTemp.createTemp(
      'word_repository_impl_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    // テスト間でDBの中身が混ざらないよう、毎回まっさらなDBファイルを使う。
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(FolderTable.tableName);
    await db.delete(WordTable.tableName);
    await db.delete(SyncQueueTable.tableName);

    folderLocal = FolderLocalDataSource(dbHelper);
    wordLocal = WordLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    onLocalChangedCallCount = 0;
  });

  WordRepositoryImpl buildRepository({
    WordLocalDataSource? localDataSource,
    FolderLocalDataSource? folderLocalDataSource,
    SyncQueueDataSource? syncQueueDataSource,
  }) {
    return WordRepositoryImpl(
      localDataSource: localDataSource ?? wordLocal,
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

  Word makeWord(String id, {String front = 'front', String back = 'back'}) =>
      Word(
        id: id,
        front: front,
        back: back,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  Future<void> insertFolder(String id, {String forUserId = userId}) =>
      folderLocal.insert(makeFolder(id), userId: forUserId);

  Future<void> insertWord(
    String id,
    String folderId, {
    String front = 'front',
    String back = 'back',
    String forUserId = userId,
  }) =>
      wordLocal.insert(
        makeWord(id, front: front, back: back),
        userId: forUserId,
        folderId: folderId,
      );

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

  group('getWords', () {
    test(
        'Fに未削除の単語「A」「B」と削除済みの単語「C」がある状態でFを指定した場合、'
        '戻り値がRightで「A」「B」を含み「C」を含まない [WRD-R01]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertWord('A', 'F');
      await insertWord('B', 'F');
      await insertWord('C', 'F');
      final db = await dbHelper.database;
      await wordLocal.markDeleted(db, 'C', DateTime.now());

      final result = await repository.getWords(userId: userId, folderId: 'F');

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (words) {
          final ids = words.map((w) => w.id).toSet();
          expect(ids.contains('A'), isTrue);
          expect(ids.contains('B'), isTrue);
          expect(ids.contains('C'), isFalse);
        },
      );
    });

    test(
        'Fに単語「A」、別のフォルダGに単語「D」がある状態でFを指定した場合、'
        '戻り値がRightで「A」を含み「D」を含まない [WRD-R02]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertFolder('G');
      await insertWord('A', 'F');
      await insertWord('D', 'G');

      final result = await repository.getWords(userId: userId, folderId: 'F');

      result.match(
        (_) => fail('Right が返るはず'),
        (words) {
          final ids = words.map((w) => w.id).toSet();
          expect(ids.contains('A'), isTrue);
          expect(ids.contains('D'), isFalse);
        },
      );
    });

    test(
        'FにUの単語「A」と、ユーザーVの単語「E」の行がある状態でFを指定した場合、'
        '戻り値がRightで「A」を含み「E」を含まない [WRD-R03]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertWord('A', 'F');
      await insertWord('E', 'F', forUserId: otherUserId);

      final result = await repository.getWords(userId: userId, folderId: 'F');

      result.match(
        (_) => fail('Right が返るはず'),
        (words) {
          final ids = words.map((w) => w.id).toSet();
          expect(ids.contains('A'), isTrue);
          expect(ids.contains('E'), isFalse);
        },
      );
    });

    test('オフラインで、Fに単語「A」がある状態でFを指定した場合、戻り値がRightで「A」を含む [WRD-R04]',
        () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline(); // オフライン状態を明示するだけで、結果には影響しない
      await insertFolder('F');
      await insertWord('A', 'F');

      final result = await repository.getWords(userId: userId, folderId: 'F');

      result.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), contains('A')),
      );
    });

    test('ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [WRD-R05]', () async {
      final repository = buildRepository(
        localDataSource: ThrowingFindByFolderIdWordLocalDataSource(dbHelper),
      );

      final result = await repository.getWords(userId: userId, folderId: 'F');

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
    });

    test(
        '削除済みのフォルダG（配下の単語もフォルダの削除に連動して削除済み）を指定した場合、'
        '戻り値がRight([]) [WRD-R06]', () async {
      final repository = buildRepository();
      await insertFolder('G');
      await insertWord('W', 'G');
      final db = await dbHelper.database;
      await wordLocal.markDeleted(db, 'W', DateTime.now());
      await folderLocal.markDeleted(db, 'G', DateTime.now());

      final result = await repository.getWords(userId: userId, folderId: 'G');

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words, isEmpty),
      );
    });

    test('ローカルに存在しないフォルダのidを指定した場合、戻り値がRight([]) [WRD-R07]', () async {
      final repository = buildRepository();

      final result =
          await repository.getWords(userId: userId, folderId: 'not-exist');

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words, isEmpty),
      );
    });
  });

  group('createWord', () {
    test(
        'オンラインで、Fに表「apple」・裏「りんご」で登録した場合、戻り値がRightで表「apple」・裏「りんご」、'
        'createdAtとupdatedAtが等しい。その後のgetWords（F）に含まれる。キューが1件増える [WRD-C01]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');

      final result = await repository.createWord(
        userId: userId,
        folderId: 'F',
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isRight(), isTrue);
      final word = result.match((_) => fail('Right が返るはず'), (w) => w);
      expect(word.front, 'apple');
      expect(word.back, 'りんご');
      expect(word.createdAt, word.updatedAt);

      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), contains(word.id)),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'オフラインで、Fに表「apple」・裏「りんご」で登録した場合、戻り値がRight。'
        'その後のgetWords（F）に含まれる。キューが1件増える [WRD-C02]', () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();
      await insertFolder('F');

      final result = await repository.createWord(
        userId: userId,
        folderId: 'F',
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isRight(), isTrue);
      final word = result.match((_) => fail('Right が返るはず'), (w) => w);
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), contains(word.id)),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'ローカルへの単語の保存が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetWords（F）に含まれない。キューの件数が変わらない [WRD-C03]', () async {
      await insertFolder('F');
      final repository = buildRepository(
        localDataSource: ThrowingSaveWordLocalDataSource(dbHelper),
      );

      final result = await repository.createWord(
        userId: userId,
        folderId: 'F',
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await wordLocal.findByFolderId('F', userId: userId);
      expect(after.where((w) => w.front == 'apple'), isEmpty);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        '単語の保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetWords（F）に含まれない。キューの件数が変わらない [WRD-C04]', () async {
      await insertFolder('F');
      final repository = buildRepository(
        syncQueueDataSource: ThrowingEnqueueSyncQueueDataSource(dbHelper),
      );

      final result = await repository.createWord(
        userId: userId,
        folderId: 'F',
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await wordLocal.findByFolderId('F', userId: userId);
      expect(after.where((w) => w.front == 'apple'), isEmpty);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        'Fに表「2024-01-01」・裏「元日」で登録した場合、その後のgetWords（F）の単語の表が'
        '文字列「2024-01-01」 [WRD-C05]', () async {
      final repository = buildRepository();
      await insertFolder('F');

      await repository.createWord(
        userId: userId,
        folderId: 'F',
        front: '2024-01-01',
        back: '元日',
      );

      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.single.front, '2024-01-01'),
      );
    });

    test('登録した直後（送信前）は、ローカルのその単語のsyncStatusがpending、deletedAtがnull [WRD-C06]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');

      final result = await repository.createWord(
        userId: userId,
        folderId: 'F',
        front: 'apple',
        back: 'りんご',
      );
      final word = result.match((_) => fail('Right が返るはず'), (w) => w);

      final row = await wordRow(word.id);
      expect(row, isNotNull);
      expect(row!['syncStatus'], 'pending');
      expect(row['deletedAt'], isNull);
    });

    test('削除済みのフォルダGを指定して登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-C07]',
        () async {
      final repository = buildRepository();
      await insertFolder('G');
      final db = await dbHelper.database;
      await folderLocal.markDeleted(db, 'G', DateTime.now());

      final result = await repository.createWord(
        userId: userId,
        folderId: 'G',
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });
  });

  group('updateWord', () {
    test(
        'オンラインで、単語W（表「A」）を表「B」に編集した場合、戻り値がRightで表が「B」、createdAtが編集前と等しく、'
        'updatedAtが編集前のupdatedAtより後。その後のgetWords（F）のWの表が「B」。キューが1件増える [WRD-U01]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');
      final createdAt = DateTime(2023, 5, 1);
      await wordLocal.insert(
        Word(
          id: 'W',
          front: 'A',
          back: 'a',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        userId: userId,
        folderId: 'F',
      );

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'B',
        back: 'a',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (word) {
          expect(word.front, 'B');
          expect(word.createdAt, createdAt);
          expect(word.updatedAt.isAfter(createdAt), isTrue);
        },
      );
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.firstWhere((w) => w.id == 'W').front, 'B'),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'オフラインで、単語W（表「A」）を表「B」に編集した場合、戻り値がRightで表が「B」。'
        'その後のgetWords（F）のWの表が「B」。キューが1件増える [WRD-U02]', () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();
      await insertFolder('F');
      await insertWord('W', 'F', front: 'A');

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'B',
        back: 'back',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (word) => expect(word.front, 'B'),
      );
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.firstWhere((w) => w.id == 'W').front, 'B'),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('ローカルに存在しないidを指定して編集した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-U03]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'not-exist',
        front: 'B',
        back: 'b',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        '削除済みの単語Wを指定して編集した場合、戻り値がLeft(NotFoundFailure)。'
        'その後のgetWords（F）にWが含まれない。キューの件数が変わらない [WRD-U04]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertWord('W', 'F', front: 'A');
      final db = await dbHelper.database;
      await wordLocal.markDeleted(db, 'W', DateTime.now());

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'B',
        back: 'b',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), isNot(contains('W'))),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        '単語W（表「A」）の編集で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetWords（F）のWの表が「A」のまま。キューの件数が変わらない [WRD-U05]', () async {
      await insertFolder('F');
      await insertWord('W', 'F', front: 'A');
      final repository = buildRepository(
        localDataSource: ThrowingSaveWordLocalDataSource(dbHelper),
      );

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'B',
        back: 'b',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await wordLocal.findByFolderId('F', userId: userId);
      expect(after.firstWhere((w) => w.id == 'W').front, 'A');
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        '単語W（表「A」・裏「a」）を、同じ表「A」・裏「a」で編集した場合、戻り値がRightで、'
        'updatedAtが編集前のupdatedAtより後。キューが1件増える [WRD-U06]', () async {
      final repository = buildRepository();
      await insertFolder('F');
      final createdAt = DateTime(2023, 5, 1);
      await wordLocal.insert(
        Word(
          id: 'W',
          front: 'A',
          back: 'a',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        userId: userId,
        folderId: 'F',
      );

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'A',
        back: 'a',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (word) => expect(word.updatedAt.isAfter(createdAt), isTrue),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('ユーザーVの単語Eのidを指定して、Uとして編集した場合、戻り値がLeft(NotFoundFailure)。Eの表は変わらない [WRD-U07]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertWord('E', 'F', front: 'A', forUserId: otherUserId);

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'E',
        front: 'B',
        back: 'b',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      final row = await wordRow('E');
      expect(row!['front'], 'A');
    });

    test(
        '単語Wの編集で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetWords（F）のWが編集前のまま [WRD-U08]', () async {
      await insertFolder('F');
      await insertWord('W', 'F', front: 'A');
      final repository = buildRepository(
        syncQueueDataSource: ThrowingEnqueueSyncQueueDataSource(dbHelper),
      );

      final result = await repository.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'B',
        back: 'b',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.firstWhere((w) => w.id == 'W').front, 'A'),
      );
    });
  });

  group('deleteWord', () {
    test(
        'オンラインで、単語Wを削除した場合、戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。'
        'ローカルのWのdeletedAtが入り、updatedAtが削除前のupdatedAtより後。キューが1件増える [WRD-X01]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');
      final createdAt = DateTime(2023, 5, 1);
      await wordLocal.insert(
        Word(
          id: 'W',
          front: 'A',
          back: 'a',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        userId: userId,
        folderId: 'F',
      );

      final result = await repository.deleteWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
      );

      expect(result.isRight(), isTrue);
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), isNot(contains('W'))),
      );
      final row = await wordRow('W');
      expect(row!['deletedAt'], isNotNull);
      expect(
        fromDateColumn(row['updatedAt']).isAfter(createdAt),
        isTrue,
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('オフラインで、単語Wを削除した場合、戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。キューが1件増える [WRD-X02]',
        () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();
      await insertFolder('F');
      await insertWord('W', 'F');

      final result = await repository.deleteWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
      );

      expect(result.isRight(), isTrue);
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), isNot(contains('W'))),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('ローカルに存在しないidを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-X03]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');

      final result = await repository.deleteWord(
        userId: userId,
        folderId: 'F',
        wordId: 'not-exist',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('削除済みの単語Wを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-X04]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertWord('W', 'F');
      final db = await dbHelper.database;
      await wordLocal.markDeleted(db, 'W', DateTime.now());

      final result = await repository.deleteWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        '単語Wの削除で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。'
        'その後のgetWords（F）にWが含まれる。キューの件数が変わらない [WRD-X05]', () async {
      await insertFolder('F');
      await insertWord('W', 'F');
      final repository = buildRepository(
        localDataSource: ThrowingMarkDeletedWordLocalDataSource(dbHelper),
      );

      final result = await repository.deleteWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), contains('W')),
      );
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('ユーザーVの単語Eのidを指定して、Uとして削除した場合、戻り値がLeft(NotFoundFailure)。EのdeletedAtはnullのまま [WRD-X06]',
        () async {
      final repository = buildRepository();
      await insertFolder('F');
      await insertWord('E', 'F', forUserId: otherUserId);

      final result = await repository.deleteWord(
        userId: userId,
        folderId: 'F',
        wordId: 'E',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.notFound()),
        (_) => fail('Left が返るはず'),
      );
      final row = await wordRow('E');
      expect(row!['deletedAt'], isNull);
    });

    test('単語Wの削除で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）にWが含まれる [WRD-X07]',
        () async {
      await insertFolder('F');
      await insertWord('W', 'F');
      final repository = buildRepository(
        syncQueueDataSource: ThrowingEnqueueSyncQueueDataSource(dbHelper),
      );

      final result = await repository.deleteWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after =
          await repository.getWords(userId: userId, folderId: 'F');
      after.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id), contains('W')),
      );
    });
  });
}
