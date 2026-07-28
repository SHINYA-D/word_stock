import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/presentation/test_session/test_result_page.dart';

// TestResultPage はコンストラクタ引数のみで完結する純粋な StatelessWidget
// Provider / Firebase 依存なし

Widget buildResultPage(int correct, int total) {
  return MaterialApp(
    home: TestResultPage(correctCount: correct, total: total),
  );
}

void main() {
  group('TestResultPage', () {
    testWidgets('正解率パーセンテージが表示される', (tester) async {
      await tester.pumpWidget(buildResultPage(8, 10));

      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('正解数 / 総問数が表示される', (tester) async {
      await tester.pumpWidget(buildResultPage(8, 10));

      expect(find.text('8 / 10 問正解'), findsOneWidget);
    });

    testWidgets('正解・不正解の内訳が表示される', (tester) async {
      await tester.pumpWidget(buildResultPage(8, 10));

      expect(find.text('正解'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('不正解'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    group('グレードメッセージ', () {
      testWidgets('90% 以上 → 素晴らしい！', (tester) async {
        await tester.pumpWidget(buildResultPage(9, 10));
        expect(find.text('素晴らしい！'), findsOneWidget);
      });

      testWidgets('70〜89% → よくできました！', (tester) async {
        await tester.pumpWidget(buildResultPage(7, 10));
        expect(find.text('よくできました！'), findsOneWidget);
      });

      testWidgets('50〜69% → もう少し！', (tester) async {
        await tester.pumpWidget(buildResultPage(5, 10));
        expect(find.text('もう少し！'), findsOneWidget);
      });

      testWidgets('50% 未満 → もっと練習しましょう', (tester) async {
        await tester.pumpWidget(buildResultPage(4, 10));
        expect(find.text('もっと練習しましょう'), findsOneWidget);
      });
    });

    testWidgets('ホームに戻るボタンが表示される', (tester) async {
      await tester.pumpWidget(buildResultPage(5, 10));

      expect(find.text('ホームに戻る'), findsOneWidget);
    });

    testWidgets('total が 0 のとき 0% が表示される', (tester) async {
      await tester.pumpWidget(buildResultPage(0, 0));

      expect(find.text('0%'), findsOneWidget);
    });
  });
}
