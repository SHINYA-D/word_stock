import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/sign_up_use_case.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/sync_status_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_auth_repository.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';
import 'package:word_stock/presentation/auth/sign_up/sign_up_view_model.dart';

/// [SignUpUseCase] はインターフェースではなく具象クラスのため、テストでは
/// 実 Firestore/SQLite 通信を避けつつコンストラクタの型要件を満たすために
/// [MockAuthRepository] と `fake_cloud_firestore` の [FakeFirebaseFirestore] を渡し、
/// 呼び出し対象の `call()` のみをオーバーライドして振る舞いを差し替える。
///
/// `delayCompleter` を渡すと、`call()` は完了を待ってから結果を返す。
/// これにより、呼び出し中（await 中）の中間状態を検証できる。
class FakeSignUpUseCase extends SignUpUseCase {
  FakeSignUpUseCase(this.result, {this.delayCompleter})
      : super(
          MockAuthRepository(),
          SyncService(
            syncQueueDataSource: SyncQueueDataSource(DatabaseHelper()),
            firestore: FakeFirebaseFirestore(),
            getCurrentUserId: () => 'test-user',
            dbHelper: DatabaseHelper(),
          ),
        );

  final Either<Failure, AppUser> result;
  final Completer<void>? delayCompleter;
  int callCount = 0;
  final List<Map<String, String>> receivedCalls = [];

  @override
  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) async {
    callCount++;
    receivedCalls.add({'email': email, 'password': password});
    if (delayCompleter != null) {
      await delayCompleter!.future;
    }
    return result;
  }
}

const _testUser = AppUser(id: 'user-1', email: 'new@example.com');

ProviderContainer _makeContainer(SignUpUseCase signUpUseCase) {
  final container = ProviderContainer(overrides: [
    signUpUseCaseProvider.overrideWithValue(signUpUseCase),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SignUpViewModel.build', () {
    test('初期状態は isLoading/isSuccess が false で errorMessage が null', () {
      final container = _makeContainer(FakeSignUpUseCase(const Right(_testUser)));

      final state = container.read(signUpViewModelProvider);

      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });
  });

  group('SignUpViewModel.signUp', () {
    test('成功した場合、isSuccess が true になり isLoading は false に戻る', () async {
      final useCase = FakeSignUpUseCase(const Right(_testUser));
      final container = _makeContainer(useCase);

      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');

      final state = container.read(signUpViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('成功した場合、SignUpUseCase に email と password がそのまま渡される', () async {
      final useCase = FakeSignUpUseCase(const Right(_testUser));
      final container = _makeContainer(useCase);

      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'foo@example.com', password: 'secret');

      expect(useCase.callCount, 1);
      expect(
        useCase.receivedCalls.single,
        {'email': 'foo@example.com', 'password': 'secret'},
      );
    });

    test('呼び出し中は isLoading が true になり isSuccess/errorMessage はリセットされる', () async {
      final completer = Completer<void>();
      final useCase = FakeSignUpUseCase(
        const Right(_testUser),
        delayCompleter: completer,
      );
      final container = _makeContainer(useCase);

      final future = container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');

      final loadingState = container.read(signUpViewModelProvider);
      expect(loadingState.isLoading, isTrue);
      expect(loadingState.isSuccess, isFalse);
      expect(loadingState.errorMessage, isNull);

      completer.complete();
      await future;
    });

    test('呼び出し中は authSyncInProgressProvider が true になり、完了後に false へ戻る', () async {
      final completer = Completer<void>();
      final useCase = FakeSignUpUseCase(
        const Right(_testUser),
        delayCompleter: completer,
      );
      final container = _makeContainer(useCase);

      final future = container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');

      expect(container.read(authSyncInProgressProvider), isTrue);

      completer.complete();
      await future;

      expect(container.read(authSyncInProgressProvider), isFalse);
    });

    test('NetworkFailure の場合、通信エラーメッセージが設定される', () async {
      final container =
          _makeContainer(FakeSignUpUseCase(const Left(Failure.network())));

      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');

      final state = container.read(signUpViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, '通信エラーが発生しました');
    });

    test('AuthFailure の場合、メール重複エラーメッセージが設定される', () async {
      final container =
          _makeContainer(FakeSignUpUseCase(const Left(Failure.auth())));

      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'dup@example.com', password: 'password123');

      final state = container.read(signUpViewModelProvider);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, 'このメールアドレスはすでに使用されています');
    });

    test('NotFoundFailure の場合、汎用エラーメッセージが設定される', () async {
      final container =
          _makeContainer(FakeSignUpUseCase(const Left(Failure.notFound())));

      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');

      final state = container.read(signUpViewModelProvider);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, 'エラーが発生しました');
    });

    test('UnknownFailure の場合、メッセージ付きの汎用エラーメッセージが設定される', () async {
      final container = _makeContainer(
        FakeSignUpUseCase(const Left(Failure.unknown('boom'))),
      );

      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');

      final state = container.read(signUpViewModelProvider);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, 'エラーが発生しました: boom');
    });

    test('失敗した場合でも authSyncInProgressProvider は false に戻る', () async {
      final container =
          _makeContainer(FakeSignUpUseCase(const Left(Failure.network())));

      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');

      expect(container.read(authSyncInProgressProvider), isFalse);
    });
  });

  group('SignUpViewModel.resetState', () {
    test('成功状態から呼び出すと初期状態に戻る', () async {
      final container = _makeContainer(FakeSignUpUseCase(const Right(_testUser)));
      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');
      expect(container.read(signUpViewModelProvider).isSuccess, isTrue);

      container.read(signUpViewModelProvider.notifier).resetState();

      final state = container.read(signUpViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('エラー状態から呼び出すと errorMessage がクリアされる', () async {
      final container =
          _makeContainer(FakeSignUpUseCase(const Left(Failure.network())));
      await container
          .read(signUpViewModelProvider.notifier)
          .signUp(email: 'new@example.com', password: 'password123');
      expect(
        container.read(signUpViewModelProvider).errorMessage,
        isNotNull,
      );

      container.read(signUpViewModelProvider.notifier).resetState();

      final state = container.read(signUpViewModelProvider);
      expect(state.errorMessage, isNull);
      expect(state.isSuccess, isFalse);
    });
  });
}
