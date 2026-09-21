import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/flashcard_result/get_flashcard_results_use_case.dart';
import 'package:word_stock/application/use_cases/folder/get_folders_use_case.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/flashcard_result_providers.dart';
import 'package:word_stock/core/di/folder_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/presentation/result/result_view_model.dart';

import '../../helpers/test_helpers.dart';

/// GetFlashcardResultsUseCase の手書き Fake。
/// `call()` が呼ばれるたびに `results` を先頭から1つ消費して返す
/// （最後の要素に達したらそれを返し続ける）。
class FakeGetFlashcardResultsUseCase implements GetFlashcardResultsUseCase {
  FakeGetFlashcardResultsUseCase(this.results);

  final List<Either<Failure, List<FlashcardResult>>> results;
  int callCount = 0;

  @override
  Future<Either<Failure, List<FlashcardResult>>> call({
    required String userId,
  }) async {
    final result =
        results[callCount < results.length ? callCount : results.length - 1];
    callCount++;
    return result;
  }
}

/// GetFoldersUseCase の手書き Fake。
class FakeGetFoldersUseCase implements GetFoldersUseCase {
  FakeGetFoldersUseCase(this.result);

  final Either<Failure, List<Folder>> result;

  @override
  Future<Either<Failure, List<Folder>>> call({required String userId}) async {
    return result;
  }
}

final testResults = [
  FlashcardResult(
    id: 'result-1',
    folderId: 'folder-1',
    totalCount: 10,
    correctCount: 8,
    date: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  ),
  FlashcardResult(
    id: 'result-2',
    folderId: 'folder-2',
    totalCount: 5,
    correctCount: 5,
    date: DateTime(2024, 1, 2),
    updatedAt: DateTime(2024, 1, 2),
  ),
];

ProviderContainer _makeContainer({
  required GetFlashcardResultsUseCase getFlashcardResultsUseCase,
  GetFoldersUseCase? getFoldersUseCase,
}) {
  final container = ProviderContainer(overrides: [
    getFlashcardResultsUseCaseProvider
        .overrideWithValue(getFlashcardResultsUseCase),
    if (getFoldersUseCase != null)
      getFoldersUseCaseProvider.overrideWithValue(getFoldersUseCase),
    currentUserProvider.overrideWithValue(testUser),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ResultViewModel.build', () {
    test('取得に成功した場合、成績一覧が state に反映される', () async {
      final container = _makeContainer(
        getFlashcardResultsUseCase:
            FakeGetFlashcardResultsUseCase([Right(testResults)]),
      );

      final result = await container.read(resultViewModelProvider.future);

      expect(result, testResults);
      expect(container.read(resultViewModelProvider).value, testResults);
    });

    test('取得結果が空リストの場合、空の state になる', () async {
      final container = _makeContainer(
        getFlashcardResultsUseCase:
            FakeGetFlashcardResultsUseCase([const Right([])]),
      );

      final result = await container.read(resultViewModelProvider.future);

      expect(result, isEmpty);
    });

    test('取得に失敗した場合、AsyncError になる', () async {
      final container = _makeContainer(
        getFlashcardResultsUseCase:
            FakeGetFlashcardResultsUseCase([const Left(Failure.network())]),
      );

      await expectLater(
        container.read(resultViewModelProvider.future),
        throwsA(const Failure.network()),
      );

      final state = container.read(resultViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.network());
    });
  });

  group('ResultViewModel.refresh', () {
    test('再取得に成功した場合、最新の成績一覧に更新される', () async {
      final updatedResults = [testResults.first];
      final container = _makeContainer(
        getFlashcardResultsUseCase: FakeGetFlashcardResultsUseCase([
          Right(testResults),
          Right(updatedResults),
        ]),
      );
      await container.read(resultViewModelProvider.future);

      final notifier = container.read(resultViewModelProvider.notifier);
      final refreshFuture = notifier.refresh();

      // refresh() 内で state が即座に AsyncLoading になる
      expect(
        container.read(resultViewModelProvider).isLoading,
        isTrue,
      );

      await refreshFuture;

      expect(
        container.read(resultViewModelProvider).value,
        updatedResults,
      );
    });

    test('folderId を指定して再取得しても、UseCase には userId のみが渡される', () async {
      final container = _makeContainer(
        getFlashcardResultsUseCase: FakeGetFlashcardResultsUseCase([
          Right(testResults),
          Right(testResults),
        ]),
      );
      await container.read(resultViewModelProvider.future);

      final notifier = container.read(resultViewModelProvider.notifier);
      await notifier.refresh(folderId: 'folder-1');

      final state = container.read(resultViewModelProvider);
      expect(state.value, testResults);
    });

    test('再取得に失敗した場合、AsyncError に遷移する', () async {
      final container = _makeContainer(
        getFlashcardResultsUseCase: FakeGetFlashcardResultsUseCase([
          Right(testResults),
          const Left(Failure.unknown('boom')),
        ]),
      );
      await container.read(resultViewModelProvider.future);

      final notifier = container.read(resultViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(resultViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.unknown('boom'));
    });
  });

  group('folderNamesProvider', () {
    test('取得に成功した場合、id をキーに name を値とする Map になる', () async {
      final container = ProviderContainer(overrides: [
        getFoldersUseCaseProvider
            .overrideWithValue(FakeGetFoldersUseCase(Right(testFolders))),
        currentUserProvider.overrideWithValue(testUser),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(folderNamesProvider.future);

      expect(result, {
        'folder-1': '英単語',
        'folder-2': 'TOEIC 頻出',
      });
    });

    test('フォルダが0件の場合、空の Map になる', () async {
      final container = ProviderContainer(overrides: [
        getFoldersUseCaseProvider
            .overrideWithValue(FakeGetFoldersUseCase(const Right([]))),
        currentUserProvider.overrideWithValue(testUser),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(folderNamesProvider.future);

      expect(result, isEmpty);
    });

    test('取得に失敗した場合、例外を投げず空の Map になる', () async {
      final container = ProviderContainer(overrides: [
        getFoldersUseCaseProvider.overrideWithValue(
          FakeGetFoldersUseCase(const Left(Failure.network())),
        ),
        currentUserProvider.overrideWithValue(testUser),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(folderNamesProvider.future);

      expect(result, isEmpty);
      expect(container.read(folderNamesProvider).hasError, isFalse);
    });
  });
}
