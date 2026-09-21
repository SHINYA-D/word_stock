import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/sign_out_use_case.dart';
import 'package:word_stock/core/error/failure.dart';

import '../../../helpers/fake_auth_use_case_repositories.dart';

void main() {
  late FakeAuthRepository fakeRepository;
  late SignOutUseCase useCase;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    useCase = SignOutUseCase(fakeRepository);
  });

  group('SignOutUseCase.call', () {
    test('呼び出した場合、Repository.signOutに委譲される', () async {
      await useCase.call();

      expect(fakeRepository.signOutCallCount, 1);
    });

    test('Repositoryが成功を返した場合、その値がそのまま返る', () async {
      fakeRepository.signOutResult = const Right(unit);

      final result = await useCase.call();

      expect(result, const Right<Failure, Unit>(unit));
    });

    test('Repositoryが失敗を返した場合、その値がそのまま返る', () async {
      fakeRepository.signOutResult = const Left(Failure.auth());

      final result = await useCase.call();

      expect(result, const Left<Failure, Unit>(Failure.auth()));
    });
  });
}
