import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/folder/create_folder_use_case.dart';
import 'package:word_stock/application/use_cases/folder/delete_folder_use_case.dart';
import 'package:word_stock/application/use_cases/folder/get_folders_use_case.dart';
import 'package:word_stock/application/use_cases/folder/update_folder_use_case.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/folder_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/presentation/home/home_view_model.dart';

import '../../helpers/test_helpers.dart';

/// GetFoldersUseCase の手書き Fake。
/// `call()` が呼ばれるたびに `results` を先頭から1つ消費して返す。
class FakeGetFoldersUseCase implements GetFoldersUseCase {
  FakeGetFoldersUseCase(this.results);

  final List<Either<Failure, List<Folder>>> results;
  int callCount = 0;
  String? lastUserId;

  @override
  Future<Either<Failure, List<Folder>>> call({required String userId}) async {
    lastUserId = userId;
    final result =
        results[callCount < results.length ? callCount : results.length - 1];
    callCount++;
    return result;
  }
}

/// CreateFolderUseCase の手書き Fake。
class FakeCreateFolderUseCase implements CreateFolderUseCase {
  FakeCreateFolderUseCase(this.result);

  final Either<Failure, Folder> result;
  String? lastUserId;
  String? lastName;
  String? lastParentFolderId;

  @override
  Future<Either<Failure, Folder>> call({
    required String userId,
    required String name,
    String? parentFolderId,
  }) async {
    lastUserId = userId;
    lastName = name;
    lastParentFolderId = parentFolderId;
    return result;
  }
}

/// UpdateFolderUseCase の手書き Fake。
class FakeUpdateFolderUseCase implements UpdateFolderUseCase {
  FakeUpdateFolderUseCase(this.result);

  final Either<Failure, Folder> result;

  @override
  Future<Either<Failure, Folder>> call({
    required String userId,
    required String folderId,
    required String name,
  }) async {
    return result;
  }
}

/// DeleteFolderUseCase の手書き Fake。
class FakeDeleteFolderUseCase implements DeleteFolderUseCase {
  FakeDeleteFolderUseCase(this.result);

  final Either<Failure, Unit> result;

  @override
  Future<Either<Failure, Unit>> call({
    required String userId,
    required String folderId,
  }) async {
    return result;
  }
}

ProviderContainer _makeContainer({
  required GetFoldersUseCase getFoldersUseCase,
  CreateFolderUseCase? createFolderUseCase,
  UpdateFolderUseCase? updateFolderUseCase,
  DeleteFolderUseCase? deleteFolderUseCase,
  AppUser? currentUser = testUser,
}) {
  final container = ProviderContainer(overrides: [
    getFoldersUseCaseProvider.overrideWithValue(getFoldersUseCase),
    if (createFolderUseCase != null)
      createFolderUseCaseProvider.overrideWithValue(createFolderUseCase),
    if (updateFolderUseCase != null)
      updateFolderUseCaseProvider.overrideWithValue(updateFolderUseCase),
    if (deleteFolderUseCase != null)
      deleteFolderUseCaseProvider.overrideWithValue(deleteFolderUseCase),
    currentUserProvider.overrideWithValue(currentUser),
  ]);
  addTearDown(container.dispose);
  // build() は Future.microtask で初期ロードを行うだけの同期 Notifier のため、
  // autoDispose によって初期ロード完了前に破棄されないようリスナーを張り続ける。
  container.listen(homeViewModelProvider, (_, __) {});
  return container;
}

/// `HomeState.folders` が読み込み中でなくなるまでマイクロタスクを消費して待つ。
/// build() 内の `Future.microtask(() => _initState())` および
/// refresh() 内の非同期処理はいずれもマイクロタスクのみで完結するため、
/// 実イベントループを跨がずにここで完了を待つことができる。
Future<void> _waitUntilNotLoading(ProviderContainer container) async {
  while (container.read(homeViewModelProvider).folders.isLoading) {
    await Future<void>.microtask(() {});
  }
}

