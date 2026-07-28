import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/core/di/settings_providers.dart';

part 'settings_view_model.g.dart';

@riverpod
class SettingsViewModel extends _$SettingsViewModel {
  late String _userId;

  @override
  Future<UserSettings> build(String userId) async {
    _userId = userId;
    final result =
        await ref.read(getSettingsUseCaseProvider).call(userId: userId);
    return result.fold((f) => throw f, (v) => v);
  }

  Future<void> updateSettings(UserSettings settings) async {
    final result = await ref.read(updateSettingsUseCaseProvider).call(
          userId: _userId,
          settings: settings,
        );
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (_) => state = AsyncValue.data(settings),
    );
  }
}
