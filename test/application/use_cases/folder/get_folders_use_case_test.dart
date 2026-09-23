import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/folder/get_folders_use_case.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/folder.dart';

import '../../../helpers/fake_folder_repository.dart';

void main() {
  late FakeFolderRepository repository;
  late GetFoldersUseCase useCase;

  setUp(() {
    repository = FakeFolderRepository();
    useCase = GetFoldersUseCase(repository);
  });

  group('GetFoldersUseCase.call', () {
    test('正常系の場合、Repository.getFoldersに引数がそのまま委譲される', () async {
      await useCase(userId: 'user-1');

      expect(repository.getFoldersCallCount, 1);
      expect(repository.lastUserId, 'user-1');
    });

    test('Repositoryが成功を返した場合、フォルダ一覧のRightがそのまま返る', () async {
      final folders = [
        Folder(
          id: 'folder-1',
          name: 'フォルダA',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      repository.getFoldersResult = Right(folders);

      final result = await useCase(userId: 'user-1');

      expect(result, Right(folders));
    });

    test('Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る', () async {
      repository.getFoldersResult = const Left(Failure.unknown('error'));

      final result = await useCase(userId: 'user-1');

      expect(result, const Left(Failure.unknown('error')));
    });
  });
}
