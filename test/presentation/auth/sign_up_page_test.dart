import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/presentation/auth/sign_up/sign_up_page.dart';

void main() {
  group('SignUpPage', () {
    testWidgets('初期表示: 3 つのフォームフィールドとアカウント作成ボタンが揃っている', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SignUpPage())),
      );

      // AppBar タイトル
      expect(find.text('新規登録'), findsOneWidget);
      // 各フィールドのラベルアイコン（email / lock）
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      // password フィールドが 2 つ（パスワード + 確認）
      expect(find.byIcon(Icons.lock_outlined), findsNWidgets(2));
      expect(find.text('アカウント作成'), findsOneWidget);
    });

    testWidgets('メールアドレスが空のままアカウント作成するとバリデーションエラーが出る', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SignUpPage())),
      );

      await tester.tap(find.text('アカウント作成'));
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('パスワードが 6 文字未満のときバリデーションエラーが出る', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SignUpPage())),
      );

      // email を入力してからパスワードを 5 文字入力
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.tap(find.text('アカウント作成'));
      await tester.pump();

      expect(find.text('6文字以上で入力してください'), findsOneWidget);
    });

    testWidgets('パスワードと確認が一致しないときバリデーションエラーが出る', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SignUpPage())),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.enterText(find.byType(TextFormField).at(2), 'different');
      await tester.tap(find.text('アカウント作成'));
      await tester.pump();

      expect(find.text('パスワードが一致しません'), findsOneWidget);
    });
  });
}
