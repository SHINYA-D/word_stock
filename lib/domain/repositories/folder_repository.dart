import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';

abstract class FolderRepository {
  Future<Either<Failure, List<Folder>>> getFolders({
    required String userId,
  });

  Future<Either<Failure, Folder>> createFolder({
    required String userId,
    required String name,
    String? parentFolderId,
  });

  Future<Either<Failure, Folder>> updateFolder({
    required String userId,
    required String folderId,
    required String name,
  });

  Future<Either<Failure, Unit>> deleteFolder({
    required String userId,
    required String folderId,
  });
}
