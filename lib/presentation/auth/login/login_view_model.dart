import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/presentation/auth/auth_state.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/sync_status_providers.dart';

part 'login_view_model.g.dart';

@riverpod
class LoginViewModel extends _$LoginViewModel {
  @override
  AuthState build() => AuthState.initial();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    ref.read(authSyncInProgressProvider.notifier).state = true;
    final result = await ref
        .read(signInWithEmailUseCaseProvider)
        .call(email: email, password: password);
    ref.read(authSyncInProgressProvider.notifier).state = false;
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.when(
          network: () => '通信エラーが発生しました',
          auth: () => 'メールアドレスまたはパスワードが正しくありません',
          notFound: () => 'アカウントが見つかりません',
          unknown: (msg) => 'エラーが発生しました: $msg',
        ),
      ),
      (_) => state = state.copyWith(isLoading: false, isSuccess: true),
    );
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    ref.read(authSyncInProgressProvider.notifier).state = true;
    final result = await ref.read(signInWithGoogleUseCaseProvider).call();
    ref.read(authSyncInProgressProvider.notifier).state = false;
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.when(
          network: () => '通信エラーが発生しました',
          auth: () => 'Google ログインに失敗しました',
          notFound: () => 'アカウントが見つかりません',
          unknown: (msg) => 'エラーが発生しました: $msg',
        ),
      ),
      (_) => state = state.copyWith(isLoading: false, isSuccess: true),
    );
  }

  void resetState() => state = AuthState.initial();
}
