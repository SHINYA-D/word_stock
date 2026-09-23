import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/word/create_word_use_case.dart';
import 'package:word_stock/application/use_cases/word/delete_word_use_case.dart';
import 'package:word_stock/application/use_cases/word/get_words_use_case.dart';
import 'package:word_stock/application/use_cases/word/update_word_use_case.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/word_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

import '../../helpers/test_helpers.dart';

const _folderId = 'folder-1';

/// GetWordsUseCase の手書き Fake。
/// `call()` が呼ばれるたびに `results` を先頭から1つ消費して返す。
class FakeGetWordsUseCase implements GetWordsUseCase {
  FakeGetWordsUseCase(this.results);

  final List<Either<Failure, List<Word>>> results;
  int callCount = 0;

  @override
  Future<Either<Failure, List<Word>>> call({
    required String userId,
    required String folderId,
  }) async {
    final result = results[callCount < results.length ? callCount : results.length - 1];
    callCount++;
    return result;
  }
}

/// CreateWordUseCase の手書き Fake。
class FakeCreateWordUseCase implements CreateWordUseCase {
  FakeCreateWordUseCase(this.result);

  final Either<Failure, Word> result;

  @override
  Future<Either<Failure, Word>> call({
    required String userId,
    required String folderId,
    required String front,
    required String back,
  }) async {
    return result;
  }
}

/// UpdateWordUseCase の手書き Fake。
class FakeUpdateWordUseCase implements UpdateWordUseCase {
  FakeUpdateWordUseCase(this.result);

  final Either<Failure, Word> result;

  @override
  Future<Either<Failure, Word>> call({
    required String userId,
    required String folderId,
    required String wordId,
    required String front,
    required String back,
  }) async {
    return result;
  }
}

/// DeleteWordUseCase の手書き Fake。
class FakeDeleteWordUseCase implements DeleteWordUseCase {
  FakeDeleteWordUseCase(this.result);

  final Either<Failure, Unit> result;

  @override
  Future<Either<Failure, Unit>> call({
    required String userId,
    required String folderId,
    required String wordId,
  }) async {
    return result;
  }
}

