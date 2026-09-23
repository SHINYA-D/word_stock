import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/domain/repositories/sample_repository.dart';

class GetSamplesUseCase {
  const GetSamplesUseCase(this._repository);

  final SampleRepository _repository;

  Future<Either<Failure, List<Sample>>> call({
    required String userId,
  }) {
    return _repository.getSamples(
      userId: userId,
    );
  }
}
