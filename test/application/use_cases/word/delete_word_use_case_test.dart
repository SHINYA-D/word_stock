import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/word/delete_word_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository({this.deleteWordResult});

  Either<Failure, Unit>? deleteWordResult;

  String? capturedUserId;
  String? capturedFolderId;
  String? capturedWordId;

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
  }) async {
    capturedUserId = userId;
    capturedFolderId = folderId;
    capturedWordId = wordId;
    return deleteWordResult!;
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
  group('DeleteWordUseCase.call', () {
    test('正しい引数でRepositoryに委譲し、Rightがそのまま返る', () async {
      final repository = _FakeWordRepository(
        deleteWordResult: const Right<Failure, Unit>(unit),
      );
      final useCase = DeleteWordUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        wordId: 'w1',
      );

      expect(repository.capturedUserId, 'u1');
      expect(repository.capturedFolderId, 'f1');
      expect(repository.capturedWordId, 'w1');
      expect(result, equals(const Right<Failure, Unit>(unit)));
    });

    test('Repositoryが失敗を返した場合、Leftがそのまま返る', () async {
      final repository = _FakeWordRepository(
        deleteWordResult: const Left<Failure, Unit>(Failure.network()),
      );
      final useCase = DeleteWordUseCase(repository);

      final result = await useCase(
        userId: 'u1',
        folderId: 'f1',
        wordId: 'w1',
      );

      expect(result, equals(const Left<Failure, Unit>(Failure.network())));
    });
  });
}
