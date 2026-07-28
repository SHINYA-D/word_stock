import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:word_stock/core/firebase/firestore_path.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_meta_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/test_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';

class SyncService {
  SyncService({
    required SyncQueueDataSource syncQueueDataSource,
    required FirebaseFirestore firestore,
    required String Function() getCurrentUserId,
    required DatabaseHelper dbHelper,
  })  : _syncQueueDataSource = syncQueueDataSource,
        _firestore = firestore,
        _getCurrentUserId = getCurrentUserId,
        _dbHelper = dbHelper;

  final SyncQueueDataSource _syncQueueDataSource;
  final FirebaseFirestore _firestore;
  final String Function() _getCurrentUserId;
  final DatabaseHelper _dbHelper;

  static const Duration _syncInterval = Duration(minutes: 5);

  // ----------------------------------------------------------------
  // ローカル → リモート 同期
  // ----------------------------------------------------------------

  /// オフライン時に積まれたキューを Firestore に反映する。
  /// ネットワーク確認 → 古い順に 1 件ずつ処理 → 失敗したら中断。
  Future<void> syncLocalToRemote({
    required ConnectivityMonitor connectivityMonitor,
  }) async {
    if (!await connectivityMonitor.isOnline()) return;

    final userId = _getCurrentUserId();
    final queueItems = await _syncQueueDataSource.getAll();

    for (final item in queueItems) {
      try {
        await _processQueueItem(item, userId);
        await _syncQueueDataSource.delete(item['id'] as int);
      } catch (e, stack) {
        // 失敗した時点で中断。次回同期でキュー先頭から再開する。
        debugPrint('Sync failed: $e\n$stack');
        break;
      }
    }
  }

