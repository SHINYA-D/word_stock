import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/presentation/auth/auth_state.dart';
import 'package:word_stock/core/di/auth_providers.dart';

part 'password_reset_view_model.g.dart';

@riverpod
class PasswordResetViewModel extends _$PasswordResetViewModel {
  @override
  AuthState build() => AuthState.initial();

  Future<void> sendResetEmail({required String email}) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    final result =
        await ref.read(resetPasswordUseCaseProvider).call(email: email);
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.when(
          network: () => '通信エラーが発生しました',
          auth: () => 'メールアドレスが見つかりません',
          notFound: () => 'アカウントが見つかりません',
          unknown: (msg) => 'エラーが発生しました: $msg',
        ),
      ),
      (_) => state = state.copyWith(isLoading: false, isSuccess: true),
    );
  }

  void resetState() => state = AuthState.initial();
}
