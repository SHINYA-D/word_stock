import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/presentation/auth/auth_state.dart';
import 'package:word_stock/presentation/auth/login/login_page.dart';
import 'package:word_stock/presentation/auth/login/login_view_model.dart';

void main() {
  group('LoginPage', () {
    testWidgets('初期表示: フォーム・ボタン・リンクが揃っている', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );

      expect(find.text('WordStock'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
      expect(find.text('ログイン'), findsOneWidget);
      expect(find.text('Google でログイン'), findsOneWidget);
      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('パスワードを忘れた方'), findsOneWidget);
    });

    testWidgets('メール・パスワードが空のままログインするとバリデーションエラーが出る', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );

      await tester.tap(find.text('ログイン'));
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
      expect(find.text('パスワードを入力してください'), findsOneWidget);
    });

    testWidgets('パスワード表示切り替えアイコンをタップすると visibility アイコンが変わる', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );

      // 初期状態は visibility_off
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      // タップ後は visibility に切り替わる
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('ローディング中はボタン内に CircularProgressIndicator が表示される', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginViewModelProvider.overrideWith(LoadingLoginViewModel.new),
          ],
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pump();

      // ローディング中はボタン内に CircularProgressIndicator が出る
      expect(
        find.descendant(
          of: find.byType(FilledButton).first,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });
  });
}

/// ローディング状態を返すフェイク ViewModel
class LoadingLoginViewModel extends LoginViewModel {
  @override
  AuthState build() => const AuthState(isLoading: true, isSuccess: false);
}
