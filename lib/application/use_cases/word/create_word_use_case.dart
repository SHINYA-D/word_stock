import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';

class CreateWordUseCase {
  const CreateWordUseCase(this._repository);

  final WordRepository _repository;

  Future<Either<Failure, Word>> call({
    required String userId,
    required String folderId,
    required String front,
    required String back,
  }) {
    return _repository.createWord(
      userId: userId,
      folderId: folderId,
      front: front,
      back: back,
    );
  }
}
