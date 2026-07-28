import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/repositories/folder_repository.dart';
import 'package:word_stock/infrastructure/data_sources/firestore_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/test_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/test_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';

class FolderRepositoryImpl implements FolderRepository {
  FolderRepositoryImpl({
    required FolderLocalDataSource localDataSource,
    required WordLocalDataSource wordLocalDataSource,
    required TestResultLocalDataSource testResultLocalDataSource,
    required FirestoreDataSource remoteDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required ConnectivityMonitor connectivityMonitor,
  })  : _local = localDataSource,
        _wordLocal = wordLocalDataSource,
        _testResultLocal = testResultLocalDataSource,
        _remote = remoteDataSource,
        _syncQueue = syncQueueDataSource,
        _dbHelper = dbHelper,
        _connectivity = connectivityMonitor;

  final FolderLocalDataSource _local;
  final WordLocalDataSource _wordLocal;
  final TestResultLocalDataSource _testResultLocal;
  final FirestoreDataSource _remote;
  final SyncQueueDataSource _syncQueue;
  final DatabaseHelper _dbHelper;
  final ConnectivityMonitor _connectivity;

  static const _uuid = Uuid();

  @override
  Future<Either<Failure, List<Folder>>> getFolders({
    required String userId,
    String? parentFolderId,
  }) async {
    try {
      final folders =
          await _local.findByUserId(userId, parentFolderId: parentFolderId);
      return Right(folders);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Folder>> createFolder({
    required String userId,
    required String name,
    String? parentFolderId,
  }) async {
    try {
      final now = DateTime.now();
      final folder = Folder(
        id: _uuid.v4(),
        name: name,
        parentFolderId: parentFolderId,
        createdAt: now,
        updatedAt: now,
      );
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        await _local.insert(folder, userId: userId, syncStatus: 'synced');
        await _remote.writeFolder(folder, userId);
      } else {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.insert(
            FolderTable.tableName,
            {
              'id': folder.id,
              'name': folder.name,
              'parentFolderId': folder.parentFolderId,
              'userId': userId,
              'createdAt': folder.createdAt.toIso8601String(),
              'updatedAt': folder.updatedAt.toIso8601String(),
              'syncStatus': 'pending',
            },
          );
          await _syncQueue.enqueueInTransaction(
            txn,
            operation: 'create',
            tableName: FolderTable.tableName,
            recordId: folder.id,
            payload: {
              'name': folder.name,
              'parentFolderId': folder.parentFolderId,
              'createdAt': folder.createdAt.toIso8601String(),
              'updatedAt': folder.updatedAt.toIso8601String(),
            },
          );
        });
      }
      return Right(folder);
    } on FirebaseException catch (e) {
      return Left(_mapException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Folder>> updateFolder({
    required String userId,
    required String folderId,
    required String name,
  }) async {
    try {
      final existing = await _local.findById(folderId);
      final now = DateTime.now();
      final folder = Folder(
        id: folderId,
        name: name,
        parentFolderId: existing?.parentFolderId,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        await _local.update(folder, userId: userId, syncStatus: 'synced');
        await _remote.writeFolder(folder, userId);
      } else {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.update(
            FolderTable.tableName,
            {
              'name': folder.name,
              'updatedAt': folder.updatedAt.toIso8601String(),
              'syncStatus': 'pending',
            },
            where: 'id = ?',
            whereArgs: [folderId],
          );
          await _syncQueue.enqueueInTransaction(
            txn,
            operation: 'update',
            tableName: FolderTable.tableName,
            recordId: folder.id,
            payload: {
              'name': folder.name,
              'parentFolderId': folder.parentFolderId,
              'createdAt': folder.createdAt.toIso8601String(),
              'updatedAt': folder.updatedAt.toIso8601String(),
            },
          );
        });
      }
      return Right(folder);
    } on FirebaseException catch (e) {
      return Left(_mapException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFolder({
    required String userId,
    required String folderId,
  }) async {
    try {
      // 配下のサブフォルダ・単語・成績データも含めてカスケード削除する
      final folderIds = await _collectFolderIdsRecursively(userId, folderId);
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        for (final id in folderIds) {
          final words = await _wordLocal.findByFolderId(id, userId: userId);
          for (final word in words) {
            await _wordLocal.delete(word.id);
            await _remote.deleteRemoteWord(userId, id, word.id);
          }
          final results =
              await _testResultLocal.findByUserId(userId, folderId: id);
          for (final result in results) {
            await _testResultLocal.delete(result.id);
            await _remote.deleteRemoteTestResult(userId, result.id);
          }
          await _local.delete(id);
          await _remote.deleteRemoteFolder(userId, id);
        }
      } else {
        // トランザクション内では同一DB接続の別クエリを実行できない(sqfliteがロックされデッドロックする)ため、
        // 削除対象のID収集はトランザクション開始前に完了させる
        final wordsByFolder = <String, List<String>>{};
        final resultIdsByFolder = <String, List<String>>{};
        for (final id in folderIds) {
          final words = await _wordLocal.findByFolderId(id, userId: userId);
          wordsByFolder[id] = words.map((w) => w.id).toList();
          final results =
              await _testResultLocal.findByUserId(userId, folderId: id);
          resultIdsByFolder[id] = results.map((r) => r.id).toList();
        }

        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          for (final id in folderIds) {
            for (final wordId in wordsByFolder[id]!) {
              await txn.delete(
                WordTable.tableName,
                where: 'id = ?',
                whereArgs: [wordId],
              );
              await _syncQueue.enqueueInTransaction(
                txn,
                operation: 'delete',
                tableName: WordTable.tableName,
                recordId: wordId,
                parentId: id,
              );
            }
            for (final resultId in resultIdsByFolder[id]!) {
              await txn.delete(
                TestResultTable.tableName,
                where: 'id = ?',
                whereArgs: [resultId],
              );
              await _syncQueue.enqueueInTransaction(
                txn,
                operation: 'delete',
                tableName: TestResultTable.tableName,
                recordId: resultId,
              );
            }
            await txn.delete(
              FolderTable.tableName,
              where: 'id = ?',
              whereArgs: [id],
            );
            await _syncQueue.enqueueInTransaction(
              txn,
              operation: 'delete',
              tableName: FolderTable.tableName,
              recordId: id,
            );
          }
        });
      }
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(_mapException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  /// 指定フォルダとその配下のサブフォルダIDを再帰的に収集する
  Future<List<String>> _collectFolderIdsRecursively(
    String userId,
    String rootFolderId,
  ) async {
    final ids = <String>[rootFolderId];
    final children =
        await _local.findByUserId(userId, parentFolderId: rootFolderId);
    for (final child in children) {
      ids.addAll(await _collectFolderIdsRecursively(userId, child.id));
    }
    return ids;
  }

  Failure _mapException(FirebaseException e) {
    if (e.code == 'unavailable' || e.code == 'network-request-failed') {
      return const Failure.network();
    }
    return Failure.unknown(e.message ?? e.code);
  }
}
