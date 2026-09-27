import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/repositories/folder_repository.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/folder_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

/// 読み取りはローカルだけから行う。登録・編集・削除は、オンライン・オフラインに関係なく
/// ローカルへの保存とキューへの登録を同じトランザクションで行い、その後に送信を依頼する。
class FolderRepositoryImpl implements FolderRepository {
  FolderRepositoryImpl({
    required FolderLocalDataSource localDataSource,
    required WordLocalDataSource wordLocalDataSource,
    required FlashcardResultLocalDataSource flashcardResultLocalDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required void Function() onLocalChanged,
  })  : _local = localDataSource,
        _wordLocal = wordLocalDataSource,
        _flashcardResultLocal = flashcardResultLocalDataSource,
        _syncQueue = syncQueueDataSource,
        _dbHelper = dbHelper,
        _onLocalChanged = onLocalChanged;

  final FolderLocalDataSource _local;
  final WordLocalDataSource _wordLocal;
  final FlashcardResultLocalDataSource _flashcardResultLocal;
  final SyncQueueDataSource _syncQueue;
  final DatabaseHelper _dbHelper;
  final void Function() _onLocalChanged;

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
      final db = await _dbHelper.database;
      final saved = await db.transaction((txn) async {
        if (parentFolderId != null &&
            await _local.findActive(txn, parentFolderId, userId: userId) == null) {
          return false;
        }
        await _local.save(txn, folder, userId: userId, syncStatus: 'pending');
        await _enqueue(txn, userId, FolderTable.tableName, folder.id);
        return true;
      });
      if (!saved) return const Left(Failure.notFound());
      _onLocalChanged();
      return Right(folder);
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
      final db = await _dbHelper.database;
      final updated = await db.transaction((txn) async {
        final existing = await _local.findActive(txn, folderId, userId: userId);
        if (existing == null) return null;
        final folder = existing.copyWith(name: name, updatedAt: DateTime.now());
        await _local.save(txn, folder, userId: userId, syncStatus: 'pending');
        await _enqueue(txn, userId, FolderTable.tableName, folderId);
        return folder;
      });
      if (updated == null) return const Left(Failure.notFound());
      _onLocalChanged();
      return Right(updated);
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
      final db = await _dbHelper.database;
      final deleted = await db.transaction((txn) async {
        if (await _local.findActive(txn, folderId, userId: userId) == null) {
          return false;
        }
        // 配下のサブフォルダ・単語・成績も、同じ時刻で論理削除する（カスケード削除）
        final now = DateTime.now();
        for (final id in await _collectFolderIds(txn, userId, folderId)) {
          for (final wordId
              in await _wordLocal.findActiveIdsByFolder(txn, id, userId: userId)) {
            await _wordLocal.markDeleted(txn, wordId, now);
            await _enqueue(txn, userId, WordTable.tableName, wordId,
                isDelete: true, parentId: id);
          }
          for (final resultId in await _flashcardResultLocal
              .findActiveIdsByFolder(txn, id, userId: userId)) {
            await _flashcardResultLocal.markDeleted(txn, resultId, now);
            await _enqueue(txn, userId, FlashcardResultTable.tableName, resultId,
                isDelete: true);
          }
          await _local.markDeleted(txn, id, now);
          await _enqueue(txn, userId, FolderTable.tableName, id, isDelete: true);
        }
        return true;
      });
      if (!deleted) return const Left(Failure.notFound());
      _onLocalChanged();
      return const Right(unit);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  /// 指定フォルダとその配下の未削除のサブフォルダ id（深い方が先）
  Future<List<String>> _collectFolderIds(
    DatabaseExecutor txn,
    String userId,
    String rootFolderId,
  ) async {
    final ids = <String>[];
    for (final child
        in await _local.findActiveChildIds(txn, rootFolderId, userId: userId)) {
      ids.addAll(await _collectFolderIds(txn, userId, child));
    }
    ids.add(rootFolderId);
    return ids;
  }

  Future<void> _enqueue(
    DatabaseExecutor txn,
    String userId,
    String tableName,
    String recordId, {
    bool isDelete = false,
    String? parentId,
  }) {
    return _syncQueue.enqueueInTransaction(
      txn,
      operation: SyncService.operationFor(isDelete: isDelete),
      tableName: tableName,
      recordId: recordId,
      parentId: parentId,
      userId: userId,
    );
  }
}
