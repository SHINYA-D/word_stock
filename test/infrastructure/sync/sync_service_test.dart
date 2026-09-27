// 仕様書: docs/detailed_design/online_offline/online_offline.md（接頭辞 SYN、5章）
//
// 期待値はすべて上記仕様書から作った。SyncService の実装は「どう呼ぶか」を知るためだけに読んでいる。
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/settings_local_data_source.dart';
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
import 'package:word_stock/infrastructure/repositories/flashcard_result_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/folder_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/settings_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/word_repository_impl.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

import '../../helpers/fake_infrastructure.dart';

/// [SyncRemoteDataSource] の手書きフェイク（インメモリ）。
///
/// - [seed] でリモートに直接データを投入できる（サーバー受付時刻を明示できる）
/// - [get] でリモートの現在のデータを読める
/// - [calls] に `fetch:<entity>` / `write:<entity>:<id>` の順番を記録する
/// - [fetchGate] / [writeGate] を設定すると、complete するまでその呼び出しが完了しない
/// - [failFetchEntityOnce] / [failWriteRecordIdOnce] で、次の 1 回だけ例外を投げさせられる
class FakeSyncRemoteDataSource implements SyncRemoteDataSource {
  final Map<SyncEntity, Map<String, Map<String, SyncRecord>>> _store = {
    for (final e in SyncEntity.values) e: <String, Map<String, SyncRecord>>{},
  };

  final List<String> calls = [];

  SyncEntity? failFetchEntityOnce;
  String? failWriteRecordIdOnce;

  Completer<void>? fetchGate;
  Completer<void>? writeGate;

  int _serverSeq = 0;
  DateTime _nextServerTime() =>
      DateTime.utc(2024, 1, 1).add(Duration(seconds: _serverSeq++));

  void seed(String userId, SyncRecord record, {DateTime? serverUpdatedAt}) {
    _store[record.entity]!.putIfAbsent(userId, () => {})[record.id] =
        SyncRecord(
      entity: record.entity,
      id: record.id,
      parentId: record.parentId,
      fields: record.fields,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      serverUpdatedAt: serverUpdatedAt ?? _nextServerTime(),
    );
  }

  SyncRecord? get(SyncEntity entity, String userId, String id) =>
      _store[entity]![userId]?[id];

  @override
  Future<List<SyncRecord>> fetchChanges(
    String userId,
    SyncEntity entity, {
    DateTime? since,
  }) async {
    calls.add('fetch:${entity.name}');
    if (fetchGate != null) await fetchGate!.future;
    if (failFetchEntityOnce == entity) {
      failFetchEntityOnce = null;
      throw Exception('fetch failed: ${entity.name}');
    }
    final byId = _store[entity]![userId] ?? {};
    return byId.values
        .where((r) =>
            since == null ||
            (r.serverUpdatedAt != null && r.serverUpdatedAt!.isAfter(since)))
        .toList();
  }

  @override
  Future<SyncRecord?> writeIfNewer(String userId, SyncRecord record) async {
    calls.add('write:${record.entity.name}:${record.id}');
    if (writeGate != null) await writeGate!.future;
    if (failWriteRecordIdOnce == record.id) {
      failWriteRecordIdOnce = null;
      throw Exception('write failed: ${record.id}');
    }
    final byId = _store[record.entity]!.putIfAbsent(userId, () => {});
    final existing = byId[record.id];
    if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
      byId[record.id] = SyncRecord(
        entity: record.entity,
        id: record.id,
        parentId: record.parentId,
        fields: record.fields,
        updatedAt: record.updatedAt,
        deletedAt: record.deletedAt,
        serverUpdatedAt: _nextServerTime(),
      );
      return null;
    }
    return existing;
  }
}

SyncRecord folderRecord({
  required String id,
  required String name,
  String? parentFolderId,
  required DateTime updatedAt,
  DateTime? deletedAt,
}) =>
    SyncRecord(
      entity: SyncEntity.folder,
      id: id,
      fields: {
        'name': name,
        'parentFolderId': parentFolderId,
        'createdAt': updatedAt,
      },
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );

SyncRecord wordRecord({
  required String id,
  required String folderId,
  required String front,
  required String back,
  required DateTime updatedAt,
  DateTime? deletedAt,
}) =>
    SyncRecord(
      entity: SyncEntity.word,
      id: id,
      parentId: folderId,
      fields: {'front': front, 'back': back, 'createdAt': updatedAt},
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );

SyncRecord resultRecord({
  required String id,
  required String folderId,
  required int totalCount,
  required int correctCount,
  required DateTime updatedAt,
  DateTime? deletedAt,
}) =>
    SyncRecord(
      entity: SyncEntity.flashcardResult,
      id: id,
      fields: {
        'folderId': folderId,
        'totalCount': totalCount,
        'correctCount': correctCount,
        'date': updatedAt,
      },
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );

SyncRecord settingsRecord({
  required String forUserId,
  required String colorTheme,
  bool darkMode = false,
  required DateTime updatedAt,
}) =>
    SyncRecord(
      entity: SyncEntity.settings,
      id: forUserId,
      fields: {'colorTheme': colorTheme, 'darkMode': darkMode},
      updatedAt: updatedAt,
    );

