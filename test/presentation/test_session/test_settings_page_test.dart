import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/test_session/test_settings_page.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

import '../../helpers/test_helpers.dart';

const _folderId = 'folder-1';
const _folderName = '英単語';

Widget buildTestSettingsPage({List<Override> extra = const []}) {
  return buildWithMockRepositories(
    child: const TestSettingsPage(folderId: _folderId, folderName: _folderName),
    extra: extra,
  );
}

void main() {
  group('TestSettingsPage', () {
    testWidgets('フォルダ名が表示される', (tester) async {
      await tester.pumpWidget(
        buildTestSettingsPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataTestSettingsWordListVM.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(_folderName), findsOneWidget);
    });

    testWidgets('単語数が表示される', (tester) async {
      await tester.pumpWidget(
        buildTestSettingsPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataTestSettingsWordListVM.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('単語数: 3枚'), findsOneWidget);
    });

    testWidgets('シャッフル切り替えスイッチが表示されデフォルトで ON になっている', (tester) async {
      await tester.pumpWidget(
        buildTestSettingsPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataTestSettingsWordListVM.new),
        ]),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidget.value, isTrue);
      expect(find.text('シャッフル出題'), findsOneWidget);
    });

    testWidgets('単語が 0 件のとき「テスト開始」ボタンが無効化される', (tester) async {
      await tester.pumpWidget(
        buildTestSettingsPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(EmptyTestSettingsWordListVM.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('テスト開始'), findsOneWidget);
      expect(find.text('単語が1枚以上必要です'), findsOneWidget);
    });

    testWidgets('単語が存在するとき「テスト開始」ボタンが有効化される', (tester) async {
      await tester.pumpWidget(
        buildTestSettingsPage(extra: [
          wordListViewModelProvider(_folderId)
              .overrideWith(DataTestSettingsWordListVM.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('テスト開始'), findsOneWidget);
      // 単語がある場合はエラーメッセージが表示されない
      expect(find.text('単語が1枚以上必要です'), findsNothing);
    });
  });
}

class DataTestSettingsWordListVM extends WordListViewModel {
  @override
  Future<List<Word>> build(String folderId) async => testWords;
}

class EmptyTestSettingsWordListVM extends WordListViewModel {
  @override
  Future<List<Word>> build(String folderId) async => [];
}
