import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/repositories/flashcard_result_repository.dart';
import 'package:word_stock/infrastructure/data_sources/firestore_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/flashcard_result_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';

class FlashcardResultRepositoryImpl implements FlashcardResultRepository {
  FlashcardResultRepositoryImpl({
    required FlashcardResultLocalDataSource localDataSource,
    required FirestoreDataSource remoteDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required ConnectivityMonitor connectivityMonitor,
  })  : _local = localDataSource,
        _remote = remoteDataSource,
        _syncQueue = syncQueueDataSource,
        _dbHelper = dbHelper,
        _connectivity = connectivityMonitor;

  final FlashcardResultLocalDataSource _local;
  final FirestoreDataSource _remote;
  final SyncQueueDataSource _syncQueue;
  final DatabaseHelper _dbHelper;
  final ConnectivityMonitor _connectivity;

  static const _uuid = Uuid();

  @override
  Future<Either<Failure, List<FlashcardResult>>> getFlashcardResults({
    required String userId,
    String? folderId,
  }) async {
    try {
      final results = await _local.findByUserId(userId, folderId: folderId);
      return Right(results);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FlashcardResult>> saveFlashcardResult({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  }) async {
    try {
      final now = DateTime.now();
      final result = FlashcardResult(
        id: _uuid.v4(),
        folderId: folderId,
        totalCount: totalCount,
        correctCount: correctCount,
        date: now,
        updatedAt: now,
      );
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        await _local.insert(result, userId: userId, syncStatus: 'synced');
        await _remote.writeFlashcardResult(result, userId);
      } else {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.insert(
            FlashcardResultTable.tableName,
            {
              'id': result.id,
              'folderId': result.folderId,
              'totalCount': result.totalCount,
              'correctCount': result.correctCount,
              'date': result.date.toIso8601String(),
              'userId': userId,
              'updatedAt': result.updatedAt.toIso8601String(),
              'syncStatus': 'pending',
            },
          );
          await _syncQueue.enqueueInTransaction(
            txn,
            operation: 'create',
            tableName: FlashcardResultTable.tableName,
            recordId: result.id,
            payload: {
              'folderId': result.folderId,
              'totalCount': result.totalCount,
              'correctCount': result.correctCount,
              'date': result.date.toIso8601String(),
              'updatedAt': result.updatedAt.toIso8601String(),
            },
          );
        });
      }
      return Right(result);
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
