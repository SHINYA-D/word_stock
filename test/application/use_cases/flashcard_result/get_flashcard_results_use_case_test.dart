import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/flashcard_result/get_flashcard_results_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/repositories/flashcard_result_repository.dart';

class _FakeFlashcardResultRepository implements FlashcardResultRepository {
  _FakeFlashcardResultRepository({this.getFlashcardResultsResult});

  Either<Failure, List<FlashcardResult>>? getFlashcardResultsResult;

  String? capturedUserId;

  @override
  Future<Either<Failure, List<FlashcardResult>>> getFlashcardResults({
    required String userId,
  }) async {
    capturedUserId = userId;
    return getFlashcardResultsResult!;
  }

  @override
  Future<Either<Failure, FlashcardResult>> saveFlashcardResult({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('GetFlashcardResultsUseCase.call', () {
    test('正しい引数でRepositoryに委譲し、Rightがそのまま返る', () async {
      final now = DateTime(2024, 1, 1);
      final results = [
        FlashcardResult(
          id: 'r1',
          folderId: 'f1',
          totalCount: 10,
          correctCount: 8,
          date: now,
          updatedAt: now,
        ),
      ];
      final repository = _FakeFlashcardResultRepository(
        getFlashcardResultsResult:
            Right<Failure, List<FlashcardResult>>(results),
      );
      final useCase = GetFlashcardResultsUseCase(repository);

      final result = await useCase(userId: 'u1');

      expect(repository.capturedUserId, 'u1');
      expect(result, equals(Right<Failure, List<FlashcardResult>>(results)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final repository = _FakeFlashcardResultRepository(
        getFlashcardResultsResult:
            const Left<Failure, List<FlashcardResult>>(Failure.notFound()),
      );
      final useCase = GetFlashcardResultsUseCase(repository);

      final result = await useCase(userId: 'u1');

      expect(
        result,
        equals(
          const Left<Failure, List<FlashcardResult>>(Failure.notFound()),
        ),
      );
    });
  });
}
