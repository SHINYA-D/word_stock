import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/settings/update_settings_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.updateSettingsResult});

  Either<Failure, Unit>? updateSettingsResult;

  String? capturedUserId;
  UserSettings? capturedSettings;

  @override
  Future<Either<Failure, UserSettings>> getSettings({
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> updateSettings({
    required String userId,
    required UserSettings settings,
  }) async {
    capturedUserId = userId;
    capturedSettings = settings;
    return updateSettingsResult!;
  }
}

void main() {
  group('UpdateSettingsUseCase.call', () {
    test('正しい引数でRepositoryに委譲し、Rightがそのまま返る', () async {
      final settings = UserSettings(
        colorTheme: 'teal',
        darkMode: false,
        updatedAt: DateTime(2024, 1, 1),
      );
      final repository = _FakeSettingsRepository(
        updateSettingsResult: const Right<Failure, Unit>(unit),
      );
      final useCase = UpdateSettingsUseCase(repository);

      final result = await useCase(userId: 'u1', settings: settings);

      expect(repository.capturedUserId, 'u1');
      expect(repository.capturedSettings, settings);
      expect(result, equals(const Right<Failure, Unit>(unit)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final settings = UserSettings(
        colorTheme: 'teal',
        darkMode: false,
        updatedAt: DateTime(2024, 1, 1),
      );
      final repository = _FakeSettingsRepository(
        updateSettingsResult: const Left<Failure, Unit>(Failure.unknown('e')),
      );
      final useCase = UpdateSettingsUseCase(repository);

      final result = await useCase(userId: 'u1', settings: settings);

      expect(
        result,
        equals(const Left<Failure, Unit>(Failure.unknown('e'))),
      );
    });
  });
}
