import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/word/word_create_page.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

import '../../helpers/test_helpers.dart';

const _folderId = 'folder-1';

/// WordCreatePage 単体では ViewModel をoverrideせず、
/// buildWithMockRepositories() が注入する MockWordRepository 経由の
/// 本物の WordListViewModel（build() / createWord()）をそのまま動かす。
/// MockWordRepository は Future.delayed(200ms) で応答するため、
/// pumpWidget 直後に一定時間分の pump を挟んで初期フェッチの Future を
/// 確実に解決させてから操作を行う（未解決のままテストを終えると
/// 「A Timer is still pending」で失敗するため）。
Future<void> _pumpAndSettleWordCreatePage(WidgetTester tester) async {
  // MockWordRepository の getWords()/createWord() の Future.delayed(200ms) を
  // 確実に消化するため、アニメーション用の pumpAndSettle とは別に実時間を進める
  // （200ms ちょうどだと実行環境の負荷次第で間に合わないことがあるため余裕を持たせる）。
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Widget buildWordCreatePage({List<Override> extra = const []}) {
  return buildWithMockRepositories(
    child: const WordCreatePage(folderId: _folderId),
    extra: extra,
  );
}

/// 保存後の Navigator.pop() を検証するため、1つ前の画面から
/// push した状態で WordCreatePage を表示するヘルパー。
Widget buildWordCreatePageWithHome({List<Override> extra = const []}) {
  return buildWithMockRepositories(
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WordCreatePage(folderId: _folderId),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    extra: extra,
  );
}

void main() {
  group('WordCreatePage', () {
    testWidgets('初期表示で表・裏カードのラベルが表示される', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      expect(find.text('表'), findsOneWidget);
      expect(find.text('裏'), findsOneWidget);
      expect(find.text('単語を追加'), findsOneWidget);
    });

    testWidgets('表カードをタップすると展開しTextFieldが表示される', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('表カードに文字を入力すると保存ボタンが有効になる', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();

      IgnorePointer currentIgnorePointer() => tester
          .widgetList<IgnorePointer>(find.ancestor(
            of: find.widgetWithText(FilledButton, '保存'),
            matching: find.byType(IgnorePointer),
          ))
          .first;

      // 未入力時は保存ボタンがタップを無視する状態になっている
      expect(currentIgnorePointer().ignoring, isTrue);

      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pumpAndSettle();

      // 入力後は保存ボタンがタップを受け付ける状態になる
      expect(currentIgnorePointer().ignoring, isFalse);
    });

    testWidgets('表が未確定のまま裏カードをタップすると確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      await tester.tap(find.text('裏'));
      await tester.pumpAndSettle();

      expect(find.text('入力が未完了です'), findsOneWidget);
      expect(find.text('表カードの入力を完了させてください'), findsOneWidget);
    });

    testWidgets('確認ダイアログのOKをタップするとダイアログが閉じる', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      await tester.tap(find.text('裏'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('入力が未完了です'), findsNothing);
    });

    testWidgets('表カードに入力して保存すると表カードが折りたたまれる', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      // 表カードが折りたたまれた状態に戻るため、展開時に出る閉じるボタンが消える
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('apple'), findsOneWidget);
    });

    testWidgets('表を確定後に裏カードをタップするとダイアログを出さずに展開できる', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('裏'));
      await tester.pumpAndSettle();

      expect(find.text('入力が未完了です'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('展開中に閉じるアイコンをタップすると折りたたまれる', (tester) async {
      await tester.pumpWidget(buildWordCreatePage());
      await _pumpAndSettleWordCreatePage(tester);

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('表裏に入力して裏カードを保存すると単語が保存され画面が閉じる', (tester) async {
      await tester.pumpWidget(buildWordCreatePageWithHome());
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await _pumpAndSettleWordCreatePage(tester);
      expect(find.byType(WordCreatePage), findsOneWidget);

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('裏'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'りんご');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.byType(WordCreatePage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('保存に失敗した場合、エラーのスナックバーが表示される', (tester) async {
      await tester.pumpWidget(buildWordCreatePageWithHome(extra: [
        wordListViewModelProvider(_folderId)
            .overrideWith(_FailingCreateWordListViewModel.new),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('裏'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'りんご');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      // ScaffoldMessenger は MaterialApp 直下で共有されるため、
      // WordCreatePage が pop された後も SnackBar は表示され続ける
      expect(find.text('追加に失敗しました'), findsOneWidget);
    });
  });
}

class _FailingCreateWordListViewModel extends WordListViewModel {
  @override
  Future<List<Word>> build(String folderId) async => [];

  @override
  Future<void> createWord({
    required String front,
    required String back,
  }) async {
    state = AsyncValue.error(
      const Failure.unknown('追加に失敗しました'),
      StackTrace.current,
    );
  }
}
