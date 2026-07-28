import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/application/use_cases/settings/get_settings_use_case.dart';
import 'package:word_stock/application/use_cases/settings/update_settings_use_case.dart';
import 'package:word_stock/core/di/repository_providers.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
GetSettingsUseCase getSettingsUseCase(Ref ref) =>
    GetSettingsUseCase(ref.watch(settingsRepositoryProvider));

@Riverpod(keepAlive: true)
UpdateSettingsUseCase updateSettingsUseCase(Ref ref) =>
    UpdateSettingsUseCase(ref.watch(settingsRepositoryProvider));
