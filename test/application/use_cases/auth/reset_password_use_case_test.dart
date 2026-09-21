import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/reset_password_use_case.dart';
import 'package:word_stock/core/error/failure.dart';

import '../../../helpers/fake_auth_use_case_repositories.dart';

void main() {
  late FakeAuthRepository fakeRepository;
  late ResetPasswordUseCase useCase;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    useCase = ResetPasswordUseCase(fakeRepository);
  });

  group('ResetPasswordUseCase.call', () {
    test('メールアドレスを指定して呼び出した場合、Repositoryに同じメールアドレスで委譲される', () async {
      await useCase.call(email: 'user@example.com');

      expect(fakeRepository.sendPasswordResetEmailCallCount, 1);
      expect(fakeRepository.receivedResetPasswordEmail, 'user@example.com');
    });

    test('Repositoryが成功を返した場合、その値がそのまま返る', () async {
      fakeRepository.sendPasswordResetEmailResult = const Right(unit);

      final result = await useCase.call(email: 'user@example.com');

      expect(result, const Right<Failure, Unit>(unit));
    });

    test('Repositoryが失敗を返した場合、その値がそのまま返る', () async {
      fakeRepository.sendPasswordResetEmailResult =
          const Left(Failure.network());

      final result = await useCase.call(email: 'user@example.com');

      expect(result, const Left<Failure, Unit>(Failure.network()));
    });
  });
}
