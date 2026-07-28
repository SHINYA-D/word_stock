import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';

class UpdateSettingsUseCase {
  const UpdateSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String userId,
    required UserSettings settings,
  }) {
    return _repository.updateSettings(userId: userId, settings: settings);
  }
}
