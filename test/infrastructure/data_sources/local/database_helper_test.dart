// 仕様書: docs/detailed_design/online_offline/online_offline.md（接頭辞 SYN、5.5 既存データの移行）
//         docs/high_level_design/online_offline.md（概要 §既存データの移行）
//
// 期待値はすべて上記仕様書から作った。DatabaseHelper の実装は「どう呼ぶか」を知るためだけに読んでいる。
//
// 移行の再現方法:
// バージョン1のテーブル定義（deletedAt 列・sync_queue.user_id 列が無い。main ブランチの
// lib/infrastructure/data_sources/local/tables/*.dart と同じ）で、本番と同じ物理パス
// （wordstock.db）に直接 SQLite ファイルを作ってデータを入れ、そのファイルを閉じてから
// `DatabaseHelper().database` を初めて呼ぶ。これにより sqflite が実際に
// `onUpgrade`（oldVersion=1, newVersion=2）を呼び、`DatabaseHelper.migrateToV2` が
// 本番と同じ経路で実行される。DatabaseHelper はシングルトンでパスが固定なため、
// この移行は setUpAll で 1 回だけ行い、以降の各 test() はその結果を読むだけにしている
// （書き込みを伴う SYN-M04 だけ、他のケースが使わない別の id で観測する）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/settings_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/remote/sync_remote_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/sync_record.dart';
import 'package:word_stock/infrastructure/repositories/flashcard_result_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/folder_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/settings_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/word_repository_impl.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

import '../../../helpers/fake_infrastructure.dart';

/// [SyncRemoteDataSource] の最小限の手書きフェイク（SYN-M04 の「最初の取得」だけに使う）。
class _FakeSyncRemoteDataSource implements SyncRemoteDataSource {
  final Map<SyncEntity, Map<String, SyncRecord>> _store = {
    for (final e in SyncEntity.values) e: <String, SyncRecord>{},
  };

  void seed(SyncRecord record) => _store[record.entity]![record.id] = record;

  @override
  Future<List<SyncRecord>> fetchChanges(
    String userId,
    SyncEntity entity, {
    DateTime? since,
  }) async {
    final all = _store[entity]!.values.toList();
    if (since == null) return all;
    return all
        .where((r) => r.serverUpdatedAt != null && r.serverUpdatedAt!.isAfter(since))
        .toList();
  }

  @override
  Future<SyncRecord?> writeIfNewer(String userId, SyncRecord record) async => null;
}

