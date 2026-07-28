import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/repositories/flashcard_result_repository.dart';

class GetFlashcardResultsUseCase {
  const GetFlashcardResultsUseCase(this._repository);

  final FlashcardResultRepository _repository;

  Future<Either<Failure, List<FlashcardResult>>> call({
    required String userId,
  }) {
    return _repository.getFlashcardResults(userId: userId);
  }
}
