import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/test_result.dart';

abstract class TestResultRepository {
  Future<Either<Failure, List<TestResult>>> getTestResults({
    required String userId,
  });

  Future<Either<Failure, TestResult>> saveTestResult({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  });
}
