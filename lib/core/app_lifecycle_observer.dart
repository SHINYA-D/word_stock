import 'package:flutter/widgets.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  AppLifecycleObserver({
    required SyncService syncService,
    required ConnectivityMonitor connectivityMonitor,
  })  : _syncService = syncService,
        _connectivityMonitor = connectivityMonitor;

  final SyncService _syncService;
  final ConnectivityMonitor _connectivityMonitor;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncService.syncRemoteToLocalOnResumed(
        connectivityMonitor: _connectivityMonitor,
      );
    }
  }
}
