import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';
import 'package:word_stock/infrastructure/data_sources/firestore_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/word_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';

class WordRepositoryImpl implements WordRepository {
  WordRepositoryImpl({
    required WordLocalDataSource localDataSource,
    required FirestoreDataSource remoteDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required ConnectivityMonitor connectivityMonitor,
  })  : _local = localDataSource,
        _remote = remoteDataSource,
        _syncQueue = syncQueueDataSource,
        _dbHelper = dbHelper,
        _connectivity = connectivityMonitor;

  final WordLocalDataSource _local;
  final FirestoreDataSource _remote;
  final SyncQueueDataSource _syncQueue;
  final DatabaseHelper _dbHelper;
  final ConnectivityMonitor _connectivity;

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
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        await _local.insert(word,
            userId: userId, folderId: folderId, syncStatus: 'synced');
        await _remote.writeWord(word, userId, folderId);
      } else {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.insert(
            WordTable.tableName,
            {
              'id': word.id,
              'front': word.front,
              'back': word.back,
              'folderId': folderId,
              'userId': userId,
              'createdAt': word.createdAt.toIso8601String(),
              'updatedAt': word.updatedAt.toIso8601String(),
              'syncStatus': 'pending',
            },
          );
          await _syncQueue.enqueueInTransaction(
            txn,
            operation: 'create',
            tableName: WordTable.tableName,
            recordId: word.id,
            parentId: folderId,
            payload: {
              'front': word.front,
              'back': word.back,
              'createdAt': word.createdAt.toIso8601String(),
              'updatedAt': word.updatedAt.toIso8601String(),
            },
          );
        });
      }
      return Right(word);
    } on FirebaseException catch (e) {
      return Left(_mapException(e));
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
      final existing = await _local.findById(wordId);
      final now = DateTime.now();
      final word = Word(
        id: wordId,
        front: front,
        back: back,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        await _local.update(word,
            userId: userId, folderId: folderId, syncStatus: 'synced');
        await _remote.writeWord(word, userId, folderId);
      } else {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.update(
            WordTable.tableName,
            {
              'front': word.front,
              'back': word.back,
              'updatedAt': word.updatedAt.toIso8601String(),
              'syncStatus': 'pending',
            },
            where: 'id = ?',
            whereArgs: [wordId],
          );
          await _syncQueue.enqueueInTransaction(
            txn,
            operation: 'update',
            tableName: WordTable.tableName,
            recordId: word.id,
            parentId: folderId,
            payload: {
              'front': word.front,
              'back': word.back,
              'createdAt': word.createdAt.toIso8601String(),
              'updatedAt': word.updatedAt.toIso8601String(),
            },
          );
        });
      }
      return Right(word);
    } on FirebaseException catch (e) {
      return Left(_mapException(e));
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
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        await _local.delete(wordId);
        await _remote.deleteRemoteWord(userId, folderId, wordId);
      } else {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
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
            parentId: folderId,
          );
        });
      }
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(_mapException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  Failure _mapException(FirebaseException e) {
    if (e.code == 'unavailable' || e.code == 'network-request-failed') {
      return const Failure.network();
    }
    return Failure.unknown(e.message ?? e.code);
  }
}
