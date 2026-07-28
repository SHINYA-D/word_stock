import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/test_result.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/data_sources/firestore_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';

/// [FirestoreDataSource] の実装を Firebase 無しで検証するためのフェイク。
///
/// 実際の Firestore 通信は行わず、呼び出し内容をすべて記録するだけの
/// シンプルなフェイクとして振る舞う（`test/helpers/test_helpers.dart` の
/// Mock*Repository と同じ「手書きフェイク」方針に従う）。
class FakeFirestoreDataSource implements FirestoreDataSource {
  final List<({Folder folder, String userId})> writtenFolders = [];
  final List<({String userId, String folderId})> deletedFolders = [];
  final List<({Word word, String userId, String folderId})> writtenWords = [];
  final List<({String userId, String folderId, String wordId})>
      deletedWords = [];
  final List<({TestResult result, String userId})> writtenTestResults = [];
  final List<({String userId, String testResultId})> deletedTestResults = [];
  final List<({UserSettings settings, String userId})> writtenSettings = [];

  /// テストから任意の例外を投げさせたい場合に設定する。
  Exception? exceptionToThrow;

  void _maybeThrow() {
    final e = exceptionToThrow;
    if (e != null) throw e;
  }

  @override
  Future<void> writeFolder(Folder folder, String userId) async {
    _maybeThrow();
    writtenFolders.add((folder: folder, userId: userId));
  }

  @override
  Future<void> deleteRemoteFolder(String userId, String folderId) async {
    _maybeThrow();
    deletedFolders.add((userId: userId, folderId: folderId));
  }

  @override
  Future<void> writeWord(Word word, String userId, String folderId) async {
    _maybeThrow();
    writtenWords.add((word: word, userId: userId, folderId: folderId));
  }

  @override
  Future<void> deleteRemoteWord(
    String userId,
    String folderId,
    String wordId,
  ) async {
    _maybeThrow();
    deletedWords.add((userId: userId, folderId: folderId, wordId: wordId));
  }

  @override
  Future<void> writeTestResult(TestResult result, String userId) async {
    _maybeThrow();
    writtenTestResults.add((result: result, userId: userId));
  }

  @override
  Future<void> deleteRemoteTestResult(
    String userId,
    String testResultId,
  ) async {
    _maybeThrow();
    deletedTestResults.add((userId: userId, testResultId: testResultId));
  }

  @override
  Future<void> writeSettings(UserSettings settings, String userId) async {
    _maybeThrow();
    writtenSettings.add((settings: settings, userId: userId));
  }
}

/// [ConnectivityMonitor] のオンライン/オフライン状態をテストから固定するためのフェイク。
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool online = true}) : _online = online;

  bool _online;

  void setOnline(bool online) => _online = online;

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> onStatusChanged() => Stream.value(_online);
}
