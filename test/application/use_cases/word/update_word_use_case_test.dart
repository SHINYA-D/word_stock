import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/word/update_word_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository({this.updateWordResult});

  Either<Failure, Word>? updateWordResult;

  String? capturedUserId;
  String? capturedFolderId;
  String? capturedWordId;
  String? capturedFront;
  String? capturedBack;

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Word>> updateWord({
    required String userId,
    required String folderId,
    required String wordId,
    required String front,
    required String back,
  }) async {
    capturedUserId = userId;
    capturedFolderId = folderId;
    capturedWordId = wordId;
    capturedFront = front;
    capturedBack = back;
    return updateWordResult!;
  }
}

void main() {
  group('UpdateWordUseCase.call', () {
    test('正しい引数でRepositoryに委譲し、Rightがそのまま返る', () async {
      final now = DateTime(2024, 1, 1);
      final word = Word(
        id: 'w1',
        front: 'apple',
        back: 'りんご',
        createdAt: now,
        updatedAt: now,
      );
      final repository = _FakeWordRepository(
        updateWordResult: Right<Failure, Word>(word),
      );
      final useCase = UpdateWordUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        wordId: 'w1',
        front: 'apple',
        back: 'りんご',
      );

      expect(repository.capturedUserId, 'u1');
      expect(repository.capturedFolderId, 'f1');
      expect(repository.capturedWordId, 'w1');
      expect(repository.capturedFront, 'apple');
      expect(repository.capturedBack, 'りんご');
      expect(result, equals(Right<Failure, Word>(word)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final repository = _FakeWordRepository(
        updateWordResult: const Left<Failure, Word>(Failure.notFound()),
      );
      final useCase = UpdateWordUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        wordId: 'w1',
        front: 'apple',
        back: 'りんご',
      );

      expect(result, equals(const Left<Failure, Word>(Failure.notFound())));
    });
  });
}
