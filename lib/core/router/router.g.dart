// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $splashRoute,
      $loginRoute,
      $signUpRoute,
      $passwordResetRoute,
      $flashcardModeSettingsRoute,
      $flashcardModeRoute,
      $flashcardModeResultRoute,
      $appShellRoute,
    ];

RouteBase get $splashRoute => GoRouteData.$route(
      path: '/',
      factory: $SplashRouteExtension._fromState,
    );

extension $SplashRouteExtension on SplashRoute {
  static SplashRoute _fromState(GoRouterState state) => const SplashRoute();

  String get location => GoRouteData.$location(
        '/',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $loginRoute => GoRouteData.$route(
      path: '/login',
      factory: $LoginRouteExtension._fromState,
    );

extension $LoginRouteExtension on LoginRoute {
  static LoginRoute _fromState(GoRouterState state) => const LoginRoute();

  String get location => GoRouteData.$location(
        '/login',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $signUpRoute => GoRouteData.$route(
      path: '/sign-up',
      factory: $SignUpRouteExtension._fromState,
    );

extension $SignUpRouteExtension on SignUpRoute {
  static SignUpRoute _fromState(GoRouterState state) => const SignUpRoute();

  String get location => GoRouteData.$location(
        '/sign-up',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $passwordResetRoute => GoRouteData.$route(
      path: '/password-reset',
      factory: $PasswordResetRouteExtension._fromState,
    );

extension $PasswordResetRouteExtension on PasswordResetRoute {
  static PasswordResetRoute _fromState(GoRouterState state) =>
      const PasswordResetRoute();

  String get location => GoRouteData.$location(
        '/password-reset',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $flashcardModeSettingsRoute => GoRouteData.$route(
      path: '/test-settings/:folderId',
      factory: $FlashcardModeSettingsRouteExtension._fromState,
    );

extension $FlashcardModeSettingsRouteExtension on FlashcardModeSettingsRoute {
  static FlashcardModeSettingsRoute _fromState(GoRouterState state) =>
      FlashcardModeSettingsRoute(
        folderId: state.pathParameters['folderId']!,
        $extra: state.extra as String?,
      );

  String get location => GoRouteData.$location(
        '/test-settings/${Uri.encodeComponent(folderId)}',
      );

  void go(BuildContext context) => context.go(location, extra: $extra);

  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: $extra);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: $extra);

  void replace(BuildContext context) =>
      context.replace(location, extra: $extra);
}

RouteBase get $flashcardModeRoute => GoRouteData.$route(
      path: '/test/:folderId',
      factory: $FlashcardModeRouteExtension._fromState,
    );

extension $FlashcardModeRouteExtension on FlashcardModeRoute {
  static FlashcardModeRoute _fromState(GoRouterState state) =>
      FlashcardModeRoute(
        folderId: state.pathParameters['folderId']!,
        $extra: state.extra as FlashcardModeRouteExtra,
      );

  String get location => GoRouteData.$location(
        '/test/${Uri.encodeComponent(folderId)}',
      );

  void go(BuildContext context) => context.go(location, extra: $extra);

  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: $extra);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: $extra);

  void replace(BuildContext context) =>
      context.replace(location, extra: $extra);
}

RouteBase get $flashcardModeResultRoute => GoRouteData.$route(
      path: '/flashcard-result',
      factory: $FlashcardModeResultRouteExtension._fromState,
    );

extension $FlashcardModeResultRouteExtension on FlashcardModeResultRoute {
  static FlashcardModeResultRoute _fromState(GoRouterState state) =>
      FlashcardModeResultRoute(
        correctCount: int.parse(state.uri.queryParameters['correct-count']!)!,
        total: int.parse(state.uri.queryParameters['total']!)!,
      );

  String get location => GoRouteData.$location(
        '/flashcard-result',
        queryParams: {
          'correct-count': correctCount.toString(),
          'total': total.toString(),
        },
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appShellRoute => ShellRouteData.$route(
      navigatorKey: AppShellRoute.$navigatorKey,
      factory: $AppShellRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: '/home',
          factory: $HomeRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/folder/:folderId',
          factory: $FolderRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/results',
          factory: $ResultsRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/settings',
          factory: $SettingsRouteExtension._fromState,
        ),
      ],
    );

extension $AppShellRouteExtension on AppShellRoute {
  static AppShellRoute _fromState(GoRouterState state) => const AppShellRoute();
}

extension $HomeRouteExtension on HomeRoute {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  String get location => GoRouteData.$location(
        '/home',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $FolderRouteExtension on FolderRoute {
  static FolderRoute _fromState(GoRouterState state) => FolderRoute(
        folderId: state.pathParameters['folderId']!,
        $extra: state.extra as String?,
      );

  String get location => GoRouteData.$location(
        '/folder/${Uri.encodeComponent(folderId)}',
      );

  void go(BuildContext context) => context.go(location, extra: $extra);

  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: $extra);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: $extra);

  void replace(BuildContext context) =>
      context.replace(location, extra: $extra);
}

extension $ResultsRouteExtension on ResultsRoute {
  static ResultsRoute _fromState(GoRouterState state) => const ResultsRoute();

  String get location => GoRouteData.$location(
        '/results',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsRouteExtension on SettingsRoute {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  String get location => GoRouteData.$location(
        '/settings',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$routerHash() => r'1dd43481a4cc518aafa8d2195a9b82b5b29aaccc';

/// See also [router].
@ProviderFor(router)
final routerProvider = Provider<GoRouter>.internal(
  router,
  name: r'routerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$routerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RouterRef = ProviderRef<GoRouter>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
