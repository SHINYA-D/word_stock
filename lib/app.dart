import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/app_lifecycle_observer.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/sync_providers.dart';
import 'package:word_stock/core/router/router.dart';
import 'package:word_stock/core/theme/app_theme.dart';
import 'package:word_stock/presentation/settings/settings_view_model.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  AppLifecycleObserver? _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    final autoSync = ref.read(autoSyncServiceProvider);
    // オンライン復帰時に同期する
    autoSync.start();

    // ログイン済みになったら同期する（起動時にログイン済みだった場合を含む）
    ref.listenManual(currentUserProvider, (previous, next) {
      if (next != null && previous?.id != next.id) autoSync.onSignedIn();
    }, fireImmediately: true);

    // resumed 時に同期する（前回の取得から5分以上たっていれば）
    _lifecycleObserver = AppLifecycleObserver(onResumed: autoSync.onResumed);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  @override
  void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    ref.read(autoSyncServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final user = ref.watch(currentUserProvider);
    final settingsAsync =
        user != null ? ref.watch(settingsViewModelProvider(user.id)) : null;
    final settings = settingsAsync?.value;
    final seedColor =
        AppTheme.colorThemes[settings?.colorTheme ?? 'indigo'] ??
            AppTheme.colorThemes['indigo']!;
    final isDark = settings?.darkMode ?? false;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'WordStock',
      theme: AppTheme.light(seedColor: seedColor),
      darkTheme: AppTheme.dark(seedColor: seedColor),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
