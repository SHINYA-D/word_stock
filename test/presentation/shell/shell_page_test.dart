import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:word_stock/presentation/shell/shell_page.dart';

/// ShellPage は BottomNavigationBar（NavigationBar）の描画とタブ切り替えのみを持つ
/// ルーティングシェルであり、独自の ViewModel やロジック分岐は `_tabIndex` の一箇所のみ。
/// そのため本テストは「4タブが表示されること」「タップで対応する画面に遷移すること」
/// 「サブパスでも該当タブが選択状態になること」に絞る。
/// GoRouter を実際に構築する必要があるため、アプリ本体の router.dart には依存せず
/// テスト専用の最小限の GoRouter（/home, /results, /sample, /settings, /folder/:id）を用意する。
void main() {
  GoRouter buildTestRouter({required String initialLocation}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, navigator) => ShellPage(child: navigator),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const Text('home-screen'),
            ),
            GoRoute(
              path: '/folder/:folderId',
              builder: (context, state) => const Text('folder-screen'),
            ),
            GoRoute(
              path: '/results',
              builder: (context, state) => const Text('results-screen'),
            ),
            GoRoute(
              path: '/sample',
              builder: (context, state) => const Text('sample-screen'),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const Text('settings-screen'),
            ),
          ],
        ),
      ],
    );
  }

  group('ShellPage', () {
    testWidgets('4つのナビゲーション項目（ホーム・成績・テスト・設定）が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: buildTestRouter(initialLocation: '/home')),
      );

      expect(find.text('ホーム'), findsOneWidget);
      expect(find.text('成績'), findsOneWidget);
      expect(find.text('テスト'), findsOneWidget);
      expect(find.text('設定'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('/home 表示時はホームタブが選択状態になる', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: buildTestRouter(initialLocation: '/home')),
      );

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
      expect(find.text('home-screen'), findsOneWidget);
    });

    testWidgets('/folder/:id のようなホーム配下のサブパスでもホームタブが選択される', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: buildTestRouter(initialLocation: '/folder/folder-1')),
      );

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
      expect(find.text('folder-screen'), findsOneWidget);
    });

    testWidgets('成績タブをタップすると /results 画面へ切り替わる', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: buildTestRouter(initialLocation: '/home')),
      );

      await tester.tap(find.text('成績'));
      await tester.pumpAndSettle();

      expect(find.text('results-screen'), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });

    testWidgets('テストタブをタップすると /sample 画面へ切り替わる', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: buildTestRouter(initialLocation: '/home')),
      );

      await tester.tap(find.text('テスト'));
      await tester.pumpAndSettle();

      expect(find.text('sample-screen'), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });

    testWidgets('設定タブをタップすると /settings 画面へ切り替わる', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: buildTestRouter(initialLocation: '/home')),
      );

      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();

      expect(find.text('settings-screen'), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 3);
    });
  });
}
