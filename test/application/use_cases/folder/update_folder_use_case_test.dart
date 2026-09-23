import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/folder/update_folder_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';

import '../../../helpers/fake_folder_repository.dart';

void main() {
  late FakeFolderRepository repository;
  late UpdateFolderUseCase useCase;

  setUp(() {
    repository = FakeFolderRepository();
    useCase = UpdateFolderUseCase(repository);
  });

  group('UpdateFolderUseCase.call', () {
    test('正常系の場合、Repository.updateFolderに引数がそのまま委譲される', () async {
      await useCase(userId: 'user-1', folderId: 'folder-1', name: '新しい名前');

      expect(repository.updateFolderCallCount, 1);
      expect(repository.lastUserId, 'user-1');
      expect(repository.lastFolderId, 'folder-1');
      expect(repository.lastName, '新しい名前');
    });

    test('Repositoryが成功を返した場合、更新後フォルダのRightがそのまま返る', () async {
      final folder = Folder(
        id: 'folder-1',
        name: '新しい名前',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );
      repository.updateFolderResult = Right(folder);

      final result = await useCase(
        userId: 'user-1',
        folderId: 'folder-1',
        name: '新しい名前',
      );

      expect(result, Right(folder));
    });

    test('Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る', () async {
      repository.updateFolderResult = const Left(Failure.network());

      final result = await useCase(
        userId: 'user-1',
        folderId: 'folder-1',
        name: '新しい名前',
      );

      expect(result, const Left(Failure.network()));
    });
  });
}
