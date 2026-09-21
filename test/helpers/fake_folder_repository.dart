import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/repositories/folder_repository.dart';

/// `lib/application/use_cases/folder/**` の単体テスト用の手書きフェイク。
///
/// 呼び出し引数を記録し、`resultToReturn` で戻り値（Right/Left）を
/// 差し替えられるようにしている。mockito/mocktail は使わない方針のため
/// 手書きで実装している。
class FakeFolderRepository implements FolderRepository {
  Either<Failure, List<Folder>> getFoldersResult = const Right(<Folder>[]);
  Either<Failure, Folder>? createFolderResult;
  Either<Failure, Folder>? updateFolderResult;
  Either<Failure, Unit> deleteFolderResult = const Right(unit);

  int getFoldersCallCount = 0;
  int createFolderCallCount = 0;
  int updateFolderCallCount = 0;
  int deleteFolderCallCount = 0;

  String? lastUserId;
  String? lastName;
  String? lastParentFolderId;
  String? lastFolderId;

  @override
  Future<Either<Failure, List<Folder>>> getFolders({
    required String userId,
  }) async {
    getFoldersCallCount++;
    lastUserId = userId;
    return getFoldersResult;
  }

  @override
  Future<Either<Failure, Folder>> createFolder({
    required String userId,
    required String name,
    String? parentFolderId,
  }) async {
    createFolderCallCount++;
    lastUserId = userId;
    lastName = name;
    lastParentFolderId = parentFolderId;
    return createFolderResult ??
        Right(
          Folder(
            id: 'fake-id',
            name: name,
            parentFolderId: parentFolderId,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        );
  }

  @override
  Future<Either<Failure, Folder>> updateFolder({
    required String userId,
    required String folderId,
    required String name,
  }) async {
    updateFolderCallCount++;
    lastUserId = userId;
    lastFolderId = folderId;
    lastName = name;
    return updateFolderResult ??
        Right(
          Folder(
            id: folderId,
            name: name,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        );
  }

  @override
  Future<Either<Failure, Unit>> deleteFolder({
    required String userId,
    required String folderId,
  }) async {
    deleteFolderCallCount++;
    lastUserId = userId;
    lastFolderId = folderId;
    return deleteFolderResult;
  }
}
