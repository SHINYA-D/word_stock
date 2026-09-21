import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/flashcard_result/save_flashcard_result_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/repositories/flashcard_result_repository.dart';

class _FakeFlashcardResultRepository implements FlashcardResultRepository {
  _FakeFlashcardResultRepository({this.saveFlashcardResultResult});

  Either<Failure, FlashcardResult>? saveFlashcardResultResult;

  String? capturedUserId;
  String? capturedFolderId;
  int? capturedTotalCount;
  int? capturedCorrectCount;

  @override
  Future<Either<Failure, List<FlashcardResult>>> getFlashcardResults({
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, FlashcardResult>> saveFlashcardResult({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  }) async {
    capturedUserId = userId;
    capturedFolderId = folderId;
    capturedTotalCount = totalCount;
    capturedCorrectCount = correctCount;
    return saveFlashcardResultResult!;
  }
}

void main() {
  group('SaveFlashcardResultUseCase.call', () {
    test('正しい引数でRepositoryに委譲し、Rightがそのまま返る', () async {
      final now = DateTime(2024, 1, 1);
      final saved = FlashcardResult(
        id: 'r1',
        folderId: 'f1',
        totalCount: 10,
        correctCount: 7,
        date: now,
        updatedAt: now,
      );
      final repository = _FakeFlashcardResultRepository(
        saveFlashcardResultResult: Right<Failure, FlashcardResult>(saved),
      );
      final useCase = SaveFlashcardResultUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        totalCount: 10,
        correctCount: 7,
      );

      expect(repository.capturedUserId, 'u1');
      expect(repository.capturedFolderId, 'f1');
      expect(repository.capturedTotalCount, 10);
      expect(repository.capturedCorrectCount, 7);
      expect(result, equals(Right<Failure, FlashcardResult>(saved)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final repository = _FakeFlashcardResultRepository(
        saveFlashcardResultResult: const Left<Failure, FlashcardResult>(
          Failure.network(),
        ),
      );
      final useCase = SaveFlashcardResultUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        totalCount: 10,
        correctCount: 7,
      );

      expect(
        result,
        equals(const Left<Failure, FlashcardResult>(Failure.network())),
      );
    });
  });
}