void main() {
  const userId = 'U';
  const otherUserId = 'V';

  DateTime t(int minutes) =>
      DateTime.utc(2024, 6, 1, 12).add(Duration(minutes: minutes));

  late DatabaseHelper dbHelper;
  late FolderLocalDataSource folderLocal;
  late WordLocalDataSource wordLocal;
  late FlashcardResultLocalDataSource flashcardResultLocal;
  late SettingsLocalDataSource settingsLocal;
  late SyncQueueDataSource syncQueue;
  late SyncLocalDataSource syncLocal;
  late FakeSyncRemoteDataSource fakeRemote;
  late FakeConnectivityMonitor fakeConnectivity;
  late SyncService syncService;
  late FolderRepositoryImpl folderRepo;
  late WordRepositoryImpl wordRepo;
  late FlashcardResultRepositoryImpl resultRepo;
  late SettingsRepositoryImpl settingsRepo;
  late String? currentUserId;
  late DateTime fakeNow;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir =
        await Directory.systemTemp.createTemp('sync_service_test_');
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
    settingsLocal = SettingsLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    syncLocal = SyncLocalDataSource(dbHelper);
    fakeRemote = FakeSyncRemoteDataSource();
    fakeConnectivity = FakeConnectivityMonitor(online: true);
    currentUserId = userId;
    fakeNow = t(0);

    syncService = SyncService(
      localDataSource: syncLocal,
      syncQueueDataSource: syncQueue,
      remoteDataSource: fakeRemote,
      connectivityMonitor: fakeConnectivity,
      getCurrentUserId: () => currentUserId,
      clock: () => fakeNow,
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

  // ---- ローカルの下ごしらえ用ヘルパー ----

  Future<void> setFolder(
    String id, {
    required String name,
    String? parentFolderId,
    required DateTime updatedAt,
    bool pending = false,
    String forUserId = userId,
  }) async {
    await folderLocal.insert(
      Folder(
        id: id,
        name: name,
        parentFolderId: parentFolderId,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      ),
      userId: forUserId,
      syncStatus: pending ? 'pending' : 'synced',
    );
    if (pending) {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: id,
        userId: forUserId,
        parentId: parentFolderId,
      );
    }
  }

  Future<void> deleteFolderLocal(
    String id,
    DateTime at, {
    String forUserId = userId,
    String? parentId,
  }) async {
    final db = await dbHelper.database;
    await folderLocal.markDeleted(db, id, at);
    await syncQueue.enqueue(
      operation: 'delete',
      tableName: FolderTable.tableName,
      recordId: id,
      userId: forUserId,
      parentId: parentId,
    );
  }

  Future<void> setWord(
    String id, {
    required String folderId,
    required String front,
    String back = 'back',
    required DateTime updatedAt,
    bool pending = false,
    String forUserId = userId,
  }) async {
    await wordLocal.insert(
      Word(
        id: id,
        front: front,
        back: back,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      ),
      userId: forUserId,
      folderId: folderId,
      syncStatus: pending ? 'pending' : 'synced',
    );
    if (pending) {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: WordTable.tableName,
        recordId: id,
        userId: forUserId,
        parentId: folderId,
      );
    }
  }

  Future<void> setResult(
    String id, {
    required String folderId,
    int totalCount = 10,
    int correctCount = 7,
    required DateTime updatedAt,
    bool pending = false,
    String forUserId = userId,
  }) async {
    await flashcardResultLocal.insert(
      FlashcardResult(
        id: id,
        folderId: folderId,
        totalCount: totalCount,
        correctCount: correctCount,
        date: updatedAt,
        updatedAt: updatedAt,
      ),
      userId: forUserId,
      syncStatus: pending ? 'pending' : 'synced',
    );
    if (pending) {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FlashcardResultTable.tableName,
        recordId: id,
        userId: forUserId,
      );
    }
  }

  Future<void> setSettings({
    required String colorTheme,
    bool darkMode = false,
    required DateTime updatedAt,
    bool pending = false,
    String forUserId = userId,
  }) async {
    await settingsLocal.upsert(
      UserSettings(
        colorTheme: colorTheme,
        darkMode: darkMode,
        updatedAt: updatedAt,
      ),
      userId: forUserId,
      syncStatus: pending ? 'pending' : 'synced',
    );
    if (pending) {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: SettingsTable.tableName,
        recordId: forUserId,
        userId: forUserId,
      );
    }
  }

  Future<bool> rowExists(String table, String idColumn, String id) async {
    final db = await dbHelper.database;
    final rows =
        await db.query(table, where: '$idColumn = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  Future<int> queueCountFor(String forUserId, String table, String id) async {
    final items = await syncQueue.getByUser(forUserId);
    return items.where((i) => i.tableName == table && i.recordId == id).length;
  }

  Future<List<Folder>> getFolders({String? parentFolderId}) async => folderRepo
      .getFolders(userId: userId, parentFolderId: parentFolderId)
      .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));

  Future<List<Word>> getWords(String folderId) async => wordRepo
      .getWords(userId: userId, folderId: folderId)
      .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));

  Future<List<FlashcardResult>> getResults({String? folderId}) async =>
      resultRepo
          .getFlashcardResults(userId: userId, folderId: folderId)
          .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));

  Future<UserSettings> getSettingsOf(String forUserId) async => settingsRepo
      .getSettings(userId: forUserId)
      .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));

  group('取得（5.1）', () {
    test('ローカルにフォルダがなく、リモートに未削除のフォルダFがある状態で取得した場合、getFoldersにFが含まれsyncStatusがsyncedになる [SYN-P01]',
        () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'A', updatedAt: t(1)));

      await syncService.syncAll();

      final folders = await getFolders();
      expect(folders.map((f) => f.id), contains('F'));
      expect(folders.firstWhere((f) => f.id == 'F').name, 'A');
      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId);
      expect(row!.pending, isFalse);
    });

    test('ローカルにフォルダがなく、リモートに削除済みのフォルダFがある状態で取得した場合、getFoldersにFが含まれずローカルにFの行がない [SYN-P02]',
        () async {
      fakeRemote.seed(
        userId,
        folderRecord(id: 'F', name: 'A', updatedAt: t(1), deletedAt: t(1)),
      );

      await syncService.syncAll();

      expect((await getFolders()).map((f) => f.id), isNot(contains('F')));
      expect(await rowExists(FolderTable.tableName, 'id', 'F'), isFalse);
    });

    test('ローカルにsyncedのフォルダF(名前A)があり、リモートのFが名前Bでローカルより新しい状態で取得した場合、ローカルのFの名前がBになりsyncedのまま [SYN-P03]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(1));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(2)));

      await syncService.syncAll();

      final folder = (await getFolders()).firstWhere((f) => f.id == 'F');
      expect(folder.name, 'B');
      expect(folder.updatedAt.isAtSameMomentAs(t(2)), isTrue);
      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId);
      expect(row!.pending, isFalse);
    });

    test('ローカルにsyncedのフォルダF(名前A)があり、リモートのFが名前Bでローカルとupdatedatが等しい状態で取得した場合、ローカルのFの名前はAのまま [SYN-P04]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(2));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(2)));

      await syncService.syncAll();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'A');
    });

    test('ローカルにsyncedのフォルダF(名前A)があり、リモートのFが名前Bでローカルより古い状態で取得した場合、ローカルのFの名前はAのまま [SYN-P05]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(2));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(1)));

      await syncService.syncAll();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'A');
    });

    test('ローカルにpendingのフォルダF(名前A、キュー1件)があり、リモートのFが名前Bでローカルより新しい状態で取得した場合、ローカルのFの名前がBでsyncedになりキューが0件になる [SYN-P06]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(2), pending: true);
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(3)));

      await syncService.syncAll();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'B');
      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId);
      expect(row!.pending, isFalse);
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('ローカルにpendingのフォルダF(名前A、キュー1件)があり、リモートのFが名前Bでローカルとupdatedatが等しい状態で取得した場合、ローカルのFの名前がBでsyncedになりキューが0件になる [SYN-P07]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(2), pending: true);
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(2)));

      await syncService.syncAll();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'B');
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('ローカルにpendingのフォルダF(名前A、キュー1件)があり、リモートのFが名前Bでローカルより古い状態で取得した場合、'
        '取得の直後はローカルのFの名前がAのままでsyncStatusがpending、キューにFの項目が1件のまま、リモートのFの名前はBのまま [SYN-P08]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(3), pending: true);
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(2)));
      // 取得の直後に走る送信がこの検証より先に完了しないよう、リモートの書き込みを止めておく。
      fakeRemote.writeGate = Completer<void>();

      final future = syncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 100));

      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId);
      expect(row!.pending, isTrue);
      expect(row.record.fields['name'], 'A');
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 1);
      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.fields['name'], 'B');

      fakeRemote.writeGate!.complete();
      await future;
    });

    test('ローカルにsyncedの未削除のフォルダFがあり、リモートのFが削除済みでローカルより新しい状態で取得した場合、getFoldersにFが含まれない [SYN-P09]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(1));
      fakeRemote.seed(
        userId,
        folderRecord(id: 'F', name: 'A', updatedAt: t(2), deletedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getFolders()).map((f) => f.id), isNot(contains('F')));
    });

    test('この端末でフォルダFを削除してpending(キュー1件)の状態で、リモートのFが未削除・名前Bでローカルの削除より新しい状態で取得した場合、'
        'getFoldersにF(名前B)が含まれキューが0件になる [SYN-P10]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(1));
      await deleteFolderLocal('F', t(2));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(3)));

      await syncService.syncAll();

      expect((await getFolders()).map((f) => f.id), contains('F'));
      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'B');
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test(
        'ローカルにsyncedのフォルダF、その子フォルダG、Gの中の単語W、Fの成績Rがあり、リモートのFが削除済みでローカルより新しい状態で取得した場合、'
        'getFoldersにF・Gが含まれずgetWords(G)にWが含まれずgetFlashcardResultsにRが含まれず、'
        'キューにG・W・Rの項目が1件ずつ増える [SYN-P11]', () async {
      await setFolder('F', name: 'F', updatedAt: t(1));
      await setFolder('G', name: 'G', parentFolderId: 'F', updatedAt: t(1));
      await setWord('W', folderId: 'G', front: 'w', updatedAt: t(1));
      await setResult('R', folderId: 'F', updatedAt: t(1));
      fakeRemote.seed(
        userId,
        folderRecord(id: 'F', name: 'F', updatedAt: t(2), deletedAt: t(2)),
      );
      fakeRemote.writeGate = Completer<void>();

      final future = syncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 100));

      expect((await getFolders()).map((f) => f.id), isNot(contains('F')));
      expect(
        (await getFolders(parentFolderId: 'F')).map((f) => f.id),
        isNot(contains('G')),
      );
      expect((await getWords('G')).map((w) => w.id), isNot(contains('W')));
      expect((await getResults()).map((r) => r.id), isNot(contains('R')));
      expect(await queueCountFor(userId, FolderTable.tableName, 'G'), 1);
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 1);
      expect(await queueCountFor(userId, FlashcardResultTable.tableName, 'R'), 1);

      fakeRemote.writeGate!.complete();
      await future;
    });

    test(
        'ローカルにsyncedのフォルダFと、Fの中のpendingの単語W(リモートのFの削除より新しい編集)があり、'
        'リモートのFが削除済みでローカルのFより新しい状態で取得した場合、getWords(F)にWが含まれない [SYN-P12]', () async {
      await setFolder('F', name: 'F', updatedAt: t(1));
      await setWord('W', folderId: 'F', front: 'w', updatedAt: t(5), pending: true);
      fakeRemote.seed(
        userId,
        folderRecord(id: 'F', name: 'F', updatedAt: t(2), deletedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).map((w) => w.id), isNot(contains('W')));
    });

    test('ローカルに単語がなく、リモートのフォルダFの中に未削除の単語W(表apple・裏りんご)がある状態で取得した場合、'
        'getWords(F)にW(表apple・裏りんご)が含まれsyncedになる [SYN-P13]', () async {
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'apple', back: 'りんご', updatedAt: t(1)),
      );

      await syncService.syncAll();

      final words = await getWords('F');
      expect(words.map((w) => w.id), contains('W'));
      final w = words.firstWhere((w) => w.id == 'W');
      expect(w.front, 'apple');
      expect(w.back, 'りんご');
      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.word, 'W', userId: userId);
      expect(row!.pending, isFalse);
    });

    test('ローカルに単語がなく、リモートのフォルダFの中に削除済みの単語Wがある状態で取得した場合、getWords(F)にWが含まれずローカルにWの行がない [SYN-P14]',
        () async {
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'a', back: 'b', updatedAt: t(1), deletedAt: t(1)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).map((w) => w.id), isNot(contains('W')));
      expect(await rowExists(WordTable.tableName, 'id', 'W'), isFalse);
    });

    test('ローカルにsyncedの単語W(表A)があり、リモートのWが表Bでローカルより新しい状態で取得した場合、ローカルのWの表がBでsyncedのまま [SYN-P15]',
        () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(1));
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'B', back: 'back', updatedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'B');
    });

    test('ローカルにsyncedの単語W(表A)があり、リモートのWが表Bでローカルより古い状態で取得した場合、ローカルのWの表はAのまま [SYN-P16]',
        () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(2));
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'B', back: 'back', updatedAt: t(1)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'A');
    });

    test('ローカルにpendingの単語W(表A、キュー1件)があり、リモートのWが表Bでローカルより新しい状態で取得した場合、'
        'ローカルのWの表がBでsyncedになりキューが0件になる [SYN-P17]', () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(2), pending: true);
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'B', back: 'back', updatedAt: t(3)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'B');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 0);
    });

    test('ローカルにpendingの単語W(表A、キュー1件)があり、リモートのWが表Bでローカルより古い状態で取得した場合、'
        '取得の直後はローカルのWの表がAのままでpending、キューにWの項目が1件のまま [SYN-P18]', () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(3), pending: true);
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'B', back: 'back', updatedAt: t(2)),
      );
      fakeRemote.writeGate = Completer<void>();

      final future = syncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 100));

      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.word, 'W', userId: userId);
      expect(row!.pending, isTrue);
      expect(row.record.fields['front'], 'A');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 1);

      fakeRemote.writeGate!.complete();
      await future;
    });

    test('ローカルにsyncedの未削除の単語Wがあり、リモートのWが削除済みでローカルより新しい状態で取得した場合、getWordsにWが含まれない [SYN-P19]',
        () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(1));
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'A', back: 'back', updatedAt: t(2), deletedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).map((w) => w.id), isNot(contains('W')));
    });

    test('ローカルにpendingの単語W(表A、キュー1件)があり、リモートのWが表Bでローカルとupdatedatが等しい状態で取得した場合、'
        'ローカルのWの表がBでsyncedになりキューが0件になる [SYN-P20]', () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(2), pending: true);
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'B', back: 'back', updatedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'B');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 0);
    });

    test('リモートに表が文字列2024-01-01の単語Wがある状態で取得した場合、getWordsの戻り値のWの表が文字列2024-01-01のまま [SYN-P21]',
        () async {
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: '2024-01-01', back: 'back', updatedAt: t(1)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, '2024-01-01');
    });

    test('ローカルに成績がなく、リモートに未削除の成績R(問題数10・正解数7)がある状態で取得した場合、getFlashcardResultsにR(問題数10・正解数7)が含まれる [SYN-P22]',
        () async {
      fakeRemote.seed(
        userId,
        resultRecord(id: 'R', folderId: 'F', totalCount: 10, correctCount: 7, updatedAt: t(1)),
      );

      await syncService.syncAll();

      final r = (await getResults()).firstWhere((r) => r.id == 'R');
      expect(r.totalCount, 10);
      expect(r.correctCount, 7);
    });

    test('ローカルに成績がなく、リモートに削除済みの成績Rがある状態で取得した場合、getFlashcardResultsにRが含まれない [SYN-P23]',
        () async {
      fakeRemote.seed(
        userId,
        resultRecord(id: 'R', folderId: 'F', totalCount: 10, correctCount: 7, updatedAt: t(1), deletedAt: t(1)),
      );

      await syncService.syncAll();

      expect((await getResults()).map((r) => r.id), isNot(contains('R')));
    });

    test('ローカルにsyncedの未削除の成績Rがあり、リモートのRが削除済みでローカルより新しい状態で取得した場合、getFlashcardResultsにRが含まれない [SYN-P24]',
        () async {
      await setResult('R', folderId: 'F', updatedAt: t(1));
      fakeRemote.seed(
        userId,
        resultRecord(id: 'R', folderId: 'F', totalCount: 10, correctCount: 7, updatedAt: t(2), deletedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getResults()).map((r) => r.id), isNot(contains('R')));
    });

    test('ローカルに設定がなく、リモートの設定がカラーテーマteal・ダークモードtrueの状態で取得した場合、getSettingsの戻り値がカラーテーマteal・ダークモードtrue [SYN-P25]',
        () async {
      fakeRemote.seed(
        userId,
        settingsRecord(forUserId: userId, colorTheme: 'teal', darkMode: true, updatedAt: t(1)),
      );

      await syncService.syncAll();

      final s = await getSettingsOf(userId);
      expect(s.colorTheme, 'teal');
      expect(s.darkMode, isTrue);
    });

    test('ローカルにsyncedの設定(カラーテーマindigo)があり、リモートの設定がカラーテーマtealでローカルより新しい状態で取得した場合、getSettingsの戻り値のカラーテーマがteal [SYN-P26]',
        () async {
      await setSettings(colorTheme: 'indigo', updatedAt: t(1));
      fakeRemote.seed(
        userId,
        settingsRecord(forUserId: userId, colorTheme: 'teal', updatedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getSettingsOf(userId)).colorTheme, 'teal');
    });

    test('ローカルにsyncedの設定(カラーテーマindigo)があり、リモートの設定がカラーテーマtealでローカルより古い状態で取得した場合、getSettingsの戻り値のカラーテーマがindigoのまま [SYN-P27]',
        () async {
      await setSettings(colorTheme: 'indigo', updatedAt: t(2));
      fakeRemote.seed(
        userId,
        settingsRecord(forUserId: userId, colorTheme: 'teal', updatedAt: t(1)),
      );

      await syncService.syncAll();

      expect((await getSettingsOf(userId)).colorTheme, 'indigo');
    });

    test('ローカルにpendingの設定(カラーテーマindigo、キュー1件)があり、リモートの設定がカラーテーマtealでローカルより新しい状態で取得した場合、'
        'getSettingsの戻り値のカラーテーマがtealになりキューが0件になる [SYN-P28]', () async {
      await setSettings(colorTheme: 'indigo', updatedAt: t(2), pending: true);
      fakeRemote.seed(
        userId,
        settingsRecord(forUserId: userId, colorTheme: 'teal', updatedAt: t(3)),
      );

      await syncService.syncAll();

      expect((await getSettingsOf(userId)).colorTheme, 'teal');
      expect(await queueCountFor(userId, SettingsTable.tableName, userId), 0);
    });

    test('ローカルにpendingの設定(カラーテーマindigo、キュー1件)があり、リモートの設定がカラーテーマtealでローカルより古い状態で取得した場合、'
        '取得の直後はgetSettingsの戻り値のカラーテーマがindigoのままでキューに設定の項目が1件のまま [SYN-P29]', () async {
      await setSettings(colorTheme: 'indigo', updatedAt: t(3), pending: true);
      fakeRemote.seed(
        userId,
        settingsRecord(forUserId: userId, colorTheme: 'teal', updatedAt: t(2)),
      );
      fakeRemote.writeGate = Completer<void>();

      final future = syncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 100));

      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.settings, userId, userId: userId);
      expect(row!.pending, isTrue);
      expect(row.record.fields['colorTheme'], 'indigo');
      expect(await queueCountFor(userId, SettingsTable.tableName, userId), 1);

      fakeRemote.writeGate!.complete();
      await future;
    });

    test('Uの取得の基準がある状態で、別の端末がオフラインで編集したフォルダF(updatedAtは前回の取得より前、サーバー受付時刻は前回の取得より後)がリモートにあり、'
        '取得した場合、ローカルのFがリモートのFの内容になる [SYN-P30]', () async {
      await setFolder('F', name: 'old', updatedAt: t(1));
      await syncLocal.writeMetaDate('pullCursor:$userId', t(10));
      fakeRemote.seed(
        userId,
        folderRecord(id: 'F', name: 'edited-offline', updatedAt: t(5)),
        serverUpdatedAt: t(12),
      );

      await syncService.syncAll();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'edited-offline');
    });

    test('Uの取得の基準がない状態で、リモートにサーバー受付時刻が異なるフォルダF1・F2・F3がある状態で取得した場合、getFoldersの戻り値にF1・F2・F3がすべて含まれる [SYN-P31]',
        () async {
      fakeRemote.seed(userId, folderRecord(id: 'F1', name: 'F1', updatedAt: t(1)));
      fakeRemote.seed(userId, folderRecord(id: 'F2', name: 'F2', updatedAt: t(2)));
      fakeRemote.seed(userId, folderRecord(id: 'F3', name: 'F3', updatedAt: t(3)));

      await syncService.syncAll();

      expect((await getFolders()).map((f) => f.id).toSet(), {'F1', 'F2', 'F3'});
    });

    test('フォルダの取得の後、単語の取得がリモートの失敗で中断し、その後もう一度取得した場合(2回目はすべて成功)、'
        '1回目の後の取得の基準が1回目の前と同じで、1回目で取得できなかった単語の変更が2回目の後にローカルに反映されている [SYN-P32]', () async {
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'apple', back: 'back', updatedAt: t(1)),
      );
      fakeRemote.failFetchEntityOnce = SyncEntity.word;

      await syncService.syncAll();

      expect(await syncLocal.readMeta('pullCursor:$userId'), isNull);
      expect((await getWords('F')).map((w) => w.id), isNot(contains('W')));

      await syncService.syncAll();

      expect((await getWords('F')).map((w) => w.id), contains('W'));
    });

    test('ユーザーVの取得の基準があり、Uの取得の基準がない状態で、Uとして取得した場合、リモートのUのフォルダがすべてgetFoldersの戻り値に含まれる [SYN-P33]',
        () async {
      await syncLocal.writeMetaDate('pullCursor:$otherUserId', t(5));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'F', updatedAt: t(1)));

      await syncService.syncAll();

      expect((await getFolders()).map((f) => f.id), contains('F'));
    });

    test('リモートにフォルダFがある状態で、同じ範囲を2回続けて取得した場合、getFoldersの戻り値にFが1件だけ含まれ2回目の後のローカルのFは1回目の後と同じ内容 [SYN-P34]',
        () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'F', updatedAt: t(1)));

      await syncService.syncAll();
      final after1 = (await getFolders()).firstWhere((f) => f.id == 'F');

      await syncService.syncAll();
      final after2s = (await getFolders()).where((f) => f.id == 'F').toList();

      expect(after2s, hasLength(1));
      expect(after2s.single.name, after1.name);
      expect(after2s.single.updatedAt, after1.updatedAt);
    });

    test('ローカルにsyncedの単語W(表A)があり、リモートのWが表Bでローカルとupdatedatが等しい状態で取得した場合、ローカルのWの表はAのまま [SYN-P35]',
        () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(2));
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'B', back: 'back', updatedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'A');
    });

    test('ローカルにsyncedの設定(カラーテーマindigo)があり、リモートの設定がカラーテーマtealでローカルとupdatedatが等しい状態で取得した場合、getSettingsの戻り値のカラーテーマがindigoのまま [SYN-P36]',
        () async {
      await setSettings(colorTheme: 'indigo', updatedAt: t(2));
      fakeRemote.seed(
        userId,
        settingsRecord(forUserId: userId, colorTheme: 'teal', updatedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getSettingsOf(userId)).colorTheme, 'indigo');
    });

    test('ローカルにpendingの設定(カラーテーマindigo、キュー1件)があり、リモートの設定がカラーテーマtealでローカルとupdatedatが等しい状態で取得した場合、'
        'getSettingsの戻り値のカラーテーマがtealになりキューが0件になる [SYN-P37]', () async {
      await setSettings(colorTheme: 'indigo', updatedAt: t(2), pending: true);
      fakeRemote.seed(
        userId,
        settingsRecord(forUserId: userId, colorTheme: 'teal', updatedAt: t(2)),
      );

      await syncService.syncAll();

      expect((await getSettingsOf(userId)).colorTheme, 'teal');
      expect(await queueCountFor(userId, SettingsTable.tableName, userId), 0);
    });

    // 仕様書に個別の ID は割り当てられていないが、概要 §フォルダの削除を取得したとき
    // （SYN-P11・P12 と同じ根拠）で説明されている「配下に後から届いたデータも削除済みに
    // 合わせる」を、同じ取得の中でフォルダより後に処理される単語の側から検証する
    // （未カバー行 L209-212 の解消）。
    test('リモートから届いた単語Wの親フォルダFが同じ取得の中で先に削除済みになっていた場合、Wも削除済みとしてキューに積まれる',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1));
      fakeRemote.seed(
        userId,
        folderRecord(id: 'F', name: 'F', updatedAt: t(2), deletedAt: t(2)),
      );
      fakeRemote.seed(
        userId,
        wordRecord(id: 'W', folderId: 'F', front: 'w', back: 'b', updatedAt: t(2)),
      );
      // 取得で積まれたキュー項目が、同じ syncAll 内の直後の送信ですぐ消費・巻き戻されないよう、
      // 送信の書き込みを止めて「取得の直後」の状態を観測する。
      fakeRemote.writeGate = Completer<void>();

      final future = syncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 100));

      expect((await getWords('F')).map((w) => w.id), isNot(contains('W')));
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 1);

      fakeRemote.writeGate!.complete();
      await future;
    });
  });

  group('送信（5.2）', () {
    test('ローカルに登録したフォルダF(名前A、キュー1件)があり、リモートにFがない状態で送信した場合、'
        'リモートにF(名前A・deletedAtがnull)ができキューが0件・ローカルのFがsyncedになる [SYN-S01]', () async {
      await setFolder('F', name: 'A', updatedAt: t(1), pending: true);

      await syncService.pushPending();

      final remote = fakeRemote.get(SyncEntity.folder, userId, 'F');
      expect(remote, isNotNull);
      expect(remote!.fields['name'], 'A');
      expect(remote.deletedAt, isNull);
      expect(remote.updatedAt, t(1));
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId);
      expect(row!.pending, isFalse);
    });

    test('ローカルで編集したフォルダF(名前B、キュー1件)があり、リモートのF(名前A)がローカルより古い状態で送信した場合、'
        'リモートのFの名前がBになりキューが0件・ローカルのFがsyncedになる [SYN-S02]', () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'A', updatedAt: t(1)));
      await setFolder('F', name: 'B', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.fields['name'], 'B');
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('ローカルで編集したフォルダF(名前B、キュー1件)があり、リモートのF(名前C)がローカルより新しい状態で送信した場合、'
        'リモートのFの名前はCのまま・ローカルのFの名前がCでsyncedになりキューが0件になる [SYN-S03]', () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'C', updatedAt: t(3)));
      await setFolder('F', name: 'B', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.fields['name'], 'C');
      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'C');
      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId);
      expect(row!.pending, isFalse);
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('ローカルで編集したフォルダF(名前B、キュー1件)があり、リモートのF(名前C)がローカルとupdatedatが等しい状態で送信した場合、'
        'リモートのFの名前はCのまま・ローカルのFの名前がCでsyncedになりキューが0件になる [SYN-S04]', () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'C', updatedAt: t(2)));
      await setFolder('F', name: 'B', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.fields['name'], 'C');
      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'C');
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('ローカルで削除したフォルダF(キュー1件)があり、リモートのFがローカルより古い状態で送信した場合、'
        'リモートにFのドキュメントが残りdeletedAtがローカルのFのdeletedAtと同じ時刻になりキューが0件になる [SYN-S05]', () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'A', updatedAt: t(1)));
      await setFolder('F', name: 'A', updatedAt: t(1));
      await deleteFolderLocal('F', t(2));

      await syncService.pushPending();

      final remote = fakeRemote.get(SyncEntity.folder, userId, 'F');
      expect(remote, isNotNull);
      expect(remote!.deletedAt, t(2));
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('ローカルでフォルダFの中に登録した単語W(表apple・裏りんご、キュー1件)があり、リモートにWがない状態で送信した場合、'
        'リモートのFの下にW(表apple・裏りんご)ができキューが0件・ローカルのWがsyncedになる [SYN-S06]', () async {
      await setWord('W', folderId: 'F', front: 'apple', back: 'りんご', updatedAt: t(1), pending: true);

      await syncService.pushPending();

      final remote = fakeRemote.get(SyncEntity.word, userId, 'W');
      expect(remote!.parentId, 'F');
      expect(remote.fields['front'], 'apple');
      expect(remote.fields['back'], 'りんご');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 0);
      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.word, 'W', userId: userId);
      expect(row!.pending, isFalse);
    });

    test('ローカルに表が2024-01-01の単語W(キュー1件)がある状態で送信した場合、リモートのWの表が文字列2024-01-01のまま [SYN-S07]',
        () async {
      await setWord('W', folderId: 'F', front: '2024-01-01', updatedAt: t(1), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.word, userId, 'W')!.fields['front'], '2024-01-01');
    });

    test('ローカルで編集した単語W(表B、キュー1件)があり、リモートのW(表C)がローカルより新しい状態で送信した場合、'
        'リモートのWの表はCのまま・ローカルのWの表がCでsyncedになりキューが0件になる [SYN-S08]', () async {
      fakeRemote.seed(userId, wordRecord(id: 'W', folderId: 'F', front: 'C', back: 'back', updatedAt: t(3)));
      await setWord('W', folderId: 'F', front: 'B', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.word, userId, 'W')!.fields['front'], 'C');
      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'C');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 0);
    });

    test('ローカルで削除した単語W(キュー1件)があり、リモートのWがローカルより古い状態で送信した場合、'
        'リモートにWのドキュメントが残りdeletedAtがローカルのWのdeletedAtと同じ時刻になりキューが0件になる [SYN-S09]', () async {
      fakeRemote.seed(userId, wordRecord(id: 'W', folderId: 'F', front: 'A', back: 'back', updatedAt: t(1)));
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(1));
      final db0 = await dbHelper.database;
      await wordLocal.markDeleted(db0, 'W', t(2));
      await syncQueue.enqueue(
        operation: 'delete',
        tableName: WordTable.tableName,
        recordId: 'W',
        userId: userId,
        parentId: 'F',
      );

      await syncService.pushPending();

      final remote = fakeRemote.get(SyncEntity.word, userId, 'W');
      expect(remote!.deletedAt, t(2));
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 0);
    });

    test('ローカルに登録した成績R(フォルダF・問題数10・正解数7、キュー1件)があり、リモートにRがない状態で送信した場合、'
        'リモートにR(フォルダF・問題数10・正解数7)ができdate・updatedAtがローカルと同じ時刻になりキューが0件になる [SYN-S10]', () async {
      await setResult('R', folderId: 'F', totalCount: 10, correctCount: 7, updatedAt: t(1), pending: true);

      await syncService.pushPending();

      final remote = fakeRemote.get(SyncEntity.flashcardResult, userId, 'R');
      expect(remote!.fields['folderId'], 'F');
      expect(remote.fields['totalCount'], 10);
      expect(remote.fields['correctCount'], 7);
      expect(remote.fields['date'], t(1));
      expect(remote.updatedAt, t(1));
      expect(await queueCountFor(userId, FlashcardResultTable.tableName, 'R'), 0);
    });

    test('ローカルで変更した設定(カラーテーマteal・ダークモードtrue、キュー1件)があり、リモートの設定がローカルより古い状態で送信した場合、'
        'リモートの設定がカラーテーマteal・ダークモードtrueになりキューが0件になる [SYN-S11]', () async {
      fakeRemote.seed(userId, settingsRecord(forUserId: userId, colorTheme: 'indigo', updatedAt: t(1)));
      await setSettings(colorTheme: 'teal', darkMode: true, updatedAt: t(2), pending: true);

      await syncService.pushPending();

      final remote = fakeRemote.get(SyncEntity.settings, userId, userId);
      expect(remote!.fields['colorTheme'], 'teal');
      expect(remote.fields['darkMode'], isTrue);
      expect(await queueCountFor(userId, SettingsTable.tableName, userId), 0);
    });

    test('ローカルで変更した設定(カラーテーマteal、キュー1件)があり、リモートの設定(カラーテーマpink)がローカルより新しい状態で送信した場合、'
        'リモートのカラーテーマはpinkのまま・getSettingsの戻り値のカラーテーマがpinkになりキューが0件になる [SYN-S12]', () async {
      fakeRemote.seed(userId, settingsRecord(forUserId: userId, colorTheme: 'pink', updatedAt: t(3)));
      await setSettings(colorTheme: 'teal', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.settings, userId, userId)!.fields['colorTheme'], 'pink');
      expect((await getSettingsOf(userId)).colorTheme, 'pink');
      expect(await queueCountFor(userId, SettingsTable.tableName, userId), 0);
    });

    test('キューにフォルダFの登録・Fの中の単語Wの登録がこの順で積まれた状態で送信した場合、リモートへの書き込みがF、Wの順に行われキューが0件になる [SYN-S13]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      await setWord('W', folderId: 'F', front: 'w', updatedAt: t(1), pending: true);

      await syncService.pushPending();

      final writeCalls = fakeRemote.calls.where((c) => c.startsWith('write:')).toList();
      expect(writeCalls, ['write:folder:F', 'write:word:W']);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('キューにフォルダFの登録、単語Wの登録がこの順で積まれ、Fの書き込みがリモートの失敗で失敗した状態で送信した場合、'
        'リモートにF・Wがなく、Wの書き込みは呼ばれず、キューがF、Wの順で2件のまま、ローカルのF・WのsyncStatusがpendingのまま [SYN-S14]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      await setWord('W', folderId: 'F', front: 'w', updatedAt: t(1), pending: true);
      fakeRemote.failWriteRecordIdOnce = 'F';

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F'), isNull);
      expect(fakeRemote.get(SyncEntity.word, userId, 'W'), isNull);
      expect(fakeRemote.calls.where((c) => c.startsWith('write:word')), isEmpty);
      final items = await syncQueue.getByUser(userId);
      expect(items.map((i) => i.recordId), ['F', 'W']);
      final db = await dbHelper.database;
      expect((await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId))!.pending, isTrue);
      expect((await syncLocal.find(db, SyncEntity.word, 'W', userId: userId))!.pending, isTrue);
    });

    test('SYN-S14の状態の後、リモートが回復してから送信した場合、リモートにF・Wができキューが0件・ローカルのF・WのsyncStatusがsyncedになる [SYN-S15]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      await setWord('W', folderId: 'F', front: 'w', updatedAt: t(1), pending: true);
      fakeRemote.failWriteRecordIdOnce = 'F';
      await syncService.pushPending();

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F'), isNotNull);
      expect(fakeRemote.get(SyncEntity.word, userId, 'W'), isNotNull);
      expect(await syncQueue.countByUser(userId), 0);
      final db = await dbHelper.database;
      expect((await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId))!.pending, isFalse);
      expect((await syncLocal.find(db, SyncEntity.word, 'W', userId: userId))!.pending, isFalse);
    });

    test('オフラインでフォルダFの名前をA→B→Cと2回編集し(キュー2件)、オンラインになってから送信した場合、'
        'リモートのFの名前がCになりキューが0件・ローカルのFがsyncedになる [SYN-S16]', () async {
      await setFolder('F', name: 'A', updatedAt: t(1), pending: true);
      await setFolder('F', name: 'B', updatedAt: t(2), pending: true);
      await setFolder('F', name: 'C', updatedAt: t(3), pending: true);
      expect(await syncQueue.countByUser(userId), 3);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.fields['name'], 'C');
      expect(await syncQueue.countByUser(userId), 0);
      final db = await dbHelper.database;
      expect((await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId))!.pending, isFalse);
    });

    test('キューに単語Wの項目が1件ある状態で送信を始め、その項目の送信中にWを表Dに編集した場合、'
        '送信が終わった後、ローカルのWのsyncStatusがpendingでキューにWの項目が1件ある [SYN-S17]', () async {
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(1), pending: true);
      fakeRemote.writeGate = Completer<void>();

      final future = syncService.pushPending();
      await Future.delayed(const Duration(milliseconds: 100));
      await wordRepo.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'D',
        back: 'back',
      );
      fakeRemote.writeGate!.complete();
      await future;

      final db = await dbHelper.database;
      final row = await syncLocal.find(db, SyncEntity.word, 'W', userId: userId);
      expect(row!.pending, isTrue);
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 1);
    });

    test('キューにユーザーVのフォルダGの項目が1件あり、Uがログイン中の状態で送信した場合、リモートにGがなくキューにGの項目が1件のまま [SYN-S18]',
        () async {
      await setFolder('G', name: 'G', updatedAt: t(1), pending: true, forUserId: otherUserId);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, otherUserId, 'G'), isNull);
      expect(await queueCountFor(otherUserId, FolderTable.tableName, 'G'), 1);
    });

    test('オフラインで、キューにフォルダFの項目が1件ある状態で送信した場合、リモートへの書き込みが呼ばれずキューが1件のまま [SYN-S19]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      fakeConnectivity.setOnline(false);

      await syncService.pushPending();

      expect(fakeRemote.calls, isEmpty);
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('キューにフォルダFの項目が1件ある状態で、送信を2回同時に始めた場合、リモートへのFの書き込みが1回だけ呼ばれキューが0件になる [SYN-S20]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);

      final f1 = syncService.pushPending();
      final f2 = syncService.pushPending();
      await Future.wait([f1, f2]);

      expect(fakeRemote.calls.where((c) => c == 'write:folder:F'), hasLength(1));
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('ローカルでフォルダF(中に単語W)を削除し、キューにW・Fの項目がある状態で送信した場合、リモートのF・Wのドキュメントにdeletedatが入りキューが0件になる [SYN-S22]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1));
      await setWord('W', folderId: 'F', front: 'w', updatedAt: t(1));
      final db0 = await dbHelper.database;
      await wordLocal.markDeleted(db0, 'W', t(2));
      await syncQueue.enqueue(
        operation: 'delete',
        tableName: WordTable.tableName,
        recordId: 'W',
        userId: userId,
        parentId: 'F',
      );
      await folderLocal.markDeleted(db0, 'F', t(2));
      await syncQueue.enqueue(
        operation: 'delete',
        tableName: FolderTable.tableName,
        recordId: 'F',
        userId: userId,
      );

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.deletedAt, t(2));
      expect(fakeRemote.get(SyncEntity.word, userId, 'W')!.deletedAt, t(2));
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('ローカルで編集した単語W(表B、キュー1件)があり、リモートのW(表A)がローカルより古い状態で送信した場合、'
        'リモートのWの表がBになりキューが0件・ローカルのWがsyncedになる [SYN-S23]', () async {
      fakeRemote.seed(userId, wordRecord(id: 'W', folderId: 'F', front: 'A', back: 'back', updatedAt: t(1)));
      await setWord('W', folderId: 'F', front: 'B', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.word, userId, 'W')!.fields['front'], 'B');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 0);
      final db = await dbHelper.database;
      expect((await syncLocal.find(db, SyncEntity.word, 'W', userId: userId))!.pending, isFalse);
    });

    test('ローカルで編集した単語W(表B、キュー1件)があり、リモートのW(表C)がローカルとupdatedatが等しい状態で送信した場合、'
        'リモートのWの表はCのまま・ローカルのWの表がCでsyncedになりキューが0件になる [SYN-S24]', () async {
      fakeRemote.seed(userId, wordRecord(id: 'W', folderId: 'F', front: 'C', back: 'back', updatedAt: t(2)));
      await setWord('W', folderId: 'F', front: 'B', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.word, userId, 'W')!.fields['front'], 'C');
      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'C');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 0);
    });

    test('ローカルで変更した設定(カラーテーマteal、キュー1件)があり、リモートにUの設定がない状態で送信した場合、'
        'リモートの設定のカラーテーマがtealになりキューが0件になる [SYN-S25]', () async {
      await setSettings(colorTheme: 'teal', updatedAt: t(1), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.settings, userId, userId)!.fields['colorTheme'], 'teal');
      expect(await queueCountFor(userId, SettingsTable.tableName, userId), 0);
    });

    test('ローカルで変更した設定(カラーテーマteal、キュー1件)があり、リモートの設定(カラーテーマpink)がローカルとupdatedatが等しい状態で送信した場合、'
        'リモートのカラーテーマはpinkのまま・getSettingsの戻り値のカラーテーマがpinkになりキューが0件になる [SYN-S26]', () async {
      fakeRemote.seed(userId, settingsRecord(forUserId: userId, colorTheme: 'pink', updatedAt: t(2)));
      await setSettings(colorTheme: 'teal', updatedAt: t(2), pending: true);

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.settings, userId, userId)!.fields['colorTheme'], 'pink');
      expect((await getSettingsOf(userId)).colorTheme, 'pink');
      expect(await queueCountFor(userId, SettingsTable.tableName, userId), 0);
    });

    test('フォルダの削除に連動して削除された成績R(キュー1件)があり、リモートのRがローカルより古い状態で送信した場合、'
        'リモートにRのドキュメントが残りdeletedAtがローカルのRのdeletedAtと同じ時刻になりキューが0件になる [SYN-S27]', () async {
      fakeRemote.seed(userId, resultRecord(id: 'R', folderId: 'F', totalCount: 10, correctCount: 7, updatedAt: t(1)));
      await setResult('R', folderId: 'F', updatedAt: t(1));
      final db0 = await dbHelper.database;
      await flashcardResultLocal.markDeleted(db0, 'R', t(2));
      await syncQueue.enqueue(
        operation: 'delete',
        tableName: FlashcardResultTable.tableName,
        recordId: 'R',
        userId: userId,
      );

      await syncService.pushPending();

      expect(fakeRemote.get(SyncEntity.flashcardResult, userId, 'R')!.deletedAt, t(2));
      expect(await queueCountFor(userId, FlashcardResultTable.tableName, 'R'), 0);
    });

    // 仕様書に個別の ID は割り当てられていないが、実装のコメント（§送信「リモートの方が
    // 新しいか同じ：…ただし送信中にローカルがさらに変更されていたら、その変更は次の項目で送る」）
    // で説明されている分岐を検証する（未カバー行 L284 の解消）。SYN-S17 の「リモートが勝つ」版。
    test('キューに単語Wの項目が1件ある状態で送信を始め、その送信中にリモートより新しい内容にWを編集した場合、'
        'ローカルのWは編集後の内容のままリモートには書き込まれずキューにWの項目が1件残る', () async {
      fakeRemote.seed(userId, wordRecord(id: 'W', folderId: 'F', front: 'C', back: 'back', updatedAt: t(5)));
      await setWord('W', folderId: 'F', front: 'A', updatedAt: t(1), pending: true);
      fakeRemote.writeGate = Completer<void>();

      final future = syncService.pushPending();
      await Future.delayed(const Duration(milliseconds: 100));
      await wordRepo.updateWord(
        userId: userId,
        folderId: 'F',
        wordId: 'W',
        front: 'E',
        back: 'back',
      );
      fakeRemote.writeGate!.complete();
      await future;

      expect((await getWords('F')).firstWhere((w) => w.id == 'W').front, 'E');
      expect(fakeRemote.get(SyncEntity.word, userId, 'W')!.fields['front'], 'C');
      expect(await queueCountFor(userId, WordTable.tableName, 'W'), 1);
    });
  });

  group('同期のきっかけ（5.3）', () {
    test('オフラインでフォルダFを編集し(キュー1件)、オンラインに戻った場合、リモートへの呼び出しで取得の読み取りがすべて終わった後に送信の書き込みが始まる [SYN-T04]',
        () async {
      await setFolder('F', name: 'B', updatedAt: t(1), pending: true);

      await syncService.syncAll();

      final lastFetch = fakeRemote.calls.lastIndexWhere((c) => c.startsWith('fetch:'));
      final firstWrite = fakeRemote.calls.indexWhere((c) => c.startsWith('write:'));
      expect(firstWrite, greaterThan(lastFetch));
    });

    test('オフラインでフォルダFを名前Bに編集し(キュー1件)、リモートのF(名前A)がそれより古い状態でオンラインに戻った場合、'
        'リモートのFの名前がBになりキューが0件・ローカルのFがsyncedになる [SYN-T05]', () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'A', updatedAt: t(1)));
      await setFolder('F', name: 'B', updatedAt: t(2), pending: true);

      await syncService.syncAll();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.fields['name'], 'B');
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
      final db = await dbHelper.database;
      expect((await syncLocal.find(db, SyncEntity.folder, 'F', userId: userId))!.pending, isFalse);
    });

    test('オフラインでフォルダFを名前Bに編集し(キュー1件)、リモートのF(名前C)がそれより新しい状態でオンラインに戻った場合、'
        'リモートのFの名前はCのまま・ローカルのFの名前がCになりキューが0件になる [SYN-T06]', () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'C', updatedAt: t(3)));
      await setFolder('F', name: 'B', updatedAt: t(2), pending: true);

      await syncService.syncAll();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F')!.fields['name'], 'C');
      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'C');
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('前回の取得から5分以上たった状態で、リモートのフォルダFがローカルより新しく(名前B)、アプリがバックグラウンドから戻った場合、ローカルのFの名前がBになる [SYN-T08]',
        () async {
      await setFolder('F', name: 'A', updatedAt: t(1));
      await syncLocal.writeMetaDate('lastPulledAt:$userId', t(0));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(2)));
      fakeNow = t(0).add(SyncService.resumedInterval);

      await syncService.syncOnResumed();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'B');
    });

    test('前回の取得から5分未満の状態で、キューにフォルダGの項目が1件あり、アプリがバックグラウンドから戻った場合、'
        'リモートへの読み取り・書き込みが呼ばれずキューが1件のまま [SYN-T09]', () async {
      await setFolder('G', name: 'G', updatedAt: t(1), pending: true);
      await syncLocal.writeMetaDate('lastPulledAt:$userId', t(0));
      fakeNow = t(0).add(const Duration(minutes: 4));

      await syncService.syncOnResumed();

      expect(fakeRemote.calls, isEmpty);
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('Uの取得の基準がない状態で、リモートにフォルダFがあり、アプリがバックグラウンドから戻った場合、getFoldersの戻り値にFが含まれる [SYN-T10]',
        () async {
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'F', updatedAt: t(1)));

      await syncService.syncOnResumed();

      expect((await getFolders()).map((f) => f.id), contains('F'));
    });

    test('オフラインで、前回の取得から5分以上たった状態でアプリがバックグラウンドから戻った場合、リモートへの読み取り・書き込みが呼ばれない [SYN-T11]',
        () async {
      await syncLocal.writeMetaDate('lastPulledAt:$userId', t(0));
      fakeNow = t(0).add(SyncService.resumedInterval);
      fakeConnectivity.setOnline(false);

      await syncService.syncOnResumed();

      expect(fakeRemote.calls, isEmpty);
    });

    test('キューにフォルダFの項目が1件ある状態で同期処理を始め、取得がリモートの失敗で失敗した場合、'
        'リモートへの書き込みが呼ばれずキューにFの項目が1件のまま [SYN-T14]', () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      fakeRemote.failFetchEntityOnce = SyncEntity.folder;

      await syncService.syncAll();

      expect(fakeRemote.calls.where((c) => c.startsWith('write:')), isEmpty);
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 1);
    });

    test('同期処理の実行中にフォルダGを登録し、同じ実行中にオンライン復帰のきっかけがもう1回起きた場合、'
        '実行中の同期処理が終わった後、同期処理がもう1回だけ行われリモートにGがありキューが0件になる [SYN-T15]', () async {
      fakeRemote.fetchGate = Completer<void>();

      final run1 = syncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 100));
      await folderRepo.createFolder(userId: userId, name: 'G');
      final run2 = syncService.syncAll();
      fakeRemote.fetchGate!.complete();
      await Future.wait([run1, run2]);

      expect(fakeRemote.calls.where((c) => c == 'fetch:folder'), hasLength(2));
      expect(fakeRemote.calls.any((c) => c.startsWith('write:folder')), isTrue);
      expect(await syncQueue.countByUser(userId), 0);
    });

    test('同期処理の送信がAuthFailureに当たるリモートの失敗(認証の期限切れ)で失敗した場合、キューの項目が残る [SYN-T16]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      fakeRemote.failWriteRecordIdOnce = 'F';

      await syncService.syncAll();

      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 1);
      expect(currentUserId, userId);
    });

    test('同期処理の取得の実行中に、オンラインでRepositoryからフォルダGを登録した場合、'
        'Gの書き込みは取得の読み取りがすべて終わった後に呼ばれ、同期処理が終わった後リモートにGがありキューが0件になる [SYN-T17]',
        () async {
      fakeRemote.fetchGate = Completer<void>();

      final run = syncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 100));
      await folderRepo.createFolder(userId: userId, name: 'G');
      fakeRemote.fetchGate!.complete();
      await run;

      final lastFetch = fakeRemote.calls.lastIndexWhere((c) => c.startsWith('fetch:'));
      final gWrite = fakeRemote.calls.indexWhere((c) => c.startsWith('write:folder'));
      expect(gWrite, greaterThan(lastFetch));
      expect(fakeRemote.calls.where((c) => c.startsWith('write:folder')), isNotEmpty);
      expect(await syncQueue.countByUser(userId), 0);
    });
  });

  group('ログアウト（5.4）', () {
    test('オンラインで、キューにフォルダFの項目が1件ある状態でログアウト前の送信を行った場合、リモートにFがあり未送信の件数が0を返す [SYN-O01]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);

      final remaining = await syncService.pushBeforeSignOut();

      expect(remaining, 0);
      expect(fakeRemote.get(SyncEntity.folder, userId, 'F'), isNotNull);
    });

    test('オフラインで、キューにフォルダFの項目が1件ある状態でログアウト前の送信を行った場合、リモートへの書き込みが呼ばれず未送信の件数が1を返す [SYN-O02]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      fakeConnectivity.setOnline(false);

      final remaining = await syncService.pushBeforeSignOut();

      expect(remaining, 1);
      expect(fakeRemote.calls, isEmpty);
    });

    test('オフラインで、ローカルにUのフォルダFがあり、キューにFの項目が1件ある状態でログアウトした場合、ローカルにFの行が残りキューにFの項目が1件残る [SYN-O05]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      fakeConnectivity.setOnline(false);

      await syncService.pushBeforeSignOut();

      expect(await rowExists(FolderTable.tableName, 'id', 'F'), isTrue);
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 1);
    });

    test('SYN-O05の状態の後、オンラインでUとして再びログインした場合、リモートにFがありキューにFの項目が0件になる [SYN-O06]',
        () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      fakeConnectivity.setOnline(false);
      await syncService.pushBeforeSignOut();
      fakeConnectivity.setOnline(true);

      await syncService.syncRemoteToLocalOnLogin();

      expect(fakeRemote.get(SyncEntity.folder, userId, 'F'), isNotNull);
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 0);
    });

    test('SYN-O05の状態の後、オンラインでユーザーVとしてログインした場合、'
        'VのgetFoldersの戻り値にFが含まれず、リモートのVのデータにFがなく、キューにUのFの項目が1件残る [SYN-O07]', () async {
      await setFolder('F', name: 'F', updatedAt: t(1), pending: true);
      fakeConnectivity.setOnline(false);
      await syncService.pushBeforeSignOut();
      fakeConnectivity.setOnline(true);
      currentUserId = otherUserId;

      await syncService.syncRemoteToLocalOnLogin();

      final vFolders = await folderRepo
          .getFolders(userId: otherUserId)
          .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));
      expect(vFolders.map((f) => f.id), isNot(contains('F')));
      expect(fakeRemote.get(SyncEntity.folder, otherUserId, 'F'), isNull);
      expect(await queueCountFor(userId, FolderTable.tableName, 'F'), 1);
    });
  });
}
