import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/repositories/folder_repository.dart';

class GetFoldersUseCase {
  const GetFoldersUseCase(this._repository);

  final FolderRepository _repository;

  Future<Either<Failure, List<Folder>>> call({
    required String userId,
  }) {
    return _repository.getFolders(
      userId: userId,
    );
  }
}
