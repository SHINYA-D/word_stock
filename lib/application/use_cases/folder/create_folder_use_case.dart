import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/repositories/folder_repository.dart';

class CreateFolderUseCase {
  const CreateFolderUseCase(this._repository);

  final FolderRepository _repository;

  Future<Either<Failure, Folder>> call({
    required String userId,
    required String name,
    String? parentFolderId,
  }) {
    return _repository.createFolder(
      userId: userId,
      name: name,
      parentFolderId: parentFolderId,
    );
  }
}
