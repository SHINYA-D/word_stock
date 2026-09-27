// SYN-L04〜L06 の期待値: docs/detailed_design/online_offline/online_offline.md
// （接頭辞 SYN、6章「ユースケース」）。SignInWithGoogleUseCase / SyncService の実装は
// 「どう呼ぶか」を知るためだけに読んでいる。
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/application/use_cases/auth/sign_in_with_google_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_meta_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/remote/sync_remote_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/sync_record.dart';
import 'package:word_stock/infrastructure/repositories/folder_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/word_repository_impl.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

import '../../../helpers/fake_auth_use_case_repositories.dart';
import '../../../helpers/fake_infrastructure.dart';

/// SYN-L04〜L06 用の [SyncRemoteDataSource] の手書きフェイク（インメモリ）。
/// `test/application/use_cases/auth/sign_in_with_email_use_case_test.dart` の
/// `_FakeLoginSyncRemoteDataSource` と同一の最小限フェイク（fetch のみ実データを返す・
/// write は成功扱い）。
class _FakeLoginSyncRemoteDataSource implements SyncRemoteDataSource {
  final Map<SyncEntity, Map<String, SyncRecord>> _store = {
    for (final e in SyncEntity.values) e: <String, SyncRecord>{},
  };

  bool failFetch = false;
  int fetchCallCount = 0;

  void seed(SyncRecord record) {
    _store[record.entity]![record.id] = SyncRecord(
      entity: record.entity,
      id: record.id,
      parentId: record.parentId,
      fields: record.fields,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      serverUpdatedAt: record.updatedAt,
    );
  }

  @override
  Future<List<SyncRecord>> fetchChanges(
    String userId,
    SyncEntity entity, {
    DateTime? since,
  }) async {
    fetchCallCount++;
    if (failFetch) throw Exception('fetch failed: ${entity.name}');
    return _store[entity]!.values.toList();
  }

  @override
  Future<SyncRecord?> writeIfNewer(String userId, SyncRecord record) async =>
      null;
}

