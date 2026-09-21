import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/sign_in_with_email_use_case.dart';
import 'package:word_stock/application/use_cases/auth/sign_in_with_google_use_case.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/sync_status_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/presentation/auth/login/login_view_model.dart';

const _testAppUser = AppUser(id: 'user-1', email: 'user@example.com');

/// SignInWithEmailUseCase の手書き Fake。
/// `results` を呼び出しごとに先頭から消費し、`pendingCompleter` があれば
/// それが complete されるまで応答を保留する（呼び出し中の中間状態を検証するため）。
class FakeSignInWithEmailUseCase implements SignInWithEmailUseCase {
  FakeSignInWithEmailUseCase(this.results, {this.pendingCompleter});

  final List<Either<Failure, AppUser>> results;
  final Completer<void>? pendingCompleter;
  int callCount = 0;

  @override
  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) async {
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    final result = results[callCount < results.length ? callCount : results.length - 1];
    callCount++;
    return result;
  }
}

/// SignInWithGoogleUseCase の手書き Fake。
class FakeSignInWithGoogleUseCase implements SignInWithGoogleUseCase {
  FakeSignInWithGoogleUseCase(this.results, {this.pendingCompleter});

  final List<Either<Failure, AppUser>> results;
  final Completer<void>? pendingCompleter;
  int callCount = 0;

  @override
  Future<Either<Failure, AppUser>> call() async {
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    final result = results[callCount < results.length ? callCount : results.length - 1];
    callCount++;
    return result;
  }
}

