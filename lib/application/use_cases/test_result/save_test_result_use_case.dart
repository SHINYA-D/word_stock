import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/test_result.dart';
import 'package:word_stock/domain/repositories/test_result_repository.dart';

class SaveTestResultUseCase {
  const SaveTestResultUseCase(this._repository);

  final TestResultRepository _repository;

  Future<Either<Failure, TestResult>> call({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  }) {
    return _repository.saveTestResult(
      userId: userId,
      folderId: folderId,
      totalCount: totalCount,
      correctCount: correctCount,
    );
  }
}