ProviderContainer _makeContainer({
  required GetWordsUseCase getWordsUseCase,
  CreateWordUseCase? createWordUseCase,
  UpdateWordUseCase? updateWordUseCase,
  DeleteWordUseCase? deleteWordUseCase,
}) {
  final container = ProviderContainer(overrides: [
    getWordsUseCaseProvider.overrideWithValue(getWordsUseCase),
    if (createWordUseCase != null)
      createWordUseCaseProvider.overrideWithValue(createWordUseCase),
    if (updateWordUseCase != null)
      updateWordUseCaseProvider.overrideWithValue(updateWordUseCase),
    if (deleteWordUseCase != null)
      deleteWordUseCaseProvider.overrideWithValue(deleteWordUseCase),
    currentUserProvider.overrideWithValue(testUser),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('WordListViewModel.build', () {
    test('取得に成功した場合、単語一覧が state に反映される', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
      );

      final result =
          await container.read(wordListViewModelProvider(_folderId).future);

      expect(result, testWords);
      expect(
        container.read(wordListViewModelProvider(_folderId)).value,
        testWords,
      );
    });

    test('取得結果が空リストの場合、空の state になる', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([const Right([])]),
      );

      final result =
          await container.read(wordListViewModelProvider(_folderId).future);

      expect(result, isEmpty);
    });

    test('取得に失敗した場合、AsyncError になる', () async {
      final container = _makeContainer(
        getWordsUseCase:
            FakeGetWordsUseCase([const Left(Failure.network())]),
      );

      await expectLater(
        container.read(wordListViewModelProvider(_folderId).future),
        throwsA(const Failure.network()),
      );

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.network());
    });
  });

  group('WordListViewModel.refresh', () {
    test('再取得に成功した場合、最新の単語一覧に更新される', () async {
      final updatedWords = [testWords.first];
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([
          Right(testWords),
          Right(updatedWords),
        ]),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      final refreshFuture = notifier.refresh();

      // refresh() 内で state が即座に AsyncLoading になる
      expect(
        container.read(wordListViewModelProvider(_folderId)).isLoading,
        isTrue,
      );

      await refreshFuture;

      expect(
        container.read(wordListViewModelProvider(_folderId)).value,
        updatedWords,
      );
    });

    test('再取得に失敗した場合、AsyncError に遷移する', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([
          Right(testWords),
          const Left(Failure.unknown('boom')),
        ]),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.refresh();

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.unknown('boom'));
    });
  });

  group('WordListViewModel.createWord', () {
    test('作成に成功した場合、新しい単語が現在のリストの末尾に追加される', () async {
      final newWord = Word(
        id: 'word-new',
        front: 'grape',
        back: 'ぶどう',
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
      );
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        createWordUseCase: FakeCreateWordUseCase(Right(newWord)),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.createWord(front: 'grape', back: 'ぶどう');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.value, [...testWords, newWord]);
    });

    test('現在のリストが空の場合に作成すると、作成した単語のみのリストになる', () async {
      final newWord = Word(
        id: 'word-new',
        front: 'grape',
        back: 'ぶどう',
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
      );
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([const Right([])]),
        createWordUseCase: FakeCreateWordUseCase(Right(newWord)),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.createWord(front: 'grape', back: 'ぶどう');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.value, [newWord]);
    });

    test('作成に失敗した場合、AsyncError になり既存のリストは失われる', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        createWordUseCase:
            FakeCreateWordUseCase(const Left(Failure.network())),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.createWord(front: 'grape', back: 'ぶどう');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.network());
    });
  });

  group('WordListViewModel.updateWord', () {
    test('更新に成功した場合、該当する id の単語が置き換わる', () async {
      final updated = Word(
        id: 'word-1',
        front: 'apple-updated',
        back: 'りんご(更新)',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        updateWordUseCase: FakeUpdateWordUseCase(Right(updated)),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.updateWord(
        wordId: 'word-1',
        front: 'apple-updated',
        back: 'りんご(更新)',
      );

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.value, [updated, testWords[1], testWords[2]]);
    });

    test('存在しない wordId を指定した場合、リストは変化せず更新結果は反映されない', () async {
      final updated = Word(
        id: 'not-exist',
        front: 'x',
        back: 'y',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        updateWordUseCase: FakeUpdateWordUseCase(Right(updated)),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.updateWord(wordId: 'not-exist', front: 'x', back: 'y');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.value, testWords);
    });

    test('更新に失敗した場合、AsyncError になる', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        updateWordUseCase:
            FakeUpdateWordUseCase(const Left(Failure.auth())),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.updateWord(wordId: 'word-1', front: 'a', back: 'b');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.auth());
    });
  });

  group('WordListViewModel.deleteWord', () {
    test('削除に成功した場合、該当する id の単語がリストから除外される', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        deleteWordUseCase: FakeDeleteWordUseCase(const Right(unit)),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.deleteWord(wordId: 'word-2');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.value, [testWords[0], testWords[2]]);
    });

    test('残り1件を削除した場合、空リストになる', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([
          Right([testWords.first]),
        ]),
        deleteWordUseCase: FakeDeleteWordUseCase(const Right(unit)),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.deleteWord(wordId: testWords.first.id);

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.value, isEmpty);
    });

    test('存在しない wordId を指定した場合、リストは変化しない', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        deleteWordUseCase: FakeDeleteWordUseCase(const Right(unit)),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.deleteWord(wordId: 'not-exist');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.value, testWords);
    });

    test('削除に失敗した場合、AsyncError になる', () async {
      final container = _makeContainer(
        getWordsUseCase: FakeGetWordsUseCase([Right(testWords)]),
        deleteWordUseCase:
            FakeDeleteWordUseCase(const Left(Failure.notFound())),
      );
      await container.read(wordListViewModelProvider(_folderId).future);

      final notifier =
          container.read(wordListViewModelProvider(_folderId).notifier);
      await notifier.deleteWord(wordId: 'word-1');

      final state = container.read(wordListViewModelProvider(_folderId));
      expect(state.hasError, isTrue);
      expect(state.error, const Failure.notFound());
    });
  });
}
