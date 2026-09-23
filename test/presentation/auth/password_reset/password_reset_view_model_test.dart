import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/auth/reset_password_use_case.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/presentation/auth/password_reset/password_reset_view_model.dart';

/// ResetPasswordUseCase の手書き Fake。
/// `call()` が呼ばれるたびに引数を記録し、あらかじめ渡された結果を返す。
class FakeResetPasswordUseCase implements ResetPasswordUseCase {
  FakeResetPasswordUseCase(this.result);

  final Either<Failure, Unit> result;

  String? lastEmail;
  int callCount = 0;

  @override
  Future<Either<Failure, Unit>> call({required String email}) async {
    lastEmail = email;
    callCount++;
    return result;
  }
}

ProviderContainer _makeContainer({
  required Either<Failure, Unit> result,
}) {
  final container = ProviderContainer(overrides: [
    resetPasswordUseCaseProvider
        .overrideWithValue(FakeResetPasswordUseCase(result)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('PasswordResetViewModel.build', () {
    test('初期状態の場合、isLoading/isSuccess が false で errorMessage が null になる', () {
      final container = _makeContainer(result: const Right(unit));

      final state = container.read(passwordResetViewModelProvider);

      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });
  });

  group('PasswordResetViewModel.sendResetEmail', () {
    test('送信に成功した場合、isSuccess が true になり isLoading が false に戻る', () async {
      final container = _makeContainer(result: const Right(unit));
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);

      await notifier.sendResetEmail(email: 'test@example.com');

      final state = container.read(passwordResetViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('通信エラーの場合、errorMessage に通信エラー文言が設定される', () async {
      final container = _makeContainer(
        result: const Left(Failure.network()),
      );
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);

      await notifier.sendResetEmail(email: 'test@example.com');

      final state = container.read(passwordResetViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, '通信エラーが発生しました');
    });

    test('認証エラーの場合、errorMessage にメールアドレスが見つからない旨の文言が設定される', () async {
      final container = _makeContainer(
        result: const Left(Failure.auth()),
      );
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);

      await notifier.sendResetEmail(email: 'test@example.com');

      final state = container.read(passwordResetViewModelProvider);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, 'メールアドレスが見つかりません');
    });

    test('アカウント未検出の場合、errorMessage にアカウントが見つからない旨の文言が設定される', () async {
      final container = _makeContainer(
        result: const Left(Failure.notFound()),
      );
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);

      await notifier.sendResetEmail(email: 'test@example.com');

      final state = container.read(passwordResetViewModelProvider);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, 'アカウントが見つかりません');
    });

    test('不明なエラーの場合、errorMessage に元のメッセージを含む文言が設定される', () async {
      final container = _makeContainer(
        result: const Left(Failure.unknown('boom')),
      );
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);

      await notifier.sendResetEmail(email: 'test@example.com');

      final state = container.read(passwordResetViewModelProvider);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, 'エラーが発生しました: boom');
    });

    test('呼び出し直後は isLoading が true になり isSuccess/errorMessage がリセットされる', () async {
      final container = _makeContainer(
        result: const Left(Failure.network()),
      );
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);

      // 前回の失敗状態を作っておき、次の呼び出しでリセットされることを確認する。
      await notifier.sendResetEmail(email: 'test@example.com');
      expect(
        container.read(passwordResetViewModelProvider).errorMessage,
        isNotNull,
      );

      final future = notifier.sendResetEmail(email: 'retry@example.com');

      final loadingState = container.read(passwordResetViewModelProvider);
      expect(loadingState.isLoading, isTrue);
      expect(loadingState.isSuccess, isFalse);
      expect(loadingState.errorMessage, isNull);

      await future;
    });

    test('email 引数が UseCase にそのまま渡される', () async {
      final fakeUseCase = FakeResetPasswordUseCase(const Right(unit));
      final container = ProviderContainer(overrides: [
        resetPasswordUseCaseProvider.overrideWithValue(fakeUseCase),
      ]);
      addTearDown(container.dispose);
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);

      await notifier.sendResetEmail(email: 'user@example.com');

      expect(fakeUseCase.lastEmail, 'user@example.com');
      expect(fakeUseCase.callCount, 1);
    });
  });

  group('PasswordResetViewModel.resetState', () {
    test('成功状態からリセットした場合、初期状態に戻る', () async {
      final container = _makeContainer(result: const Right(unit));
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);
      await notifier.sendResetEmail(email: 'test@example.com');
      expect(
        container.read(passwordResetViewModelProvider).isSuccess,
        isTrue,
      );

      notifier.resetState();

      final state = container.read(passwordResetViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('失敗状態からリセットした場合、errorMessage がクリアされる', () async {
      final container = _makeContainer(
        result: const Left(Failure.network()),
      );
      final notifier =
          container.read(passwordResetViewModelProvider.notifier);
      await notifier.sendResetEmail(email: 'test@example.com');
      expect(
        container.read(passwordResetViewModelProvider).errorMessage,
        isNotNull,
      );

      notifier.resetState();

      final state = container.read(passwordResetViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });
  });
}
