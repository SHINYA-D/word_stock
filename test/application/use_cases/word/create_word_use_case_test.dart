import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/word/create_word_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository({this.createWordResult});

  Either<Failure, Word>? createWordResult;

  String? capturedUserId;
  String? capturedFolderId;
  String? capturedFront;
  String? capturedBack;

  @override
  Future<Either<Failure, Word>> createWord({
    required String userId,
    required String folderId,
    required String front,
    required String back,
  }) async {
    capturedUserId = userId;
    capturedFolderId = folderId;
    capturedFront = front;
    capturedBack = back;
    return createWordResult!;
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
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('CreateWordUseCase.call', () {
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
        createWordResult: Right<Failure, Word>(word),
      );
      final useCase = CreateWordUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        front: 'apple',
        back: 'りんご',
      );

      expect(repository.capturedUserId, 'u1');
      expect(repository.capturedFolderId, 'f1');
      expect(repository.capturedFront, 'apple');
      expect(repository.capturedBack, 'りんご');
      expect(result, equals(Right<Failure, Word>(word)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final repository = _FakeWordRepository(
        createWordResult: const Left<Failure, Word>(Failure.network()),
      );
      final useCase = CreateWordUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        front: 'apple',
        back: 'りんご',
      );

      expect(result, equals(const Left<Failure, Word>(Failure.network())));
    });
  });
}
