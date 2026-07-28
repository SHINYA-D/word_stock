import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';

class GetWordsUseCase {
  const GetWordsUseCase(this._repository);

  final WordRepository _repository;

  Future<Either<Failure, List<Word>>> call({
    required String userId,
    required String folderId,
  }) {
    return _repository.getWords(userId: userId, folderId: folderId);
  }
}
