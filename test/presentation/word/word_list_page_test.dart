import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/word/word_list_page.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

import '../../helpers/test_helpers.dart';

const _folderId = 'folder-1';
const _folderName = '英単語';

Widget buildWordListPage({List<Override> extra = const []}) {
  return buildWithMockRepositories(
    child: const WordListPage(folderId: _folderId, folderName: _folderName),
    extra: extra,
  );
}

void main() {
  group('WordListPage', () {
    testWidgets('ローディング中は CircularProgressIndicator が表示される', (tester) async {
      await tester.pumpWidget(
        buildWordListPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(LoadingWordListViewModel.new),
        ]),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('単語 0 件のとき「単語がありません」が表示される', (tester) async {
      await tester.pumpWidget(
        buildWordListPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(EmptyWordListViewModel.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('単語がありません'), findsOneWidget);
    });

    testWidgets('単語が存在するとき表面・裏面が表示される', (tester) async {
      await tester.pumpWidget(
        buildWordListPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataWordListViewModel.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('apple'), findsOneWidget);
      expect(find.text('りんご'), findsOneWidget);
      expect(find.text('banana'), findsOneWidget);
    });

    testWidgets('検索キーワードに一致しない単語は非表示になる', (tester) async {
      await tester.pumpWidget(
        buildWordListPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataWordListViewModel.new),
        ]),
      );

      // 'apple' を検索
      // enterText は検索フィールド (EditableText) にも 'apple' を書き込むため
      // find.text('apple') が検索フィールドとワードタイルの両方にマッチすることに注意
      await tester.enterText(find.byType(TextField).first, 'apple');
      await tester.pump();

      // 'apple' に一致しない単語が非表示になっていることを確認
      expect(find.text('banana'), findsNothing);
      expect(find.text('cherry'), findsNothing);
    });

    testWidgets('検索クリアボタンをタップすると全単語が再表示される', (tester) async {
      await tester.pumpWidget(
        buildWordListPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataWordListViewModel.new),
        ]),
      );

      await tester.enterText(find.byType(TextField).first, 'apple');
      await tester.pump();
      // clear ボタンが表示される
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(find.text('banana'), findsOneWidget);
    });

    testWidgets('FAB をタップすると単語追加ダイアログが表示される', (tester) async {
      await tester.pumpWidget(
        buildWordListPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataWordListViewModel.new),
        ]),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('単語を追加'), findsOneWidget);
      expect(find.text('単語（表面）'), findsOneWidget);
      expect(find.text('意味（裏面）'), findsOneWidget);
    });
  });
}

class LoadingWordListViewModel extends WordListViewModel {
  @override
  Future<List<Word>> build(String folderId) =>
      // 決して完了しない Future → provider が AsyncLoading のままになる
      Completer<List<Word>>().future;
}

class EmptyWordListViewModel extends WordListViewModel {
  @override
  Future<List<Word>> build(String folderId) async => [];
}

class DataWordListViewModel extends WordListViewModel {
  @override
  Future<List<Word>> build(String folderId) async => testWords;
}
