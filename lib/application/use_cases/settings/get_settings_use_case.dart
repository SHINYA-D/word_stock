import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';

class GetSettingsUseCase {
  const GetSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, UserSettings>> call({required String userId}) {
    return _repository.getSettings(userId: userId);
  }
}