void main() {
  group('HomeViewModel.build', () {
    test('取得に成功した場合、フォルダ一覧が state.folders に反映される', () async {
      final getFoldersUseCase = FakeGetFoldersUseCase([Right(testFolders)]);
      final container = _makeContainer(getFoldersUseCase: getFoldersUseCase);

      // build() の同期戻り値は常に loading
      expect(container.read(homeViewModelProvider).folders.isLoading, isTrue);

      await _waitUntilNotLoading(container);

      final state = container.read(homeViewModelProvider);
      expect(state.folders.value, testFolders);
      expect(getFoldersUseCase.lastUserId, testUser.id);
    });

    test('取得結果が空リストの場合、空の folders になる', () async {
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([const Right([])]),
      );

      await _waitUntilNotLoading(container);

      expect(container.read(homeViewModelProvider).folders.value, isEmpty);
    });

    test('取得に失敗した場合、folders が AsyncError になる', () async {
      final container = _makeContainer(
        getFoldersUseCase:
            FakeGetFoldersUseCase([const Left(Failure.network())]),
      );

      await _waitUntilNotLoading(container);

      final state = container.read(homeViewModelProvider);
      expect(state.folders.hasError, isTrue);
      expect(state.folders.error, const Failure.network());
    });

    test('currentUser が null の場合、userId は空文字列として使用される', () async {
      final getFoldersUseCase = FakeGetFoldersUseCase([Right(testFolders)]);
      final container = _makeContainer(
        getFoldersUseCase: getFoldersUseCase,
        currentUser: null,
      );

      await _waitUntilNotLoading(container);

      expect(getFoldersUseCase.lastUserId, '');
    });
  });

  group('HomeViewModel.refresh', () {
    test('再取得に成功した場合、最新のフォルダ一覧に更新される', () async {
      final updatedFolders = [testFolders.first];
      final getFoldersUseCase = FakeGetFoldersUseCase([
        Right(testFolders),
        Right(updatedFolders),
      ]);
      final container = _makeContainer(getFoldersUseCase: getFoldersUseCase);
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      final refreshFuture = notifier.refresh();

      // refresh() 内で state.folders が即座に AsyncLoading になる
      expect(container.read(homeViewModelProvider).folders.isLoading, isTrue);

      await refreshFuture;

      expect(
        container.read(homeViewModelProvider).folders.value,
        updatedFolders,
      );
    });

    test('再取得に失敗した場合、folders が AsyncError に遷移する', () async {
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([
          Right(testFolders),
          const Left(Failure.unknown('boom')),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(homeViewModelProvider);
      expect(state.folders.hasError, isTrue);
      expect(state.folders.error, const Failure.unknown('boom'));
    });
  });

  group('HomeViewModel.createFolder', () {
    test('作成に成功した場合、新しいフォルダが現在のリストの末尾に追加される', () async {
      final newFolder = Folder(
        id: 'folder-new',
        name: '新フォルダ',
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
      );
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([Right(testFolders)]),
        createFolderUseCase: FakeCreateFolderUseCase(Right(newFolder)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.createFolder(name: '新フォルダ');

      final state = container.read(homeViewModelProvider);
      expect(state.folders.value, [...testFolders, newFolder]);
    });

    test('現在のリストが空の場合に作成すると、作成したフォルダのみのリストになる', () async {
      final newFolder = Folder(
        id: 'folder-new',
        name: '新フォルダ',
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
      );
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([const Right([])]),
        createFolderUseCase: FakeCreateFolderUseCase(Right(newFolder)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.createFolder(name: '新フォルダ');

      final state = container.read(homeViewModelProvider);
      expect(state.folders.value, [newFolder]);
    });

    test('作成に失敗した場合、folders が AsyncError になり既存のリストは失われる', () async {
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([Right(testFolders)]),
        createFolderUseCase:
            FakeCreateFolderUseCase(const Left(Failure.network())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.createFolder(name: '新フォルダ');

      final state = container.read(homeViewModelProvider);
      expect(state.folders.hasError, isTrue);
      expect(state.folders.error, const Failure.network());
    });
  });

  group('HomeViewModel.updateFolder', () {
    test('更新に成功した場合、該当する id のフォルダが置き換わる', () async {
      final updated = Folder(
        id: 'folder-1',
        name: '英単語(更新)',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([Right(testFolders)]),
        updateFolderUseCase: FakeUpdateFolderUseCase(Right(updated)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.updateFolder(folderId: 'folder-1', name: '英単語(更新)');

      final state = container.read(homeViewModelProvider);
      expect(state.folders.value, [updated, testFolders[1]]);
    });

    test('存在しない folderId を指定した場合、リストは変化しない', () async {
      final updated = Folder(
        id: 'not-exist',
        name: 'x',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([Right(testFolders)]),
        updateFolderUseCase: FakeUpdateFolderUseCase(Right(updated)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.updateFolder(folderId: 'not-exist', name: 'x');

      final state = container.read(homeViewModelProvider);
      expect(state.folders.value, testFolders);
    });

    test('更新に失敗した場合、folders が AsyncError になる', () async {
      final container = _makeContainer(
        getFoldersUseCase: FakeGetFoldersUseCase([Right(testFolders)]),
        updateFolderUseCase:
            FakeUpdateFolderUseCase(const Left(Failure.auth())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.updateFolder(folderId: 'folder-1', name: 'x');

      final state = container.read(homeViewModelProvider);
      expect(state.folders.hasError, isTrue);
      expect(state.folders.error, const Failure.auth());
    });
  });

  group('HomeViewModel.deleteFolder', () {
    test('削除に成功した場合、refresh() が呼ばれ最新のフォルダ一覧に更新される', () async {
      final updatedFolders = [testFolders.first];
      final getFoldersUseCase = FakeGetFoldersUseCase([
        Right(testFolders),
        Right(updatedFolders),
      ]);
      final container = _makeContainer(
        getFoldersUseCase: getFoldersUseCase,
        deleteFolderUseCase: FakeDeleteFolderUseCase(const Right(unit)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.deleteFolder(folderId: 'folder-2');
      await _waitUntilNotLoading(container);

      expect(
        container.read(homeViewModelProvider).folders.value,
        updatedFolders,
      );
      expect(getFoldersUseCase.callCount, 2);
    });

    test('削除に失敗した場合、folders が AsyncError になり refresh は呼ばれない', () async {
      final getFoldersUseCase = FakeGetFoldersUseCase([Right(testFolders)]);
      final container = _makeContainer(
        getFoldersUseCase: getFoldersUseCase,
        deleteFolderUseCase:
            FakeDeleteFolderUseCase(const Left(Failure.notFound())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.deleteFolder(folderId: 'folder-1');

      final state = container.read(homeViewModelProvider);
      expect(state.folders.hasError, isTrue);
      expect(state.folders.error, const Failure.notFound());
      expect(getFoldersUseCase.callCount, 1);
    });
  });
}
