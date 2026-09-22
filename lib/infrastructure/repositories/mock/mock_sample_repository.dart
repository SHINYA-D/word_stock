import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/domain/repositories/sample_repository.dart';

/// テストパイプライン検証用のインメモリサンプルリポジトリ。
/// 本実装（SQLite / Firestore）は持たず、通常モードでもこのクラスを使う。
class MockSampleRepository implements SampleRepository {
  final _store = <String, List<Sample>>{};
  int _idCounter = 1;

  MockSampleRepository() {
    // サンプルデータ
    _store['mock-user-id'] = [
      Sample(
        id: 'sample-1',
        name: 'サンプルA',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Sample(
        id: 'sample-2',
        name: 'サンプルB',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  List<Sample> _userSamples(String userId) =>
      _store.putIfAbsent(userId, () => []);

  @override
  Future<Either<Failure, List<Sample>>> getSamples({
    required String userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Right(List.of(_userSamples(userId)));
  }

  @override
  Future<Either<Failure, Sample>> createSample({
    required String userId,
    required String name,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    final sample = Sample(
      id: 'sample-new-${_idCounter++}',
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    _userSamples(userId).add(sample);
    return Right(sample);
  }

  @override
  Future<Either<Failure, Sample>> updateSample({
    required String userId,
    required String sampleId,
    required String name,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final list = _userSamples(userId);
    final idx = list.indexWhere((s) => s.id == sampleId);
    if (idx == -1) return const Left(Failure.notFound());
    final updated = list[idx].copyWith(name: name, updatedAt: DateTime.now());
    list[idx] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, Unit>> deleteSample({
    required String userId,
    required String sampleId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _userSamples(userId).removeWhere((s) => s.id == sampleId);
    return const Right(unit);
  }
}
