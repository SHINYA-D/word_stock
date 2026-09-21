import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/word/get_words_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository({this.getWordsResult});

  Either<Failure, List<Word>>? getWordsResult;

  String? capturedUserId;
  String? capturedFolderId;

  @override
  Future<Either<Failure, Word>> createWord({
    required String userId,
    required String folderId,
    required String front,
    required String back,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> deleteWord({
    required String userId,
    required String folderId,
    required String wordId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<Word>>> getWords({
    required String userId,
    required String folderId,
  }) async {
    capturedUserId = userId;
    capturedFolderId = folderId;
    return getWordsResult!;
  }

  @override
  Future<Either<Failure, Word>> updateWord({
    required String userId,
    required String folderId,
    required String wordId,
    required String front,
    required String back,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('GetWordsUseCase.call', () {
    test('正しい引数でRepositoryに委譲し、Rightがそのまま返る', () async {
      final now = DateTime(2024, 1, 1);
      final words = [
        Word(
          id: 'w1',
          front: 'apple',
          back: 'りんご',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final repository = _FakeWordRepository(
        getWordsResult: Right<Failure, List<Word>>(words),
      );
      final useCase = GetWordsUseCase(repository);

      final result = await useCase(userId: 'u1', folderId: 'f1');

      expect(repository.capturedUserId, 'u1');
      expect(repository.capturedFolderId, 'f1');
      expect(result, equals(Right<Failure, List<Word>>(words)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final repository = _FakeWordRepository(
        getWordsResult: const Left<Failure, List<Word>>(Failure.network()),
      );
      final useCase = GetWordsUseCase(repository);

      final result = await useCase(userId: 'u1', folderId: 'f1');

      expect(
        result,
        equals(const Left<Failure, List<Word>>(Failure.network())),
      );
    });
  });
}
