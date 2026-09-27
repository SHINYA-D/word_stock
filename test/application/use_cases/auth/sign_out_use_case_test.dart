import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/sign_out_use_case.dart';
import 'package:word_stock/core/error/failure.dart';

import '../../../helpers/fake_auth_use_case_repositories.dart';

/// 呼び出し順を記録するための共有リスト。
/// 共有ヘルパー（`fake_auth_use_case_repositories.dart`）は変更せず、
/// このテストファイル内だけで順序記録用の薄いラッパーを用意する。
class _RecordingSyncService extends FakeSyncServiceForLogin {
  _RecordingSyncService(this.callOrder);

  final List<String> callOrder;

  @override
  Future<int> pushBeforeSignOut() async {
    callOrder.add('pushBeforeSignOut');
    return super.pushBeforeSignOut();
  }
}

class _RecordingAuthRepository extends FakeAuthRepository {
  _RecordingAuthRepository(this.callOrder);

  final List<String> callOrder;

  @override
  Future<Either<Failure, Unit>> signOut() async {
    callOrder.add('signOut');
    return super.signOut();
  }
}

void main() {
  late FakeAuthRepository fakeRepository;
  late FakeSyncServiceForLogin fakeSyncRepository;
  late SignOutUseCase useCase;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    fakeSyncRepository = FakeSyncServiceForLogin();
    useCase = SignOutUseCase(fakeRepository, fakeSyncRepository);
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

    test('呼び出した場合、ログアウト前の送信(pushBeforeSignOut)が1回呼ばれる', () async {
      await useCase.call();

      expect(fakeSyncRepository.pushBeforeSignOutCallCount, 1);
    });

    test('呼び出した場合、送信(pushBeforeSignOut)がRepository.signOutより先に呼ばれる', () async {
      final callOrder = <String>[];
      final recordingUseCase = SignOutUseCase(
        _RecordingAuthRepository(callOrder),
        _RecordingSyncService(callOrder),
      );

      await recordingUseCase.call();

      expect(callOrder, ['pushBeforeSignOut', 'signOut']);
    });

    test('未送信が残っていても(pendingCountAfterPush > 0)、ログアウトする', () async {
      fakeSyncRepository.pendingCountAfterPush = 3;

      final result = await useCase.call();

      expect(fakeRepository.signOutCallCount, 1);
      expect(result, const Right<Failure, Unit>(unit));
    });
  });
}
