import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/word/widgets/animated_word_card.dart';
import 'package:word_stock/presentation/word/word_edit_page.dart';

import '../../helpers/test_helpers.dart';

const _folderId = 'folder-1';

/// MockWordRepository の folder-1/word-1 と front/back を一致させておく
/// （updateWord() が Failure.notFound を返さないようにするため）。
final _testWord = Word(
  id: 'word-1',
  front: 'apple',
  back: 'りんご',
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

/// MockWordRepository の folder-1 ストアに存在しない wordId。
/// updateWord() が Failure.notFound を返す（＝更新失敗）ケースを
/// 本物の WordListViewModel / MockWordRepository のまま再現するために使う。
final _missingWord = Word(
  id: 'word-does-not-exist',
  front: 'apple',
  back: 'りんご',
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

/// WordEditPage は wordListViewModelProvider を ref.listen でエラー監視するだけで、
/// 表示自体は widget.word（コンストラクタ引数）を初期値として使う。
/// そのため ViewModel はサブクラスで override せず、本物の WordListViewModel と
/// MockWordRepository をそのまま使う（build() の非同期解決は初回の
/// pumpAndSettle() で待つ）。
Widget buildWordEditPage({Word? word}) {
  return buildWithMockRepositories(
    child: WordEditPage(folderId: _folderId, word: word ?? _testWord),
  );
}

/// PopScope の挙動（展開中の戻る操作で変更を破棄する）を検証するため、
/// 1つ前の画面から push した状態で WordEditPage を表示するヘルパー。
Widget buildWordEditPageWithHome({Word? word}) {
  return buildWithMockRepositories(
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WordEditPage(folderId: _folderId, word: word ?? _testWord),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('WordEditPage', () {
    testWidgets('初期表示で表・裏カードに既存の値が表示される', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      // wordListViewModelProvider は ref.listen のみで監視され、build() 完了時に
      // 新しいフレームが自動でスケジュールされないため、pumpAndSettle() だけでは
      // MockWordRepository.getWords() の Future.delayed(200ms) を待ちきれず
      // テスト終了時に "Timer is still pending" で失敗する。明示的に時間を進めておく。
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('表'), findsOneWidget);
      expect(find.text('裏'), findsOneWidget);
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('りんご'), findsOneWidget);
      expect(find.text('単語を編集'), findsOneWidget);
    });

    testWidgets('表カードをタップすると展開しTextFieldに既存の値が入っている', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'apple');
    });

    testWidgets('未変更のまま展開した場合、保存ボタンが無効な状態になる', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();

      final ignorePointer = tester
          .widgetList<IgnorePointer>(find.ancestor(
            of: find.widgetWithText(FilledButton, '保存'),
            matching: find.byType(IgnorePointer),
          ))
          .first;
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('表カードの文字を変更すると保存ボタンが有効になる', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apricot');
      await tester.pumpAndSettle();

      final ignorePointer = tester
          .widgetList<IgnorePointer>(find.ancestor(
            of: find.widgetWithText(FilledButton, '保存'),
            matching: find.byType(IgnorePointer),
          ))
          .first;
      expect(ignorePointer.ignoring, isFalse);
    });

    testWidgets('表カードを変更して保存すると更新され折りたたまれた状態で新しい値が表示される', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apricot');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      // 展開時のみ表示される閉じるアイコンが消え、折りたたみ状態に戻る
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('apricot'), findsOneWidget);
    });

    testWidgets('展開中に閉じるアイコンをタップすると変更が破棄され元の値に戻る', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'temp');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('apple'), findsOneWidget);
      expect(find.text('temp'), findsNothing);
    });

    testWidgets('テキストを空にして保存するとバリデーションエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.text(AnimatedWordCard.validationMessage), findsOneWidget);
    });

    testWidgets('バリデーションエラー表示中にカードをタップするとエラーが消える', (tester) async {
      await tester.pumpWidget(buildWordEditPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text(AnimatedWordCard.validationMessage), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text(AnimatedWordCard.validationMessage), findsNothing);
    });

    testWidgets('更新に失敗した場合、エラーのスナックバーが表示される', (tester) async {
      // MockWordRepository の folder-1 ストアに存在しない wordId を渡すことで、
      // 本物の UpdateWordUseCase / MockWordRepository のまま Failure.notFound を発生させる。
      await tester.pumpWidget(buildWordEditPage(word: _missingWord));
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apricot');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.text('更新に失敗しました'), findsOneWidget);
    });

    testWidgets('展開中に戻る操作をすると変更を破棄して画面は閉じない', (tester) async {
      await tester.pumpWidget(buildWordEditPageWithHome());
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(WordEditPage), findsOneWidget);

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'temp');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // PopScope が pop をブロックし変更を破棄するため、画面は残ったまま元の値に戻る
      expect(find.byType(WordEditPage), findsOneWidget);
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('temp'), findsNothing);
    });
  });
}
