// 仕様書: docs/detailed_design/online_offline/online_offline.md（接頭辞 SYN、5.3 同期のきっかけ）
//
// 期待値はすべて上記仕様書から作った。AutoSyncService / SyncService の実装は
// 「どう呼ぶか」を知るためだけに読んでいる。
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/domain/entities/folder.dart';
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
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';
import 'package:word_stock/infrastructure/data_sources/remote/sync_remote_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/sync_record.dart';
import 'package:word_stock/infrastructure/repositories/folder_repository_impl.dart';
import 'package:word_stock/infrastructure/sync/auto_sync_service.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

import '../../helpers/fake_infrastructure.dart';

/// [SyncRemoteDataSource] の手書きフェイク（インメモリ）。
/// `test/infrastructure/sync/sync_service_test.dart` の同名フェイクを参考に、
/// このファイルの検証に必要な範囲だけを持たせている。
class FakeSyncRemoteDataSource implements SyncRemoteDataSource {
  final Map<SyncEntity, Map<String, Map<String, SyncRecord>>> _store = {
    for (final e in SyncEntity.values) e: <String, Map<String, SyncRecord>>{},
  };

  final List<String> calls = [];

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

/// ネットワーク状態の変化（[ConnectivityMonitor.onStatusChanged]）を手動で流せるフェイク。
/// 共有ヘルパーの `FakeConnectivityMonitor`（`test/helpers/fake_infrastructure.dart`）は
/// 固定値の `Stream.value` しか返せないため、複数の状態変化を検証するこのファイル専用に用意する。
class StreamConnectivityMonitor implements ConnectivityMonitor {
  StreamConnectivityMonitor({bool online = true}) : _online = online;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> onStatusChanged() => _controller.stream;

  /// ネットワーク状態の変化を通知する。
  void emit(bool online) {
    _online = online;
    _controller.add(online);
  }

