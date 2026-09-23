import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/domain/repositories/sample_repository.dart';

class CreateSampleUseCase {
  const CreateSampleUseCase(this._repository);

  final SampleRepository _repository;

  Future<Either<Failure, Sample>> call({
    required String userId,
    required String name,
  }) {
    return _repository.createSample(
      userId: userId,
      name: name,
    );
  }
}
