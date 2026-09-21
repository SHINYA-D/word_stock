import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/folder/create_folder_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';

import '../../../helpers/fake_folder_repository.dart';

void main() {
  late FakeFolderRepository repository;
  late CreateFolderUseCase useCase;

  setUp(() {
    repository = FakeFolderRepository();
    useCase = CreateFolderUseCase(repository);
  });

  group('CreateFolderUseCase.call', () {
    test('正常系の場合、Repository.createFolderに引数がそのまま委譲される', () async {
      await useCase(
        userId: 'user-1',
        name: 'フォルダA',
        parentFolderId: 'parent-1',
      );

      expect(repository.createFolderCallCount, 1);
      expect(repository.lastUserId, 'user-1');
      expect(repository.lastName, 'フォルダA');
      expect(repository.lastParentFolderId, 'parent-1');
    });

    test('Repositoryが成功を返した場合、戻り値のRightがそのまま返る', () async {
      final folder = Folder(
        id: 'folder-1',
        name: 'フォルダA',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      repository.createFolderResult = Right(folder);

      final result = await useCase(userId: 'user-1', name: 'フォルダA');

      expect(result, Right(folder));
    });

    test('Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る', () async {
      repository.createFolderResult = const Left(Failure.network());

      final result = await useCase(userId: 'user-1', name: 'フォルダA');

      expect(result, const Left(Failure.network()));
    });
  });
}