  void dispose() => _controller.close();
}

SyncRecord folderRecord({
  required String id,
  required String name,
  String? parentFolderId,
  required DateTime updatedAt,
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
    );

void main() {
  const userId = 'U';

  DateTime t(int minutes) =>
      DateTime.utc(2024, 6, 1, 12).add(Duration(minutes: minutes));

  late DatabaseHelper dbHelper;
  late FolderLocalDataSource folderLocal;
  late WordLocalDataSource wordLocal;
  late FlashcardResultLocalDataSource flashcardResultLocal;
  late SyncQueueDataSource syncQueue;
  late SyncLocalDataSource syncLocal;
  late FakeSyncRemoteDataSource fakeRemote;
  late FakeConnectivityMonitor fakeConnectivity;
  late SyncService syncService;
  late FolderRepositoryImpl folderRepo;
  late AutoSyncService autoSync;
  late String? currentUserId;
  late DateTime fakeNow;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir =
        await Directory.systemTemp.createTemp('auto_sync_service_test_');
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
      onLocalChanged: () => autoSync.onLocalChanged(),
    );

    autoSync = AutoSyncService(
      connectivityMonitor: fakeConnectivity,
      syncService: syncService,
    );
  });

  tearDown(() => autoSync.stop());

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

  Future<int> queueCountFor(String forUserId, String table, String id) async {
    final items = await syncQueue.getByUser(forUserId);
    return items.where((i) => i.tableName == table && i.recordId == id).length;
  }

  Future<List<Folder>> getFolders() async => folderRepo
      .getFolders(userId: userId)
      .then((r) => r.match((_) => throw Exception('unexpected Left'), (v) => v));

  /// AutoSyncService の呼び出し（内部で unawaited）の完了を待つ。
  /// SyncService は実行を直列化する（同じ内部キューに追いかけて積む）ので、
  /// ここで syncAll() を呼んで await すると、それより前に積まれた処理の完了も待てる。
  Future<void> settle() => syncService.syncAll();

  /// onLocalChanged()（送信だけ）の完了を待つ。settle() と違い取得(fetch)を伴わない
  /// pushPending() で直列キューに合流するので、「取得の読み取りは呼ばれない」ことの検証を壊さない。
  Future<void> settlePush() => syncService.pushPending();

  group('アプリの起動（onSignedIn）', () {
    test(
        'ログイン済み・オンラインで、リモートのフォルダFがローカルより新しく(名前B)、'
        'キューにフォルダGの登録が1件ある状態でアプリを起動した場合、'
        'ローカルのFの名前がBになりリモートにGができてキューが0件になる [SYN-T01]', () async {
      await setFolder('F', name: 'A', updatedAt: t(1));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(2)));
      await setFolder('G', name: 'G', updatedAt: t(1), pending: true);

      autoSync.start();
      autoSync.onSignedIn();
      await settle();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'B');
      expect(fakeRemote.get(SyncEntity.folder, userId, 'G'), isNotNull);
      expect(await queueCountFor(userId, FolderTable.tableName, 'G'), 0);
    });

    test(
        'ログイン済み・オフラインで、キューにフォルダGの登録が1件ある状態でアプリを起動した場合、'
        'リモートへの読み取り・書き込みが呼ばれずキューが1件のまま [SYN-T02]', () async {
      fakeConnectivity.setOnline(false);
      await setFolder('G', name: 'G', updatedAt: t(1), pending: true);

      autoSync.start();
      autoSync.onSignedIn();
      await settle();

      expect(fakeRemote.calls, isEmpty);
      expect(await queueCountFor(userId, FolderTable.tableName, 'G'), 1);
    });

    test('未ログイン・オンラインでアプリを起動した場合、リモートへの読み取り・書き込みが呼ばれない [SYN-T03]',
        () async {
      currentUserId = null;

      autoSync.start();
      autoSync.onSignedIn();
      await settle();

      expect(fakeRemote.calls, isEmpty);
    });
  });

  group('オンライン復帰・オフライン（onStatusChanged）', () {
    test(
        'オフラインでフォルダFを編集し(キューにFの項目が1件)、オンラインに戻った場合、'
        '取得の読み取りがすべて終わった後に送信の書き込みが始まる [SYN-T04]', () async {
      final monitor = StreamConnectivityMonitor();
      final service = SyncService(
        localDataSource: syncLocal,
        syncQueueDataSource: syncQueue,
        remoteDataSource: fakeRemote,
        connectivityMonitor: monitor,
        getCurrentUserId: () => currentUserId,
        clock: () => fakeNow,
      );
      final auto = AutoSyncService(connectivityMonitor: monitor, syncService: service);
      await setFolder('F', name: 'B', updatedAt: t(2), pending: true);

      auto.start();
      monitor.emit(false); // オフラインを明示（この時点では同期しない）
      monitor.emit(true); // オフライン → オンラインの復帰で同期処理が始まる
      await pumpEventQueue();
      await service.syncAll(); // 直列キューに積んで、復帰による1回目の完了を待つ

      // SyncEntity は4種類（folder/word/flashcardResult/settings）。
      // 1回目の同期処理では、その4回のfetchがすべて終わってからwriteが始まる。
      expect(fakeRemote.calls.length, greaterThanOrEqualTo(5));
      expect(fakeRemote.calls.take(4).every((c) => c.startsWith('fetch:')), isTrue);
      expect(fakeRemote.calls[4], 'write:folder:F');

      auto.stop();
      monitor.dispose();
    });

    test('オンラインからオフラインに変わった場合、リモートへの読み取り・書き込みが呼ばれない [SYN-T07]',
        () async {
      final monitor = StreamConnectivityMonitor();
      final service = SyncService(
        localDataSource: syncLocal,
        syncQueueDataSource: syncQueue,
        remoteDataSource: fakeRemote,
        connectivityMonitor: monitor,
        getCurrentUserId: () => currentUserId,
        clock: () => fakeNow,
      );
      final auto = AutoSyncService(connectivityMonitor: monitor, syncService: service);

      auto.start();
      monitor.emit(true); // オフライン → オンラインの復帰扱いで一度同期が走る（前提づくり）
      await pumpEventQueue();
      await service.syncAll();
      fakeRemote.calls.clear();

      monitor.emit(false); // オンライン → オフライン
      await pumpEventQueue();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(fakeRemote.calls, isEmpty);

      auto.stop();
      monitor.dispose();
    });
  });

  group('resumed（onResumed）', () {
    test(
        '前回の取得から5分以上たった状態で、リモートのフォルダFがローカルより新しく(名前B)、'
        'アプリがバックグラウンドから戻った場合、ローカルのFの名前がBになる [SYN-T08]', () async {
      await setFolder('F', name: 'A', updatedAt: t(1));
      fakeRemote.seed(userId, folderRecord(id: 'F', name: 'B', updatedAt: t(2)));
      await syncLocal.writeMetaDate('lastPulledAt:$userId', t(0));
      fakeNow = t(10); // 前回の取得(t(0))から10分後 = resumedInterval(5分)以上

      autoSync.start();
      autoSync.onResumed();
      await settle();

      expect((await getFolders()).firstWhere((f) => f.id == 'F').name, 'B');
    });
  });

  group('登録後の送信（onLocalChanged）', () {
    test('オンラインで Repository からフォルダFを登録した場合、リモートにFができキューが0件で取得の読み取りは呼ばれない [SYN-T12]',
        () async {
      // start() 自体はネットワーク状態の監視を始めるだけの操作であり、
      // ここでは「登録後の送信」だけを検証したいので呼ばない
      // （start() を呼ぶとその時点のオンライン状態が「復帰」として扱われ、取得も走ってしまうため）。
      final created = await folderRepo.createFolder(userId: userId, name: 'F');
      await settlePush();

      final id = created.match((_) => throw Exception('unexpected Left'), (f) => f.id);
      expect(fakeRemote.get(SyncEntity.folder, userId, id), isNotNull);
      expect(await queueCountFor(userId, FolderTable.tableName, id), 0);
      expect(fakeRemote.calls.any((c) => c.startsWith('fetch:')), isFalse);
    });

    test('オフラインで Repository からフォルダFを登録した場合、リモートへの書き込みが呼ばれずキューにFの項目が1件になる [SYN-T13]',
        () async {
      fakeConnectivity.setOnline(false);

      final created = await folderRepo.createFolder(userId: userId, name: 'F');
      await settlePush();

      final id = created.match((_) => throw Exception('unexpected Left'), (f) => f.id);
      expect(fakeRemote.calls.any((c) => c.startsWith('write:')), isFalse);
      expect(await queueCountFor(userId, FolderTable.tableName, id), 1);
    });
  });
}
