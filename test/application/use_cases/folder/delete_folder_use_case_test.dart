import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/folder/delete_folder_use_case.dart';
import 'package:word_stock/core/error/failure.dart';

import '../../../helpers/fake_folder_repository.dart';

void main() {
  late FakeFolderRepository repository;
  late DeleteFolderUseCase useCase;

  setUp(() {
    repository = FakeFolderRepository();
    useCase = DeleteFolderUseCase(repository);
  });

  group('DeleteFolderUseCase.call', () {
    test('正常系の場合、Repository.deleteFolderに引数がそのまま委譲される', () async {
      await useCase(userId: 'user-1', folderId: 'folder-1');

      expect(repository.deleteFolderCallCount, 1);
      expect(repository.lastUserId, 'user-1');
      expect(repository.lastFolderId, 'folder-1');
    });

    test('Repositoryが成功を返した場合、Right(unit)がそのまま返る', () async {
      repository.deleteFolderResult = const Right(unit);

      final result = await useCase(userId: 'user-1', folderId: 'folder-1');

      expect(result, const Right(unit));
    });

    test('Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る', () async {
      repository.deleteFolderResult = const Left(Failure.notFound());

      final result = await useCase(userId: 'user-1', folderId: 'folder-1');

      expect(result, const Left(Failure.notFound()));
    });
  });
}
