import 'package:word_stock/domain/repositories/sync_repository.dart';

/// 開発用の同期リポジトリ。モックモードではリモートがないので何もしない。
class MockSyncRepository implements SyncRepository {
  @override
  Future<void> syncRemoteToLocalOnLogin() async {}

  @override
  Future<int> pushBeforeSignOut() async => 0;
}
