import 'dart:developer' show log;

import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/repositories/auth_repository.dart';
import 'package:word_stock/domain/repositories/sync_repository.dart';

class SignInWithEmailUseCase {
  const SignInWithEmailUseCase(this._repository, this._syncService);

  final AuthRepository _repository;
  final SyncRepository _syncService;

  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) async {
    final result =
        await _repository.signInWithEmail(email: email, password: password);
    await result.fold(
      (_) async {},
      (_) async {
        try {
          await _syncService.syncRemoteToLocalOnLogin();
        } catch (e, stack) {
          // 同期失敗はログインの成否には影響させない（後続の resumed 同期で回復する）
          log('syncRemoteToLocalOnLogin failed: $e\n$stack');
        }
      },
    );
    return result;
  }
}
