import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/sign_in_with_email_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';

import '../../../helpers/fake_auth_use_case_repositories.dart';

void main() {
  late FakeAuthRepository fakeRepository;
  late FakeSyncServiceForLogin fakeSyncService;
  late SignInWithEmailUseCase useCase;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    fakeSyncService = FakeSyncServiceForLogin();
    useCase = SignInWithEmailUseCase(fakeRepository, fakeSyncService);
  });

  group('SignInWithEmailUseCase.call', () {
    test('email/passwordを指定して呼び出した場合、Repositoryに同じ値で委譲される', () async {
      await useCase.call(email: 'user@example.com', password: 'password123');

      expect(fakeRepository.signInWithEmailCallCount, 1);
      expect(
        fakeRepository.receivedSignInWithEmail,
        (email: 'user@example.com', password: 'password123'),
      );
    });

    test('ログインに成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される', () async {
      const user = AppUser(id: 'u1', email: 'user@example.com');
      fakeRepository.signInWithEmailResult = const Right(user);

      final result =
          await useCase.call(email: 'user@example.com', password: 'password123');

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });

    test('ログインに失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない', () async {
      fakeRepository.signInWithEmailResult = const Left(Failure.auth());

      final result =
          await useCase.call(email: 'user@example.com', password: 'wrong');

      expect(result, const Left<Failure, AppUser>(Failure.auth()));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 0);
    });

    test('ログイン成功後の同期処理で例外が発生した場合、例外は握りつぶされログイン結果はそのまま返る', () async {
      const user = AppUser(id: 'u1', email: 'user@example.com');
      fakeRepository.signInWithEmailResult = const Right(user);
      fakeSyncService.exceptionToThrow = Exception('sync failed');

      final result =
          await useCase.call(email: 'user@example.com', password: 'password123');

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });
  });
}
