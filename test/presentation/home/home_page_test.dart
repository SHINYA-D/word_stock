import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/presentation/home/home_page.dart';
import 'package:word_stock/presentation/home/home_state.dart';
import 'package:word_stock/presentation/home/home_view_model.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('HomePage', () {
    testWidgets('ローディング中は CircularProgressIndicator が表示される', (tester) async {
      await tester.pumpWidget(
        buildWithMockRepositories(
          child: const HomePage(),
          extra: [
            homeViewModelProvider.overrideWith(LoadingHomeViewModel.new),
          ],
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('フォルダが 0 件のときエンプティビューが表示される', (tester) async {
      await tester.pumpWidget(
        buildWithMockRepositories(
          child: const HomePage(),
          extra: [
            homeViewModelProvider.overrideWith(EmptyHomeViewModel.new),
          ],
        ),
      );

      expect(find.text('フォルダがありません'), findsOneWidget);
      expect(find.text('フォルダを作成'), findsOneWidget);
    });

    testWidgets('フォルダが存在するときリストに名前が表示される', (tester) async {
      await tester.pumpWidget(
        buildWithMockRepositories(
          child: const HomePage(),
          extra: [
            homeViewModelProvider.overrideWith(DataHomeViewModel.new),
          ],
        ),
      );

      expect(find.text('英単語'), findsOneWidget);
      expect(find.text('TOEIC 頻出'), findsOneWidget);
    });

    testWidgets('FAB をタップするとフォルダ作成ダイアログが表示される', (tester) async {
      await tester.pumpWidget(
        buildWithMockRepositories(
          child: const HomePage(),
          extra: [
            homeViewModelProvider.overrideWith(EmptyHomeViewModel.new),
          ],
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('フォルダを作成'), findsWidgets);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('作成'), findsOneWidget);
    });

    testWidgets('フォルダ削除ダイアログに削除確認メッセージが表示される', (tester) async {
      await tester.pumpWidget(
        buildWithMockRepositories(
          child: const HomePage(),
          extra: [
            homeViewModelProvider.overrideWith(DataHomeViewModel.new),
          ],
        ),
      );

      // FolderListTile の削除アクションを呼び出す
      // trailing の PopupMenuButton をタップ
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      expect(find.text('フォルダを削除'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });
  });
}

/// ローディング状態
class LoadingHomeViewModel extends HomeViewModel {
  @override
  HomeState build() => HomeState.loading();
}

/// フォルダ 0 件
class EmptyHomeViewModel extends HomeViewModel {
  @override
  HomeState build() => const HomeState(folders: AsyncValue.data([]));
}

/// サンプルフォルダあり
class DataHomeViewModel extends HomeViewModel {
  @override
  HomeState build() => HomeState(folders: AsyncValue.data(testFolders));
}
