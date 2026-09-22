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
  return ProviderScope(
    overrides: _baseOverrides(repository),
    child: const MaterialApp(home: SamplePage()),
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

Finder get _createButton => find.widgetWithText(FilledButton, '作成');
Finder get _saveButton => find.widgetWithText(FilledButton, '保存');

bool _isEnabled(Finder buttonFinder, WidgetTester tester) =>
    tester.widget<FilledButton>(buttonFinder).onPressed != null;

void main() {
  group('SamplePage 表示', () {
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
        '一覧の読み込みが完了する前の場合、CircularProgressIndicatorが表示され一覧・「サンプルがありません」は表示されない [SMP-D04]',
        (tester) async {
      // 取得を完了させないようゲートで止め、読み込み中の状態を安定して観測する
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')])
        ..getGate = Completer<void>();

      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.text('サンプルがありません'), findsNothing);

      // テスト終了時に pending Future を残さないよう解放する
      repo.getGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'サンプルが0件の状態で画面を開いた場合、上から順にサンプルのアイコン（Icons.science_outlined）・「サンプルがありません」が表示されFloatingActionButtonも表示される [SMP-D05]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.science_outlined);
      final textFinder = find.text('サンプルがありません');
      expect(iconFinder, findsOneWidget);
      expect(textFinder, findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      final iconY = tester.getTopLeft(iconFinder).dy;
      final textY = tester.getTopLeft(textFinder).dy;
      expect(iconY, lessThan(textY));
    });

    testWidgets(
        'サンプルが0件の状態で画面を開いた場合、「サンプルがありません」の下にIcons.addのアイコンと「サンプルを作成」の文言を持つボタンが表示される [SMP-D06]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      final emptyTextFinder = find.text('サンプルがありません');
      final createButtonFinder = find.widgetWithText(FilledButton, 'サンプルを作成');
      expect(createButtonFinder, findsOneWidget);
      expect(
        find.descendant(
          of: createButtonFinder,
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
      final emptyY = tester.getTopLeft(emptyTextFinder).dy;
      final buttonY = tester.getTopLeft(createButtonFinder).dy;
      expect(emptyY, lessThan(buttonY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で画面を開いた場合、一覧に「A」「B」がこの順で表示され各行の右端にIcons.more_vertが表示され「サンプルがありません」は表示されない [SMP-D07]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('サンプルがありません'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));

      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets('30件がある状態で画面を開き一覧を下端までスクロールした場合、30件目のサンプル名が表示される [SMP-D08]',
        (tester) async {
      final samples = List.generate(
        30,
        (i) => _sample('id-$i', 'Sample${i + 1}'),
      );
      final repo = FakeSampleRepository(initial: samples);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sample30'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sample30'), findsOneWidget);
    });

    testWidgets(
        '名前が「a」×20の1件がある状態で画面を開いた場合、一覧にその1件が表示されオーバーフローのエラーが発生しない [SMP-D09]',
        (tester) async {
      final name = 'a' * 20;
      final repo = FakeSampleRepository(initial: [_sample('a-id', name)]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text(name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '名前が「あ」×10の1件がある状態で画面を開いた場合、一覧にその1件が表示されオーバーフローのエラーが発生しない [SMP-D10]',
        (tester) async {
      final name = 'あ' * 10;
      final repo = FakeSampleRepository(initial: [_sample('a-id', name)]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text(name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '一覧の初期読み込みがUnknownFailureで失敗した場合、ErrorScreenが表示され「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示され一覧・「サンプルがありません」は表示されない [SMP-D11]',
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

    testWidgets(
        'SMP-D11の状態で「A」の1件が取得できるようにしてから「再試行」をタップした場合、ErrorScreenが消え一覧に「A」が表示される [SMP-D12]',
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

    testWidgets(
        'SMP-D11の状態で「再試行」をタップし再読み込みもUnknownFailureで失敗した場合、ErrorScreenが表示され「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D13]',
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

    testWidgets(
        '「A」が表示されている状態でRepositoryに「B」を追加し一覧を下に引っ張って離した場合、一覧に「A」「B」がこの順で表示される [SMP-D14]',
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
        '「A」が表示されている状態でプルして更新し読み込みがUnknownFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreenは表示されずスナックバーに「操作が失敗しました。」と表示される [SMP-D15]',
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
  });

  group('SamplePage 作成', () {
    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップした場合、作成ダイアログが表示されタイトル「サンプルを作成」・「サンプル名」・空の入力欄・「半角20文字（全角10文字）まで」・「キャンセル」ボタン・「作成」ボタンが表示され「作成」ボタンは無効 [SMP-C01]',
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
      expect(find.widgetWithText(TextButton, 'キャンセル'), findsOneWidget);
      expect(_createButton, findsOneWidget);
      expect(_isEnabled(_createButton, tester), isFalse);
    });

    testWidgets(
        '「A」の1件がある状態でFloatingActionButtonをタップした場合、作成ダイアログの要素が上から「サンプルを作成」→「サンプル名」→入力欄→「半角20文字（全角10文字）まで」→ボタンの順に並び「キャンセル」が左「作成」が右に並ぶ [SMP-C02]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);

      final titleY = tester.getTopLeft(find.text('サンプルを作成')).dy;
      final fieldY = tester.getTopLeft(find.byType(TextField)).dy;
      final helperY = tester.getTopLeft(find.text('半角20文字（全角10文字）まで')).dy;
      final cancelPos = tester.getTopLeft(find.widgetWithText(TextButton, 'キャンセル'));
      final createPos = tester.getTopLeft(_createButton);

      expect(titleY, lessThan(fieldY));
      expect(fieldY, lessThan(helperY));
      expect(helperY, lessThan(cancelPos.dy + 1));
      expect(cancelPos.dy, closeTo(createPos.dy, 1));
      expect(cancelPos.dx, lessThan(createPos.dx));
    });

    testWidgets('サンプルが0件の状態でSMP-D06のボタンをタップした場合、作成ダイアログが表示されタイトル「サンプルを作成」が表示される [SMP-C03]',
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
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力して「作成」をタップし作成に成功した場合、作成ダイアログが閉じ一覧に「A」「B」がこの順で表示される [SMP-C04]',
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
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        'サンプルが0件の状態で作成ダイアログに「A」を入力して「作成」をタップし作成に成功した場合、作成ダイアログが閉じ「サンプルがありません」が消え一覧に「A」の1件が表示される [SMP-C05]',
        (tester) async {
      final repo = FakeSampleRepository();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('サンプルがありません'), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「 B 」（前後に半角スペース）を入力して「作成」をタップし作成に成功した場合、一覧に「A」「B」がこの順で表示される（「B」の前後にスペースがない） [SMP-C06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), ' B ');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.text('B'), findsOneWidget);
      expect(find.text(' B '), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「A」を入力して「作成」をタップし作成に成功した場合、一覧に「A」「A」の2件が表示される [SMP-C07]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      await tester.tap(_createButton);
      await tester.pumpAndSettle();

      expect(find.text('A'), findsNWidgets(2));
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力して「キャンセル」をタップした場合、作成ダイアログが閉じ一覧は「A」の1件のまま [SMP-C08]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力しダイアログの外側をタップした場合、作成ダイアログが閉じ一覧は「A」の1件のまま [SMP-C09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openCreateDialog(tester);
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力して「作成」をタップし作成の処理が完了する前の場合、作成ダイアログは表示されたまま「作成」ボタンが無効 [SMP-C10]',
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
      expect(_isEnabled(_createButton, tester), isFalse);

      // テスト終了時に pending Future を残さないよう解放する
      repo.createGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力して「作成」をタップし処理が完了する前にもう一度「作成」をタップし作成に成功した場合、一覧に「A」「B」の2件だけが表示される（「B」は1件） [SMP-C11]',
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
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力して「作成」をタップし作成がUnknownFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreenは表示されず作成ダイアログは表示されたままで入力欄に「B」が残りスナックバーに「操作が失敗しました。」と表示される [SMP-C12]',
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

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'B');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });
  });

  group('SamplePage 変更', () {
    testWidgets('「A」の1件がある状態で「A」のIcons.more_vertをタップした場合、メニューに「編集」「削除」が表示される [SMP-U01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openMenu(tester);

      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」のメニューから「編集」をタップした場合、編集ダイアログが表示されタイトル「サンプルを編集」・「サンプル名」・初期値「A」の入力欄・「半角20文字（全角10文字）まで」・「キャンセル」ボタン・「保存」ボタンが表示され「保存」ボタンは有効 [SMP-U02]',
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
      expect(find.widgetWithText(TextButton, 'キャンセル'), findsOneWidget);
      expect(_saveButton, findsOneWidget);
      expect(_isEnabled(_saveButton, tester), isTrue);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の編集ダイアログの入力を「C」に変えて「保存」をタップし変更に成功した場合、編集ダイアログが閉じ一覧に「C」「B」がこの順で表示される [SMP-U03]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester, index: 0);
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      final cY = tester.getTopLeft(find.text('C')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(cY, lessThan(bY));
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログの入力を変えずに「保存」をタップし変更に成功した場合、編集ダイアログが閉じ一覧は「A」の1件のまま [SMP-U04]',
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
        '「A」の1件がある状態で「A」の編集ダイアログの入力を「C」に変えて「キャンセル」をタップした場合、編集ダイアログが閉じ一覧は「A」の1件のまま [SMP-U05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('C'), findsNothing);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログの入力を「C」に変えて「保存」をタップし変更の処理が完了する前の場合、編集ダイアログは表示されたまま「保存」ボタンが無効 [SMP-U06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateGate = Completer<void>();
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_isEnabled(_saveButton, tester), isFalse);

      repo.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログの入力を「C」に変えて「保存」をタップし変更がUnknownFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreenは表示されず編集ダイアログは表示されたままで入力欄に「C」が残りスナックバーに「操作が失敗しました。」と表示される [SMP-U07]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'C');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });
  });

  group('SamplePage 削除', () {
    testWidgets(
        '「A」の1件がある状態で「A」のメニューから「削除」をタップした場合、削除ダイアログが表示され上から順にタイトル「サンプルを削除」・「※「A」を削除しますか？」・ボタンが並び「キャンセル」が左「削除」が右に並ぶ [SMP-X01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester);

      expect(find.text('サンプルを削除'), findsOneWidget);
      expect(find.text('※「A」を削除しますか？'), findsOneWidget);
      final titleY = tester.getTopLeft(find.text('サンプルを削除')).dy;
      final contentY = tester.getTopLeft(find.text('※「A」を削除しますか？')).dy;
      final cancelPos = tester.getTopLeft(find.widgetWithText(TextButton, 'キャンセル'));
      final deletePos = tester.getTopLeft(find.widgetWithText(FilledButton, '削除'));
      expect(titleY, lessThan(contentY));
      expect(contentY, lessThan(cancelPos.dy + 1));
      expect(cancelPos.dy, closeTo(deletePos.dy, 1));
      expect(cancelPos.dx, lessThan(deletePos.dx));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログの「削除」をタップし削除に成功した場合、削除ダイアログが閉じ一覧に「B」の1件だけが表示される [SMP-X02]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の削除ダイアログの「削除」をタップし削除に成功した場合、削除ダイアログが閉じ「サンプルがありません」が表示される [SMP-X03]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('サンプルがありません'), findsOneWidget);
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログの「キャンセル」をタップした場合、削除ダイアログが閉じ一覧に「A」「B」がこの順で表示される [SMP-X04]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      final aY = tester.getTopLeft(find.text('A')).dy;
      final bY = tester.getTopLeft(find.text('B')).dy;
      expect(aY, lessThan(bY));
    });

    testWidgets(
        '「A」「B」の2件がある状態で「A」の削除ダイアログの「削除」をタップし削除がUnknownFailureで失敗した場合、削除ダイアログが閉じ一覧に「A」「B」がこの順で表示されErrorScreenは表示されずスナックバーに「操作が失敗しました。」と表示される [SMP-X05]',
        (tester) async {
      final repo = FakeSampleRepository(
        initial: [_sample('a-id', 'A'), _sample('b-id', 'B')],
      );
      repo.deleteFailures.add(const Failure.unknown('boom'));
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester, index: 0);
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });
  });

  group('SamplePage 画面遷移', () {
    testWidgets(
        '「A」の1件がある状態で一覧の「A」の行（Icons.more_vert以外）をタップした場合、/folder/<Aのid>に遷移し遷移先に渡されるextraは「A」 [SMP-T01]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSampleApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      expect(find.text('folder-screen:a-id:A'), findsOneWidget);
    });
  });

  group('SamplePage エラー種別ごとの扱い', () {
    testWidgets(
        '一覧の初期読み込みがNotFoundFailureで失敗した場合、ErrorScreenが表示され「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E01]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.notFound());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('サンプルの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('一覧の初期読み込みがNetworkFailureで失敗した場合、NetworkErrorDialogが表示されErrorScreenは表示されない [SMP-E02]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.network());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text('通信エラー'), findsOneWidget);
      expect(find.text('通信に失敗しました。\nログイン画面に戻ります。'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets('一覧の初期読み込みがAuthFailureで失敗した場合、NetworkErrorDialogが表示されErrorScreenは表示されない [SMP-E03]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      expect(find.text('通信エラー'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
    });

    testWidgets(
        '一覧の初期読み込みがNetworkFailureで失敗し表示されたNetworkErrorDialogの「OK」をタップした場合、/loginに遷移する [SMP-E04]',
        (tester) async {
      final repo = FakeSampleRepository()..getFailures.add(const Failure.network());
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
        '「A」が表示されている状態でプルして更新し読み込みがNetworkFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されずスナックバーに「操作が失敗しました。」と表示される [SMP-E05]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.network());
      await _pullToRefresh(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」が表示されている状態でプルして更新し読み込みがAuthFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されずスナックバーに「操作が失敗しました。」と表示される [SMP-E06]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      repo.getFailures.add(const Failure.auth());
      await _pullToRefresh(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力して「作成」をタップし作成がNetworkFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されず作成ダイアログは表示されたままで入力欄に「B」が残りスナックバーに「操作が失敗しました。」と表示される [SMP-E07]',
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

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'B');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で作成ダイアログに「B」を入力して「作成」をタップし作成がAuthFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されず作成ダイアログは表示されたままで入力欄に「B」が残りスナックバーに「操作が失敗しました。」と表示される [SMP-E08]',
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

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'B');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」を「C」に変更し変更がNotFoundFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreenは表示されず編集ダイアログは表示されたままで入力欄に「C」が残りスナックバーに「操作が失敗しました。」と表示される [SMP-E09]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateFailures.add(const Failure.notFound());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'C');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログの入力を「C」に変えて「保存」をタップし変更がNetworkFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されず編集ダイアログは表示されたままで入力欄に「C」が残りスナックバーに「操作が失敗しました。」と表示される [SMP-E10]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateFailures.add(const Failure.network());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'C');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の編集ダイアログの入力を「C」に変えて「保存」をタップし変更がAuthFailureで失敗した場合、一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されず編集ダイアログは表示されたままで入力欄に「C」が残りスナックバーに「操作が失敗しました。」と表示される [SMP-E11]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.updateFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openEditDialog(tester);
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'C');
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の削除ダイアログの「削除」をタップし削除がNetworkFailureで失敗した場合、削除ダイアログが閉じ一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されずスナックバーに「操作が失敗しました。」と表示される [SMP-E12]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.deleteFailures.add(const Failure.network());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });

    testWidgets(
        '「A」の1件がある状態で「A」の削除ダイアログの「削除」をタップし削除がAuthFailureで失敗した場合、削除ダイアログが閉じ一覧は「A」の1件のまま表示されErrorScreen・NetworkErrorDialogは表示されずスナックバーに「操作が失敗しました。」と表示される [SMP-E13]',
        (tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      repo.deleteFailures.add(const Failure.auth());
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();

      await _openDeleteDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(ErrorScreen), findsNothing);
      expect(find.text('通信エラー'), findsNothing);
      expect(find.text('操作が失敗しました。'), findsOneWidget);
    });
  });

  group('SamplePage 入力ルール（作成ダイアログ / SMP-N01〜N04）', () {
    Future<FakeSampleRepository> openCreate(WidgetTester tester) async {
      final repo = FakeSampleRepository(initial: [_sample('a-id', 'A')]);
      await tester.pumpWidget(buildSamplePage(repo));
      await tester.pumpAndSettle();
      await _openCreateDialog(tester);
      return repo;
    }

    final validWidthCases = <String, String>{
      '「a」×20': 'a' * 20,
      '「あ」×10': 'あ' * 10,
      '「a」×18＋「あ」（幅20）': '${'a' * 18}あ',
      '「Ａ」×10（全角英字）': 'Ａ' * 10,
    };

    for (final entry in validWidthCases.entries) {
      testWidgets('作成ダイアログの入力欄に${entry.key}を入力した場合、そのまま入力欄に反映される [SMP-N01]',
          (tester) async {
        await openCreate(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, entry.value);
      });
    }

    testWidgets('作成ダイアログの入力欄に「a」×20の後に「a」を入力した場合、入力欄は「a」×20のまま [SMP-N01]',
        (tester) async {
      await openCreate(tester);
      final base = 'a' * 20;
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}a');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets('作成ダイアログの入力欄に「あ」×10の後に「あ」を入力した場合、入力欄は「あ」×10のまま [SMP-N01]',
        (tester) async {
      await openCreate(tester);
      final base = 'あ' * 10;
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}あ');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets('作成ダイアログの入力欄に「a」×19の後に「あ」を入力した場合、入力欄は「a」×19のまま [SMP-N01]',
        (tester) async {
      await openCreate(tester);
      final base = 'a' * 19;
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}あ');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    final enabledCases = <String, String>{
      '「a」': 'a',
      '「 a 」': ' a ',
      '「あ」': 'あ',
    };
    for (final entry in enabledCases.entries) {
      testWidgets('作成ダイアログの入力欄に${entry.key}を入力した場合、「作成」ボタンが有効になる [SMP-N02]',
          (tester) async {
        await openCreate(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isEnabled(_createButton, tester), isTrue);
      });
    }

    final disabledCases = <String, String>{
      '空': '',
      '「 」（半角スペース1つ）': ' ',
      '「　」（全角スペース1つ）': '　',
      '「 　 」（半角・全角の混在）': ' 　 ',
    };
    for (final entry in disabledCases.entries) {
      testWidgets('作成ダイアログの入力欄に${entry.key}を入力した場合、「作成」ボタンが無効になる [SMP-N02]',
          (tester) async {
        await openCreate(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isEnabled(_createButton, tester), isFalse);
      });
    }

    final trimCases = <String, (String, String)>{
      '「 B 」': (' B ', 'B'),
      '「　B　」': ('　B　', 'B'),
      '「A B」': ('A B', 'A B'),
    };
    for (final entry in trimCases.entries) {
      testWidgets(
          '作成ダイアログに${entry.key}を入力して「作成」をタップした場合、前後のスペースを除いた「${entry.value.$2}」が名前として保存される [SMP-N03]',
          (tester) async {
        final repo = await openCreate(tester);
        await tester.enterText(find.byType(TextField), entry.value.$1);
        await tester.pump();
        await tester.tap(_createButton);
        await tester.pumpAndSettle();

        expect(repo.samples.any((s) => s.name == entry.value.$2), isTrue);
      });
    }

    testWidgets('作成ダイアログの入力欄に「 」＋「a」×19（幅20）を入力した場合、そのまま入力欄に反映される [SMP-N04]',
        (tester) async {
      await openCreate(tester);
      final value = ' ${'a' * 19}';
      await tester.enterText(find.byType(TextField), value);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, value);
    });

    testWidgets('作成ダイアログの入力欄に「 」＋「a」×19の後に「a」を入力した場合、入力欄は「 」＋「a」×19のまま [SMP-N04]',
        (tester) async {
      await openCreate(tester);
      final base = ' ${'a' * 19}';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}a');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });
  });

  group('SamplePage 入力ルール（編集ダイアログ / SMP-N05〜N08）', () {
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

    final validWidthCases = <String, String>{
      '「a」×20': 'a' * 20,
      '「あ」×10': 'あ' * 10,
      '「a」×18＋「あ」（幅20）': '${'a' * 18}あ',
      '「Ａ」×10（全角英字）': 'Ａ' * 10,
    };

    for (final entry in validWidthCases.entries) {
      testWidgets('編集ダイアログの入力欄に${entry.key}を入力した場合、そのまま入力欄に反映される [SMP-N05]',
          (tester) async {
        await openEditCleared(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, entry.value);
      });
    }

    testWidgets('編集ダイアログの入力欄に「a」×20の後に「a」を入力した場合、入力欄は「a」×20のまま [SMP-N05]',
        (tester) async {
      await openEditCleared(tester);
      final base = 'a' * 20;
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}a');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets('編集ダイアログの入力欄に「あ」×10の後に「あ」を入力した場合、入力欄は「あ」×10のまま [SMP-N05]',
        (tester) async {
      await openEditCleared(tester);
      final base = 'あ' * 10;
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}あ');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    testWidgets('編集ダイアログの入力欄に「a」×19の後に「あ」を入力した場合、入力欄は「a」×19のまま [SMP-N05]',
        (tester) async {
      await openEditCleared(tester);
      final base = 'a' * 19;
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}あ');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });

    final enabledCases = <String, String>{
      '「a」': 'a',
      '「 a 」': ' a ',
      '「あ」': 'あ',
    };
    for (final entry in enabledCases.entries) {
      testWidgets('編集ダイアログの入力欄に${entry.key}を入力した場合、「保存」ボタンが有効になる [SMP-N06]',
          (tester) async {
        await openEditCleared(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isEnabled(_saveButton, tester), isTrue);
      });
    }

    final disabledCases = <String, String>{
      '空': '',
      '「 」（半角スペース1つ）': ' ',
      '「　」（全角スペース1つ）': '　',
      '「 　 」（半角・全角の混在）': ' 　 ',
    };
    for (final entry in disabledCases.entries) {
      testWidgets('編集ダイアログの入力欄に${entry.key}を入力した場合、「保存」ボタンが無効になる [SMP-N06]',
          (tester) async {
        await openEditCleared(tester);
        await tester.enterText(find.byType(TextField), entry.value);
        await tester.pump();

        expect(_isEnabled(_saveButton, tester), isFalse);
      });
    }

    final trimCases = <String, (String, String)>{
      '「 B 」': (' B ', 'B'),
      '「　B　」': ('　B　', 'B'),
      '「A B」': ('A B', 'A B'),
    };
    for (final entry in trimCases.entries) {
      testWidgets(
          '編集ダイアログに${entry.key}を入力して「保存」をタップした場合、前後のスペースを除いた「${entry.value.$2}」が名前として保存される [SMP-N07]',
          (tester) async {
        final repo = await openEditCleared(tester);
        await tester.enterText(find.byType(TextField), entry.value.$1);
        await tester.pump();
        await tester.tap(_saveButton);
        await tester.pumpAndSettle();

        expect(repo.samples.any((s) => s.name == entry.value.$2), isTrue);
      });
    }

    testWidgets('編集ダイアログの入力欄に「 」＋「a」×19（幅20）を入力した場合、そのまま入力欄に反映される [SMP-N08]',
        (tester) async {
      await openEditCleared(tester);
      final value = ' ${'a' * 19}';
      await tester.enterText(find.byType(TextField), value);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, value);
    });

    testWidgets('編集ダイアログの入力欄に「 」＋「a」×19の後に「a」を入力した場合、入力欄は「 」＋「a」×19のまま [SMP-N08]',
        (tester) async {
      await openEditCleared(tester);
      final base = ' ${'a' * 19}';
      await tester.enterText(find.byType(TextField), base);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '${base}a');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, base);
    });
  });
}
