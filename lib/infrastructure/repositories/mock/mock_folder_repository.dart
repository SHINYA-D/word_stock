import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/repositories/folder_repository.dart';

/// 開発用インメモリフォルダリポジトリ。
class MockFolderRepository implements FolderRepository {
  final _store = <String, List<Folder>>{};
  int _idCounter = 1;

  MockFolderRepository() {
    // サンプルデータ
    _store['mock-user-id'] = [
      Folder(
        id: 'folder-1',
        name: '英単語',
        parentFolderId: null,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Folder(
        id: 'folder-2',
        name: 'TOEIC 頻出',
        parentFolderId: null,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  List<Folder> _userFolders(String userId) =>
      _store.putIfAbsent(userId, () => []);

  @override
  Future<Either<Failure, List<Folder>>> getFolders({
    required String userId,
    String? parentFolderId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final all = _userFolders(userId);
    final filtered = all
        .where((f) => f.parentFolderId == parentFolderId)
        .toList();
    return Right(filtered);
  }

  @override
  Future<Either<Failure, Folder>> createFolder({
    required String userId,
    required String name,
    String? parentFolderId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    final folder = Folder(
      id: 'folder-${_idCounter++}',
      name: name,
      parentFolderId: parentFolderId,
      createdAt: now,
      updatedAt: now,
    );
    _userFolders(userId).add(folder);
    return Right(folder);
  }

  @override
  Future<Either<Failure, Folder>> updateFolder({
    required String userId,
    required String folderId,
    required String name,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final list = _userFolders(userId);
    final idx = list.indexWhere((f) => f.id == folderId);
    if (idx == -1) return const Left(Failure.notFound());
    final updated = list[idx].copyWith(name: name, updatedAt: DateTime.now());
    list[idx] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, Unit>> deleteFolder({
    required String userId,
    required String folderId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final list = _userFolders(userId);
    list.removeWhere((f) => f.id == folderId || f.parentFolderId == folderId);
    return const Right(unit);
  }
}