  Future<void> _processQueueItem(
    Map<String, dynamic> item,
    String userId,
  ) async {
    final tableName = item['table_name'] as String;
    final recordId = item['record_id'] as String;
    final parentId = item['parent_id'] as String?;
    final operation = item['operation'] as String;
    final payloadStr = item['payload'] as String?;

    final path = _buildPath(tableName, userId, recordId, parentId);

    if (operation == 'delete') {
      await _firestore.doc(path).delete();
    } else {
      final decoded =
          jsonDecode(payloadStr!) as Map<String, dynamic>;
      final firestoreData = _convertToFirestoreData(decoded);

      // Firestoreトランザクションで競合解決（Phase 8 の要件も満たす）
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.doc(path);
        final docSnapshot = await transaction.get(docRef);

        if (docSnapshot.exists) {
          final remoteData = docSnapshot.data()!;
          final remoteUpdatedAtRaw = remoteData['updatedAt'];
          if (remoteUpdatedAtRaw is Timestamp) {
            final remoteUpdatedAt = remoteUpdatedAtRaw.toDate();
            final localUpdatedAtStr = decoded['updatedAt'] as String?;
            if (localUpdatedAtStr != null) {
              final localUpdatedAt = DateTime.parse(localUpdatedAtStr);
              if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
                return; // リモートが新しいのでスキップ
              }
            }
          }
        }
        transaction.set(docRef, firestoreData);
      });
    }
  }

  /// JSON payload 内の ISO8601 文字列を DateTime に変換して Firestore 形式に整える。
  Map<String, dynamic> _convertToFirestoreData(Map<String, dynamic> decoded) {
    final result = <String, dynamic>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is String && _isIso8601(value)) {
        result[entry.key] = DateTime.parse(value);
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  bool _isIso8601(String value) {
    try {
      DateTime.parse(value);
      return value.contains('T') || value.contains('-');
    } catch (_) {
      return false;
    }
  }

  String _buildPath(
    String tableName,
    String userId,
    String recordId,
    String? parentId,
  ) {
    switch (tableName) {
      case FolderTable.tableName:
        return FirestorePath.folder(userId, recordId);
      case WordTable.tableName:
        if (parentId == null) {
          throw Exception('parentId is required for words');
        }
        return FirestorePath.word(userId, parentId, recordId);
      case TestResultTable.tableName:
        return FirestorePath.testResult(userId, recordId);
      case SettingsTable.tableName:
        return FirestorePath.settings(userId);
      default:
        throw Exception('Unknown table_name: $tableName');
    }
  }

  // ----------------------------------------------------------------
  // リモート → ローカル 同期（ログイン時・全件）
  // ----------------------------------------------------------------

  Future<void> syncRemoteToLocalOnLogin() async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    // folders
    final foldersSnapshot = await _firestore
        .collection(FirestorePath.folders(userId))
        .get();

    await db.transaction((txn) async {
      for (final doc in foldersSnapshot.docs) {
        await _upsertFolderWithConflictCheck(txn, doc, userId);
      }
    });

    // 各フォルダの words
    for (final folderDoc in foldersSnapshot.docs) {
      final wordsSnapshot = await _firestore
          .collection(FirestorePath.words(userId, folderDoc.id))
          .get();

      await db.transaction((txn) async {
        for (final wordDoc in wordsSnapshot.docs) {
          await _upsertWordWithConflictCheck(
              txn, wordDoc, userId, folderDoc.id);
        }
      });
    }

    // test_results
    final resultsSnapshot = await _firestore
        .collection(FirestorePath.testResults(userId))
        .get();

    await db.transaction((txn) async {
      for (final doc in resultsSnapshot.docs) {
        await _upsertTestResultWithConflictCheck(txn, doc, userId);
      }
    });

    // settings
    final settingsDoc =
        await _firestore.doc(FirestorePath.settings(userId)).get();
    if (settingsDoc.exists) {
      await db.transaction((txn) async {
        await _upsertSettingsWithConflictCheck(txn, settingsDoc, userId);
      });
    }

    await _updateLastSyncedAt(_dbHelper);
  }

  // ----------------------------------------------------------------
  // リモート → ローカル 同期（resumed 時・差分）
  // ----------------------------------------------------------------

  Future<void> syncRemoteToLocalOnResumed({
    required ConnectivityMonitor connectivityMonitor,
  }) async {
    if (!await connectivityMonitor.isOnline()) return;

    final lastSyncedAt = await _getLastSyncedAt(_dbHelper);
    if (lastSyncedAt != null) {
      final elapsed = DateTime.now().difference(lastSyncedAt);
      if (elapsed < _syncInterval) return;
    }

    final userId = _getCurrentUserId();
    final lastSyncedAtForQuery = lastSyncedAt ?? DateTime(1970);
    final db = await _dbHelper.database;

    // folders 差分
    final foldersSnapshot = await _firestore
        .collection(FirestorePath.folders(userId))
        .where('updatedAt', isGreaterThan: lastSyncedAtForQuery)
        .get();

    await db.transaction((txn) async {
      for (final doc in foldersSnapshot.docs) {
        await _upsertFolderWithConflictCheck(txn, doc, userId);
      }
    });

    // 全フォルダの words 差分
    final allFoldersSnapshot = await _firestore
        .collection(FirestorePath.folders(userId))
        .get();

    for (final folderDoc in allFoldersSnapshot.docs) {
      final wordsSnapshot = await _firestore
          .collection(FirestorePath.words(userId, folderDoc.id))
          .where('updatedAt', isGreaterThan: lastSyncedAtForQuery)
          .get();

      if (wordsSnapshot.docs.isEmpty) continue;

      await db.transaction((txn) async {
        for (final wordDoc in wordsSnapshot.docs) {
          await _upsertWordWithConflictCheck(
              txn, wordDoc, userId, folderDoc.id);
        }
      });
    }

    // test_results 差分
    final resultsSnapshot = await _firestore
        .collection(FirestorePath.testResults(userId))
        .where('updatedAt', isGreaterThan: lastSyncedAtForQuery)
        .get();

    await db.transaction((txn) async {
      for (final doc in resultsSnapshot.docs) {
        await _upsertTestResultWithConflictCheck(txn, doc, userId);
      }
    });

    // settings 差分
    final settingsDoc =
        await _firestore.doc(FirestorePath.settings(userId)).get();
    if (settingsDoc.exists) {
      final remoteUpdatedAt =
          (settingsDoc.data()!['updatedAt'] as Timestamp?)?.toDate();
      if (remoteUpdatedAt != null &&
          remoteUpdatedAt.isAfter(lastSyncedAtForQuery)) {
        await db.transaction((txn) async {
          await _upsertSettingsWithConflictCheck(txn, settingsDoc, userId);
        });
      }
    }

    await _updateLastSyncedAt(_dbHelper);
  }

  // ----------------------------------------------------------------
  // 競合チェック付き UPSERT ヘルパー
  // ----------------------------------------------------------------

  Future<void> _upsertFolderWithConflictCheck(
    Transaction txn,
    DocumentSnapshot doc,
    String userId,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final remoteUpdatedAt = (data['updatedAt'] as Timestamp).toDate();

    final localRows = await txn.query(
      FolderTable.tableName,
      where: 'id = ?',
      whereArgs: [doc.id],
    );

    if (localRows.isNotEmpty) {
      final localRow = localRows.first;
      if (localRow['syncStatus'] as String == 'pending') return;
      final localUpdatedAt =
          DateTime.parse(localRow['updatedAt'] as String);
      if (localUpdatedAt.isAfter(remoteUpdatedAt)) return;
    }

    await txn.insert(
      FolderTable.tableName,
      {
        'id': doc.id,
        'name': data['name'] as String,
        'parentFolderId': data['parentFolderId'] as String?,
        'userId': userId,
        'createdAt':
            (data['createdAt'] as Timestamp).toDate().toIso8601String(),
        'updatedAt': remoteUpdatedAt.toIso8601String(),
        'syncStatus': 'synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _upsertWordWithConflictCheck(
    Transaction txn,
    DocumentSnapshot doc,
    String userId,
    String folderId,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final remoteUpdatedAt = (data['updatedAt'] as Timestamp).toDate();

    final localRows = await txn.query(
      WordTable.tableName,
      where: 'id = ?',
      whereArgs: [doc.id],
    );

    if (localRows.isNotEmpty) {
      final localRow = localRows.first;
      if (localRow['syncStatus'] as String == 'pending') return;
      final localUpdatedAt =
          DateTime.parse(localRow['updatedAt'] as String);
      if (localUpdatedAt.isAfter(remoteUpdatedAt)) return;
    }

    await txn.insert(
      WordTable.tableName,
      {
        'id': doc.id,
        'front': data['front'] as String,
        'back': data['back'] as String,
        'folderId': folderId,
        'userId': userId,
        'createdAt':
            (data['createdAt'] as Timestamp).toDate().toIso8601String(),
        'updatedAt': remoteUpdatedAt.toIso8601String(),
        'syncStatus': 'synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _upsertTestResultWithConflictCheck(
    Transaction txn,
    DocumentSnapshot doc,
    String userId,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final remoteUpdatedAt = (data['updatedAt'] as Timestamp).toDate();

    final localRows = await txn.query(
      TestResultTable.tableName,
      where: 'id = ?',
      whereArgs: [doc.id],
    );

    if (localRows.isNotEmpty) {
      final localRow = localRows.first;
      if (localRow['syncStatus'] as String == 'pending') return;
      final localUpdatedAt =
          DateTime.parse(localRow['updatedAt'] as String);
      if (localUpdatedAt.isAfter(remoteUpdatedAt)) return;
    }

    await txn.insert(
      TestResultTable.tableName,
      {
        'id': doc.id,
        'folderId': data['folderId'] as String,
        'totalCount': data['totalCount'] as int,
        'correctCount': data['correctCount'] as int,
        'date': (data['date'] as Timestamp).toDate().toIso8601String(),
        'userId': userId,
        'updatedAt': remoteUpdatedAt.toIso8601String(),
        'syncStatus': 'synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _upsertSettingsWithConflictCheck(
    Transaction txn,
    DocumentSnapshot doc,
    String userId,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final remoteUpdatedAtRaw = data['updatedAt'];
    final remoteUpdatedAt = remoteUpdatedAtRaw is Timestamp
        ? remoteUpdatedAtRaw.toDate()
        : DateTime.now();

    final localRows = await txn.query(
      SettingsTable.tableName,
      where: 'userId = ?',
      whereArgs: [userId],
    );

    if (localRows.isNotEmpty) {
      final localRow = localRows.first;
      if (localRow['syncStatus'] as String == 'pending') return;
      final localUpdatedAt =
          DateTime.parse(localRow['updatedAt'] as String);
      if (localUpdatedAt.isAfter(remoteUpdatedAt)) return;
    }

    await txn.insert(
      SettingsTable.tableName,
      {
        'userId': userId,
        'colorTheme': (data['colorTheme'] as String?) ?? 'indigo',
        'darkMode': (data['darkMode'] as bool? ?? false) ? 1 : 0,
        'updatedAt': remoteUpdatedAt.toIso8601String(),
        'syncStatus': 'synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ----------------------------------------------------------------
  // lastSyncedAt 管理
  // ----------------------------------------------------------------

  Future<void> _updateLastSyncedAt(DatabaseHelper helper) async {
    final db = await helper.database;
    await db.insert(
      SyncMetaTable.tableName,
      {
        'key': 'lastSyncedAt',
        'value': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> _getLastSyncedAt(DatabaseHelper helper) async {
    final db = await helper.database;
    final rows = await db.query(
      SyncMetaTable.tableName,
      where: 'key = ?',
      whereArgs: ['lastSyncedAt'],
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['value'] as String);
  }
}
