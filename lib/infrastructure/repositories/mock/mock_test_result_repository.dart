import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/test_result.dart';
import 'package:word_stock/domain/repositories/test_result_repository.dart';

/// 開発用インメモリ成績リポジトリ。
class MockTestResultRepository implements TestResultRepository {
  final _store = <String, List<TestResult>>{};
  int _idCounter = 1;

  MockTestResultRepository() {
    // サンプルデータ
    const userId = 'mock-user-id';
    _store[userId] = [
      TestResult(
        id: 'result-1',
        folderId: 'folder-1',
        totalCount: 3,
        correctCount: 2,
        date: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      TestResult(
        id: 'result-2',
        folderId: 'folder-2',
        totalCount: 2,
        correctCount: 2,
        date: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }

  @override
  Future<Either<Failure, List<TestResult>>> getTestResults({
    required String userId,
    String? folderId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final all = _store[userId] ?? [];
    final filtered = folderId == null
        ? all
        : all.where((r) => r.folderId == folderId).toList();
    // 新しい順
    final sorted = List.of(filtered)
      ..sort((a, b) => b.date.compareTo(a.date));
    return Right(sorted);
  }

  @override
  Future<Either<Failure, TestResult>> saveTestResult({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    final result = TestResult(
      id: 'result-${_idCounter++}',
      folderId: folderId,
      totalCount: totalCount,
      correctCount: correctCount,
      date: now,
      updatedAt: now,
    );
    _store.putIfAbsent(userId, () => []).add(result);
    return Right(result);
  }
}
