import 'dart:async';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';
import 'sync_service.dart';

class AutoSyncService {
  AutoSyncService({
    required ConnectivityMonitor connectivityMonitor,
    required SyncService syncService,
  })  : _connectivityMonitor = connectivityMonitor,
        _syncService = syncService;

  final ConnectivityMonitor _connectivityMonitor;
  final SyncService _syncService;
  StreamSubscription<bool>? _subscription;

  void start() {
    _subscription?.cancel();
    _subscription =
        _connectivityMonitor.onStatusChanged().listen((isOnline) {
      if (isOnline) {
        _syncService.syncLocalToRemote(
          connectivityMonitor: _connectivityMonitor,
        );
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