ProviderContainer _makeContainer({
  SignInWithEmailUseCase? signInWithEmailUseCase,
  SignInWithGoogleUseCase? signInWithGoogleUseCase,
}) {
  final container = ProviderContainer(overrides: [
    if (signInWithEmailUseCase != null)
      signInWithEmailUseCaseProvider.overrideWithValue(signInWithEmailUseCase),
    if (signInWithGoogleUseCase != null)
      signInWithGoogleUseCaseProvider.overrideWithValue(signInWithGoogleUseCase),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('LoginViewModel.build', () {
    test('初期状態は isLoading/isSuccess が false で errorMessage が null になる', () {
      final container = _makeContainer();

      final state = container.read(loginViewModelProvider);

      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });
  });

  group('LoginViewModel.signInWithEmail', () {
    test('成功した場合、isLoading が false・isSuccess が true になる', () async {
      final container = _makeContainer(
        signInWithEmailUseCase:
            FakeSignInWithEmailUseCase([const Right(_testAppUser)]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');

      final state = container.read(loginViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('呼び出し中は isLoading が true になり同期フラグが立ち、完了後にフラグが戻る', () async {
      final completer = Completer<void>();
      final container = _makeContainer(
        signInWithEmailUseCase: FakeSignInWithEmailUseCase(
          [const Right(_testAppUser)],
          pendingCompleter: completer,
        ),
      );
      // autoDispose のため、購読を保持しないと非同期処理の途中で
      // プロバイダが破棄され state が initial に戻ってしまう。
      container.listen(loginViewModelProvider, (_, __) {}, fireImmediately: true);
      final notifier = container.read(loginViewModelProvider.notifier);

      final future =
          notifier.signInWithEmail(email: 'a@example.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      final loadingState = container.read(loginViewModelProvider);
      expect(loadingState.isLoading, isTrue);
      expect(loadingState.isSuccess, isFalse);
      expect(container.read(authSyncInProgressProvider), isTrue);

      completer.complete();
      await future;

      expect(container.read(authSyncInProgressProvider), isFalse);
    });

    test('NetworkFailure の場合、通信エラーメッセージになる', () async {
      final container = _makeContainer(
        signInWithEmailUseCase:
            FakeSignInWithEmailUseCase([const Left(Failure.network())]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');

      final state = container.read(loginViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, '通信エラーが発生しました');
    });

    test('AuthFailure の場合、メール/パスワード不一致メッセージになる', () async {
      final container = _makeContainer(
        signInWithEmailUseCase:
            FakeSignInWithEmailUseCase([const Left(Failure.auth())]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, 'メールアドレスまたはパスワードが正しくありません');
    });

    test('NotFoundFailure の場合、アカウントが見つからないメッセージになる', () async {
      final container = _makeContainer(
        signInWithEmailUseCase:
            FakeSignInWithEmailUseCase([const Left(Failure.notFound())]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, 'アカウントが見つかりません');
    });

    test('UnknownFailure の場合、元のメッセージを含んだエラーメッセージになる', () async {
      final container = _makeContainer(
        signInWithEmailUseCase: FakeSignInWithEmailUseCase(
          [const Left(Failure.unknown('boom'))],
        ),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, 'エラーが発生しました: boom');
    });

    test('失敗後に再度成功した場合、errorMessage がクリアされ isSuccess が true になる', () async {
      final container = _makeContainer(
        signInWithEmailUseCase: FakeSignInWithEmailUseCase([
          const Left(Failure.network()),
          const Right(_testAppUser),
        ]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');
      expect(container.read(loginViewModelProvider).errorMessage, isNotNull);

      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, isNull);
      expect(state.isSuccess, isTrue);
    });
  });

  group('LoginViewModel.signInWithGoogle', () {
    test('成功した場合、isLoading が false・isSuccess が true になる', () async {
      final container = _makeContainer(
        signInWithGoogleUseCase:
            FakeSignInWithGoogleUseCase([const Right(_testAppUser)]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithGoogle();

      final state = container.read(loginViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('呼び出し中は isLoading が true になり同期フラグが立ち、完了後にフラグが戻る', () async {
      final completer = Completer<void>();
      final container = _makeContainer(
        signInWithGoogleUseCase: FakeSignInWithGoogleUseCase(
          [const Right(_testAppUser)],
          pendingCompleter: completer,
        ),
      );
      // autoDispose のため、購読を保持しないと非同期処理の途中で
      // プロバイダが破棄され state が initial に戻ってしまう。
      container.listen(loginViewModelProvider, (_, __) {}, fireImmediately: true);
      final notifier = container.read(loginViewModelProvider.notifier);

      final future = notifier.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(loginViewModelProvider).isLoading, isTrue);
      expect(container.read(authSyncInProgressProvider), isTrue);

      completer.complete();
      await future;

      expect(container.read(authSyncInProgressProvider), isFalse);
    });

    test('NetworkFailure の場合、通信エラーメッセージになる', () async {
      final container = _makeContainer(
        signInWithGoogleUseCase:
            FakeSignInWithGoogleUseCase([const Left(Failure.network())]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithGoogle();

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, '通信エラーが発生しました');
    });

    test('AuthFailure の場合、Google ログイン失敗メッセージになる（Emailとは異なる文言）', () async {
      final container = _makeContainer(
        signInWithGoogleUseCase:
            FakeSignInWithGoogleUseCase([const Left(Failure.auth())]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithGoogle();

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, 'Google ログインに失敗しました');
    });

    test('NotFoundFailure の場合、アカウントが見つからないメッセージになる', () async {
      final container = _makeContainer(
        signInWithGoogleUseCase:
            FakeSignInWithGoogleUseCase([const Left(Failure.notFound())]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithGoogle();

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, 'アカウントが見つかりません');
    });

    test('UnknownFailure の場合、元のメッセージを含んだエラーメッセージになる', () async {
      final container = _makeContainer(
        signInWithGoogleUseCase: FakeSignInWithGoogleUseCase(
          [const Left(Failure.unknown('boom'))],
        ),
      );
      final notifier = container.read(loginViewModelProvider.notifier);

      await notifier.signInWithGoogle();

      final state = container.read(loginViewModelProvider);
      expect(state.errorMessage, 'エラーが発生しました: boom');
    });
  });

  group('LoginViewModel.resetState', () {
    test('呼び出すと state が初期状態に戻る', () async {
      final container = _makeContainer(
        signInWithEmailUseCase:
            FakeSignInWithEmailUseCase([const Left(Failure.network())]),
      );
      final notifier = container.read(loginViewModelProvider.notifier);
      await notifier.signInWithEmail(email: 'a@example.com', password: 'pw');
      expect(container.read(loginViewModelProvider).errorMessage, isNotNull);

      notifier.resetState();

      final state = container.read(loginViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });
  });
}
