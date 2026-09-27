import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

/// 読み取りはローカルだけから行う。登録・編集・削除は、オンライン・オフラインに関係なく
/// ローカルへの保存とキューへの登録を同じトランザクションで行い、その後に送信を依頼する。
class WordRepositoryImpl implements WordRepository {
  WordRepositoryImpl({
    required WordLocalDataSource localDataSource,
    required FolderLocalDataSource folderLocalDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required void Function() onLocalChanged,
  })  : _local = localDataSource,
        _folderLocal = folderLocalDataSource,
        _syncQueue = syncQueueDataSource,
        _dbHelper = dbHelper,
        _onLocalChanged = onLocalChanged;

  final WordLocalDataSource _local;
  final FolderLocalDataSource _folderLocal;
  final SyncQueueDataSource _syncQueue;
  final DatabaseHelper _dbHelper;
  final void Function() _onLocalChanged;

  static const _uuid = Uuid();

  @override
  Future<Either<Failure, List<Word>>> getWords({
    required String userId,
    required String folderId,
  }) async {
    try {
      final words = await _local.findByFolderId(folderId, userId: userId);
      return Right(words);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Word>> createWord({
    required String userId,
    required String folderId,
    required String front,
    required String back,
  }) async {
    try {
      final now = DateTime.now();
      final word = Word(
        id: _uuid.v4(),
        front: front,
        back: back,
        createdAt: now,
        updatedAt: now,
      );
      final db = await _dbHelper.database;
      final saved = await db.transaction((txn) async {
        if (await _folderLocal.findActive(txn, folderId, userId: userId) == null) {
          return false;
        }
        await _local.save(txn, word,
            userId: userId, folderId: folderId, syncStatus: 'pending');
        await _enqueue(txn, userId, word.id, folderId);
        return true;
      });
      if (!saved) return const Left(Failure.notFound());
      _onLocalChanged();
      return Right(word);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Word>> updateWord({
    required String userId,
    required String folderId,
    required String wordId,
    required String front,
    required String back,
  }) async {
    try {
      final db = await _dbHelper.database;
      final updated = await db.transaction((txn) async {
        final existing = await _local.findActive(txn, wordId, userId: userId);
        if (existing == null) return null;
        final word = existing.copyWith(
          front: front,
          back: back,
          updatedAt: DateTime.now(),
        );
        await _local.save(txn, word,
            userId: userId, folderId: folderId, syncStatus: 'pending');
        await _enqueue(txn, userId, wordId, folderId);
        return word;
      });
      if (updated == null) return const Left(Failure.notFound());
      _onLocalChanged();
      return Right(updated);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteWord({
    required String userId,
    required String folderId,
    required String wordId,
  }) async {
    try {
      final db = await _dbHelper.database;
      final deleted = await db.transaction((txn) async {
        if (await _local.findActive(txn, wordId, userId: userId) == null) {
          return false;
        }
        await _local.markDeleted(txn, wordId, DateTime.now());
        await _enqueue(txn, userId, wordId, folderId, isDelete: true);
        return true;
      });
      if (!deleted) return const Left(Failure.notFound());
      _onLocalChanged();
      return const Right(unit);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  Future<void> _enqueue(
    DatabaseExecutor txn,
    String userId,
    String wordId,
    String folderId, {
    bool isDelete = false,
  }) {
    return _syncQueue.enqueueInTransaction(
      txn,
      operation: SyncService.operationFor(isDelete: isDelete),
      tableName: WordTable.tableName,
      recordId: wordId,
      parentId: folderId,
      userId: userId,
    );
  }
}
