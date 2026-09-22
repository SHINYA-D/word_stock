import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/sample_repository.dart';
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
  final List<({FlashcardResult result, String userId})> writtenFlashcardResults = [];
  final List<({String userId, String flashcardResultId})> deletedFlashcardResults = [];
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
  Future<void> writeFlashcardResult(FlashcardResult result, String userId) async {
    _maybeThrow();
    writtenFlashcardResults.add((result: result, userId: userId));
  }

  @override
  Future<void> deleteRemoteFlashcardResult(
    String userId,
    String flashcardResultId,
  ) async {
    _maybeThrow();
    deletedFlashcardResults.add((userId: userId, flashcardResultId: flashcardResultId));
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

/// [SampleRepository] のテスト用フェイク（ViewModel 単体テストと Widget テストで共有する）。
///
/// - [samples] がそのまま保存先になる（作成・変更・削除が反映される）
/// - `xxxFailures` に Failure を積むと、そのメソッドの呼び出しが1回だけ Left を返す（先頭から消費）
/// - `xxxGate` を設定すると、Completer が complete されるまでそのメソッドは完了しない
///   （「処理が完了する前」の状態を観測するため）
/// - `xxxCalls` に呼び出しの引数を記録する（呼ばれた回数と引数の検証用）
class FakeSampleRepository implements SampleRepository {
  FakeSampleRepository({List<Sample>? initial}) : samples = List.of(initial ?? const []);

  List<Sample> samples;

  final List<Failure> getFailures = [];
  final List<Failure> createFailures = [];
  final List<Failure> updateFailures = [];
  final List<Failure> deleteFailures = [];

  Completer<void>? getGate;
  Completer<void>? createGate;
  Completer<void>? updateGate;
  Completer<void>? deleteGate;

  final List<({String userId})> getCalls = [];
  final List<({String userId, String name})> createCalls = [];
  final List<({String userId, String sampleId, String name})> updateCalls = [];
  final List<({String userId, String sampleId})> deleteCalls = [];

  int _idCounter = 1;

  Failure? _pop(List<Failure> queue) => queue.isEmpty ? null : queue.removeAt(0);

  @override
  Future<Either<Failure, List<Sample>>> getSamples({required String userId}) async {
    getCalls.add((userId: userId));
    if (getGate != null) await getGate!.future;
    final f = _pop(getFailures);
    if (f != null) return Left(f);
    return Right(List.of(samples));
  }

  @override
  Future<Either<Failure, Sample>> createSample({
    required String userId,
    required String name,
  }) async {
    createCalls.add((userId: userId, name: name));
    if (createGate != null) await createGate!.future;
    final f = _pop(createFailures);
    if (f != null) return Left(f);
    final now = DateTime.now();
    final sample = Sample(id: 'new-${_idCounter++}', name: name, createdAt: now, updatedAt: now);
    samples.add(sample);
    return Right(sample);
  }

  @override
  Future<Either<Failure, Sample>> updateSample({
    required String userId,
    required String sampleId,
    required String name,
  }) async {
    updateCalls.add((userId: userId, sampleId: sampleId, name: name));
    if (updateGate != null) await updateGate!.future;
    final f = _pop(updateFailures);
    if (f != null) return Left(f);
    final idx = samples.indexWhere((s) => s.id == sampleId);
    if (idx == -1) return const Left(Failure.notFound());
    final updated = samples[idx].copyWith(name: name, updatedAt: DateTime.now());
    samples[idx] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, Unit>> deleteSample({
    required String userId,
    required String sampleId,
  }) async {
    deleteCalls.add((userId: userId, sampleId: sampleId));
    if (deleteGate != null) await deleteGate!.future;
    final f = _pop(deleteFailures);
    if (f != null) return Left(f);
    samples.removeWhere((s) => s.id == sampleId);
    return const Right(unit);
  }
}
