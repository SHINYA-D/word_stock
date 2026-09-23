import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/settings/get_settings_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.getSettingsResult});

  Either<Failure, UserSettings>? getSettingsResult;

  String? capturedUserId;

  @override
  Future<Either<Failure, UserSettings>> getSettings({
    required String userId,
  }) async {
    capturedUserId = userId;
    return getSettingsResult!;
  }

  @override
  Future<Either<Failure, Unit>> updateSettings({
    required String userId,
    required UserSettings settings,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('GetSettingsUseCase.call', () {
    test('正しい引数でRepositoryに委譲し、Rightがそのまま返る', () async {
      final settings = UserSettings(
        colorTheme: 'indigo',
        darkMode: true,
        updatedAt: DateTime(2024, 1, 1),
      );
      final repository = _FakeSettingsRepository(
        getSettingsResult: Right<Failure, UserSettings>(settings),
      );
      final useCase = GetSettingsUseCase(repository);

      final result = await useCase(userId: 'u1');

      expect(repository.capturedUserId, 'u1');
      expect(result, equals(Right<Failure, UserSettings>(settings)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final repository = _FakeSettingsRepository(
        getSettingsResult: const Left<Failure, UserSettings>(
          Failure.network(),
        ),
      );
      final useCase = GetSettingsUseCase(repository);

      final result = await useCase(userId: 'u1');

      expect(
        result,
        equals(const Left<Failure, UserSettings>(Failure.network())),
      );
    });
  });
}
