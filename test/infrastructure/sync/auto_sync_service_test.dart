import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';
import 'package:word_stock/infrastructure/sync/auto_sync_service.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

import '../../helpers/fake_infrastructure.dart';

/// [ConnectivityMonitor] のオンライン/オフライン変化をテストから任意のタイミングで
/// 発火させるためのフェイク。[FakeConnectivityMonitor] は `onStatusChanged()` が
/// `Stream.value` の単発イベントしか流せないため、[AutoSyncService.start] が
/// 複数回の状態変化を購読し続けることを検証するために `StreamController` を使う。
class ControllableConnectivityMonitor implements ConnectivityMonitor {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _online = true;

  void emit(bool online) {
    _online = online;
    _controller.add(online);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> onStatusChanged() => _controller.stream;

  Future<void> close() => _controller.close();
}

/// [SyncService.syncLocalToRemote] の呼び出し回数・引数を記録するためのフェイク。
///
/// `SyncService` はインターフェースではなく具象クラスのため、テストでは
/// 実 Firestore/SQLite 通信を避けつつコンストラクタの型要件を満たすために
/// `fake_cloud_firestore` の [FakeFirebaseFirestore] と実 [DatabaseHelper] を渡し、
/// 呼び出し対象のメソッドのみをオーバーライドして振る舞いを差し替える。
class FakeSyncService extends SyncService {
  FakeSyncService()
      : super(
          syncQueueDataSource: SyncQueueDataSource(DatabaseHelper()),
          firestore: FakeFirebaseFirestore(),
          getCurrentUserId: () => 'test-user',
          dbHelper: DatabaseHelper(),
        );

  int syncLocalToRemoteCallCount = 0;
  final List<ConnectivityMonitor> receivedMonitors = [];

  @override
  Future<void> syncLocalToRemote({
    required ConnectivityMonitor connectivityMonitor,
  }) async {
    syncLocalToRemoteCallCount++;
    receivedMonitors.add(connectivityMonitor);
  }
}

void main() {
  group('AutoSyncService.start()', () {
    test(
        'オンライン状態への変化を検知した場合、SyncService.syncLocalToRemoteが呼ばれる',
        () async {
      final monitor = FakeConnectivityMonitor(online: true);
      final syncService = FakeSyncService();
      final autoSyncService = AutoSyncService(
        connectivityMonitor: monitor,
        syncService: syncService,
      );

      autoSyncService.start();
      await Future<void>.delayed(Duration.zero);

      expect(syncService.syncLocalToRemoteCallCount, 1);
      expect(syncService.receivedMonitors.single, monitor);
    });

    test(
        'オフライン状態の通知を受けた場合、SyncService.syncLocalToRemoteは呼ばれない',
        () async {
      final monitor = ControllableConnectivityMonitor();
      final syncService = FakeSyncService();
      final autoSyncService = AutoSyncService(
        connectivityMonitor: monitor,
        syncService: syncService,
      );

      autoSyncService.start();
      monitor.emit(false);
      await Future<void>.delayed(Duration.zero);

      expect(syncService.syncLocalToRemoteCallCount, 0);

      await monitor.close();
    });

    test(
        'オフライン→オンラインと複数回状態が変化した場合、オンラインになった回数分だけsyncLocalToRemoteが呼ばれる',
        () async {
      final monitor = ControllableConnectivityMonitor();
      final syncService = FakeSyncService();
      final autoSyncService = AutoSyncService(
        connectivityMonitor: monitor,
        syncService: syncService,
      );

      autoSyncService.start();
      monitor.emit(false);
      await Future<void>.delayed(Duration.zero);
      monitor.emit(true);
      await Future<void>.delayed(Duration.zero);
      monitor.emit(false);
      await Future<void>.delayed(Duration.zero);
      monitor.emit(true);
      await Future<void>.delayed(Duration.zero);

      expect(syncService.syncLocalToRemoteCallCount, 2);

      await monitor.close();
    });

    test('startを2回連続で呼んだ場合、古い購読が解除され通知は二重に処理されない', () async {
      final monitor = ControllableConnectivityMonitor();
      final syncService = FakeSyncService();
      final autoSyncService = AutoSyncService(
        connectivityMonitor: monitor,
        syncService: syncService,
      );

      autoSyncService.start();
      autoSyncService.start();
      monitor.emit(true);
      await Future<void>.delayed(Duration.zero);

      expect(syncService.syncLocalToRemoteCallCount, 1);

      await monitor.close();
    });
  });

  group('AutoSyncService.stop()', () {
    test('stopを呼んだ後は、オンライン通知が来てもsyncLocalToRemoteは呼ばれない', () async {
      final monitor = ControllableConnectivityMonitor();
      final syncService = FakeSyncService();
      final autoSyncService = AutoSyncService(
        connectivityMonitor: monitor,
        syncService: syncService,
      );

      autoSyncService.start();
      autoSyncService.stop();
      monitor.emit(true);
      await Future<void>.delayed(Duration.zero);

      expect(syncService.syncLocalToRemoteCallCount, 0);

      await monitor.close();
    });

    test('startされていない状態でstopを呼んでも例外は発生しない', () {
      final monitor = FakeConnectivityMonitor(online: true);
      final syncService = FakeSyncService();
      final autoSyncService = AutoSyncService(
        connectivityMonitor: monitor,
        syncService: syncService,
      );

      expect(() => autoSyncService.stop(), returnsNormally);
    });
  });
}
