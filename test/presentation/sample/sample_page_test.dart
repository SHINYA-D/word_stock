import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/repository_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/core/widgets/error_screen.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_auth_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_flashcard_result_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_folder_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_settings_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_word_repository.dart';
import 'package:word_stock/presentation/sample/sample_page.dart';
import 'package:word_stock/presentation/shell/shell_page.dart';

import '../../helpers/fake_infrastructure.dart';
import '../../helpers/test_helpers.dart';

/// 仕様書（docs/detailed_design/presentation/sample/sample_page.md）の
/// 「ログイン中のユーザーの id は u1 とする」に合わせたテスト用ユーザー。
const _testUser = AppUser(id: 'u1', email: 'u1@example.com');

Sample _sample(
  String id,
  String name, {
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime(2024, 1, 1);
  return Sample(
    id: id,
    name: name,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

/// BottomNav・/folder・/login への画面遷移を確認するための GoRouter 付きアプリ（buildSampleApp）用の
/// モックリポジトリ一覧。ShellPage を含む最小限のルーター構成を自前で組む必要があるため、
/// buildWithMockRepositories() は使わずここで定義する。
List<Override> _baseOverrides(FakeSampleRepository repository) => [
      authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      folderRepositoryProvider.overrideWithValue(MockFolderRepository()),
      wordRepositoryProvider.overrideWithValue(MockWordRepository()),
      settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
      flashcardResultRepositoryProvider
          .overrideWithValue(MockFlashcardResultRepository()),
      currentUserProvider.overrideWithValue(_testUser),
      sampleRepositoryProvider.overrideWithValue(repository),
    ];

/// SamplePage 単体を MaterialApp(home:) に載せる。
/// SampleViewModel はサブクラスで override せず、FakeSampleRepository を
/// 経由した本物の ViewModel をそのまま動かす。
Widget buildSamplePage(FakeSampleRepository repository) {
  return buildWithMockRepositories(
    child: const SamplePage(),
    extra: [
      sampleRepositoryProvider.overrideWithValue(repository),
      currentUserProvider.overrideWithValue(_testUser),
    ],
  );
}

/// BottomNav・/folder・/login への画面遷移を確認するための GoRouter 付きアプリ。
/// ShellPage を含む最小限のルーター構成（app 本体の router.dart には依存しない）。
Widget buildSampleApp(
  FakeSampleRepository repository, {
  String initialLocation = '/sample',
}) {
  return ProviderScope(
    overrides: _baseOverrides(repository),
    child: Consumer(
      builder: (context, ref, _) {
        late final GoRouter router;
        router = GoRouter(
          initialLocation: initialLocation,
          redirect: (context, state) {
            final authState = ref.read(authStateProvider);
            if (authState.isLoading) return null;
            final isLoggedIn = authState.valueOrNull != null;
            if (!isLoggedIn && state.matchedLocation != '/login') {
              return '/login';
            }
            return null;
          },
          routes: [
            GoRoute(
              path: '/login',
              builder: (c, s) => const Text('login-screen'),
            ),
            ShellRoute(
              builder: (context, state, navigator) =>
                  ShellPage(child: navigator),
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (c, s) => const Text('home-screen'),
                ),
                GoRoute(
                  path: '/results',
                  builder: (c, s) => const Text('results-screen'),
                ),
                GoRoute(
                  path: '/sample',
                  builder: (c, s) => const SamplePage(),
                ),
                GoRoute(
                  path: '/settings',
                  builder: (c, s) => const Text('settings-screen'),
                ),
                GoRoute(
                  path: '/folder/:folderId',
                  builder: (c, s) => Text(
                    'folder-screen:${s.pathParameters['folderId']}:${s.extra}',
                  ),
                ),
              ],
            ),
          ],
        );
        ref.listen(authStateProvider, (prev, next) => router.refresh());
        return MaterialApp.router(routerConfig: router);
      },
    ),
  );
}

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// プルして更新のジェスチャーだけを開始し、完了を待たない
/// （読み込み中の表示・競合を観測するため）。
Future<void> _startPullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openCreateDialog(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, {int index = 0}) async {
  await tester.tap(find.byIcon(Icons.more_vert).at(index));
  await tester.pumpAndSettle();
}

Future<void> _openEditDialog(WidgetTester tester, {int index = 0}) async {
  await _openMenu(tester, index: index);
  await tester.tap(find.text('編集'));
  await tester.pumpAndSettle();
}

Future<void> _openDeleteDialog(WidgetTester tester, {int index = 0}) async {
  await _openMenu(tester, index: index);
  await tester.tap(find.text('削除'));
  await tester.pumpAndSettle();
}

Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}

/// 端末の戻る操作（Android の back ボタン相当）を再現する。
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Finder get _createButton => find.widgetWithText(FilledButton, '作成');
Finder get _saveButton => find.widgetWithText(FilledButton, '保存');
Finder get _cancelButton => find.widgetWithText(TextButton, 'キャンセル');
Finder get _deleteButton => find.widgetWithText(FilledButton, '削除');

bool _isFilledEnabled(Finder buttonFinder, WidgetTester tester) =>
    tester.widget<FilledButton>(buttonFinder).onPressed != null;

bool _isTextButtonEnabled(Finder buttonFinder, WidgetTester tester) =>
    tester.widget<TextButton>(buttonFinder).onPressed != null;

