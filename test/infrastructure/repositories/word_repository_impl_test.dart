import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/repositories/word_repository_impl.dart';

import '../../helpers/fake_infrastructure.dart';

void main() {
  const userId = 'user-1';
  const folderId = 'folder-1';

  late DatabaseHelper dbHelper;
  late WordLocalDataSource wordLocal;
  late SyncQueueDataSource syncQueue;
  late FakeFirestoreDataSource fakeRemote;
  late FakeConnectivityMonitor fakeConnectivity;
  late WordRepositoryImpl repository;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // DatabaseHelper は固定ファイル名を使うため、他のテストファイルと同時実行された際に
    // 同一パスを取り合ってロック競合が発生しないよう、専用の一時ディレクトリに切り替える。
    final tempDir = await Directory.systemTemp.createTemp(
      'word_repository_impl_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(WordTable.tableName);
    await db.delete(SyncQueueTable.tableName);

    wordLocal = WordLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    fakeRemote = FakeFirestoreDataSource();
    fakeConnectivity = FakeConnectivityMonitor(online: true);

    repository = WordRepositoryImpl(
      localDataSource: wordLocal,
      remoteDataSource: fakeRemote,
      syncQueueDataSource: syncQueue,
      dbHelper: dbHelper,
      connectivityMonitor: fakeConnectivity,
    );
  });

  Word makeWord(String id, {DateTime? at}) => Word(
        id: id,
        front: 'front-$id',
        back: 'back-$id',
        createdAt: at ?? DateTime(2024, 1, 1),
        updatedAt: at ?? DateTime(2024, 1, 1),
      );

  Future<void> insertWord(String id, {DateTime? at}) => wordLocal.insert(
        makeWord(id, at: at),
        userId: userId,
        folderId: folderId,
      );

  Future<List<Map<String, dynamic>>> queueRowsFor(
    String recordId,
    String operation,
  ) async {
    final db = await dbHelper.database;
    return db.query(
      SyncQueueTable.tableName,
      where: 'table_name = ? AND record_id = ? AND operation = ?',
      whereArgs: [WordTable.tableName, recordId, operation],
    );
  }

  group('getWords', () {
    test('フォルダに単語が存在する場合、ローカルDBから単語一覧が取得できる', () async {
      await insertWord('word-1');
      await insertWord('word-2');

      final result = await repository.getWords(
        userId: userId,
        folderId: folderId,
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words.map((w) => w.id).toSet(), {'word-1', 'word-2'}),
      );
    });

    test('フォルダに単語が存在しない場合、空リストが返る', () async {
      final result = await repository.getWords(
        userId: userId,
        folderId: folderId,
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (words) => expect(words, isEmpty),
      );
    });

    test('ローカルDBアクセスで例外が発生した場合、Failure.unknownが返る', () async {
      // テーブルを破壊して findByFolderId 内のクエリを失敗させる。
      final db = await dbHelper.database;
      await db.execute('DROP TABLE ${WordTable.tableName}');

      final result = await repository.getWords(
        userId: userId,
        folderId: folderId,
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );

      // 後続テストに影響しないようテーブルを復元する。
      await WordTable.onCreate(db);
    });
  });

  group('createWord - オンライン時', () {
    test('単語を作成した場合、ローカル・リモート双方に synced 状態で保存される', () async {
      final result = await repository.createWord(
        userId: userId,
        folderId: folderId,
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (word) {
          expect(word.front, 'apple');
          expect(word.back, 'りんご');
          expect(word.createdAt, word.updatedAt);
        },
      );

      final saved = await wordLocal.findByFolderId(folderId, userId: userId);
      expect(saved, hasLength(1));
      expect(fakeRemote.writtenWords, hasLength(1));
      expect(fakeRemote.writtenWords.single.userId, userId);
      expect(fakeRemote.writtenWords.single.folderId, folderId);
    });

    test('リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
      );

      final result = await repository.createWord(
        userId: userId,
        folderId: folderId,
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'denied',
      );

      final result = await repository.createWord(
        userId: userId,
        folderId: folderId,
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.unknown('denied')),
        (_) => fail('Left が返るはず'),
      );
    });

    test('ローカル書き込みで想定外の例外が発生した場合、Failure.unknownが返る', () async {
      // テーブルを破壊して _local.insert 内のクエリを失敗させる。
      final db = await dbHelper.database;
      await db.execute('DROP TABLE ${WordTable.tableName}');

      final result = await repository.createWord(
        userId: userId,
        folderId: folderId,
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );

      // 後続テストに影響しないようテーブルを復元する。
      await WordTable.onCreate(db);
    });
  });

  group('createWord - オフライン時', () {
    setUp(() {
      fakeConnectivity.setOnline(false);
    });

    test('単語を作成した場合、ローカルにpending状態で保存されsync_queueにcreate登録される', () async {
      final result = await repository.createWord(
        userId: userId,
        folderId: folderId,
        front: 'apple',
        back: 'りんご',
      );

      expect(result.isRight(), isTrue);
      final wordId = result.match((_) => fail('Right が返るはず'), (w) => w.id);

      final saved = await wordLocal.findByFolderId(folderId, userId: userId);
      expect(saved, hasLength(1));
      expect(await queueRowsFor(wordId, 'create'), hasLength(1));
      expect(fakeRemote.writtenWords, isEmpty);
    });
  });

  group('updateWord - オンライン時', () {
    test('既存の単語を更新した場合、createdAtは維持されfrontとbackが更新される', () async {
      final createdAt = DateTime(2023, 5, 1);
      await insertWord('word-1', at: createdAt);

      final result = await repository.updateWord(
        userId: userId,
        folderId: folderId,
        wordId: 'word-1',
        front: 'new-front',
        back: 'new-back',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (word) {
          expect(word.front, 'new-front');
          expect(word.back, 'new-back');
          expect(word.createdAt, createdAt);
          expect(word.updatedAt.isAfter(createdAt), isTrue);
        },
      );
      expect(fakeRemote.writtenWords, hasLength(1));
    });

    test('存在しない単語IDを指定した場合、createdAtに現在時刻が使われ更新処理は継続される', () async {
      final result = await repository.updateWord(
        userId: userId,
        folderId: folderId,
        wordId: 'not-exist',
        front: 'new-front',
        back: 'new-back',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (word) => expect(word.createdAt, word.updatedAt),
      );
    });

    test('リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る', () async {
      await insertWord('word-1');
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'network-request-failed',
      );

      final result = await repository.updateWord(
        userId: userId,
        folderId: folderId,
        wordId: 'word-1',
        front: 'new-front',
        back: 'new-back',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('updateWord - オフライン時', () {
    setUp(() {
      fakeConnectivity.setOnline(false);
    });

    test('単語を更新した場合、ローカルがpending状態で更新されsync_queueにupdate登録される', () async {
      await insertWord('word-1');

      final result = await repository.updateWord(
        userId: userId,
        folderId: folderId,
        wordId: 'word-1',
        front: 'new-front',
        back: 'new-back',
      );

      expect(result.isRight(), isTrue);
      final updated = await wordLocal.findById('word-1');
      expect(updated?.front, 'new-front');
      expect(await queueRowsFor('word-1', 'update'), hasLength(1));
      expect(fakeRemote.writtenWords, isEmpty);
    });
  });

  group('deleteWord - オンライン時', () {
    test('単語を削除した場合、ローカル・リモート双方から削除される', () async {
      await insertWord('word-1');

      final result = await repository.deleteWord(
        userId: userId,
        folderId: folderId,
        wordId: 'word-1',
      );

      expect(result.isRight(), isTrue);
      expect(await wordLocal.findById('word-1'), isNull);
      expect(fakeRemote.deletedWords, [
        (userId: userId, folderId: folderId, wordId: 'word-1'),
      ]);
    });

    test('リモート削除でFirebaseExceptionが発生した場合、Failure.networkが返る', () async {
      await insertWord('word-1');
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
      );

      final result = await repository.deleteWord(
        userId: userId,
        folderId: folderId,
        wordId: 'word-1',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('deleteWord - オフライン時', () {
    setUp(() {
      fakeConnectivity.setOnline(false);
    });

    test('単語を削除した場合、ローカルから削除されsync_queueにdelete登録される', () async {
      await insertWord('word-1');

      final result = await repository.deleteWord(
        userId: userId,
        folderId: folderId,
        wordId: 'word-1',
      );

      expect(result.isRight(), isTrue);
      expect(await wordLocal.findById('word-1'), isNull);
      expect(await queueRowsFor('word-1', 'delete'), hasLength(1));
      expect(fakeRemote.deletedWords, isEmpty);
    });
  });
}
