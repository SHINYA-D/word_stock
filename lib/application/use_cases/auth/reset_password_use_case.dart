import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/repositories/auth_repository.dart';

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call({required String email}) {
    return _repository.sendPasswordResetEmail(email: email);
  }
}
