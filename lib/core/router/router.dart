import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/sync_status_providers.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/auth/login/login_page.dart';
import 'package:word_stock/presentation/auth/password_reset/password_reset_page.dart';
import 'package:word_stock/presentation/auth/sign_up/sign_up_page.dart';
import 'package:word_stock/presentation/auth/splash/splash_page.dart';
import 'package:word_stock/presentation/home/home_page.dart';
import 'package:word_stock/presentation/result/result_page.dart';
import 'package:word_stock/presentation/settings/settings_page.dart';
import 'package:word_stock/presentation/shell/shell_page.dart';
import 'package:word_stock/presentation/test_session/test_page.dart';
import 'package:word_stock/presentation/test_session/test_result_page.dart';
import 'package:word_stock/presentation/test_session/test_settings_page.dart';
import 'package:word_stock/presentation/word/word_list_page.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final goRouter = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
      final isSyncing = ref.read(authSyncInProgressProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/sign-up' || loc == '/password-reset';

      if (!isLoggedIn && !isAuthRoute && loc != '/') return '/login';
      // ログイン直後の初回同期が終わるまではホームに遷移させない
      if (isLoggedIn && isAuthRoute && !isSyncing) return '/home';
      return null;
    },
    routes: $appRoutes,
  );

  // 認証状態・同期状態が変わったら redirect を再評価させる
  ref.listen(authStateProvider, (_, __) => goRouter.refresh());
  ref.listen(authSyncInProgressProvider, (_, __) => goRouter.refresh());

  return goRouter;
}

class TestRouteExtra {
  const TestRouteExtra({
    required this.words,
    required this.shuffle,
    required this.folderName,
    required this.userId,
  });

  final List<Word> words;
  final bool shuffle;
  final String folderName;
  final String userId;
}

// ─── Auth / スプラッシュ ──────────────────────────────────────────

@immutable
@TypedGoRoute<SplashRoute>(path: '/')
class SplashRoute extends GoRouteData {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SplashPage();
}

@immutable
@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData {
  const LoginRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginPage();
}

@immutable
@TypedGoRoute<SignUpRoute>(path: '/sign-up')
class SignUpRoute extends GoRouteData {
  const SignUpRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SignUpPage();
}

@immutable
@TypedGoRoute<PasswordResetRoute>(path: '/password-reset')
class PasswordResetRoute extends GoRouteData {
  const PasswordResetRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PasswordResetPage();
}

// ─── テスト関連（BottomNav なし）───────────────────────────────────

@immutable
@TypedGoRoute<TestSettingsRoute>(path: '/test-settings/:folderId')
class TestSettingsRoute extends GoRouteData {
  const TestSettingsRoute({required this.folderId, this.$extra});

  final String folderId;
  final String? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TestSettingsPage(folderId: folderId, folderName: $extra ?? '');
  }
}

@immutable
@TypedGoRoute<TestRoute>(path: '/test/:folderId')
class TestRoute extends GoRouteData {
  const TestRoute({required this.folderId, required this.$extra});

  final String folderId;
  final TestRouteExtra $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TestPage(
      folderId: folderId,
      words: $extra.words,
      shuffle: $extra.shuffle,
      folderName: $extra.folderName,
      userId: $extra.userId,
    );
  }
}

@immutable
@TypedGoRoute<TestResultRoute>(path: '/test-result')
class TestResultRoute extends GoRouteData {
  const TestResultRoute({required this.correctCount, required this.total});

  final int correctCount;
  final int total;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TestResultPage(correctCount: correctCount, total: total);
  }
}

// ─── BottomNav シェル ──────────────────────────────────────────────

@immutable
@TypedShellRoute<AppShellRoute>(
  routes: [
    TypedGoRoute<HomeRoute>(path: '/home'),
    TypedGoRoute<FolderRoute>(path: '/folder/:folderId'),
    TypedGoRoute<ResultsRoute>(path: '/results'),
    TypedGoRoute<SettingsRoute>(path: '/settings'),
  ],
)
class AppShellRoute extends ShellRouteData {
  const AppShellRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = _shellNavigatorKey;

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    return ShellPage(child: navigator);
  }
}

@immutable
class HomeRoute extends GoRouteData {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

@immutable
class FolderRoute extends GoRouteData {
  const FolderRoute({required this.folderId, this.$extra});

  final String folderId;
  final String? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return WordListPage(folderId: folderId, folderName: $extra ?? '');
  }
}

@immutable
class ResultsRoute extends GoRouteData {
  const ResultsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ResultPage();
}

@immutable
class SettingsRoute extends GoRouteData {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsPage();
}
