import 'dart:developer' show log;

import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/repositories/auth_repository.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository, this._syncService);

  final AuthRepository _repository;
  final SyncService _syncService;

  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) async {
    final result = await _repository.signUpWithEmail(
        email: email, password: password);
    await result.fold(
      (_) async {},
      (_) async {
        try {
          await _syncService.syncRemoteToLocalOnLogin();
        } catch (e, stack) {
          log('syncRemoteToLocalOnLogin failed: $e\n$stack');
        }
      },
    );
    return result;
  }
}
