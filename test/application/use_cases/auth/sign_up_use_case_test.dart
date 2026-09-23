import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/sign_up_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';

import '../../../helpers/fake_auth_use_case_repositories.dart';

void main() {
  late FakeAuthRepository fakeRepository;
  late FakeSyncServiceForLogin fakeSyncService;
  late SignUpUseCase useCase;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    fakeSyncService = FakeSyncServiceForLogin();
    useCase = SignUpUseCase(fakeRepository, fakeSyncService);
  });

  group('SignUpUseCase.call', () {
    test('email/passwordを指定して呼び出した場合、Repositoryに同じ値で委譲される', () async {
      await useCase.call(email: 'new@example.com', password: 'password123');

      expect(fakeRepository.signUpWithEmailCallCount, 1);
      expect(
        fakeRepository.receivedSignUpWithEmail,
        (email: 'new@example.com', password: 'password123'),
      );
    });

    test('登録に成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される', () async {
      const user = AppUser(id: 'u1', email: 'new@example.com');
      fakeRepository.signUpWithEmailResult = const Right(user);

      final result =
          await useCase.call(email: 'new@example.com', password: 'password123');

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });

    test('登録に失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない', () async {
      fakeRepository.signUpWithEmailResult =
          const Left(Failure.unknown('already exists'));

      final result =
          await useCase.call(email: 'new@example.com', password: 'password123');

      expect(
        result,
        const Left<Failure, AppUser>(Failure.unknown('already exists')),
      );
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 0);
    });

    test('登録成功後の同期処理で例外が発生した場合、例外は握りつぶされ登録結果はそのまま返る', () async {
      const user = AppUser(id: 'u1', email: 'new@example.com');
      fakeRepository.signUpWithEmailResult = const Right(user);
      fakeSyncService.exceptionToThrow = Exception('sync failed');

      final result =
          await useCase.call(email: 'new@example.com', password: 'password123');

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });
  });
}