void main() {
  late FakeAuthRepository fakeRepository;
  late FakeSyncServiceForLogin fakeSyncService;
  late SignInWithGoogleUseCase useCase;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    fakeSyncService = FakeSyncServiceForLogin();
    useCase = SignInWithGoogleUseCase(fakeRepository, fakeSyncService);
  });

  group('SignInWithGoogleUseCase.call', () {
    test('呼び出した場合、Repository.signInWithGoogleに委譲される', () async {
      await useCase.call();

      expect(fakeRepository.signInWithGoogleCallCount, 1);
    });

    test('ログインに成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される', () async {
      const user = AppUser(id: 'u1', email: 'user@example.com');
      fakeRepository.signInWithGoogleResult = const Right(user);

      final result = await useCase.call();

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });

    test('ログインに失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない', () async {
      fakeRepository.signInWithGoogleResult = const Left(Failure.auth());

      final result = await useCase.call();

      expect(result, const Left<Failure, AppUser>(Failure.auth()));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 0);
    });

    test('ログイン成功後の同期処理で例外が発生した場合、例外は握りつぶされログイン結果はそのまま返る', () async {
      const user = AppUser(id: 'u1', email: 'user@example.com');
      fakeRepository.signInWithGoogleResult = const Right(user);
      fakeSyncService.exceptionToThrow = Exception('sync failed');

      final result = await useCase.call();

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });
  });

  // ---------------------------------------------------------------
  // SYN-L04〜L06: 本物の SyncService + SQLite（sqflite_common_ffi）で確かめる。
  // ---------------------------------------------------------------
  group('SignInWithGoogleUseCase.call（本物のSyncServiceを使う同期の確認）', () {
    const userId = 'u1';
    const user = AppUser(id: userId, email: 'user@example.com');
    final now = DateTime.utc(2024, 6, 1, 12);

    late DatabaseHelper dbHelper;
    late FolderLocalDataSource folderLocal;
    late WordLocalDataSource wordLocal;
    late FlashcardResultLocalDataSource flashcardResultLocal;
    late SyncQueueDataSource syncQueue;
    late SyncLocalDataSource syncLocal;
    late _FakeLoginSyncRemoteDataSource fakeRemote;
    late FakeConnectivityMonitor fakeConnectivity;
    late SyncService realSyncService;
    late FolderRepositoryImpl folderRepo;
    late WordRepositoryImpl wordRepo;
    late FakeAuthRepository authRepository;
    late SignInWithGoogleUseCase realUseCase;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final tempDir = await Directory.systemTemp
          .createTemp('sign_in_with_google_use_case_test_');
      await databaseFactory.setDatabasesPath(tempDir.path);
    });

    setUp(() async {
      dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      await db.delete(FolderTable.tableName);
      await db.delete(WordTable.tableName);
      await db.delete(FlashcardResultTable.tableName);
      await db.delete(SettingsTable.tableName);
      await db.delete(SyncQueueTable.tableName);
      await db.delete(SyncMetaTable.tableName);

      folderLocal = FolderLocalDataSource(dbHelper);
      wordLocal = WordLocalDataSource(dbHelper);
      flashcardResultLocal = FlashcardResultLocalDataSource(dbHelper);
      syncQueue = SyncQueueDataSource(dbHelper);
      syncLocal = SyncLocalDataSource(dbHelper);
      fakeRemote = _FakeLoginSyncRemoteDataSource();
      fakeConnectivity = FakeConnectivityMonitor(online: true);

      realSyncService = SyncService(
        localDataSource: syncLocal,
        syncQueueDataSource: syncQueue,
        remoteDataSource: fakeRemote,
        connectivityMonitor: fakeConnectivity,
        getCurrentUserId: () => userId,
        clock: () => now,
      );

      folderRepo = FolderRepositoryImpl(
        localDataSource: folderLocal,
        wordLocalDataSource: wordLocal,
        flashcardResultLocalDataSource: flashcardResultLocal,
        syncQueueDataSource: syncQueue,
        dbHelper: dbHelper,
        onLocalChanged: () {},
      );
      wordRepo = WordRepositoryImpl(
        localDataSource: wordLocal,
        folderLocalDataSource: folderLocal,
        syncQueueDataSource: syncQueue,
        dbHelper: dbHelper,
        onLocalChanged: () {},
      );

      authRepository = FakeAuthRepository();
      authRepository.signInWithGoogleResult = const Right(user);
      realUseCase = SignInWithGoogleUseCase(authRepository, realSyncService);
    });

    test(
        'ローカルが空で、リモートにフォルダFとFの中の単語Wがある状態でGoogleログインに成功した場合、'
        '戻り値がRight(AppUser)になり、戻り値を返した時点でgetFoldersにF、getWords(F)にWが含まれる [SYN-L04]',
        () async {
      fakeRemote.seed(SyncRecord(
        entity: SyncEntity.folder,
        id: 'F',
        fields: {'name': 'F', 'parentFolderId': null, 'createdAt': now},
        updatedAt: now,
      ));
      fakeRemote.seed(SyncRecord(
        entity: SyncEntity.word,
        id: 'W',
        parentId: 'F',
        fields: {'front': 'apple', 'back': 'りんご', 'createdAt': now},
        updatedAt: now,
      ));

      final result = await realUseCase.call();

      expect(result, const Right<Failure, AppUser>(user));
      final folders = await folderRepo
          .getFolders(userId: userId)
          .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));
      expect(folders.map((f) => f.id), contains('F'));
      final words = await wordRepo
          .getWords(userId: userId, folderId: 'F')
          .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));
      expect(words.map((w) => w.id), contains('W'));
    });

    test('Googleログインに成功し、その後の取得がリモートの失敗で失敗した場合、戻り値がRight(AppUser)になる [SYN-L05]',
        () async {
      fakeRemote.failFetch = true;

      final result = await realUseCase.call();

      expect(result, const Right<Failure, AppUser>(user));
    });

    test(
        'GoogleログインがAuthFailureで失敗した場合、戻り値がLeft(AuthFailure)になり、'
        'リモートへのデータの読み取りが呼ばれない [SYN-L06]', () async {
      authRepository.signInWithGoogleResult = const Left(Failure.auth());
      fakeRemote.seed(SyncRecord(
        entity: SyncEntity.folder,
        id: 'F',
        fields: const {'name': 'F', 'parentFolderId': null},
        updatedAt: now,
      ));

      final result = await realUseCase.call();

      expect(result, const Left<Failure, AppUser>(Failure.auth()));
      final folders = await folderRepo
          .getFolders(userId: userId)
          .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));
      expect(folders, isEmpty);
      expect(fakeRemote.fetchCallCount, 0);
    });
  });
}
