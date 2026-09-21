import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/sign_in_with_google_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';

import '../../../helpers/fake_auth_use_case_repositories.dart';

void main() {
  late FakeAuthRepository fakeRepository;
  late FakeSyncServiceForLogin fakeSyncService;
  late SignInWithGoogleUseCase useCase;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    fakeSyncService = FakeSyncServiceForLogin();
    useCase = SignInWithGoogleUseCase(fakeRepository, fakeSyncService);
  });

  group('SignInWithGoogleUseCase.call', () {
    test('呼び出した場合、Repository.signInWithGoogleに委譲される', () async {
      await useCase.call();

      expect(fakeRepository.signInWithGoogleCallCount, 1);
    });

    test('ログインに成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される', () async {
      const user = AppUser(id: 'u1', email: 'user@example.com');
      fakeRepository.signInWithGoogleResult = const Right(user);

      final result = await useCase.call();

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });

    test('ログインに失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない', () async {
      fakeRepository.signInWithGoogleResult = const Left(Failure.auth());

      final result = await useCase.call();

      expect(result, const Left<Failure, AppUser>(Failure.auth()));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 0);
    });

    test('ログイン成功後の同期処理で例外が発生した場合、例外は握りつぶされログイン結果はそのまま返る', () async {
      const user = AppUser(id: 'u1', email: 'user@example.com');
      fakeRepository.signInWithGoogleResult = const Right(user);
      fakeSyncService.exceptionToThrow = Exception('sync failed');

      final result = await useCase.call();

      expect(result, const Right<Failure, AppUser>(user));
      expect(fakeSyncService.syncRemoteToLocalOnLoginCallCount, 1);
    });
  });
}
