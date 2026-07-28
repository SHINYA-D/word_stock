import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';

abstract class FlashcardResultRepository {
  Future<Either<Failure, List<FlashcardResult>>> getFlashcardResults({
    required String userId,
  });

  Future<Either<Failure, FlashcardResult>> saveFlashcardResult({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  });
}