void main() {
  const userId = 'U1';
  DateTime iso(String s) => DateTime.parse(s);

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late FolderLocalDataSource folderLocal;
  late WordLocalDataSource wordLocal;
  late FlashcardResultLocalDataSource flashcardResultLocal;
  late SettingsLocalDataSource settingsLocal;
  late SyncQueueDataSource syncQueue;
  late SyncLocalDataSource syncLocal;
  late FolderRepositoryImpl folderRepo;
  late WordRepositoryImpl wordRepo;
  late FlashcardResultRepositoryImpl resultRepo;
  late SettingsRepositoryImpl settingsRepo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('database_helper_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final dbPath = join(tempDir.path, 'wordstock.db');

    // ---- 1) バージョン1のテーブル定義・データで DB ファイルを直接作る ----
    final v1Db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentFolderId TEXT,
            userId TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            syncStatus TEXT NOT NULL DEFAULT 'synced'
          )
        ''');
        await db.execute('''
          CREATE TABLE words (
            id TEXT PRIMARY KEY,
            front TEXT NOT NULL,
            back TEXT NOT NULL,
            folderId TEXT NOT NULL,
            userId TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            syncStatus TEXT NOT NULL DEFAULT 'synced'
          )
        ''');
        await db.execute('''
          CREATE TABLE flashcard_results (
            id TEXT PRIMARY KEY,
            folderId TEXT NOT NULL,
            totalCount INTEGER NOT NULL,
            correctCount INTEGER NOT NULL,
            date TEXT NOT NULL,
            userId TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            syncStatus TEXT NOT NULL DEFAULT 'synced'
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            userId TEXT PRIMARY KEY,
            colorTheme TEXT NOT NULL DEFAULT 'indigo',
            darkMode INTEGER NOT NULL DEFAULT 0,
            updatedAt TEXT NOT NULL,
            syncStatus TEXT NOT NULL DEFAULT 'synced'
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            parent_id TEXT,
            payload TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );

    // SYN-M01: synced のフォルダ F1
    await v1Db.insert('folders', {
      'id': 'F1',
      'name': 'Folder1',
      'parentFolderId': null,
      'userId': userId,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-01T00:00:00.000Z',
      'syncStatus': 'synced',
    });
    // SYN-M02: pending だがキューに項目が無いフォルダ F2
    await v1Db.insert('folders', {
      'id': 'F2',
      'name': 'Folder2',
      'parentFolderId': null,
      'userId': userId,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-02T00:00:00.000Z',
      'syncStatus': 'pending',
    });
    // SYN-M03: pending でキューに項目があるフォルダ F3 と、その中の単語 W3
    await v1Db.insert('folders', {
      'id': 'F3',
      'name': 'Folder3',
      'parentFolderId': null,
      'userId': userId,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-03T00:00:00.000Z',
      'syncStatus': 'pending',
    });
    await v1Db.insert('words', {
      'id': 'W3',
      'front': 'front3',
      'back': 'back3',
      'folderId': 'F3',
      'userId': userId,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-03T00:00:00.000Z',
      'syncStatus': 'pending',
    });
    await v1Db.insert('sync_queue', {
      'operation': 'upsert',
      'table_name': 'folders',
      'record_id': 'F3',
      'parent_id': null,
      'payload': null,
      'created_at': '2024-01-03T00:00:00.000Z',
    });
    await v1Db.insert('sync_queue', {
      'operation': 'upsert',
      'table_name': 'words',
      'record_id': 'W3',
      'parent_id': 'F3',
      'payload': null,
      'created_at': '2024-01-03T00:00:01.000Z',
    });
    // SYN-M05: synced の単語 W5（フォルダ F1 の中）
    await v1Db.insert('words', {
      'id': 'W5',
      'front': 'front5',
      'back': 'back5',
      'folderId': 'F1',
      'userId': userId,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-01T00:00:00.000Z',
      'syncStatus': 'synced',
    });
    // SYN-M06: synced の成績 R6
    await v1Db.insert('flashcard_results', {
      'id': 'R6',
      'folderId': 'F1',
      'totalCount': 5,
      'correctCount': 3,
      'date': '2024-01-01T00:00:00.000Z',
      'userId': userId,
      'updatedAt': '2024-01-01T00:00:00.000Z',
      'syncStatus': 'synced',
    });
    // SYN-M07: U1 の設定（カラーテーマ teal）
    await v1Db.insert('settings', {
      'userId': userId,
      'colorTheme': 'teal',
      'darkMode': 0,
      'updatedAt': '2024-01-01T00:00:00.000Z',
      'syncStatus': 'synced',
    });
    // 旧い取得の基準（バージョン1形式。ユーザーごとではない）
    await v1Db.insert('sync_meta', {
      'key': 'lastSyncedAt',
      'value': '2024-06-01T00:00:00.000Z',
    });

    await v1Db.close();

    // ---- 2) 本番と同じ onUpgrade 経由でバージョン2に開き直す ----
    dbHelper = DatabaseHelper();
    await dbHelper.database; // ここで oldVersion(1) < newVersion(2) により migrateToV2 が走る

    folderLocal = FolderLocalDataSource(dbHelper);
    wordLocal = WordLocalDataSource(dbHelper);
    flashcardResultLocal = FlashcardResultLocalDataSource(dbHelper);
    settingsLocal = SettingsLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    syncLocal = SyncLocalDataSource(dbHelper);

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
    resultRepo = FlashcardResultRepositoryImpl(
      localDataSource: flashcardResultLocal,
      folderLocalDataSource: folderLocal,
      syncQueueDataSource: syncQueue,
      dbHelper: dbHelper,
      onLocalChanged: () {},
    );
    settingsRepo = SettingsRepositoryImpl(
      localDataSource: settingsLocal,
      syncQueueDataSource: syncQueue,
      dbHelper: dbHelper,
      onLocalChanged: () {},
    );
  });

  Future<Map<String, Object?>> rowOf(String table, String idColumn, String id) async {
    final db = await dbHelper.database;
    final rows = await db.query(table, where: '$idColumn = ?', whereArgs: [id]);
    return rows.single;
  }

  group('DB を開く（バージョン1 → 2 の移行、5.5）', () {
    test('バージョン1のDBにsyncedのフォルダFがある状態でDBを開いた場合、getFoldersの戻り値にFが含まれローカルのFのdeletedAtがnull [SYN-M01]',
        () async {
      final folders = (await folderRepo.getFolders(userId: userId))
          .match((_) => throw Exception('unexpected Left'), (v) => v);
      expect(folders.map((f) => f.id), contains('F1'));
      expect(folders.firstWhere((f) => f.id == 'F1').name, 'Folder1');

      final row = await rowOf('folders', 'id', 'F1');
      expect(row['deletedAt'], isNull);
    });

    test('バージョン1のDBにpendingのフォルダFがありキューにFの項目がない状態でDBを開いた場合、ローカルのFのsyncStatusがsyncedになる [SYN-M02]',
        () async {
      final row = await rowOf('folders', 'id', 'F2');
      expect(row['syncStatus'], 'synced');
    });

    test(
        'バージョン1のDBにUのpendingのフォルダFと単語Wがありキューにキ、Wの順で項目がある状態でDBを開いた場合、'
        'ローカルのF・WのsyncStatusがpendingのままキューがF、Wの順で2件ありどちらのuserIdもU [SYN-M03]', () async {
      final folderRow = await rowOf('folders', 'id', 'F3');
      final wordRow = await rowOf('words', 'id', 'W3');
      expect(folderRow['syncStatus'], 'pending');
      expect(wordRow['syncStatus'], 'pending');

      final items = await syncQueue.getByUser(userId);
      final relevant =
          items.where((i) => i.recordId == 'F3' || i.recordId == 'W3').toList();
      expect(relevant, hasLength(2));
      expect(relevant[0].recordId, 'F3');
      expect(relevant[0].tableName, 'folders');
      expect(relevant[1].recordId, 'W3');
      expect(relevant[1].tableName, 'words');
    });

    test(
        'バージョン1のDBを開いた後、リモートにサーバー受付時刻が古いフォルダFがある状態で最初の取得をした場合、'
        'getFoldersの戻り値にFが含まれる [SYN-M04]', () async {
      // 移行で旧い取得の基準（バージョンごとではない lastSyncedAt）は消え、
      // ユーザーごとの新しい基準（pullCursor:<userId>）もまだ書かれていない。
      expect(await syncLocal.readMeta('lastSyncedAt'), isNull);
      expect(await syncLocal.readMetaDate('pullCursor:$userId'), isNull);

      final fakeRemote = _FakeSyncRemoteDataSource();
      fakeRemote.seed(SyncRecord(
        entity: SyncEntity.folder,
        id: 'F4',
        fields: {
          'name': 'FromRemote',
          'parentFolderId': null,
          'createdAt': iso('2020-01-01T00:00:00.000Z'),
        },
        updatedAt: iso('2020-01-01T00:00:00.000Z'),
        serverUpdatedAt: iso('2020-01-01T00:00:00.000Z'), // 前回の取得より遥かに古い受付時刻
      ));
      final syncService = SyncService(
        localDataSource: syncLocal,
        syncQueueDataSource: syncQueue,
        remoteDataSource: fakeRemote,
        connectivityMonitor: FakeConnectivityMonitor(online: true),
        getCurrentUserId: () => userId,
      );

      await syncService.syncAll();

      final folders = (await folderRepo.getFolders(userId: userId))
          .match((_) => throw Exception('unexpected Left'), (v) => v);
      expect(folders.map((f) => f.id), contains('F4'));
    });

    test('バージョン1のDBにsyncedの単語W(フォルダFの中)がある状態でDBを開いた場合、getWords(F)の戻り値にWが含まれローカルのWのdeletedAtがnull [SYN-M05]',
        () async {
      final words = (await wordRepo.getWords(userId: userId, folderId: 'F1'))
          .match((_) => throw Exception('unexpected Left'), (v) => v);
      expect(words.map((w) => w.id), contains('W5'));
      expect(words.firstWhere((w) => w.id == 'W5').front, 'front5');

      final row = await rowOf('words', 'id', 'W5');
      expect(row['deletedAt'], isNull);
    });

    test('バージョン1のDBにsyncedの成績Rがある状態でDBを開いた場合、getFlashcardResultsの戻り値にRが含まれローカルのRのdeletedAtがnull [SYN-M06]',
        () async {
      final results = (await resultRepo.getFlashcardResults(userId: userId))
          .match((_) => throw Exception('unexpected Left'), (v) => v);
      expect(results.map((r) => r.id), contains('R6'));
      expect(results.firstWhere((r) => r.id == 'R6').totalCount, 5);
      expect(results.firstWhere((r) => r.id == 'R6').correctCount, 3);

      final row = await rowOf('flashcard_results', 'id', 'R6');
      expect(row['deletedAt'], isNull);
    });

    test('バージョン1のDBにUの設定(カラーテーマteal)がある状態でDBを開いた場合、getSettingsの戻り値のカラーテーマがteal [SYN-M07]',
        () async {
      final settings = (await settingsRepo.getSettings(userId: userId))
          .match((_) => throw Exception('unexpected Left'), (v) => v);
      expect(settings.colorTheme, 'teal');
    });
  });
}
