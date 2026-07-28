import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/domain/entities/test_result.dart';
import 'package:word_stock/presentation/result/result_page.dart';
import 'package:word_stock/presentation/result/result_view_model.dart';

import '../../helpers/test_helpers.dart';

Widget buildResultPage({List<Override> extra = const []}) {
  return buildWithMockRepositories(child: const ResultPage(), extra: extra);
}

void main() {
  group('ResultPage', () {
    testWidgets('ローディング中は CircularProgressIndicator が表示される', (tester) async {
      await tester.pumpWidget(
        buildResultPage(
          extra: [resultViewModelProvider.overrideWith(LoadingResultViewModel.new)],
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('成績データが 0 件のときエンプティビューが表示される', (tester) async {
      await tester.pumpWidget(
        buildResultPage(
           extra: [resultViewModelProvider.overrideWith(EmptyResultViewModel.new)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('まだ成績データがありません'), findsOneWidget);
      expect(find.text('テストを完了すると成績が記録されます'), findsOneWidget);
    });

    testWidgets('成績データが存在するとき結果カードが表示される', (tester) async {
      await tester.pumpWidget(
        buildResultPage(extra: [
          resultViewModelProvider.overrideWith(DataResultViewModel.new),
          // folderNames は空 Map で OK（フォルダ名表示は任意）
          folderNamesProvider.overrideWith((ref) async => {}),
        ]),
      );
      await tester.pumpAndSettle();

      // 2 件のデータが表示される
      expect(find.text('2 / 3 正解'), findsOneWidget);
      expect(find.text('2 / 2 正解'), findsOneWidget);
    });

    testWidgets('AppBar に「成績表」と表示される', (tester) async {
      await tester.pumpWidget(
        buildResultPage(
          extra: [resultViewModelProvider.overrideWith(EmptyResultViewModel.new)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('成績表'), findsOneWidget);
    });
  });
}

class LoadingResultViewModel extends ResultViewModel {
  @override
  Future<List<TestResult>> build() =>
      Completer<List<TestResult>>().future;
}

class EmptyResultViewModel extends ResultViewModel {
  @override
  Future<List<TestResult>> build() async => [];
}

class DataResultViewModel extends ResultViewModel {
  @override
  Future<List<TestResult>> build() async => [
        TestResult(
          id: 'r1',
          folderId: 'folder-1',
          totalCount: 3,
          correctCount: 2,
          date: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        TestResult(
          id: 'r2',
          folderId: 'folder-2',
          totalCount: 2,
          correctCount: 2,
          date: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ];
}
