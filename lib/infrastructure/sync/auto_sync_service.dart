import 'dart:async';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';
import 'sync_service.dart';

/// 同期のきっかけを [SyncService] に伝える。
///
/// | きっかけ | 行うこと |
/// |---------|---------|
/// | オフラインからオンラインに戻った | 同期処理（取得 → 送信） |
/// | ログイン済みになった（起動時を含む） | 同期処理（取得 → 送信） |
/// | resumed | 前回の取得から5分以上たっていれば同期処理 |
/// | 登録・編集・削除をした | 送信だけ |
class AutoSyncService {
  AutoSyncService({
    required ConnectivityMonitor connectivityMonitor,
    required SyncService syncService,
  })  : _connectivityMonitor = connectivityMonitor,
        _syncService = syncService;

  final ConnectivityMonitor _connectivityMonitor;
  final SyncService _syncService;
  StreamSubscription<bool>? _subscription;
  bool? _lastOnline;

  void start() {
    _subscription?.cancel();
    _lastOnline = null;
    _subscription = _connectivityMonitor.onStatusChanged().listen((isOnline) {
      final wasOnline = _lastOnline;
      _lastOnline = isOnline;
      if (isOnline && wasOnline != true) {
        unawaited(_syncService.syncAll());
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// ログイン済みになったとき（アプリ起動時にログイン済みだった場合を含む）
  void onSignedIn() => unawaited(_syncService.syncAll());

  /// アプリがバックグラウンドから戻ったとき
  void onResumed() => unawaited(_syncService.syncOnResumed());

  /// 登録・編集・削除をしたとき
  void onLocalChanged() => unawaited(_syncService.pushPending());
}
