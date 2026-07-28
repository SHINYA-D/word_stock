import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/app_lifecycle_observer.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/local_data_source_providers.dart';
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
    // AutoSyncService を起動（オンライン復帰時に自動同期）
    ref.read(autoSyncServiceProvider).start();

    // AppLifecycleObserver を登録（resumed 時に差分同期）
    _lifecycleObserver = AppLifecycleObserver(
      syncService: ref.read(syncServiceProvider),
      connectivityMonitor: ref.read(connectivityMonitorProvider),
    );
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