void main() {
  group('SamplePage 3.1 表示', () {
    testWidgets('「A」の1件がある状態で画面を開いた場合、AppBarに「サンプル」と表示される [SMP-D01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text('サンプル'), findsOneWidget);
    });

    testWidgets('/sampleを開いた場合、ボトムナビゲーションバーが表示され「テスト」タブが選択状態になる [SMP-D02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });

    testWidgets(
        '「A」の1件がある状態で画面を開いた場合、画面右下にIcons.addのアイコンを持つFloatingActionButtonが表示される [SMP-D03]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(
        find.descendant(of: fab, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
    });

    testWidgets(
        'サンプルが0件の状態で画面を開いた場合、画面右下にIcons.addのアイコンを持つFloatingActionButtonが表示される [SMP-D04]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(
        find.descendant(of: fab, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
    });

    testWidgets('「A」「B」の2件がある状態で画面を開いた場合、各行の右端にIcons.more_vertが1つずつ計2つ表示される [SMP-D05]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    });

    testWidgets(
        'サンプルが0件の状態で画面を開いた場合、上から順にIcons.science_outlined・「サンプルがありません」・Icons.addと「サンプルを作成」のボタンが表示され一覧の行は表示されない [SMP-D06]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.science_outlined);
      final textFinder = find.text('サンプルがありません');
      final createButtonFinder = find.widgetWithText(FilledButton, 'サンプルを作成');
      expect(iconFinder, findsOneWidget);
      expect(textFinder, findsOneWidget);
      expect(createButtonFinder, findsOneWidget);
      expect(
        find.descendant(
          of: createButtonFinder,
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
      final iconY = tester.getTopLeft(iconFinder).dy;
      final textY = tester.getTopLeft(textFinder).dy;
      final buttonY = tester.getTopLeft(createButtonFinder).dy;
      expect(iconY, lessThan(textY));
      expect(textY, lessThan(buttonY));
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で画面を開いた場合、一覧に「A」「B」がこの順で表示され「サンプルがありません」は表示されない [SMP-D07]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets('作成日時が古い順に「A」「B」「C」の3件がある状態で画面を開いた場合、一覧に上から「A」「B」「C」の順で表示される [SMP-D08]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [
          _sample('a-id', 'A'),
          _sample('b-id', 'B'),
          _sample('c-id', 'C'),
        ],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      final cY = tester.getTopLeft(find.text('C')).dy;
      expect(aY, lessThan(bY));
      expect(bY, lessThan(cY));
    });

    testWidgets('作成日時が古い順に「S01」〜「S30」の30件がある状態で画面を開き下へスクロールした場合、「S30」が表示される [SMP-D09]',
        (tester) async {
      final samples = List.generate(
        30,
        (i) => _sample('id-$i', 'S${(i + 1).toString().padLeft(2, '0')}'),
      );
      final repo = FakeSampleRepository(initial: samples);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('S30'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('S30'), findsOneWidget);
    });

    testWidgets(
        '「あいうえおかきくけこ」（幅20）の1件がある状態で画面を開いた場合、一覧にその1件が表示されオーバーフローのエラーが発生しない [SMP-D10]',
        (tester) async {
      const name = 'あいうえおかきくけこ';
      final repo = FakeSampleRepository(initial: [_sample('a-id', name)]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text(name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '画面を開き初期読み込みが完了していない場合、CircularProgressIndicatorが表示され一覧・「サンプルがありません」は表示されない [SMP-D11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')])
        ..getGate = Completer<void>();

      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.text('サンプルがありません'), findsNothing);

      repo.getGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('画面を開き初期読み込みが完了していない場合、FloatingActionButtonは表示されない [SMP-D12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')])
        ..getGate = Completer<void>();

      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      repo.getGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '画面を開き初期読み込みがUnknownFailureで失敗した場合、ErrorScreenが表示され「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D13]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.text('サンプルがありません'), findsNothing);
    });

    testWidgets('画面を開き初期読み込みがUnknownFailureで失敗した場合、FloatingActionButtonは表示されない [SMP-D14]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('SamplePage 3.2 再試行', () {
    testWidgets(
        'ErrorScreen表示中にRepositoryが「A」を返すようにして「再試行」をタップした場合、一覧に「A」が表示されErrorScreenは表示されない [SMP-D15]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.samples = [_sample('a-id', 'A')];
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('ErrorScreen表示中に「再試行」をタップし読み込みが完了していない場合、CircularProgressIndicatorが表示され「再試行」は表示されない [SMP-D16]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.getGate = Completer<void>();
      await tester.tap(find.text('再試行'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('再試行'), findsNothing);

      repo.getGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'ErrorScreen表示中に「再試行」をタップし読み込みが再びUnknownFailureで失敗した場合、ErrorScreenが表示され「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D17]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.getFailures.add(const Failure.unknown('boom again'));
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });
  });

  group('SamplePage 3.3 プルして更新', () {
    testWidgets('「A」が表示されている状態でRepositoryに「B」を追加し一覧を下に引っ張って離した場合、一覧に「A」「B」がこの順で表示される [SMP-D18]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.text('B'), findsNothing);

      repo.samples.add(_sample('b-id', 'B'));
      await _pullToRefresh(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」が表示されている状態で一覧を下に引っ張って離し読み込みが完了していない場合、RefreshProgressIndicatorが表示され一覧は「A」が表示されたまま [SMP-D19]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getGate = Completer<void>();
      await _startPullToRefresh(tester);

      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      repo.getGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」が表示されている状態でプルして更新し読み込みがUnknownFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreenは表示されずスナックバーに「操作が失敗しました。」と表示される [SMP-D20]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.unknown('boom'));
      await _pullToRefresh(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」が表示されている状態でプルして更新を2回続けて行い2回ともUnknownFailureで失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-D21]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.unknown('boom1'));
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.unknown('boom2'));
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
        '0件の状態でRepositoryに「A」が追加された状態にして画面を下に引っ張って離した場合、一覧に「A」が表示され「サンプルがありません」は表示されない [SMP-D22]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.text('サンプルがありません'), findsOneWidget);

      repo.samples.add(_sample('a-id', 'A'));
      // 0件表示中は ListView が無いため、Scaffold の body 全体を対象に引っ張る
      await tester.fling(
        find.byType(Scaffold),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsNothing);
    });
  });

  group('SamplePage 3.4 メニュー', () {
    testWidgets('「A」の1件がある状態で「A」のIcons.more_vertをタップした場合、「編集」「削除」が表示される [SMP-D23]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openMenu(tester);

      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets('「A」の1件がある状態で「A」のIcons.more_vertをタップした場合、上から「編集」「削除」の順で表示される [SMP-D24]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openMenu(tester);

      final editY = tester.getTopLeft(find.text('編集')).dy;
      final deleteY = tester.getTopLeft(find.text('削除')).dy;
      expect(editY, lessThan(deleteY));
    });

    testWidgets(
        '「A」の1件がある状態でメニューを開きメニューの外側をタップした場合、「編集」「削除」は表示されず一覧は「A」の1件のまま [SMP-D25]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await _tapOutside(tester);

      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態でメニューを開き端末の戻る操作をした場合、「編集」「削除」は表示されず一覧は「A」の1件のままでパスは/sampleのまま [SMP-D26]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await _pressBack(tester);

      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」のメニューを開き続けて「B」のIcons.more_vertをタップした場合、「A」のメニューが閉じ「編集」「削除」は表示されず一覧は「A」「B」の2件のまま [SMP-D27]',
        (tester) async {
      // A の直後の行だとメニューのオーバーレイと物理的に重なり、タップが
      // 意図せずメニュー項目自体にヒットしてしまうため、十分に離れた行を
      // 「B」役に使う（同じ「別の行の more_vert をタップする」操作を検証する）。
      final repo = FakeSampleRepository(
        initial: [
          _sample('a-id', 'A'),
          _sample('c1-id', 'C1'),
          _sample('c2-id', 'C2'),
          _sample('c3-id', 'C3'),
          _sample('b-id', 'B'),
        ],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openMenu(tester, index: 0);
      await tester.tap(find.byIcon(Icons.more_vert).at(4));
      await tester.pumpAndSettle();

      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('SamplePage 3.5 作成', () {
    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップした場合、作成ダイアログが表示されタイトル「サンプルを作成」・「サンプル名」・空の入力欄・「半角20文字（全角10文字）まで」・「キャンセル」（左）・「作成」（右）が表示され「作成」は無効 [SMP-C01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);

      expect(find.text('サンプルを作成'), findsOneWidget);
      expect(find.text('サンプル名'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(find.text('半角20文字（全角10文字）まで'), findsOneWidget);
      expect(_cancelButton, findsOneWidget);
      expect(_createButton, findsOneWidget);
      expect(_isFilledEnabled(_createButton, tester), isFalse);

      final titleY = tester.getTopLeft(find.text('サンプルを作成')).dy;
      final fieldY = tester.getTopLeft(find.byType(TextField)).dy;
      final helperY = tester.getTopLeft(find.text('半角20文字（全角10文字）まで')).dy;
      final cancelPos = tester.getTopLeft(_cancelButton);
      final createPos = tester.getTopLeft(_createButton);
      expect(titleY, lessThan(fieldY));
      expect(fieldY, lessThan(helperY));
      expect(helperY, lessThan(cancelPos.dy + 1));
      expect(cancelPos.dy, closeTo(createPos.dy, 1));
      expect(cancelPos.dx, lessThan(createPos.dx));
    });

    testWidgets(
        'サンプルが0件の状態で「サンプルを作成」ボタンをタップした場合、作成ダイアログが表示されタイトル「サンプルを作成」・「サンプル名」・空の入力欄・「半角20文字（全角10文字）まで」・「キャンセル」（左）・「作成」（右）が表示され「作成」は無効 [SMP-C02]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'サンプルを作成'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('サンプルを作成'),
        ),
        findsOneWidget,
      );
      expect(find.text('サンプル名'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(find.text('半角20文字（全角10文字）まで'), findsOneWidget);
      expect(_cancelButton, findsOneWidget);
      expect(_createButton, findsOneWidget);
      expect(_isFilledEnabled(_createButton, tester), isFalse);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップした場合、ダイアログが閉じ一覧に上から「A」「B」の順で表示される [SMP-C03]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '0件の状態で「サンプルを作成」ボタンをタップし「B」を入力して「作成」をタップした場合、ダイアログが閉じ一覧に「B」が表示され「サンプルがありません」は表示されない [SMP-C04]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'サンプルを作成'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('サンプルがありません'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「A」を入力して「作成」をタップした場合、ダイアログが閉じ一覧に「A」「A」の2件が表示される [SMP-C05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsNWidgets(2));
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「 B 」（前後に半角スペース）を入力して「作成」をタップした場合、ダイアログが閉じ一覧に上から「A」「B」の順で表示される [SMP-C06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), ' B ');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text(' B '), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「　B　」（前後に全角スペース）を入力して「作成」をタップした場合、ダイアログが閉じ一覧に上から「A」「B」の順で表示される [SMP-C07]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), '　B　');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('　B　'), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じ一覧は「A」の1件のまま [SMP-C08]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_cancelButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力してダイアログの外側をタップした場合、ダイアログが閉じ一覧は「A」の1件のまま [SMP-C09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await _tapOutside(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して端末の戻る操作をした場合、ダイアログが閉じ一覧は「A」の1件のまま [SMP-C10]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await _pressBack(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成が完了していない場合、「作成」が無効になる [SMP-C11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_isFilledEnabled(_createButton, tester), isFalse);

      repo.createGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して作成の完了前に「作成」を2回続けてタップした場合、ダイアログが閉じ一覧に「A」「B」の2件が表示される（「B」は1件だけ） [SMP-C12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pump();
      // ボタンが無効化されているため、2回目のタップは無視される
      await tester.tap(_createButton);
      await tester.pump();

      repo.createGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(repo.createCalls.length, 1);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成が完了していない場合、ダイアログ内にCircularProgressIndicatorは表示されない [SMP-C13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      repo.createGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成が完了していない場合、「キャンセル」が無効になる [SMP-C14]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pump();

      expect(_isTextButtonEnabled(_cancelButton, tester), isFalse);

      repo.createGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-C15]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pump();
      await _tapOutside(tester);

      expect(find.byType(AlertDialog), findsOneWidget);

      repo.createGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-C16]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pump();
      await _pressBack(tester);

      expect(find.byType(AlertDialog), findsOneWidget);

      repo.createGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成がUnknownFailureで失敗した場合、ダイアログは閉じず入力欄に「B」が残り「作成」は有効でスナックバーに「操作が失敗しました。」と表示され一覧は「A」の1件のまま [SMP-C17]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'B');
      expect(_isFilledEnabled(_createButton, tester), isTrue);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('B'), findsOneWidget); // 入力欄のテキストとして
      expect(find.text('A'), findsOneWidget); // 一覧は「A」の1件のまま
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップしUnknownFailureで失敗した後もう一度「作成」をタップして再びUnknownFailureで失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-C18]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createFailures.add(const Failure.unknown('boom1'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pump();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();

      repo.createFailures.add(const Failure.unknown('boom2'));
      await tester.tap(_createButton);
      await tester.pump();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
        '0件の状態で「サンプルを作成」ボタンをタップし「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じ「サンプルがありません」と「サンプルを作成」ボタンが表示されたまま [SMP-C19]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'サンプルを作成'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_cancelButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('サンプルがありません'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'サンプルを作成'), findsOneWidget);
    });

    testWidgets(
        '0件の状態で「サンプルを作成」ボタンをタップし「B」を入力して「作成」をタップし作成がUnknownFailureで失敗した場合、ダイアログは閉じず入力欄に「B」が残り「作成」は有効でスナックバーに「操作が失敗しました。」と表示されダイアログの背後には「サンプルがありません」が表示されたまま [SMP-C20]',
        (tester) async {
      final repo = FakeSampleRepository();
      repo.createFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'サンプルを作成'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'B');
      expect(_isFilledEnabled(_createButton, tester), isTrue);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「あいうえおかきくけこ」（幅20）を入力した場合、入力欄にその値が表示されオーバーフローのエラーが発生しない [SMP-C21]',
        (tester) async {
      const name = 'あいうえおかきくけこ';
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), name);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, name);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '作成日時が古い順に「S01」〜「S30」の30件があり一覧の先頭が表示されている状態でFloatingActionButtonをタップし「S31」を入力して「作成」をタップした場合、スクロール操作をしなくても画面内に「S31」が表示される [SMP-C22]',
        (tester) async {
      final samples = List.generate(
        30,
        (i) => _sample('id-$i', 'S${(i + 1).toString().padLeft(2, '0')}'),
      );
      final repo = FakeSampleRepository(initial: samples);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.text('S01'), findsOneWidget);

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'S31');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('S31'), findsOneWidget);
    });
  });

  group('SamplePage 3.6 編集', () {
    testWidgets(
        '「A」の1件がある状態で「A」のメニューから「編集」をタップした場合、ダイアログが表示されタイトル「サンプルを編集」・「サンプル名」・「A」が入った入力欄・「半角20文字（全角10文字）まで」・「キャンセル」（左）・「保存」（右）が表示され「保存」は有効 [SMP-U01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);

      expect(find.text('サンプルを編集'), findsOneWidget);
      expect(find.text('サンプル名'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'A');
      expect(find.text('半角20文字（全角10文字）まで'), findsOneWidget);
      expect(_cancelButton, findsOneWidget);
      expect(_saveButton, findsOneWidget);
      expect(_isFilledEnabled(_saveButton, tester), isTrue);

      final titleY = tester.getTopLeft(find.text('サンプルを編集')).dy;
      final fieldY = tester.getTopLeft(find.byType(TextField)).dy;
      final helperY = tester.getTopLeft(find.text('半角20文字（全角10文字）まで')).dy;
      final cancelPos = tester.getTopLeft(_cancelButton);
      final savePos = tester.getTopLeft(_saveButton);
      expect(titleY, lessThan(fieldY));
      expect(fieldY, lessThan(helperY));
      expect(helperY, lessThan(cancelPos.dy + 1));
      expect(cancelPos.dy, closeTo(savePos.dy, 1));
      expect(cancelPos.dx, lessThan(savePos.dx));
    });

    testWidgets(
        '「あいうえおかきくけこ」（幅20）の1件がある状態でその編集ダイアログを開いた場合、入力欄に「あいうえおかきくけこ」が表示されオーバーフローのエラーが発生しない [SMP-U02]',
        (tester) async {
      const name = 'あいうえおかきくけこ';
      final repo = FakeSampleRepository(initial: [_sample('a-id', name)]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, name);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '作成日時が古い順に「A」「B」「C」の3件がある状態で「B」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップした場合、ダイアログが閉じ一覧に上から「A」「X」「C」の順で表示される [SMP-U03]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [
          _sample('a-id', 'A'),
          _sample('b-id', 'B'),
          _sample('c-id', 'C'),
        ],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final xY = tester.getTopLeft(find.text('X')).dy;
      final cY = tester.getTopLeft(find.text('C')).dy;
      expect(aY, lessThan(xY));
      expect(xY, lessThan(cY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「A」に変えて「保存」をタップした場合、ダイアログが閉じ一覧に「A」「A」の2件が表示される [SMP-U04]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsNWidgets(2));
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を変えずに「保存」をタップした場合、ダイアログが閉じ一覧は「A」の1件のまま [SMP-U05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「 X 」（前後に半角スペース）に変えて「保存」をタップした場合、ダイアログが閉じ一覧に上から「A」「X」の順で表示される [SMP-U06]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), ' X ');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('X'), findsOneWidget);
      expect(find.text(' X '), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final xY = tester.getTopLeft(find.text('X')).dy;
      expect(aY, lessThan(xY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「　X　」（前後に全角スペース）に変えて「保存」をタップした場合、ダイアログが閉じ一覧に上から「A」「X」の順で表示される [SMP-U07]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), '　X　');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('　X　'), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final xY = tester.getTopLeft(find.text('X')).dy;
      expect(aY, lessThan(xY));
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えて「キャンセル」をタップした場合、ダイアログが閉じ一覧は「A」の1件のまま [SMP-U08]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_cancelButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('X'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えてダイアログの外側をタップした場合、ダイアログが閉じ一覧は「A」の1件のまま [SMP-U09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await _tapOutside(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('X'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えて端末の戻る操作をした場合、ダイアログが閉じ一覧は「A」の1件のまま [SMP-U10]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await _pressBack(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('X'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更が完了していない場合、「保存」が無効になる [SMP-U11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_isFilledEnabled(_saveButton, tester), isFalse);

      repo.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「X」に変えて変更の完了前に「保存」を2回続けてタップした場合、ダイアログが閉じ一覧に上から「A」「X」の2件が表示される [SMP-U12]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.updateGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();

      repo.updateGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final xY = tester.getTopLeft(find.text('X')).dy;
      expect(aY, lessThan(xY));
      expect(repo.updateCalls.length, 1);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更が完了していない場合、ダイアログ内にCircularProgressIndicatorは表示されない [SMP-U13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      repo.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更が完了していない場合、「キャンセル」が無効になる [SMP-U14]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();

      expect(_isTextButtonEnabled(_cancelButton, tester), isFalse);

      repo.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-U15]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();
      await _tapOutside(tester);

      expect(find.byType(AlertDialog), findsOneWidget);

      repo.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-U16]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();
      await _pressBack(tester);

      expect(find.byType(AlertDialog), findsOneWidget);

      repo.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更がUnknownFailureで失敗した場合、ダイアログは閉じず入力欄に「X」が残り「保存」は有効でスナックバーに「操作が失敗しました。」と表示され一覧は上から「A」「B」のまま [SMP-U17]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.updateFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'X');
      expect(_isFilledEnabled(_saveButton, tester), isTrue);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップしUnknownFailureで失敗した後もう一度「保存」をタップして再びUnknownFailureで失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-U18]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.updateFailures.add(const Failure.unknown('boom1'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();

      repo.updateFailures.add(const Failure.unknown('boom2'));
      await tester.tap(_saveButton);
      await tester.pump();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログを開き入力欄を空にしてから「あいうえおかきくけこ」（幅20）を入力した場合、入力欄にその値が表示されオーバーフローのエラーが発生しない [SMP-U19]',
        (tester) async {
      const name = 'あいうえおかきくけこ';
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.enterText(find.byType(TextField), name);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, name);
      expect(tester.takeException(), isNull);
    });
  });

  group('SamplePage 3.7 削除', () {
    testWidgets(
        '「A」の1件がある状態で「A」のメニューから「削除」をタップした場合、ダイアログが表示され上から順にタイトル「サンプルを削除」・「※「A」を削除しますか？」・「キャンセル」（左）・「削除」（右）が表示される [SMP-X01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester);

      expect(find.text('サンプルを削除'), findsOneWidget);
      expect(find.text('※「A」を削除しますか？'), findsOneWidget);
      final titleY = tester.getTopLeft(find.text('サンプルを削除')).dy;
      final contentY = tester.getTopLeft(find.text('※「A」を削除しますか？')).dy;
      final cancelPos = tester.getTopLeft(_cancelButton);
      final deletePos = tester.getTopLeft(_deleteButton);
      expect(titleY, lessThan(contentY));
      expect(contentY, lessThan(cancelPos.dy + 1));
      expect(cancelPos.dy, closeTo(deletePos.dy, 1));
      expect(cancelPos.dx, lessThan(deletePos.dx));
    });

    testWidgets(
        '「あいうえおかきくけこ」（幅20）の1件がある状態でその削除ダイアログを開いた場合、注記「※「あいうえおかきくけこ」を削除しますか？」が表示されオーバーフローのエラーが発生しない [SMP-X02]',
        (tester) async {
      const name = 'あいうえおかきくけこ';
      final repo = FakeSampleRepository(initial: [_sample('a-id', name)]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester);

      expect(find.text('※「$name」を削除しますか？'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じ一覧に「B」の1件だけが表示される [SMP-X03]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '作成日時が古い順に「A」「B」「C」の3件がある状態で「B」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じ一覧に上から「A」「C」の順で表示される [SMP-X04]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [
          _sample('a-id', 'A'),
          _sample('b-id', 'B'),
          _sample('c-id', 'C'),
        ],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 1);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('B'), findsNothing);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final cY = tester.getTopLeft(find.text('C')).dy;
      expect(aY, lessThan(cY));
    });

    testWidgets(
        '「A」の1件がある状態で「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じ「サンプルがありません」と「サンプルを作成」ボタンが表示される [SMP-X05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('サンプルがありません'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'サンプルを作成'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「キャンセル」をタップした場合、ダイアログが閉じ一覧は「A」「B」の2件のまま [SMP-X06]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_cancelButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いてダイアログの外側をタップした場合、ダイアログが閉じ一覧は「A」「B」の2件のまま [SMP-X07]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await _tapOutside(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて端末の戻る操作をした場合、ダイアログが閉じ一覧は「A」「B」の2件のまま [SMP-X08]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await _pressBack(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除が完了していない場合、削除ダイアログ（「サンプルを削除」）は表示されていない [SMP-X09]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();
      // ダイアログを閉じる遷移アニメーションの完了を待つ
      // （削除の完了は待たない。deleteGate は保留のまま）
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('サンプルを削除'), findsNothing);

      repo.deleteGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除が完了していない場合、画面にCircularProgressIndicatorは表示されない [SMP-X10]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      repo.deleteGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除がUnknownFailureで失敗した場合、削除ダイアログは表示されずスナックバーに「操作が失敗しました。」と表示され一覧は「A」「B」の2件のまま [SMP-X11]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」を削除してUnknownFailureで失敗した後もう一度「A」の削除ダイアログを開いて「削除」をタップし再びUnknownFailureで失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-X12]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteFailures.add(const Failure.unknown('boom1'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();

      repo.deleteFailures.add(const Failure.unknown('boom2'));
      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
        '一覧に「A」「B」が表示されRepository上では「A」が既に削除されている状態で「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じ一覧に「B」の1件だけが表示され「操作が失敗しました。」は表示されない [SMP-X13]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      // Repository 上で「A」を先に削除しておく（画面には「A」がまだ表示されている）
      repo.samples.removeWhere((s) => s.id == 'a-id');

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('操作が失敗しました。'), findsNothing);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除の完了前に「A」のIcons.more_vertをタップした場合、「編集」「削除」のメニューは表示されない [SMP-X14]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();
      // ダイアログを閉じる遷移アニメーションの完了を待つ
      // （削除の完了は待たない。deleteGate は保留のまま）
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.more_vert).at(0));
      await tester.pumpAndSettle();

      expect(find.text('編集'), findsNothing);
      expect(find.text('削除'), findsNothing);

      repo.deleteGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除の完了前にFloatingActionButtonから「C」を作成して作成と削除の両方が成功した場合、両方の完了後に一覧に上から「B」「C」の順で表示され「A」は表示されない [SMP-X15]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.deleteGate = Completer<void>();
      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      repo.deleteGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('A'), findsNothing);
      final bY = tester.getTopLeft(find.text('B')).dy;
      final cY = tester.getTopLeft(find.text('C')).dy;
      expect(bY, lessThan(cY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除の完了前に一覧を下に引っ張って離しプルして更新の読み込みが削除前の「A」「B」を返して削除の完了より後に終わった場合、両方の完了後に一覧に「B」の1件だけが表示され「A」は表示されない [SMP-X16]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      final pullGate = Completer<void>();
      repo.getResponses.add((
        gate: pullGate,
        returnValue: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      ));
      await _startPullToRefresh(tester);

      // プルして更新が保留中は pumpAndSettle がタイムアウトするため、
      // ここから先は pump() だけで操作する
      repo.deleteGate = Completer<void>();
      // プルして更新が保留中で pumpAndSettle が使えないため、メニューとダイアログの
      // アニメーションを手動で進める。開き切る前はタップの当たり判定が無く、
      // PopupMenuButton の onSelected はメニューが閉じ切ってから走る
      await tester.tap(find.byIcon(Icons.more_vert).at(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // メニューが開き切る
      await tester.tap(find.text('削除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // メニューが閉じ切る
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // 削除ダイアログが開き切る
      await tester.tap(_deleteButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      repo.deleteGate!.complete();
      await tester.pump();
      await tester.pump();

      pullGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除の完了前に一覧の「B」をタップした場合、遷移先のパスが/folder/<Bのid>になり遷移先に渡されるextraが「B」 [SMP-X17]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();

      repo.deleteGate = Completer<void>();
      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();

      expect(find.text('folder-screen:b-id:B'), findsOneWidget);

      repo.deleteGate!.complete();
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除の完了前に「B」のIcons.more_vertをタップした場合、「編集」「削除」が表示される [SMP-X18]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pump();

      // 削除しているのは「A」なので、別の行である「B」のメニューを開く
      await tester.tap(find.byIcon(Icons.more_vert).at(1));
      await tester.pumpAndSettle();

      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);

      repo.deleteGate!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('SamplePage 3.8 画面遷移', () {
    testWidgets(
        'idが「sample-1」名前が「A」の1件がある状態で一覧の「A」をタップした場合、遷移先のパスが/folder/sample-1になり遷移先に渡されるextraが「A」 [SMP-T01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('sample-1', 'A')]);
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      expect(find.text('folder-screen:sample-1:A'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」のIcons.more_vertをタップした場合、遷移しない（パスは/sampleのまま）で「編集」「削除」が表示される [SMP-T02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();

      await _openMenu(tester);

      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
      expect(find.textContaining('folder-screen'), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('SamplePage 3.9 エラー種別ごとの扱い', () {
    testWidgets('画面を開き初期読み込みがNotFoundFailureで失敗した場合、ErrorScreenが表示され「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E01]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.notFound());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('画面を開き初期読み込みがNetworkFailureで失敗した場合、NetworkErrorDialogが表示されErrorScreenは表示されない [SMP-E02]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.network());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text('通信エラー'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets(
        '初期読み込みがNetworkFailureで失敗しNetworkErrorDialogが表示された状態で「OK」をタップした場合、遷移先のパスが/loginになる [SMP-E03]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.network());
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets('画面を開き初期読み込みがAuthFailureで失敗した場合、NetworkErrorDialogが表示されErrorScreenは表示されない [SMP-E04]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text('通信エラー'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets(
        '初期読み込みがAuthFailureで失敗しNetworkErrorDialogが表示された状態で「OK」をタップした場合、遷移先のパスが/loginになる [SMP-E05]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets(
        'ErrorScreen表示中に「再試行」をタップし読み込みがNotFoundFailureで失敗した場合、ErrorScreenが表示され「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E06]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.getFailures.add(const Failure.notFound());
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets(
        'ErrorScreen表示中に「再試行」をタップし読み込みがNetworkFailureで失敗した場合、NetworkErrorDialogが表示される [SMP-E07]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.getFailures.add(const Failure.network());
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.text('通信エラー'), findsOneWidget);
    });

    testWidgets(
        '「再試行」後の読み込みがNetworkFailureで失敗しNetworkErrorDialogが表示された状態で「OK」をタップした場合、遷移先のパスが/loginになる [SMP-E08]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.getFailures.add(const Failure.network());
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets(
        'ErrorScreen表示中に「再試行」をタップし読み込みがAuthFailureで失敗した場合、NetworkErrorDialogが表示される [SMP-E09]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.getFailures.add(const Failure.auth());
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.text('通信エラー'), findsOneWidget);
    });

    testWidgets(
        '「再試行」後の読み込みがAuthFailureで失敗しNetworkErrorDialogが表示された状態で「OK」をタップした場合、遷移先のパスが/loginになる [SMP-E10]',
        (tester) async {
      final repo = FakeSampleRepository()
        ..getFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorScreen), findsOneWidget);

      repo.getFailures.add(const Failure.auth());
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text('通信エラー'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('login-screen'), findsOneWidget);
    });

    testWidgets(
        '「A」が表示されている状態で一覧を下に引っ張って離し読み込みがNotFoundFailureで失敗した場合、スナックバーに「操作が失敗しました。」と表示され一覧には「A」が表示されたまま [SMP-E11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.notFound());
      await _pullToRefresh(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」が表示されている状態で一覧を下に引っ張って離し読み込みがNetworkFailureで失敗した場合、スナックバーに「操作が失敗しました。」と表示され一覧には「A」が表示されたままNetworkErrorDialogは表示されない [SMP-E12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.network());
      await _pullToRefresh(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」が表示されている状態で一覧を下に引っ張って離し読み込みがAuthFailureで失敗した場合、スナックバーに「操作が失敗しました。」と表示され一覧には「A」が表示されたままNetworkErrorDialogは表示されない [SMP-E13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.auth());
      await _pullToRefresh(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成がNetworkFailureで失敗した場合、ダイアログは閉じず入力欄に「B」が残りスナックバーに「操作が失敗しました。」と表示され一覧は「A」の1件のままNetworkErrorDialogは表示されない [SMP-E14]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createFailures.add(const Failure.network());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'B');
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップし「B」を入力して「作成」をタップし作成がAuthFailureで失敗した場合、ダイアログは閉じず入力欄に「B」が残りスナックバーに「操作が失敗しました。」と表示され一覧は「A」の1件のままNetworkErrorDialogは表示されない [SMP-E15]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.createFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'B');
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更がNotFoundFailureで失敗した場合、ダイアログは閉じず入力欄に「X」が残りスナックバーに「操作が失敗しました。」と表示され一覧は上から「A」「B」のまま [SMP-E16]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.updateFailures.add(const Failure.notFound());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'X');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更がNetworkFailureで失敗した場合、ダイアログは閉じず入力欄に「X」が残りスナックバーに「操作が失敗しました。」と表示され一覧は上から「A」「B」のままNetworkErrorDialogは表示されない [SMP-E17]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.updateFailures.add(const Failure.network());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'X');
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      // 一覧は上から「A」「B」のまま
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「B」の編集ダイアログを開き入力欄を「X」に変えて「保存」をタップし変更がAuthFailureで失敗した場合、ダイアログは閉じず入力欄に「X」が残りスナックバーに「操作が失敗しました。」と表示され一覧は上から「A」「B」のままNetworkErrorDialogは表示されない [SMP-E18]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.updateFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 1);
      await tester.enterText(find.byType(TextField), 'X');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'X');
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      // 一覧は上から「A」「B」のまま
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除がNotFoundFailureで失敗した場合、削除ダイアログは表示されずスナックバーに「操作が失敗しました。」と表示され一覧は「A」「B」の2件のまま [SMP-E19]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteFailures.add(const Failure.notFound());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除がNetworkFailureで失敗した場合、削除ダイアログは表示されずスナックバーに「操作が失敗しました。」と表示され一覧は「A」「B」の2件のままNetworkErrorDialogは表示されない [SMP-E20]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteFailures.add(const Failure.network());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログを開いて「削除」をタップし削除がAuthFailureで失敗した場合、削除ダイアログは表示されずスナックバーに「操作が失敗しました。」と表示され一覧は「A」「B」の2件のままNetworkErrorDialogは表示されない [SMP-E21]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('SamplePage 2.2 入力ルール（作成ダイアログ / SMP-N01, SMP-N02）', () {
    Future<FakeSampleRepository> openCreate(WidgetTester tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialog(tester);
      return repo;
    }

    final n01Enabled = <String, String>{'「B」': 'B', '「 B 」（前後に半角スペース）': ' B '};
    for (final entry in n01Enabled.entries) {
      testWidgets('作成ダイアログの入力欄に${entry.key}を入力した場合、「作成」ボタンが有効になる [SMP-N01]',
          (tester) async {
        await openCreate(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isFilledEnabled(_createButton, tester), isTrue);
      });
    }

    final n01Disabled = <String, String>{
      '（空）': '',
      '「   」（半角スペース3つ）': '   ',
      '「　　」（全角スペース2つ）': '　　',
      '「 　 」（半角・全角の混在）': ' 　 ',
    };
    for (final entry in n01Disabled.entries) {
      testWidgets('作成ダイアログの入力欄に${entry.key}を入力した場合、「作成」ボタンが無効になる [SMP-N01]',
          (tester) async {
        await openCreate(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isFilledEnabled(_createButton, tester), isFalse);
      });
    }

    final n02Valid = <String, String>{
      '「abcdefghijklmnopqrst」（半角20）': 'abcdefghijklmnopqrst',
      '「あいうえおかきくけこ」（全角10）': 'あいうえおかきくけこ',
      '「あいうえおabcdefghij」（全角5＋半角10）': 'あいうえおabcdefghij',
    };
    for (final entry in n02Valid.entries) {
      testWidgets('作成ダイアログの入力欄に${entry.key}を入力した場合、そのまま入力欄に反映される [SMP-N02]',
          (tester) async {
        await openCreate(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, entry.value);
      });
    }

    testWidgets(
        '作成ダイアログの入力欄に「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合（半角21）、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N02]',
        (tester) async {
      await openCreate(tester);
      const base = 'abcdefghijklmnopqrst';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}u');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets(
        '作成ダイアログの入力欄に「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合（全角11）、入力欄は「あいうえおかきくけこ」のまま [SMP-N02]',
        (tester) async {
      await openCreate(tester);
      const base = 'あいうえおかきくけこ';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '$baseさ');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets(
        '作成ダイアログの入力欄に「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合（全角10＋半角1）、入力欄は「あいうえおかきくけこ」のまま [SMP-N02]',
        (tester) async {
      await openCreate(tester);
      const base = 'あいうえおかきくけこ';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}a');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets(
        '作成ダイアログの入力欄が空の状態で「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N02]',
        (tester) async {
      await openCreate(tester);
      await tester.enterText(find.byType(TextField), ' abcdefghijklmnopqrst');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets(
        '作成ダイアログの入力欄が空の状態で「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N02]',
        (tester) async {
      await openCreate(tester);
      await tester.enterText(
        find.byType(TextField),
        'abcdefghijklmnopqrstuvwxyz0123',
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });
  });

  group('SamplePage 2.2 入力ルール（編集ダイアログ / SMP-N03, SMP-N04）', () {
    Future<FakeSampleRepository> openEditCleared(WidgetTester tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      await _openEditDialog(tester);
      // 境界値は初期値「A」の入力欄を空にしてから入力した値とする
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      return repo;
    }

    final n03Enabled = <String, String>{'「X」': 'X', '「 X 」（前後に半角スペース）': ' X '};
    for (final entry in n03Enabled.entries) {
      testWidgets('編集ダイアログの入力欄に${entry.key}を入力した場合、「保存」ボタンが有効になる [SMP-N03]',
          (tester) async {
        await openEditCleared(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isFilledEnabled(_saveButton, tester), isTrue);
      });
    }

    final n03Disabled = <String, String>{
      '（空）': '',
      '「   」（半角スペース3つ）': '   ',
      '「　　」（全角スペース2つ）': '　　',
      '「 　 」（半角・全角の混在）': ' 　 ',
    };
    for (final entry in n03Disabled.entries) {
      testWidgets('編集ダイアログの入力欄に${entry.key}を入力した場合、「保存」ボタンが無効になる [SMP-N03]',
          (tester) async {
        await openEditCleared(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isFilledEnabled(_saveButton, tester), isFalse);
      });
    }

    final n04Valid = <String, String>{
      '「abcdefghijklmnopqrst」（半角20）': 'abcdefghijklmnopqrst',
      '「あいうえおかきくけこ」（全角10）': 'あいうえおかきくけこ',
      '「あいうえおabcdefghij」（全角5＋半角10）': 'あいうえおabcdefghij',
    };
    for (final entry in n04Valid.entries) {
      testWidgets('編集ダイアログの入力欄に${entry.key}を入力した場合、そのまま入力欄に反映される [SMP-N04]',
          (tester) async {
        await openEditCleared(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, entry.value);
      });
    }

    testWidgets(
        '編集ダイアログの入力欄に「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合（半角21）、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N04]',
        (tester) async {
      await openEditCleared(tester);
      const base = 'abcdefghijklmnopqrst';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}u');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets(
        '編集ダイアログの入力欄に「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合（全角11）、入力欄は「あいうえおかきくけこ」のまま [SMP-N04]',
        (tester) async {
      await openEditCleared(tester);
      const base = 'あいうえおかきくけこ';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '$baseさ');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets(
        '編集ダイアログの入力欄に「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合（全角10＋半角1）、入力欄は「あいうえおかきくけこ」のまま [SMP-N04]',
        (tester) async {
      await openEditCleared(tester);
      const base = 'あいうえおかきくけこ';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}a');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets(
        '編集ダイアログの入力欄が空の状態で「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N04]',
        (tester) async {
      await openEditCleared(tester);
      await tester.enterText(find.byType(TextField), ' abcdefghijklmnopqrst');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets(
        '編集ダイアログの入力欄を空にしてから「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N04]',
        (tester) async {
      await openEditCleared(tester);
      await tester.enterText(
        find.byType(TextField),
        'abcdefghijklmnopqrstuvwxyz0123',
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });
  });
}
