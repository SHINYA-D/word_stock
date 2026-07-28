import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/presentation/auth/password_reset/password_reset_page.dart';

void main() {
  group('PasswordResetPage', () {
    testWidgets('初期表示: 説明文・メールフィールド・送信ボタンが揃っている', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PasswordResetPage())),
      );

      expect(find.text('パスワードリセット'), findsOneWidget);
      expect(
        find.text('登録済みのメールアドレスにパスワードリセット用のリンクを送信します。'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.text('送信する'), findsOneWidget);
    });

    testWidgets('メールアドレスが空のまま送信するとバリデーションエラーが出る', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PasswordResetPage())),
      );

      await tester.tap(find.text('送信する'));
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('メールアドレスを入力するとバリデーションエラーが出ない', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PasswordResetPage())),
      );

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsNothing);
    });
  });
}
