import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/repositories/sync_repository.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';
import 'package:word_stock/infrastructure/data_sources/remote/sync_remote_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/sync_record.dart';

/// ローカル（SQLite）とリモートの同期。
///
/// - 取得：前回の取得以降にリモートが受け付けた変更をローカルに反映する
/// - 送信：キューを積んだ順に 1 件ずつリモートに反映する（ローカルの最新の行を送る）
/// - 同じデータの変更がぶつかったら、updatedAt が新しい方を正とする（同じならリモート）
/// - 取得・送信は同時に 1 つだけ動かす。失敗は例外にせず、次のきっかけで再試行する
class SyncService implements SyncRepository {
  SyncService({
    required SyncLocalDataSource localDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required SyncRemoteDataSource remoteDataSource,
    required ConnectivityMonitor connectivityMonitor,
    required String? Function() getCurrentUserId,
    DateTime Function()? clock,
  })  : _local = localDataSource,
        _queue = syncQueueDataSource,
        _remote = remoteDataSource,
        _connectivity = connectivityMonitor,
        _getCurrentUserId = getCurrentUserId,
        _now = clock ?? DateTime.now;

  final SyncLocalDataSource _local;
  final SyncQueueDataSource _queue;
  final SyncRemoteDataSource _remote;
  final ConnectivityMonitor _connectivity;
  final String? Function() _getCurrentUserId;
  final DateTime Function() _now;

  /// resumed 時に取得するまでの間隔
  static const Duration resumedInterval = Duration(minutes: 5);

  /// リモートとの通信 1 回あたりの時間の上限
  static const Duration remoteTimeout = Duration(seconds: 30);

  /// 差分取得の範囲を、記録した基準より少し前から取る幅。
  /// 取得の途中（別のコレクションを読んでいる間）に受け付けられた変更を取りこぼさないため。
  /// 同じデータを2回反映しても結果は変わらない。
  static const Duration _pullOverlap = Duration(minutes: 10);

  static const _operationUpsert = 'upsert';
  static const _operationDelete = 'delete';

  static String _cursorKey(String userId) => 'pullCursor:$userId';
  static String _lastPulledKey(String userId) => 'lastPulledAt:$userId';

  // ---------------------------------------------------------------
  // 同期のきっかけ（公開 API）
  // ---------------------------------------------------------------

  /// 同期処理（取得 → 送信）。取得に失敗したら送信しない。
  Future<void> syncAll() => _schedule(_Job.full, () async {
        final userId = await _readyUserId();
        if (userId == null) return;
        if (!await _guard('pull', () => _pull(userId))) return;
        await _guard('push', () => _push(userId));
      });

  /// 送信だけ（登録・編集・削除の直後）。
  Future<void> pushPending() => _schedule(_Job.push, () async {
        final userId = await _readyUserId();
        if (userId == null) return;
        await _guard('push', () => _push(userId));
      });

  /// resumed 時。前回の取得から [resumedInterval] 以上たっていれば同期処理をする。
  Future<void> syncOnResumed() async {
    final userId = _getCurrentUserId();
    if (userId == null || !await _connectivity.isOnline()) return;
    final last = await _local.readMetaDate(_lastPulledKey(userId));
    if (last != null && _now().difference(last) < resumedInterval) return;
    await syncAll();
  }

  @override
  Future<void> syncRemoteToLocalOnLogin() => syncAll();

  @override
  Future<int> pushBeforeSignOut() async {
    final userId = _getCurrentUserId();
    if (userId == null) return 0;
    await pushPending();
    return _queue.countByUser(userId);
  }

  // ---------------------------------------------------------------
  // 実行の直列化
  // ---------------------------------------------------------------

  Future<void> _tail = Future.value();
  final Map<_Job, Future<void>> _waiting = {};

  /// 取得・送信を 1 つずつ順番に動かす。同じ種類の処理がまだ始まらずに待っていれば、それにまとめる。
  Future<void> _schedule(_Job job, Future<void> Function() body) {
    final waiting = _waiting[job];
    if (waiting != null) return waiting;
    final run = _tail.then((_) {
      _waiting.remove(job);
      return body();
    });
    _waiting[job] = run;
    _tail = run.catchError((Object _) {});
    return run;
  }

  Future<String?> _readyUserId() async {
    final userId = _getCurrentUserId();
    if (userId == null) return null;
    if (!await _connectivity.isOnline()) return null;
    return userId;
  }

  /// 同期の失敗は画面に出さず、ログに残して false を返す。
  Future<bool> _guard(String label, Future<void> Function() body) async {
    try {
      await body();
      return true;
    } catch (e, stack) {
      debugPrint('Sync $label failed: $e\n$stack');
      return false;
    }
  }

  Future<T> _remoteCall<T>(Future<T> call) => call.timeout(remoteTimeout);

  // ---------------------------------------------------------------
  // 取得（リモート → ローカル）
  // ---------------------------------------------------------------

