import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/repositories/flashcard_result_repository.dart';

class SaveFlashcardResultUseCase {
  const SaveFlashcardResultUseCase(this._repository);

  final FlashcardResultRepository _repository;

  Future<Either<Failure, FlashcardResult>> call({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  }) {
    return _repository.saveFlashcardResult(
      userId: userId,
      folderId: folderId,
      totalCount: totalCount,
      correctCount: correctCount,
    );
  }
}
