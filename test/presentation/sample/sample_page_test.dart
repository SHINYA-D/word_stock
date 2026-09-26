import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/repository_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/core/widgets/error_screen.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_auth_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_flashcard_result_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_folder_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_settings_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_word_repository.dart';
import 'package:word_stock/presentation/sample/sample_page.dart';
import 'package:word_stock/presentation/sample/widgets/sample_list_tile.dart';
import 'package:word_stock/presentation/shell/shell_page.dart';

import '../../helpers/fake_infrastructure.dart';
import '../../helpers/test_helpers.dart';

// ─── フィクスチャ ──────────────────────────────────────────────

Sample _sample(String id, String name, DateTime createdAt) =>
    Sample(id: id, name: name, createdAt: createdAt, updatedAt: createdAt);

final _sampleA = _sample('sample-a', 'A', DateTime(2024, 1, 1));
final _sampleB = _sample('sample-b', 'B', DateTime(2024, 1, 2));
final _sampleC = _sample('sample-c', 'C', DateTime(2024, 1, 3));
const _wide20 = 'あいうえおかきくけこ'; // 全角10文字 = 幅20

List<Sample> _many(int count) => List.generate(
      count,
      (i) => _sample(
        's${i + 1}',
        'S${(i + 1).toString().padLeft(2, '0')}',
        DateTime(2024, 1, i + 1),
      ),
    );

// ─── ビルドヘルパー ────────────────────────────────────────────

Widget _buildPage(FakeSampleRepository repo, {List<Override> extra = const []}) {
  return buildWithMockRepositories(
    child: const SamplePage(),
    extra: [
      sampleRepositoryProvider.overrideWithValue(repo),
      ...extra,
    ],
  );
}

/// GoRouter 込みで SamplePage を表示するヘルパー。
/// `/sample`（ShellPage 配下）・`/folder/:folderId`（遷移確認用の代替画面）・`/login`
/// の3経路を持つ最小限のルーターに、実際の redirect（authStateProvider を見てログイン画面へ飛ばす）を再現する。
final _testRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/sample',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellPage(child: child),
        routes: [
          GoRoute(path: '/sample', builder: (c, s) => const SamplePage()),
          GoRoute(
            path: '/folder/:folderId',
            builder: (c, s) => Text('folder:${s.pathParameters['folderId']}:${s.extra}'),
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (c, s) => const Text('login-screen')),
    ],
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      if (!isLoggedIn && loc != '/login') return '/login';
      return null;
    },
  );
  ref.listen(authStateProvider, (_, __) => router.refresh());
  return router;
});

Widget _buildPageWithRouter(FakeSampleRepository repo, {List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      folderRepositoryProvider.overrideWithValue(MockFolderRepository()),
      wordRepositoryProvider.overrideWithValue(MockWordRepository()),
      settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
      flashcardResultRepositoryProvider.overrideWithValue(MockFlashcardResultRepository()),
      currentUserProvider.overrideWithValue(testUser),
      sampleRepositoryProvider.overrideWithValue(repo),
      ...extra,
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(_testRouterProvider)),
    ),
  );
}

// ─── 操作・検証ヘルパー ────────────────────────────────────────

List<String> _tileNames(WidgetTester tester) => tester
    .widgetList<SampleListTile>(find.byType(SampleListTile))
    .map((t) => t.sample.name)
    .toList();

Future<void> _openMenuFor(WidgetTester tester, String name) async {
  final tile = find.ancestor(of: find.text(name), matching: find.byType(Card));
  await tester.tap(find.descendant(of: tile, matching: find.byIcon(Icons.more_vert)));
  await tester.pumpAndSettle();
}

Future<void> _openEditDialogFor(WidgetTester tester, String name) async {
  await _openMenuFor(tester, name);
  await tester.tap(find.text('編集'));
  await tester.pumpAndSettle();
}

Future<void> _openDeleteDialogFor(WidgetTester tester, String name) async {
  await _openMenuFor(tester, name);
  await tester.tap(find.text('削除'));
  await tester.pumpAndSettle();
}

Future<void> _openCreateDialogFromFab(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _openCreateDialogFromEmptyButton(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'サンプルを作成'));
  await tester.pumpAndSettle();
}