  Future<void> _pull(String userId) async {
    final cursor = await _local.readMetaDate(_cursorKey(userId));
    final since = cursor?.subtract(_pullOverlap);
    var newest = cursor;

    // フォルダを先に反映し、単語・成績を反映するときに親フォルダの削除を判定できるようにする
    for (final entity in SyncEntity.values) {
      final records = await _remoteCall(
          _remote.fetchChanges(userId, entity, since: since));
      final db = await _local.database;
      await db.transaction((txn) async {
        for (final record in records) {
          await _applyRemote(txn, userId, record);
        }
      });
      for (final record in records) {
        final received = record.serverUpdatedAt;
        if (received != null && (newest == null || received.isAfter(newest))) {
          newest = received;
        }
      }
    }

    // すべて反映できたときだけ基準を進める（途中で失敗したら、次は同じ範囲を取り直す）。
    // 受付時刻を持つデータが無かった全件取得の後は、最も古い時刻を基準にして次から差分にする
    await _local.writeMetaDate(
      _cursorKey(userId),
      newest ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    await _local.writeMetaDate(_lastPulledKey(userId), _now());
  }

  /// 取得した 1 件をローカルに反映する（概要 §取得 の反映表）。
  Future<void> _applyRemote(
    Transaction txn,
    String userId,
    SyncRecord remote,
  ) async {
    final table = SyncLocalDataSource.tableOf(remote.entity);
    final local = await _local.find(txn, remote.entity, remote.id, userId: userId);

    if (local == null) {
      if (remote.isDeleted) return;
      await _local.put(txn, remote, userId: userId, pending: false);
    } else if (!local.pending) {
      if (!remote.updatedAt.isAfter(local.record.updatedAt)) return;
      await _local.put(txn, remote, userId: userId, pending: false);
    } else {
      // 未送信の変更がある：ローカルの方が新しければ残し、後で送信する
      if (local.record.updatedAt.isAfter(remote.updatedAt)) return;
      await _local.put(txn, remote, userId: userId, pending: false);
      await _queue.deleteForRecord(txn, table, remote.id);
    }

    if (remote.isDeleted) {
      if (remote.entity == SyncEntity.folder) {
        await _deleteDescendants(txn, userId, remote.id);
      }
      return;
    }
    // 削除済みのフォルダの中に届いたデータは、フォルダの削除に合わせて削除済みにする
    final folderId = switch (remote.entity) {
      SyncEntity.word => remote.parentId,
      SyncEntity.flashcardResult => remote.fields['folderId'] as String?,
      SyncEntity.folder => remote.fields['parentFolderId'] as String?,
      SyncEntity.settings => null,
    };
    if (folderId != null &&
        await _local.isFolderDeleted(txn, folderId, userId: userId)) {
      await _markDeletedAndEnqueue(txn, userId, remote.entity, remote.id,
          parentId: remote.parentId);
      if (remote.entity == SyncEntity.folder) {
        await _deleteDescendants(txn, userId, remote.id);
      }
    }
  }

  /// フォルダの配下を、ローカルの変更があってもすべて削除済みにし、キューに積む。
  Future<void> _deleteDescendants(
    Transaction txn,
    String userId,
    String folderId,
  ) async {
    final descendants =
        await _local.activeDescendants(txn, folderId, userId: userId);
    for (final d in descendants) {
      await _markDeletedAndEnqueue(txn, userId, d.entity, d.id, parentId: d.parentId);
    }
  }

  Future<void> _markDeletedAndEnqueue(
    Transaction txn,
    String userId,
    SyncEntity entity,
    String id, {
    String? parentId,
  }) async {
    final table = SyncLocalDataSource.tableOf(entity);
    await _local.markDeleted(txn, entity, id, _now());
    await _queue.enqueueInTransaction(
      txn,
      operation: _operationDelete,
      tableName: table,
      recordId: id,
      parentId: parentId,
      userId: userId,
    );
  }

  // ---------------------------------------------------------------
  // 送信（ローカル → リモート）
  // ---------------------------------------------------------------

  /// 失敗したらそこで止める（例外を投げる）。残りは順番を保ったままキューに残る。
  Future<void> _push(String userId) async {
    final items = await _queue.getByUser(userId);
    final db = await _local.database;
    for (final item in items) {
      final entity = SyncLocalDataSource.entityOf(item.tableName);
      final local = await _local.find(db, entity, item.recordId, userId: userId);
      final record = local?.record ?? _legacyTombstone(entity, item);
      if (record == null) {
        // 行が無く、送るものが無い（登録してすぐ消えた等）項目は捨てる
        await _queue.delete(item.id);
        continue;
      }

      final newerRemote = await _remoteCall(_remote.writeIfNewer(userId, record));

      await db.transaction((txn) async {
        if (newerRemote == null) {
          await _queue.delete(item.id, txn);
          if (local != null &&
              !await _queue.hasItemsForRecord(txn, item.tableName, item.recordId)) {
            await _local.markSynced(txn, entity, item.recordId);
          }
          return;
        }
        // リモートの方が新しいか同じ：書き込まずに、リモートの内容でローカルを上書きする。
        // ただし送信中にローカルがさらに変更されていたら、その変更は次の項目で送る
        final current =
            await _local.find(txn, entity, item.recordId, userId: userId);
        if (current != null &&
            current.record.updatedAt.isAfter(newerRemote.updatedAt)) {
          await _queue.delete(item.id, txn);
          return;
        }
        await _applyRemote(txn, userId, newerRemote);
        await _queue.deleteForRecord(txn, item.tableName, item.recordId);
      });
    }
  }

  /// バージョン1のキューに残っていた削除（行は物理的に消えている）を、リモートの論理削除として送る。
  SyncRecord? _legacyTombstone(SyncEntity entity, SyncQueueItem item) {
    if (item.operation != _operationDelete) return null;
    if (entity == SyncEntity.word && item.parentId == null) return null;
    return SyncRecord(
      entity: entity,
      id: item.recordId,
      parentId: item.parentId,
      fields: const {},
      updatedAt: item.createdAt,
      deletedAt: item.createdAt,
    );
  }

  /// Repository がキューに積むときの操作名
  static String operationFor({required bool isDelete}) =>
      isDelete ? _operationDelete : _operationUpsert;
}

enum _Job { full, push }
