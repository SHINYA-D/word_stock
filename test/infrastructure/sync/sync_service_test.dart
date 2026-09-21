import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/firebase/firestore_path.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_meta_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

import '../../helpers/fake_infrastructure.dart';

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late SyncQueueDataSource syncQueue;
  late FakeFirebaseFirestore firestore;
  late FakeConnectivityMonitor connectivity;
  String? currentUserId = userId;
  late SyncService service;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // DatabaseHelper は 'wordstock.db' という固定のファイル名を使うため、
    // 他のテストファイルと同時実行された際に同一パスを取り合ってロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリに切り替える。
    final tempDir = await Directory.systemTemp.createTemp(
      'sync_service_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    for (final t in [
      FolderTable.tableName,
      WordTable.tableName,
      FlashcardResultTable.tableName,
      SettingsTable.tableName,
      SyncQueueTable.tableName,
      SyncMetaTable.tableName,
    ]) {
      await db.delete(t);
    }

    syncQueue = SyncQueueDataSource(dbHelper);
    firestore = FakeFirebaseFirestore();
    connectivity = FakeConnectivityMonitor(online: true);
    currentUserId = userId;

    service = SyncService(
      syncQueueDataSource: syncQueue,
      firestore: firestore,
      getCurrentUserId: () => currentUserId,
      dbHelper: dbHelper,
    );
  });

  // --------------------------------------------------------------
  // ヘルパー
  // --------------------------------------------------------------

  Map<String, dynamic> folderPayload({
    String name = 'folder-name',
    String? parentFolderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      {
        'name': name,
        'parentFolderId': parentFolderId,
        'createdAt': (createdAt ?? DateTime(2024, 1, 1)).toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      };

  Map<String, dynamic> wordPayload({
    String front = 'front',
    String back = 'back',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      {
        'front': front,
        'back': back,
        'createdAt': (createdAt ?? DateTime(2024, 1, 1)).toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      };

  Map<String, dynamic> flashcardResultPayload({
    String folderId = 'f1',
    int totalCount = 10,
    int correctCount = 8,
    DateTime? date,
    DateTime? updatedAt,
  }) =>
      {
        'folderId': folderId,
        'totalCount': totalCount,
        'correctCount': correctCount,
        'date': (date ?? DateTime(2024, 1, 1)).toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      };

  Map<String, dynamic> settingsPayload({
    String colorTheme = 'indigo',
    bool darkMode = false,
    DateTime? updatedAt,
  }) =>
      {
        'colorTheme': colorTheme,
        'darkMode': darkMode,
        'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      };

  Future<void> insertLocalFolderRow({
    required String id,
    String name = 'local-name',
    DateTime? updatedAt,
    String syncStatus = 'synced',
  }) async {
    final db = await dbHelper.database;
    await db.insert(FolderTable.tableName, {
      'id': id,
      'name': name,
      'parentFolderId': null,
      'userId': userId,
      'createdAt': DateTime(2024, 1, 1).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      'syncStatus': syncStatus,
    });
  }

  Future<void> insertLocalWordRow({
    required String id,
    String front = 'local-front',
    DateTime? updatedAt,
    String syncStatus = 'synced',
  }) async {
    final db = await dbHelper.database;
    await db.insert(WordTable.tableName, {
      'id': id,
      'front': front,
      'back': 'local-back',
      'folderId': 'f1',
      'userId': userId,
      'createdAt': DateTime(2024, 1, 1).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      'syncStatus': syncStatus,
    });
  }

  Future<void> insertLocalFlashcardResultRow({
    required String id,
    int correctCount = 1,
    DateTime? updatedAt,
    String syncStatus = 'synced',
  }) async {
    final db = await dbHelper.database;
    await db.insert(FlashcardResultTable.tableName, {
      'id': id,
      'folderId': 'f1',
      'totalCount': 10,
      'correctCount': correctCount,
      'date': DateTime(2024, 1, 1).toIso8601String(),
      'userId': userId,
      'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      'syncStatus': syncStatus,
    });
  }

  Future<void> insertLocalSettingsRow({
    String colorTheme = 'local-theme',
    DateTime? updatedAt,
    String syncStatus = 'synced',
  }) async {
    final db = await dbHelper.database;
    await db.insert(SettingsTable.tableName, {
      'userId': userId,
      'colorTheme': colorTheme,
      'darkMode': 0,
      'updatedAt': (updatedAt ?? DateTime(2024, 1, 1)).toIso8601String(),
      'syncStatus': syncStatus,
    });
  }

  Future<List<Map<String, dynamic>>> localFolderRows() async {
    final db = await dbHelper.database;
    return db.query(FolderTable.tableName);
  }

  Future<List<Map<String, dynamic>>> localWordRows() async {
    final db = await dbHelper.database;
    return db.query(WordTable.tableName);
  }

  Future<List<Map<String, dynamic>>> localFlashcardResultRows() async {
    final db = await dbHelper.database;
    return db.query(FlashcardResultTable.tableName);
  }

  Future<List<Map<String, dynamic>>> localSettingsRows() async {
    final db = await dbHelper.database;
    return db.query(SettingsTable.tableName);
  }

  Future<DateTime?> lastSyncedAt() async {
    final db = await dbHelper.database;
    final rows = await db.query(
      SyncMetaTable.tableName,
      where: 'key = ?',
      whereArgs: ['lastSyncedAt'],
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['value'] as String);
  }

  Future<void> setLastSyncedAt(DateTime dateTime) async {
    final db = await dbHelper.database;
    await db.insert(
      SyncMetaTable.tableName,
      {'key': 'lastSyncedAt', 'value': dateTime.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ================================================================
  // syncLocalToRemote
  // ================================================================

  group('syncLocalToRemote', () {
    test('オフラインの場合、キューは処理されずFirestoreにも書き込まれない', () async {
      connectivity.setOnline(false);
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: 'f1',
        payload: folderPayload(),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      expect(await syncQueue.count(), 1);
      final snapshot =
          await firestore.collection(FirestorePath.folders(userId)).get();
      expect(snapshot.docs, isEmpty);
    });

    test('ユーザーIDがnullの場合、キューは処理されない', () async {
      currentUserId = null;
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: 'f1',
        payload: folderPayload(),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      expect(await syncQueue.count(), 1);
    });

    test('フォルダのupsert操作の場合、Firestoreに書き込まれキューから削除される', () async {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: 'f1',
        payload: folderPayload(name: 'my-folder'),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc =
          await firestore.doc(FirestorePath.folder(userId, 'f1')).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'my-folder');
      expect(doc.data()!['updatedAt'], isA<Timestamp>());
      expect(await syncQueue.count(), 0);
    });

    test('単語のupsert操作でparentIdが指定されている場合、正しいパスに書き込まれる', () async {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: WordTable.tableName,
        recordId: 'w1',
        parentId: 'f1',
        payload: wordPayload(front: 'apple'),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc =
          await firestore.doc(FirestorePath.word(userId, 'f1', 'w1')).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['front'], 'apple');
      expect(await syncQueue.count(), 0);
    });

    test('単語のupsert操作でparentIdがnullの場合、例外が発生し同期が中断されキューに残る', () async {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: WordTable.tableName,
        recordId: 'w1',
        payload: wordPayload(),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      expect(await syncQueue.count(), 1);
      final snapshot = await firestore
          .collection(FirestorePath.words(userId, 'f1'))
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test('成績データのupsert操作の場合、Firestoreに書き込まれる', () async {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FlashcardResultTable.tableName,
        recordId: 'r1',
        payload: flashcardResultPayload(),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc = await firestore
          .doc(FirestorePath.flashcardResult(userId, 'r1'))
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['totalCount'], 10);
    });

    test('設定のupsert操作の場合、Firestoreに書き込まれる', () async {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: SettingsTable.tableName,
        recordId: 'config',
        payload: settingsPayload(colorTheme: 'blue'),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc = await firestore.doc(FirestorePath.settings(userId)).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['colorTheme'], 'blue');
    });

    test('不明なtable_nameの場合、例外が発生し同期が中断されキューに残る', () async {
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: 'unknown_table',
        recordId: 'x1',
        payload: folderPayload(),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      expect(await syncQueue.count(), 1);
    });

    test('delete操作の場合、Firestoreからドキュメントが削除されキューから削除される', () async {
      await firestore
          .doc(FirestorePath.folder(userId, 'f1'))
          .set({'name': 'to-delete'});
      await syncQueue.enqueue(
        operation: 'delete',
        tableName: FolderTable.tableName,
        recordId: 'f1',
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc =
          await firestore.doc(FirestorePath.folder(userId, 'f1')).get();
      expect(doc.exists, isFalse);
      expect(await syncQueue.count(), 0);
    });

    test('リモートの方が新しい場合、競合解決により書き込みがスキップされる', () async {
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote-name',
        'updatedAt': DateTime(2024, 6, 1),
      });
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: 'f1',
        payload: folderPayload(
          name: 'local-name',
          updatedAt: DateTime(2024, 1, 1),
        ),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc =
          await firestore.doc(FirestorePath.folder(userId, 'f1')).get();
      expect(doc.data()!['name'], 'remote-name');
      // 競合による意図的なスキップは例外ではないため、キューからは削除される。
      expect(await syncQueue.count(), 0);
    });

    test('ローカルの方が新しい場合、競合解決によりFirestoreが上書きされる', () async {
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote-name',
        'updatedAt': DateTime(2024, 1, 1),
      });
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: 'f1',
        payload: folderPayload(
          name: 'local-name',
          updatedAt: DateTime(2024, 6, 1),
        ),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc =
          await firestore.doc(FirestorePath.folder(userId, 'f1')).get();
      expect(doc.data()!['name'], 'local-name');
    });

    test('複数キューがある場合、途中で失敗すると以降のアイテムは未処理のまま残る', () async {
      // created_at 昇順で処理されるため、先に積んだ不正なアイテムが先に処理される。
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: WordTable.tableName,
        recordId: 'w-invalid',
        payload: wordPayload(),
      ); // parentId なし → 例外
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: 'f-valid',
        payload: folderPayload(),
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      expect(await syncQueue.count(), 2);
      final doc =
          await firestore.doc(FirestorePath.folder(userId, 'f-valid')).get();
      expect(doc.exists, isFalse);
    });

    test('payloadに非ISO8601文字列や真偽値が含まれる場合、日付以外はそのままの型で書き込まれる', () async {
      final payload = folderPayload()
        ..addAll({'note': 'plain text', 'flag': true, 'count': 5});
      await syncQueue.enqueue(
        operation: 'upsert',
        tableName: FolderTable.tableName,
        recordId: 'f1',
        payload: payload,
      );

      await service.syncLocalToRemote(connectivityMonitor: connectivity);

      final doc =
          await firestore.doc(FirestorePath.folder(userId, 'f1')).get();
      final data = doc.data()!;
      expect(data['note'], 'plain text');
      expect(data['flag'], true);
      expect(data['count'], 5);
      expect(data['createdAt'], isA<Timestamp>());
    });
  });

  // ================================================================
  // syncRemoteToLocalOnLogin
  // ================================================================

  group('syncRemoteToLocalOnLogin', () {
    test('ユーザーIDがnullの場合、何も同期されない', () async {
      currentUserId = null;
      await firestore
          .doc(FirestorePath.folder(userId, 'f1'))
          .set({'name': 'remote', 'updatedAt': DateTime(2024, 1, 1)});

      await service.syncRemoteToLocalOnLogin();

      expect(await localFolderRows(), isEmpty);
      expect(await lastSyncedAt(), isNull);
    });

    test(
        'Firestoreのfolders/words/flashcard_results/settingsが全てローカルDBに反映される',
        () async {
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'folder-1',
        'parentFolderId': null,
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 2),
      });
      await firestore
          .doc(FirestorePath.word(userId, 'f1', 'w1'))
          .set({
        'front': 'apple',
        'back': 'りんご',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 2),
      });
      await firestore
          .doc(FirestorePath.flashcardResult(userId, 'r1'))
          .set({
        'folderId': 'f1',
        'totalCount': 10,
        'correctCount': 7,
        'date': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 2),
      });
      await firestore.doc(FirestorePath.settings(userId)).set({
        'colorTheme': 'green',
        'darkMode': true,
        'updatedAt': DateTime(2024, 1, 2),
      });

      await service.syncRemoteToLocalOnLogin();

      final folders = await localFolderRows();
      expect(folders, hasLength(1));
      expect(folders.first['name'], 'folder-1');
      expect(folders.first['syncStatus'], 'synced');

      final words = await localWordRows();
      expect(words, hasLength(1));
      expect(words.first['front'], 'apple');
      expect(words.first['folderId'], 'f1');

      final results = await localFlashcardResultRows();
      expect(results, hasLength(1));
      expect(results.first['correctCount'], 7);

      final settings = await localSettingsRows();
      expect(settings, hasLength(1));
      expect(settings.first['colorTheme'], 'green');
      expect(settings.first['darkMode'], 1);

      expect(await lastSyncedAt(), isNotNull);
    });

    test('設定ドキュメントが存在しない場合、ローカルのsettingsテーブルは更新されない', () async {
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'folder-1',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      expect(await localSettingsRows(), isEmpty);
    });

    test('settingsドキュメントにupdatedAtフィールドが無い場合、現在時刻を用いて登録される', () async {
      await firestore.doc(FirestorePath.settings(userId)).set({
        'colorTheme': 'indigo',
        'darkMode': false,
      });

      await service.syncRemoteToLocalOnLogin();

      final settings = await localSettingsRows();
      expect(settings, hasLength(1));
      final updatedAt = DateTime.parse(settings.first['updatedAt'] as String);
      expect(
        DateTime.now().difference(updatedAt).inMinutes.abs() < 1,
        isTrue,
      );
    });

    test('ローカルのsyncStatusがpendingの場合、リモートの内容で上書きされない', () async {
      await insertLocalFolderRow(
        id: 'f1',
        name: 'local-pending',
        syncStatus: 'pending',
        updatedAt: DateTime(2024, 1, 1),
      );
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote-newer',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 6, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final folders = await localFolderRows();
      expect(folders.first['name'], 'local-pending');
      expect(folders.first['syncStatus'], 'pending');
    });

    test('ローカルのupdatedAtがリモートより新しい場合、上書きされない', () async {
      await insertLocalFolderRow(
        id: 'f1',
        name: 'local-newer',
        syncStatus: 'synced',
        updatedAt: DateTime(2024, 6, 1),
      );
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote-older',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final folders = await localFolderRows();
      expect(folders.first['name'], 'local-newer');
    });

    test('単語のローカルsyncStatusがpendingの場合、リモートの内容で上書きされない', () async {
      // syncRemoteToLocalOnLogin は folders の Snapshot を起点に配下の words を
      // 取得するため、親フォルダの Firestore ドキュメントも必要。
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'folder-1',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });
      await insertLocalWordRow(
        id: 'w1',
        front: 'local-pending',
        syncStatus: 'pending',
        updatedAt: DateTime(2024, 1, 1),
      );
      await firestore.doc(FirestorePath.word(userId, 'f1', 'w1')).set({
        'front': 'remote-newer',
        'back': 'remote-back',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 6, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final words = await localWordRows();
      expect(words.first['front'], 'local-pending');
    });

    test('単語のローカルupdatedAtがリモートより新しい場合、上書きされない', () async {
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'folder-1',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });
      await insertLocalWordRow(
        id: 'w1',
        front: 'local-newer',
        syncStatus: 'synced',
        updatedAt: DateTime(2024, 6, 1),
      );
      await firestore.doc(FirestorePath.word(userId, 'f1', 'w1')).set({
        'front': 'remote-older',
        'back': 'remote-back',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final words = await localWordRows();
      expect(words.first['front'], 'local-newer');
    });

    test('成績データのローカルsyncStatusがpendingの場合、リモートの内容で上書きされない', () async {
      await insertLocalFlashcardResultRow(
        id: 'r1',
        correctCount: 1,
        syncStatus: 'pending',
        updatedAt: DateTime(2024, 1, 1),
      );
      await firestore.doc(FirestorePath.flashcardResult(userId, 'r1')).set({
        'folderId': 'f1',
        'totalCount': 10,
        'correctCount': 9,
        'date': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 6, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final results = await localFlashcardResultRows();
      expect(results.first['correctCount'], 1);
    });

    test('成績データのローカルupdatedAtがリモートより新しい場合、上書きされない', () async {
      await insertLocalFlashcardResultRow(
        id: 'r1',
        correctCount: 1,
        syncStatus: 'synced',
        updatedAt: DateTime(2024, 6, 1),
      );
      await firestore.doc(FirestorePath.flashcardResult(userId, 'r1')).set({
        'folderId': 'f1',
        'totalCount': 10,
        'correctCount': 9,
        'date': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final results = await localFlashcardResultRows();
      expect(results.first['correctCount'], 1);
    });

    test('設定のローカルsyncStatusがpendingの場合、リモートの内容で上書きされない', () async {
      await insertLocalSettingsRow(
        colorTheme: 'local-pending',
        syncStatus: 'pending',
        updatedAt: DateTime(2024, 1, 1),
      );
      await firestore.doc(FirestorePath.settings(userId)).set({
        'colorTheme': 'remote-newer',
        'darkMode': true,
        'updatedAt': DateTime(2024, 6, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final settings = await localSettingsRows();
      expect(settings.first['colorTheme'], 'local-pending');
    });

    test('設定のローカルupdatedAtがリモートより新しい場合、上書きされない', () async {
      await insertLocalSettingsRow(
        colorTheme: 'local-newer',
        syncStatus: 'synced',
        updatedAt: DateTime(2024, 6, 1),
      );
      await firestore.doc(FirestorePath.settings(userId)).set({
        'colorTheme': 'remote-older',
        'darkMode': true,
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnLogin();

      final settings = await localSettingsRows();
      expect(settings.first['colorTheme'], 'local-newer');
    });
  });

  // ================================================================
  // syncRemoteToLocalOnResumed
  // ================================================================

  group('syncRemoteToLocalOnResumed', () {
    test('オフラインの場合、何も同期されない', () async {
      connectivity.setOnline(false);
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      expect(await localFolderRows(), isEmpty);
    });

    test('lastSyncedAtが5分以内の場合、スロットルされ同期は行われない', () async {
      await setLastSyncedAt(DateTime.now().subtract(const Duration(minutes: 2)));
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime.now(),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      expect(await localFolderRows(), isEmpty);
    });

    test('lastSyncedAtが5分より前の場合、差分同期が実行される', () async {
      final oldSync = DateTime.now().subtract(const Duration(minutes: 10));
      await setLastSyncedAt(oldSync);
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote-updated',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime.now(),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      final folders = await localFolderRows();
      expect(folders, hasLength(1));
      expect(folders.first['name'], 'remote-updated');
      final updatedLastSync = await lastSyncedAt();
      expect(updatedLastSync!.isAfter(oldSync), isTrue);
    });

    test('lastSyncedAtが存在しない場合、1970年からの差分として同期が実行される', () async {
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote-first-sync',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      final folders = await localFolderRows();
      expect(folders, hasLength(1));
      expect(folders.first['name'], 'remote-first-sync');
    });

    test('ユーザーIDがnullの場合、同期は実行されない', () async {
      currentUserId = null;
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'remote',
        'createdAt': DateTime(2024, 1, 1),
        'updatedAt': DateTime(2024, 1, 1),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      expect(await localFolderRows(), isEmpty);
    });

    test('フォルダに単語の差分が無い場合、そのフォルダの単語同期はスキップされる', () async {
      final oldSync = DateTime.now().subtract(const Duration(minutes: 10));
      await setLastSyncedAt(oldSync);
      // フォルダ自体も単語も lastSyncedAt より古い更新日時 → 差分なし
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'unchanged-folder',
        'createdAt': DateTime(2020, 1, 1),
        'updatedAt': DateTime(2020, 1, 1),
      });
      await firestore.doc(FirestorePath.word(userId, 'f1', 'w1')).set({
        'front': 'old',
        'back': 'old',
        'createdAt': DateTime(2020, 1, 1),
        'updatedAt': DateTime(2020, 1, 1),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      expect(await localFolderRows(), isEmpty);
      expect(await localWordRows(), isEmpty);
    });

    test('フォルダに単語の差分がある場合、その単語がローカルに反映される', () async {
      final oldSync = DateTime.now().subtract(const Duration(minutes: 10));
      await setLastSyncedAt(oldSync);
      // フォルダ自体は差分なしでも、配下の単語が更新されていれば同期対象になる。
      await firestore.doc(FirestorePath.folder(userId, 'f1')).set({
        'name': 'unchanged-folder',
        'createdAt': DateTime(2020, 1, 1),
        'updatedAt': DateTime(2020, 1, 1),
      });
      await firestore.doc(FirestorePath.word(userId, 'f1', 'w1')).set({
        'front': 'updated-word',
        'back': 'back',
        'createdAt': DateTime(2020, 1, 1),
        'updatedAt': DateTime.now(),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      final words = await localWordRows();
      expect(words, hasLength(1));
      expect(words.first['front'], 'updated-word');
    });

    test('成績データに差分がある場合、ローカルに反映される', () async {
      final oldSync = DateTime.now().subtract(const Duration(minutes: 10));
      await setLastSyncedAt(oldSync);
      await firestore.doc(FirestorePath.flashcardResult(userId, 'r1')).set({
        'folderId': 'f1',
        'totalCount': 10,
        'correctCount': 9,
        'date': DateTime(2024, 1, 1),
        'updatedAt': DateTime.now(),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      final results = await localFlashcardResultRows();
      expect(results, hasLength(1));
      expect(results.first['correctCount'], 9);
    });

    test('設定がlastSyncedAtより後に更新されている場合、ローカルに反映される', () async {
      final oldSync = DateTime.now().subtract(const Duration(minutes: 10));
      await setLastSyncedAt(oldSync);
      await firestore.doc(FirestorePath.settings(userId)).set({
        'colorTheme': 'updated-theme',
        'darkMode': true,
        'updatedAt': DateTime.now(),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      final settings = await localSettingsRows();
      expect(settings, hasLength(1));
      expect(settings.first['colorTheme'], 'updated-theme');
    });

    test('設定がlastSyncedAt以前にしか更新されていない場合、ローカルへの反映はスキップされる', () async {
      final oldSync = DateTime.now().subtract(const Duration(minutes: 10));
      await setLastSyncedAt(oldSync);
      await firestore.doc(FirestorePath.settings(userId)).set({
        'colorTheme': 'unchanged',
        'darkMode': false,
        'updatedAt': DateTime(2020, 1, 1),
      });

      await service.syncRemoteToLocalOnResumed(
        connectivityMonitor: connectivity,
      );

      expect(await localSettingsRows(), isEmpty);
    });
  });
}