/// SMP-N01 / SMP-N03 の境界値テスト名を一意にするための説明ラベル。
/// 空白の組み合わせだけが異なる値（「   」と「 　 」等）は、項目書の doc_sync が
/// 空白を除いて名前を正規化して照合するため、幅の数字だけでは名前が重複してしまう。
/// 仕様書の「境界値」列の書き方（半角スペース3つ／全角スペース2つ／混在）をそのまま使い分ける。
String _spaceLabel(String value) {
  if (value.isEmpty) return '空';
  if (value.trim().isNotEmpty) return '幅${value.length}';
  final hasHalf = value.contains(' ');
  final hasFull = value.contains('　');
  if (hasHalf && hasFull) return '半角・全角スペースの混在';
  if (hasFull) return '全角スペース${value.length}つ';
  return '半角スペース${value.length}つ';
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

FilledButton _filledButton(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

TextButton _textButton(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

Future<void> _pullToRefresh(WidgetTester tester, {Finder? scrollable}) async {
  final target = scrollable ?? find.byType(ListView);
  await tester.fling(target, const Offset(0, 300), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  // ─── 3.1 表示 ──────────────────────────────────────────────
  group('SamplePage 表示', () {
    testWidgets('「A」の1件がある状態で画面を開いた場合、AppBar に「サンプル」と表示される [SMP-D01]', (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.text('サンプル'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で画面を開いた場合、ボトムナビゲーションバーが表示され、「テスト」タブが選択状態になっている [SMP-D02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });

    testWidgets(
        '「A」の1件がある状態で画面を開いた場合、画面の右下に FloatingActionButton が表示され、アイコンは Icons.add [SMP-D03]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(FloatingActionButton), matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.add);
    });

    testWidgets('0件の状態で画面を開いた場合、画面の右下に FloatingActionButton が表示され、アイコンは Icons.add [SMP-D04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: const []);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(FloatingActionButton), matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.add);
    });

    testWidgets('「A」「B」の2件がある状態で画面を開いた場合、各行の右端に Icons.more_vert が1つずつ（計2つ）表示される [SMP-D05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    });

    testWidgets(
        '0件の状態で画面を開いた場合、上から順に Icons.science_outlined、「サンプルがありません」、Icons.add と「サンプルを作成」のボタンが表示される。一覧の行は表示されない [SMP-D06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: const []);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);
      expect(find.text('サンプルがありません'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'サンプルを作成'), findsOneWidget);
      expect(find.byType(SampleListTile), findsNothing);
      final scienceTop = tester.getTopLeft(find.byIcon(Icons.science_outlined)).dy;
      final emptyTextTop = tester.getTopLeft(find.text('サンプルがありません')).dy;
      final buttonTop = tester.getTopLeft(find.widgetWithText(FilledButton, 'サンプルを作成')).dy;
      expect(scienceTop, lessThan(emptyTextTop));
      expect(emptyTextTop, lessThan(buttonTop));
    });

    testWidgets('「A」「B」の2件がある状態で画面を開いた場合、一覧に「A」「B」が表示される。「サンプルがありません」は表示されない [SMP-D07]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsNothing);
    });

    testWidgets('作成日時が古い順に「A」「B」「C」の3件がある状態で画面を開いた場合、一覧に上から「A」「B」「C」の順で表示される [SMP-D08]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB, _sampleC]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'B', 'C']);
    });

    testWidgets('作成日時が古い順に「S01」〜「S30」の30件がある状態で画面を開いた場合、一覧を下へスクロールすると「S30」が表示される [SMP-D09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: _many(30));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('S30'), 500, scrollable: find.byType(Scrollable));
      expect(find.text('S30'), findsOneWidget);
    });

    testWidgets(
        '「あいうえおかきくけこ」（幅20）の1件がある状態で画面を開いた場合、一覧に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-D10]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('sample-w', _wide20, DateTime(2024, 1, 1))]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.text(_wide20), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '画面を開き、初期読み込みが完了していない場合、CircularProgressIndicator が表示される。一覧の行・「サンプルがありません」は表示されない [SMP-D11]',
        (tester) async {
      final repo = FakeSampleRepository()..getGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SampleListTile), findsNothing);
      expect(find.text('サンプルがありません'), findsNothing);
    });

    testWidgets('画面を開き、初期読み込みが完了していない場合、FloatingActionButton は表示されない [SMP-D12]', (tester) async {
      final repo = FakeSampleRepository()..getGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets(
        '画面を開き、初期読み込みが UnknownFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D13]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('画面を開き、初期読み込みが UnknownFailure で失敗した場合、FloatingActionButton は表示されない [SMP-D14]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  // ─── 3.2 再試行 ────────────────────────────────────────────
  group('SamplePage 再試行', () {
    testWidgets(
        '初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で、Repository が「A」の1件を返すようにして「再試行」をタップした場合、一覧に「A」が表示される。ErrorScreen は表示されない [SMP-D15]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.samples = [_sampleA];
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets(
        '初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが完了していない場合、CircularProgressIndicator が表示される。「再試行」ボタンは表示されない [SMP-D16]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.getGate = Completer<void>();
      await tester.tap(find.text('再試行'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('再試行'), findsNothing);
    });

    testWidgets(
        '初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが再び UnknownFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D17]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.addAll([const Failure.unknown('e1'), const Failure.unknown('e2')]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });
  });

  // ─── 3.3 プルして更新 ──────────────────────────────────────
  group('SamplePage プルして更新', () {
    testWidgets(
        '一覧に「A」の1件が表示され、Repository には「A」「B」（作成日時が古い順）がある状態で、一覧を下に引っ張って離した場合、一覧に上から「A」「B」の順で表示される [SMP-D18]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.samples = [_sampleA, _sampleB];
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが完了していない場合、RefreshIndicator の読み込み表示が出る。一覧には「A」が表示されたまま [SMP-D19]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.getGate = Completer<void>();
      await _pullToRefresh(tester);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが UnknownFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。ErrorScreen は表示されない [SMP-D20]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.getFailures.add(const Failure.unknown('e'));
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets(
        '一覧に「A」の1件が表示されている状態で、プルして更新を2回続けて行い、2回とも UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-D21]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.getFailures.addAll([const Failure.unknown('e1'), const Failure.unknown('e2')]);
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '0件の状態（「サンプルがありません」表示中）で、Repository に「A」が追加された状態にして、画面を下に引っ張って離した場合、一覧に「A」が表示される。「サンプルがありません」は表示されない [SMP-D22]',
        (tester) async {
      final repo = FakeSampleRepository(initial: const []);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.samples = [_sampleA];
      await _pullToRefresh(tester, scrollable: find.byType(SingleChildScrollView));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsNothing);
    });
  });

  // ─── 3.4 メニュー ──────────────────────────────────────────
  group('SamplePage メニュー', () {
    testWidgets('「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、「編集」「削除」が表示される [SMP-D23]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openMenuFor(tester, 'A');
      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets('「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、上から「編集」「削除」の順で表示される [SMP-D24]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openMenuFor(tester, 'A');
      final editTop = tester.getTopLeft(find.text('編集')).dy;
      final deleteTop = tester.getTopLeft(find.text('削除')).dy;
      expect(editTop, lessThan(deleteTop));
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、メニューの外側をタップした場合、「編集」「削除」は表示されない。一覧は「A」の1件のまま [SMP-D25]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openMenuFor(tester, 'A');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、端末の戻る操作をした場合、「編集」「削除」は表示されない。一覧は「A」の1件のまま。パスは /sample のまま [SMP-D26]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await _openMenuFor(tester, 'A');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);
      expect(_tileNames(tester), ['A']);
      expect(GoRouterState.of(tester.element(find.byType(SamplePage))).matchedLocation, '/sample');
    });

    testWidgets(
        '「B」「A」の順（B が上の行）で2件がある状態で、下の行「A」の Icons.more_vert をタップしてメニューを開き、続けて上の行「B」の Icons.more_vert をタップした場合、「A」のメニューが閉じ、「編集」「削除」は表示されない（「B」のメニューは開かない）。一覧は「B」「A」の2件のまま [SMP-D27]',
        (tester) async {
      // B を先に作成して上の行、A を後に作成して下の行にする。
      // A（下の行）のメニューは下向きに開くため、上の行「B」のアイコンは
      // メニューに覆われない（覆われる配置だと「B をタップ」した座標が
      // 実際は A 自身のメニュー項目に当たってしまい、B へのタップを検証できない）。
      final bTopRow = _sample('sample-b', 'B', DateTime(2024, 1, 1));
      final aBottomRow = _sample('sample-a', 'A', DateTime(2024, 1, 2));
      final repo = FakeSampleRepository(initial: [bTopRow, aBottomRow]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openMenuFor(tester, 'A');

      // 「B」の Icons.more_vert が、開いた「A」のメニューに覆われていないことを確認する
      // （覆われていればここで tap() が hit-test 警告を出し、B ではなく A 自身の
      // メニュー項目をタップしてしまうため、先に矩形の重なりを検証する）。
      final bIconRect = tester.getRect(
        find.descendant(
          of: find.ancestor(of: find.text('B'), matching: find.byType(Card)),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      final menuRect = tester.getRect(find.byType(SingleChildScrollView).last);
      expect(
        menuRect.overlaps(bIconRect),
        isFalse,
        reason: '「A」のメニュー($menuRect)が「B」の more_vert($bIconRect)を覆っていると、'
            'B をタップしたつもりでも実際は A 自身のメニュー項目に当たってしまう',
      );

      // 「B」の Icons.more_vert をタップする（行の中から探す。A の行のアイコンと混同しない）
      final bTile = find.ancestor(of: find.text('B'), matching: find.byType(Card));
      await tester.tap(find.descendant(of: bTile, matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);
      expect(_tileNames(tester), ['B', 'A']);
    });
  });

  // ─── 3.5 作成 ──────────────────────────────────────────────
  group('SamplePage 作成', () {
    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効 [SMP-C01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      expect(find.text('サンプルを作成'), findsOneWidget);
      expect(find.text('サンプル名'), findsOneWidget);
      expect(_fieldText(tester), '');
      expect(find.text('半角20文字（全角10文字）まで'), findsOneWidget);
      final cancelTopLeft = tester.getTopLeft(find.widgetWithText(TextButton, 'キャンセル'));
      final createTopLeft = tester.getTopLeft(find.widgetWithText(FilledButton, '作成'));
      expect(cancelTopLeft.dx, lessThan(createTopLeft.dx));
      // 上から順に タイトル → 入力項目タイトル → 入力欄 → 注意書 → ボタン行 になっている
      final titleTop = tester.getTopLeft(find.text('サンプルを作成')).dy;
      final labelTop = tester.getTopLeft(find.text('サンプル名')).dy;
      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      final helperTop = tester.getTopLeft(find.text('半角20文字（全角10文字）まで')).dy;
      // 「サンプル名」はフローティングラベルとして入力欄（TextField）の枠内・上寄りに
      // 描画されるため、fieldTop（枠全体の最上部）より数px下になる。ラベルと枠を
      // 別々の上下関係として比較せず、両者とも「タイトルより下・注意書より上」であることを見る。
      expect(titleTop, lessThan(labelTop));
      expect(titleTop, lessThan(fieldTop));
      expect(labelTop, lessThan(helperTop));
      expect(fieldTop, lessThan(helperTop));
      expect(helperTop, lessThan(cancelTopLeft.dy));
      expect(_filledButton(tester, '作成').onPressed, isNull);
    });

    testWidgets(
        '0件の状態で「サンプルを作成」ボタンをタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効 [SMP-C02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: const []);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromEmptyButton(tester);
      // 背後の「サンプルを作成」ボタン（0件表示）と文言が重なるため、ダイアログ内に絞る
      final titleFinder = find.descendant(of: find.byType(AlertDialog), matching: find.text('サンプルを作成'));
      expect(titleFinder, findsOneWidget);
      expect(find.text('サンプル名'), findsOneWidget);
      expect(_fieldText(tester), '');
      expect(find.text('半角20文字（全角10文字）まで'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'キャンセル'), findsOneWidget);
      final cancelTopLeft = tester.getTopLeft(find.widgetWithText(TextButton, 'キャンセル'));
      final createTopLeft = tester.getTopLeft(find.widgetWithText(FilledButton, '作成'));
      expect(cancelTopLeft.dx, lessThan(createTopLeft.dx));
      // 上から順に タイトル → 入力項目タイトル → 入力欄 → 注意書 → ボタン行 になっている
      final titleTop = tester.getTopLeft(titleFinder).dy;
      final labelTop = tester.getTopLeft(find.text('サンプル名')).dy;
      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      final helperTop = tester.getTopLeft(find.text('半角20文字（全角10文字）まで')).dy;
      // 「サンプル名」はフローティングラベルとして入力欄（TextField）の枠内・上寄りに
      // 描画されるため、fieldTop（枠全体の最上部）より数px下になる。ラベルと枠を
      // 別々の上下関係として比較せず、両者とも「タイトルより下・注意書より上」であることを見る。
      expect(titleTop, lessThan(labelTop));
      expect(titleTop, lessThan(fieldTop));
      expect(labelTop, lessThan(helperTop));
      expect(fieldTop, lessThan(helperTop));
      expect(helperTop, lessThan(cancelTopLeft.dy));
      expect(_filledButton(tester, '作成').onPressed, isNull);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される [SMP-C03]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に「B」が表示される。「サンプルがありません」は表示されない [SMP-C04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: const []);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromEmptyButton(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「A」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に「A」「A」の2件が表示される [SMP-C05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'A']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「 B 」（前後に半角スペース）を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない） [SMP-C06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), ' B ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「　B　」（前後に全角スペース）を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない） [SMP-C07]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), '　B　');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C08]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力してダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C10]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、「作成」が無効になる [SMP-C11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pump();
      expect(_filledButton(tester, '作成').onPressed, isNull);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して、作成の完了前に「作成」を2回続けてタップした場合、ダイアログが閉じる。一覧に「A」「B」の2件が表示される（「B」は1件だけ） [SMP-C12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pump();
      repo.createGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、ダイアログ内に CircularProgressIndicator は表示されない [SMP-C13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pump();
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(CircularProgressIndicator)),
        findsNothing,
      );
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、「キャンセル」が無効になる [SMP-C14]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pump();
      expect(_textButton(tester, 'キャンセル').onPressed, isNull);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-C15]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-C16]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま [SMP-C17]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'B');
      expect(_filledButton(tester, '作成').onPressed, isNotNull);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、UnknownFailure で失敗した後、もう一度「作成」をタップして再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-C18]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])
        ..createFailures.addAll([const Failure.unknown('e1'), const Failure.unknown('e2')]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示されたまま [SMP-C19]',
        (tester) async {
      final repo = FakeSampleRepository(initial: const []);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromEmptyButton(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('サンプルがありません'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'サンプルを作成'), findsOneWidget);
    });

    testWidgets(
        '0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。ダイアログの背後には「サンプルがありません」が表示されたまま [SMP-C20]',
        (tester) async {
      final repo = FakeSampleRepository(initial: const [])..createFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromEmptyButton(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'B');
      expect(_filledButton(tester, '作成').onPressed, isNotNull);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「あいうえおかきくけこ」（幅20）を入力した場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-C21]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), _wide20);
      await tester.pump();
      expect(_fieldText(tester), _wide20);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '作成日時が古い順に「S01」〜「S30」の30件があり、一覧の先頭（「S01」）が表示されている状態で、FloatingActionButton をタップし、「S31」を入力して「作成」をタップした場合、ダイアログが閉じる。スクロール操作をしなくても、画面内に「S31」が表示される [SMP-C22]',
        (tester) async {
      final repo = FakeSampleRepository(initial: _many(30));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'S31');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('S31'), findsOneWidget);
    });
  });

  // ─── 3.6 編集 ──────────────────────────────────────────────
  group('SamplePage 編集', () {
    testWidgets(
        '「A」の1件がある状態で、「A」の Icons.more_vert をタップして「編集」をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを編集」、入力項目タイトル「サンプル名」、「A」が入った入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「保存」（右）が表示される。「保存」は有効 [SMP-U01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      expect(find.text('サンプルを編集'), findsOneWidget);
      expect(find.text('サンプル名'), findsOneWidget);
      expect(_fieldText(tester), 'A');
      expect(find.text('半角20文字（全角10文字）まで'), findsOneWidget);
      final cancelTopLeft = tester.getTopLeft(find.widgetWithText(TextButton, 'キャンセル'));
      final saveTopLeft = tester.getTopLeft(find.widgetWithText(FilledButton, '保存'));
      expect(cancelTopLeft.dx, lessThan(saveTopLeft.dx));
      // 上から順に タイトル → 入力項目タイトル → 入力欄 → 注意書 → ボタン行 になっている
      final titleTop = tester.getTopLeft(find.text('サンプルを編集')).dy;
      final labelTop = tester.getTopLeft(find.text('サンプル名')).dy;
      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      final helperTop = tester.getTopLeft(find.text('半角20文字（全角10文字）まで')).dy;
      // 「サンプル名」はフローティングラベルとして入力欄（TextField）の枠内・上寄りに
      // 描画されるため、fieldTop（枠全体の最上部）より数px下になる。ラベルと枠を
      // 別々の上下関係として比較せず、両者とも「タイトルより下・注意書より上」であることを見る。
      expect(titleTop, lessThan(labelTop));
      expect(titleTop, lessThan(fieldTop));
      expect(labelTop, lessThan(helperTop));
      expect(fieldTop, lessThan(helperTop));
      expect(helperTop, lessThan(cancelTopLeft.dy));
      expect(_filledButton(tester, '保存').onPressed, isNotNull);
    });

    testWidgets(
        '「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「編集」をタップした場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-U02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('sample-w', _wide20, DateTime(2024, 1, 1))]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, _wide20);
      expect(_fieldText(tester), _wide20);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」「C」の順で表示される [SMP-U03]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB, _sampleC]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A', 'X', 'C']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「A」に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に「A」「A」の2件が表示される [SMP-U04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'A']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を変えずに「保存」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「 X 」（前後に半角スペース）に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない） [SMP-U06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), ' X ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'X']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「　X　」（前後に全角スペース）に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない） [SMP-U07]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), '　X　');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'X']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U08]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えてダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U10]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、「保存」が無効になる [SMP-U11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..updateGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      expect(_filledButton(tester, '保存').onPressed, isNull);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて、変更の完了前に「保存」を2回続けてタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の2件が表示される [SMP-U12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..updateGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      repo.updateGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A', 'X']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、ダイアログ内に CircularProgressIndicator は表示されない [SMP-U13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..updateGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(CircularProgressIndicator)),
        findsNothing,
      );
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、「キャンセル」が無効になる [SMP-U14]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..updateGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      expect(_textButton(tester, 'キャンセル').onPressed, isNull);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-U15]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..updateGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-U16]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..updateGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残り、「保存」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま [SMP-U17]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..updateFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'X');
      expect(_filledButton(tester, '保存').onPressed, isNotNull);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、UnknownFailure で失敗した後、もう一度「保存」をタップして再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-U18]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])
        ..updateFailures.addAll([const Failure.unknown('e1'), const Failure.unknown('e2')]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を空にしてから「あいうえおかきくけこ」（幅20）を入力した場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-U19]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.enterText(find.byType(TextField), _wide20);
      await tester.pump();
      expect(_fieldText(tester), _wide20);
      expect(tester.takeException(), isNull);
    });
  });

  // ─── 3.7 削除 ──────────────────────────────────────────────
  group('SamplePage 削除', () {
    testWidgets(
        '「A」の1件がある状態で、「A」の Icons.more_vert をタップして「削除」をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを削除」、注記「※「A」を削除しますか？」、横並びの「キャンセル」（左）と「削除」（右）が表示される [SMP-X01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      expect(find.text('サンプルを削除'), findsOneWidget);
      expect(find.text('※「A」を削除しますか？'), findsOneWidget);
      final cancelTopLeft = tester.getTopLeft(find.widgetWithText(TextButton, 'キャンセル'));
      final deleteTopLeft = tester.getTopLeft(find.widgetWithText(FilledButton, '削除'));
      expect(cancelTopLeft.dx, lessThan(deleteTopLeft.dx));
      // 上から順に タイトル → 注記 → ボタン行 になっている（削除ダイアログには入力欄がない）
      final titleTop = tester.getTopLeft(find.text('サンプルを削除')).dy;
      final noteTop = tester.getTopLeft(find.text('※「A」を削除しますか？')).dy;
      expect(titleTop, lessThan(noteTop));
      expect(noteTop, lessThan(cancelTopLeft.dy));
    });

    testWidgets(
        '「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「削除」をタップした場合、注記「※「あいうえおかきくけこ」を削除しますか？」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-X02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('sample-w', _wide20, DateTime(2024, 1, 1))]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, _wide20);
      expect(find.text('※「$_wide20」を削除しますか？'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に「B」の1件だけが表示される [SMP-X03]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['B']);
    });

    testWidgets(
        '作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に上から「A」「C」の順で表示される [SMP-X04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB, _sampleC]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'B');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['A', 'C']);
    });

    testWidgets(
        '「A」の1件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示される [SMP-X05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('サンプルがありません'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'サンプルを作成'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いてダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X07]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X08]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、削除ダイアログ（「サンプルを削除」）は表示されていない [SMP-X09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('サンプルを削除'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、画面に CircularProgressIndicator は表示されない [SMP-X10]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が UnknownFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま [SMP-X11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteFailures.add(const Failure.unknown('e'));
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('サンプルを削除'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」を削除して UnknownFailure で失敗した後、もう一度「A」の削除ダイアログを開いて「削除」をタップし、再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-X12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])
        ..deleteFailures.addAll([const Failure.unknown('e1'), const Failure.unknown('e2')]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '一覧に「A」「B」が表示され、Repository 上では「A」が既に削除されている状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に「B」の1件だけが表示される。「操作が失敗しました。」は表示されない [SMP-X13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      // Repository 上ではすでに削除されている状態にする（一覧側の表示はまだ「A」を持つ）
      repo.samples.removeWhere((s) => s.id == _sampleA.id);
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['B']);
      expect(find.text('操作が失敗しました。'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「A」の Icons.more_vert をタップした場合、「編集」「削除」のメニューは表示されない（「A」の Icons.more_vert は無効） [SMP-X14]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pump();
      final aTile = find.ancestor(of: find.text('A'), matching: find.byType(Card));
      await tester.tap(find.descendant(of: aTile, matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に FloatingActionButton から「C」を作成して、作成と削除の両方が成功した場合、両方の完了後、一覧に上から「B」「C」の順で表示される。「A」は表示されない [SMP-X15]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pump();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      repo.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['B', 'C']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧を下に引っ張って離し、プルして更新の読み込みが削除前の「A」「B」を返して削除の完了より後に終わった場合、両方の完了後、一覧に「B」の1件だけが表示される。「A」は表示されない [SMP-X16]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteGate = Completer<void>();
      final refreshGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pump();
      repo.getResponses.add((gate: refreshGate, returnValue: [_sampleA, _sampleB]));
      await _pullToRefresh(tester);
      // プルして更新（refreshGate）はまだ完了していないため、RefreshIndicator の
      // 回転アニメーションが続く。ここで pumpAndSettle すると終わらないので、
      // 削除完了による内部の refresh() が状態を反映するまでを軽く pump するだけにする。
      repo.deleteGate!.complete();
      await tester.pump();
      await tester.pump();
      refreshGate.complete();
      await tester.pumpAndSettle();
      expect(_tileNames(tester), ['B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧の「B」をタップした場合、遷移先のパスが /folder/<B の id> になり、遷移先に渡される \$extra が「B」 [SMP-X17]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteGate = Completer<void>();
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(find.text('folder:${_sampleB.id}:B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「B」の Icons.more_vert をタップした場合、「編集」「削除」が表示される [SMP-X18]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteGate = Completer<void>();
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pump();
      final bTile = find.ancestor(of: find.text('B'), matching: find.byType(Card));
      await tester.tap(find.descendant(of: bTile, matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });
  });

  // ─── 3.8 画面遷移 ──────────────────────────────────────────
  group('SamplePage 画面遷移', () {
    testWidgets(
        'id が「sample-1」、名前が「A」の1件がある状態で、一覧の「A」をタップした場合、遷移先のパスが /folder/sample-1 になり、遷移先に渡される \$extra が「A」 [SMP-T01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('sample-1', 'A', DateTime(2024, 1, 1))]);
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      expect(find.text('folder:sample-1:A'), findsOneWidget);
    });

    testWidgets('「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、遷移しない（パスは /sample のまま）。「編集」「削除」が表示される [SMP-T02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await _openMenuFor(tester, 'A');
      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
      expect(find.byType(SamplePage), findsOneWidget);
    });
  });

  // ─── 3.9 エラー種別ごとの扱い ──────────────────────────────
  group('SamplePage エラー種別ごとの扱い', () {
    testWidgets(
        '画面を開き、初期読み込みが NotFoundFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E01]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.notFound());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('画面を開き、初期読み込みが NetworkFailure で失敗した場合、NetworkErrorDialog が表示される。ErrorScreen は表示されない [SMP-E02]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.network());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets(
        '初期読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E03]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.network());
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets('画面を開き、初期読み込みが AuthFailure で失敗した場合、NetworkErrorDialog が表示される。ErrorScreen は表示されない [SMP-E04]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.auth());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets(
        '初期読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E05]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.auth());
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets(
        '初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NotFoundFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E06]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.addAll([const Failure.unknown('e'), const Failure.notFound()]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets(
        '初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NetworkFailure で失敗した場合、NetworkErrorDialog が表示される [SMP-E07]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.addAll([const Failure.unknown('e'), const Failure.network()]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);
    });

    testWidgets(
        '「再試行」後の読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E08]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.addAll([const Failure.unknown('e'), const Failure.network()]);
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets(
        '初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが AuthFailure で失敗した場合、NetworkErrorDialog が表示される [SMP-E09]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.addAll([const Failure.unknown('e'), const Failure.auth()]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);
    });

    testWidgets(
        '「再試行」後の読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E10]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.addAll([const Failure.unknown('e'), const Failure.auth()]);
      await tester.pumpWidget(_buildPageWithRouter(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets(
        '一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NotFoundFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま [SMP-E11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.getFailures.add(const Failure.notFound());
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NetworkFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない [SMP-E12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.getFailures.add(const Failure.network());
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('通信エラー'), findsNothing);
    });

    testWidgets(
        '一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが AuthFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない [SMP-E13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      repo.getFailures.add(const Failure.auth());
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('通信エラー'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が NetworkFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない [SMP-E14]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createFailures.add(const Failure.network());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'B');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A']);
      expect(find.text('通信エラー'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が AuthFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない [SMP-E15]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA])..createFailures.add(const Failure.auth());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'B');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A']);
      expect(find.text('通信エラー'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NotFoundFailure で失敗した（「B」が既に削除されていた）場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま [SMP-E16]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..updateFailures.add(const Failure.notFound());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'X');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NetworkFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない [SMP-E17]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..updateFailures.add(const Failure.network());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'X');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
      expect(find.text('通信エラー'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が AuthFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない [SMP-E18]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..updateFailures.add(const Failure.auth());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'B');
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldText(tester), 'X');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
      expect(find.text('通信エラー'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NotFoundFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま [SMP-E19]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteFailures.add(const Failure.notFound());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('サンプルを削除'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NetworkFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない [SMP-E20]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteFailures.add(const Failure.network());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('サンプルを削除'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
      expect(find.text('通信エラー'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が AuthFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない [SMP-E21]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA, _sampleB])..deleteFailures.add(const Failure.auth());
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openDeleteDialogFor(tester, 'A');
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('サンプルを削除'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(_tileNames(tester), ['A', 'B']);
      expect(find.text('通信エラー'), findsNothing);
    });
  });

  // ─── 2.2 入力ルール（境界値） ──────────────────────────────
  group('SamplePage 入力ルール SMP-N01（作成ダイアログの空欄判定）', () {
    final cases = <String, bool>{
      'B': true,
      ' B ': true,
      '': false,
      '   ': false,
      '　　': false,
      ' 　 ': false,
    };
    for (final entry in cases.entries) {
      testWidgets(
          '作成ダイアログの入力欄に「${entry.key}」（${_spaceLabel(entry.key)}）を入力した場合、「作成」は${entry.value ? '有効' : '無効'}になる [SMP-N01]',
          (tester) async {
        final repo = FakeSampleRepository(initial: [_sampleA]);
        await tester.pumpWidget(_buildPage(repo));
        await tester.pumpAndSettle();
        await _openCreateDialogFromFab(tester);
        await tester.enterText(find.byType(TextField), entry.key);
        await tester.pump();
        expect(_filledButton(tester, '作成').onPressed != null, entry.value);
      });
    }
  });

  group('SamplePage 入力ルール SMP-N02（作成ダイアログの幅20制限）', () {
    testWidgets('作成ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、入力欄はそのまま「abcdefghijklmnopqrst」になる [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrst');
      await tester.pump();
      expect(_fieldText(tester), 'abcdefghijklmnopqrst');
    });

    testWidgets('作成ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、入力欄はそのまま「あいうえおかきくけこ」になる [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこ');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおかきくけこ');
    });

    testWidgets('作成ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、入力欄はそのまま「あいうえおabcdefghij」になる [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'あいうえおabcdefghij');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおabcdefghij');
    });

    testWidgets('作成ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrst');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrstu');
      await tester.pump();
      expect(_fieldText(tester), 'abcdefghijklmnopqrst');
    });

    testWidgets('作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこ');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこさ');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおかきくけこ');
    });

    testWidgets('作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこ');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこa');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおかきくけこ');
    });

    testWidgets('作成ダイアログの空の入力欄に「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), ' abcdefghijklmnopqrst');
      await tester.pump();
      expect(_fieldText(tester), '');
    });

    testWidgets(
        '作成ダイアログの空の状態で「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialogFromFab(tester);
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrstuvwxyz0123');
      await tester.pump();
      expect(_fieldText(tester), '');
    });
  });

  group('SamplePage 入力ルール SMP-N03（編集ダイアログの空欄判定）', () {
    final cases = <String, bool>{
      'X': true,
      ' X ': true,
      '': false,
      '   ': false,
      '　　': false,
      ' 　 ': false,
    };
    for (final entry in cases.entries) {
      testWidgets(
          '編集ダイアログの入力欄に「${entry.key}」（${_spaceLabel(entry.key)}）を入力した場合、「保存」は${entry.value ? '有効' : '無効'}になる [SMP-N03]',
          (tester) async {
        final repo = FakeSampleRepository(initial: [_sampleA]);
        await tester.pumpWidget(_buildPage(repo));
        await tester.pumpAndSettle();
        await _openEditDialogFor(tester, 'A');
        await tester.enterText(find.byType(TextField), entry.key);
        await tester.pump();
        expect(_filledButton(tester, '保存').onPressed != null, entry.value);
      });
    }
  });

  group('SamplePage 入力ルール SMP-N04（編集ダイアログの幅20制限）', () {
    testWidgets('編集ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、入力欄はそのまま「abcdefghijklmnopqrst」になる [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrst');
      await tester.pump();
      expect(_fieldText(tester), 'abcdefghijklmnopqrst');
    });

    testWidgets('編集ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、入力欄はそのまま「あいうえおかきくけこ」になる [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこ');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおかきくけこ');
    });

    testWidgets('編集ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、入力欄はそのまま「あいうえおabcdefghij」になる [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'あいうえおabcdefghij');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおabcdefghij');
    });

    testWidgets('編集ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrst');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrstu');
      await tester.pump();
      expect(_fieldText(tester), 'abcdefghijklmnopqrst');
    });

    testWidgets('編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこ');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこさ');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおかきくけこ');
    });

    testWidgets('編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこ');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'あいうえおかきくけこa');
      await tester.pump();
      expect(_fieldText(tester), 'あいうえおかきくけこ');
    });

    testWidgets('編集ダイアログの入力欄を空にしてから「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.enterText(find.byType(TextField), ' abcdefghijklmnopqrst');
      await tester.pump();
      expect(_fieldText(tester), '');
    });

    testWidgets(
        '編集ダイアログの入力欄を空にしてから「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N04]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sampleA]);
      await tester.pumpWidget(_buildPage(repo));
      await tester.pumpAndSettle();
      await _openEditDialogFor(tester, 'A');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrstuvwxyz0123');
      await tester.pump();
      expect(_fieldText(tester), '');
    });
  });
}
