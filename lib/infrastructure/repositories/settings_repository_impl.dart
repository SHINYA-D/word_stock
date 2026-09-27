import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/settings_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

/// 読み取りはローカルだけから行う。変更は、オンライン・オフラインに関係なく
/// ローカルへの保存とキューへの登録を同じトランザクションで行い、その後に送信を依頼する。
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required SettingsLocalDataSource localDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required void Function() onLocalChanged,
  })  : _local = localDataSource,
        _syncQueue = syncQueueDataSource,
        _dbHelper = dbHelper,
        _onLocalChanged = onLocalChanged;

  final SettingsLocalDataSource _local;
  final SyncQueueDataSource _syncQueue;
  final DatabaseHelper _dbHelper;
  final void Function() _onLocalChanged;

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
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await _local.save(txn, updated, userId: userId, syncStatus: 'pending');
        await _syncQueue.enqueueInTransaction(
          txn,
          operation: SyncService.operationFor(isDelete: false),
          tableName: SettingsTable.tableName,
          recordId: userId,
          userId: userId,
        );
      });
      _onLocalChanged();
      return const Right(unit);
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }
}
