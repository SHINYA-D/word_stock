import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';
import 'package:word_stock/infrastructure/data_sources/firestore_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/settings_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required SettingsLocalDataSource localDataSource,
    required FirestoreDataSource remoteDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required ConnectivityMonitor connectivityMonitor,
  })  : _local = localDataSource,
        _remote = remoteDataSource,
        _syncQueue = syncQueueDataSource,
        _dbHelper = dbHelper,
        _connectivity = connectivityMonitor;

  final SettingsLocalDataSource _local;
  final FirestoreDataSource _remote;
  final SyncQueueDataSource _syncQueue;
  final DatabaseHelper _dbHelper;
  final ConnectivityMonitor _connectivity;

  @override
  Future<Either<Failure, UserSettings>> getSettings({
    required String userId,
  }) async {
    try {
      final local = await _local.findByUserId(userId);
      if (local != null) return Right(local);
      return const Right(UserSettings());
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateSettings({
    required String userId,
    required UserSettings settings,
  }) async {
    try {
      final updated = settings.copyWith(updatedAt: DateTime.now());
      final isOnline = await _connectivity.isOnline();

      if (isOnline) {
        await _local.upsert(updated, userId: userId, syncStatus: 'synced');
        await _remote.writeSettings(updated, userId);
      } else {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.insert(
            SettingsTable.tableName,
            {
              'userId': userId,
              'colorTheme': updated.colorTheme,
              'darkMode': updated.darkMode ? 1 : 0,
              'updatedAt':
                  (updated.updatedAt ?? DateTime.now()).toIso8601String(),
              'syncStatus': 'pending',
            },
            conflictAlgorithm: ConflictAlgorithm.replace
          );
          await _syncQueue.enqueueInTransaction(
            txn,
            operation: 'update',
            tableName: SettingsTable.tableName,
            recordId: userId,
            payload: {
              'colorTheme': updated.colorTheme,
              'darkMode': updated.darkMode,
              'updatedAt':
                  (updated.updatedAt ?? DateTime.now()).toIso8601String(),
            },
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
