import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/settings/get_settings_use_case.dart';
import 'package:word_stock/application/use_cases/settings/update_settings_use_case.dart';
import 'package:word_stock/core/di/settings_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/presentation/settings/settings_view_model.dart';

const _userId = 'user-1';

/// GetSettingsUseCase の手書き Fake。
class FakeGetSettingsUseCase implements GetSettingsUseCase {
  FakeGetSettingsUseCase(this.result);

  final Either<Failure, UserSettings> result;
  int callCount = 0;
  String? lastUserId;

  @override
  Future<Either<Failure, UserSettings>> call({required String userId}) async {
    callCount++;
    lastUserId = userId;
    return result;
  }
}

/// UpdateSettingsUseCase の手書き Fake。
class FakeUpdateSettingsUseCase implements UpdateSettingsUseCase {
  FakeUpdateSettingsUseCase(this.result);

  final Either<Failure, Unit> result;
  String? lastUserId;
  UserSettings? lastSettings;

  @override
  Future<Either<Failure, Unit>> call({
    required String userId,
    required UserSettings settings,
  }) async {
    lastUserId = userId;
    lastSettings = settings;
    return result;
  }
}

const _initialSettings = UserSettings(colorTheme: 'indigo', darkMode: false);

ProviderContainer _makeContainer({
  required GetSettingsUseCase getSettingsUseCase,
  UpdateSettingsUseCase? updateSettingsUseCase,
}) {
  final container = ProviderContainer(overrides: [
    getSettingsUseCaseProvider.overrideWithValue(getSettingsUseCase),
    if (updateSettingsUseCase != null)
      updateSettingsUseCaseProvider.overrideWithValue(updateSettingsUseCase),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SettingsViewModel.build', () {
    test('取得に成功した場合、設定値が state に反映される', () async {
      final getSettingsUseCase =
          FakeGetSettingsUseCase(const Right(_initialSettings));
      final container = _makeContainer(getSettingsUseCase: getSettingsUseCase);

      final result =
          await container.read(settingsViewModelProvider(_userId).future);

      expect(result, _initialSettings);
      expect(
        container.read(settingsViewModelProvider(_userId)).value,
        _initialSettings,
      );
      expect(getSettingsUseCase.lastUserId, _userId);
    });

    test('取得に失敗した場合、AsyncError になる', () async {
      final getSettingsUseCase =
          FakeGetSettingsUseCase(const Left(Failure.network()));
      final container = _makeContainer(getSettingsUseCase: getSettingsUseCase);

      await expectLater(
        container.read(settingsViewModelProvider(_userId).future),
        throwsA(const Failure.network()),
      );

      final state = container.read(settingsViewModelProvider(_userId));
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.network());
    });
  });

  group('SettingsViewModel.updateSettings', () {
    test('更新に成功した場合、state が更新後の設定値になる', () async {
      final getSettingsUseCase =
          FakeGetSettingsUseCase(const Right(_initialSettings));
      final updateSettingsUseCase =
          FakeUpdateSettingsUseCase(const Right(unit));
      final container = _makeContainer(
        getSettingsUseCase: getSettingsUseCase,
        updateSettingsUseCase: updateSettingsUseCase,
      );
      await container.read(settingsViewModelProvider(_userId).future);

      final notifier =
          container.read(settingsViewModelProvider(_userId).notifier);
      const newSettings = UserSettings(colorTheme: 'red', darkMode: true);
      await notifier.updateSettings(newSettings);

      final state = container.read(settingsViewModelProvider(_userId));
      expect(state.value, newSettings);
      expect(updateSettingsUseCase.lastUserId, _userId);
      expect(updateSettingsUseCase.lastSettings, newSettings);
    });

    test('更新に失敗した場合、AsyncError になり呼び出し前の設定値は失われる', () async {
      final getSettingsUseCase =
          FakeGetSettingsUseCase(const Right(_initialSettings));
      final updateSettingsUseCase =
          FakeUpdateSettingsUseCase(const Left(Failure.network()));
      final container = _makeContainer(
        getSettingsUseCase: getSettingsUseCase,
        updateSettingsUseCase: updateSettingsUseCase,
      );
      await container.read(settingsViewModelProvider(_userId).future);

      final notifier =
          container.read(settingsViewModelProvider(_userId).notifier);
      const newSettings = UserSettings(colorTheme: 'red', darkMode: true);
      await notifier.updateSettings(newSettings);

      final state = container.read(settingsViewModelProvider(_userId));
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.network());
    });

    test('build 失敗後に updateSettings を呼んでも _userId は build 時の引数のまま使われる', () async {
      final getSettingsUseCase =
          FakeGetSettingsUseCase(const Left(Failure.unknown('boom')));
      final updateSettingsUseCase =
          FakeUpdateSettingsUseCase(const Right(unit));
      final container = _makeContainer(
        getSettingsUseCase: getSettingsUseCase,
        updateSettingsUseCase: updateSettingsUseCase,
      );
      await expectLater(
        container.read(settingsViewModelProvider(_userId).future),
        throwsA(isA<Failure>()),
      );

      final notifier =
          container.read(settingsViewModelProvider(_userId).notifier);
      const newSettings = UserSettings(colorTheme: 'green', darkMode: false);
      await notifier.updateSettings(newSettings);

      expect(updateSettingsUseCase.lastUserId, _userId);
      final state = container.read(settingsViewModelProvider(_userId));
      expect(state.value, newSettings);
    });
  });
}
