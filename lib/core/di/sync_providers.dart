import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/firebase_providers.dart';
import 'package:word_stock/core/di/local_data_source_providers.dart';
import 'package:word_stock/core/di/repository_providers.dart';
import 'package:word_stock/domain/repositories/sync_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_sync_repository.dart';
import 'package:word_stock/infrastructure/sync/auto_sync_service.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  return SyncService(
    localDataSource: ref.watch(syncLocalDataSourceProvider),
    syncQueueDataSource: ref.watch(syncQueueDataSourceProvider),
    remoteDataSource: ref.watch(syncRemoteDataSourceProvider),
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
    // モックモードでは Firestore と同期しない。
    // ログイン直後は authStateChanges より先に FirebaseAuth.currentUser が確定するので、そちらを優先する
    getCurrentUserId: () => kUseMocks
        ? null
        : ref.read(firebaseAuthProvider).currentUser?.uid ??
            ref.read(currentUserProvider)?.id,
  );
}

@Riverpod(keepAlive: true)
SyncRepository syncRepository(Ref ref) {
  if (kUseMocks) return MockSyncRepository();
  return ref.watch(syncServiceProvider);
}

@Riverpod(keepAlive: true)
AutoSyncService autoSyncService(Ref ref) {
  return AutoSyncService(
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
    syncService: ref.watch(syncServiceProvider),
  );
}
