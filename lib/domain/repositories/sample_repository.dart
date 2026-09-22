import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/sample.dart';

abstract class SampleRepository {
  Future<Either<Failure, List<Sample>>> getSamples({
    required String userId,
  });

  Future<Either<Failure, Sample>> createSample({
    required String userId,
    required String name,
  });

  Future<Either<Failure, Sample>> updateSample({
    required String userId,
    required String sampleId,
    required String name,
  });

  Future<Either<Failure, Unit>> deleteSample({
    required String userId,
    required String sampleId,
  });
}
