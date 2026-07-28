import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/test_result.dart';
import 'package:word_stock/domain/repositories/test_result_repository.dart';

class GetTestResultsUseCase {
  const GetTestResultsUseCase(this._repository);

  final TestResultRepository _repository;

  Future<Either<Failure, List<TestResult>>> call({
    required String userId,
  }) {
    return _repository.getTestResults(userId: userId);
  }
}
