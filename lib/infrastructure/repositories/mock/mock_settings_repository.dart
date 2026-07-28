import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';

/// 開発用インメモリ設定リポジトリ。
class MockSettingsRepository implements SettingsRepository {
  final _store = <String, UserSettings>{};

  @override
  Future<Either<Failure, UserSettings>> getSettings({
    required String userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Right(_store[userId] ?? const UserSettings());
  }

  @override
  Future<Either<Failure, Unit>> updateSettings({
    required String userId,
    required UserSettings settings,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _store[userId] = settings;
    return const Right(unit);
  }
}
