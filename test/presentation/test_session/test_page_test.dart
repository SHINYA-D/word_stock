import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/di/repository_providers.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_test_result_repository.dart';
import 'package:word_stock/presentation/test_session/test_page.dart';

import '../../helpers/test_helpers.dart';

Widget buildTestPage() {
  return ProviderScope(
    overrides: [
      // テスト結果の保存先のみモックに差し替える（Firebase 回避）
      testResultRepositoryProvider
          .overrideWithValue(MockTestResultRepository()),
    ],
    child: MaterialApp(
      home: TestPage(
        folderId: 'folder-1',
        words: testWords, // 3 枚 (apple, banana, cherry)
        shuffle: false,
        folderName: '英単語',
        userId: 'user-1',
      ),
    ),
  );
}

void main() {
  group('TestPage', () {
    testWidgets('start() 呼び出し前はローディングインジケーターが表示される', (tester) async {
      await tester.pumpWidget(buildTestPage());

      // addPostFrameCallback が呼ばれる前 → initial 状態
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('start() 後は 1 枚目のカードと進捗カウンターが表示される', (tester) async {
      await tester.pumpWidget(buildTestPage());
      // addPostFrameCallback → start() が呼ばれる
      await tester.pump();

      expect(find.text('1 / 3'), findsOneWidget);
      // カードの表面テキスト
      expect(find.text('apple'), findsOneWidget);
      // 表面ラベル
      expect(find.text('表面'), findsOneWidget);
      // タップヒント
      expect(find.text('タップして裏面を確認'), findsOneWidget);
    });

    testWidgets('カードをタップすると裏面が表示され正解・不正解ボタンが現れる', (tester) async {
      await tester.pumpWidget(buildTestPage());
      await tester.pump();

      // カードをタップ（GestureDetector）
      await tester.tap(find.text('apple'));
      // flip アニメーション終了まで待つ
      await tester.pumpAndSettle();

      // 裏面に切り替わる
      expect(find.text('りんご'), findsOneWidget);
      // 正解・不正解ボタン表示
      expect(find.text('正解'), findsOneWidget);
      expect(find.text('不正解'), findsOneWidget);
    });

    testWidgets('テスト中断確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(buildTestPage());
      await tester.pump();

      // PopScope の戻るジェスチャー相当を確認する方法として
      // Android の back ボタンを simulate
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('テストを中断しますか？'), findsOneWidget);
      expect(find.text('続ける'), findsOneWidget);
      expect(find.text('中断する'), findsOneWidget);
    });
  });
}
