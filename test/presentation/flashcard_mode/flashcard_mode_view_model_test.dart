import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/flashcard_result/save_flashcard_result_use_case.dart';
import 'package:word_stock/core/di/flashcard_result_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/presentation/flashcard_mode/flashcard_mode_view_model.dart';

import '../../helpers/test_helpers.dart';

const _userId = 'user-1';
const _folderId = 'folder-1';

/// SaveFlashcardResultUseCase の手書き Fake。
/// `completer` を渡すと `call()` の完了を任意のタイミングまで遅延させられる
/// （isSubmitting の途中経過を検証するため）。
class FakeSaveFlashcardResultUseCase implements SaveFlashcardResultUseCase {
  FakeSaveFlashcardResultUseCase(this.result, {this.completer});

  final Either<Failure, FlashcardResult> result;
  final Completer<void>? completer;
  int callCount = 0;
  final List<({String userId, String folderId, int totalCount, int correctCount})>
      calls = [];

  @override
  Future<Either<Failure, FlashcardResult>> call({
    required String userId,
    required String folderId,
    required int totalCount,
    required int correctCount,
  }) async {
    callCount++;
    calls.add((
      userId: userId,
      folderId: folderId,
      totalCount: totalCount,
      correctCount: correctCount,
    ));
    if (completer != null) {
      await completer!.future;
    }
    return result;
  }
}

FlashcardResult _makeResult({int totalCount = 3, int correctCount = 3}) {
  return FlashcardResult(
    id: 'result-1',
    folderId: _folderId,
    totalCount: totalCount,
    correctCount: correctCount,
    date: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

ProviderContainer _makeContainer({
  required SaveFlashcardResultUseCase saveFlashcardResultUseCase,
}) {
  final container = ProviderContainer(overrides: [
    saveFlashcardResultUseCaseProvider.overrideWithValue(
      saveFlashcardResultUseCase,
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('FlashcardModeViewModel.build', () {
    test('初期状態では未開始・未終了・0件の state になる', () {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );

      final state = container.read(flashcardModeViewModelProvider);

      expect(state.isStarted, isFalse);
      expect(state.isFinished, isFalse);
      expect(state.currentWord, isNull);
      expect(state.currentIndex, 0);
      expect(state.total, 0);
      expect(state.isFlipped, isFalse);
      expect(state.correctCount, 0);
    });
  });

  group('FlashcardModeViewModel.start', () {
    test('単語が1件以上ある場合、先頭の単語で開始状態になる', () {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);

      notifier.start(
        words: testWords,
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      final state = container.read(flashcardModeViewModelProvider);
      expect(state.isStarted, isTrue);
      expect(state.isFinished, isFalse);
      expect(state.currentWord, testWords[0]);
      expect(state.currentIndex, 0);
      expect(state.total, testWords.length);
      expect(state.isFlipped, isFalse);
      expect(state.correctCount, 0);
    });

    test('単語が0件の場合、開始と同時に終了状態になる', () {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);

      notifier.start(
        words: const [],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      final state = container.read(flashcardModeViewModelProvider);
      expect(state.isStarted, isTrue);
      expect(state.isFinished, isTrue);
      expect(state.currentWord, isNull);
      expect(state.currentIndex, 0);
      expect(state.total, 0);
      expect(state.correctCount, 0);
    });

    test('shuffle: true の場合、全単語が含まれたまま出題順が構成される', () {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);

      notifier.start(
        words: testWords,
        shuffle: true,
        userId: _userId,
        folderId: _folderId,
      );

      final state = container.read(flashcardModeViewModelProvider);
      expect(state.total, testWords.length);
      expect(testWords, contains(state.currentWord));
    });
  });

  group('FlashcardModeViewModel.flip', () {
    test('開始済みかつ未終了の場合、isFlipped が反転する', () {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: testWords,
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      notifier.flip();
      expect(container.read(flashcardModeViewModelProvider).isFlipped, isTrue);

      notifier.flip();
      expect(
        container.read(flashcardModeViewModelProvider).isFlipped,
        isFalse,
      );
    });

    test('開始前に呼び出した場合、state は変化しない', () {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      final before = container.read(flashcardModeViewModelProvider);

      notifier.flip();

      expect(container.read(flashcardModeViewModelProvider), before);
    });

    test('終了済みの場合、isFlipped は変化しない', () {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: const [],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      notifier.flip();

      expect(
        container.read(flashcardModeViewModelProvider).isFlipped,
        isFalse,
      );
    });
  });

  group('FlashcardModeViewModel.answer', () {
    test('最終カードでない場合、正誤カウントが加算され次の単語へ進みめくり状態がリセットされる', () async {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: testWords,
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );
      notifier.flip();

      await notifier.answer(isCorrect: true);

      final state = container.read(flashcardModeViewModelProvider);
      expect(state.currentWord, testWords[1]);
      expect(state.currentIndex, 1);
      expect(state.correctCount, 1);
      expect(state.isFlipped, isFalse);
      expect(state.isFinished, isFalse);
    });

    test('不正解の場合、correctCount は加算されず次の単語へ進む', () async {
      final container = _makeContainer(
        saveFlashcardResultUseCase: FakeSaveFlashcardResultUseCase(
          Right(_makeResult()),
        ),
      );
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: testWords,
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      await notifier.answer(isCorrect: false);

      final state = container.read(flashcardModeViewModelProvider);
      expect(state.correctCount, 0);
      expect(state.currentIndex, 1);
    });

    test('最終カードで保存に成功した場合、終了状態になり合計正解数が反映される', () async {
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        Right(_makeResult(totalCount: 1, correctCount: 1)),
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: [testWords[0]],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      await notifier.answer(isCorrect: true);

      final state = container.read(flashcardModeViewModelProvider);
      expect(state.isFinished, isTrue);
      expect(state.isSubmitting, isFalse);
      expect(state.correctCount, 1);
      expect(state.total, 1);
      expect(fakeUseCase.callCount, 1);
      expect(fakeUseCase.calls.single.userId, _userId);
      expect(fakeUseCase.calls.single.folderId, _folderId);
      expect(fakeUseCase.calls.single.totalCount, 1);
      expect(fakeUseCase.calls.single.correctCount, 1);
    });

    test('保存の完了を待つ間、isSubmitting が true になる', () async {
      final completer = Completer<void>();
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        Right(_makeResult(totalCount: 1, correctCount: 1)),
        completer: completer,
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: [testWords[0]],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      final future = notifier.answer(isCorrect: true);
      // answer() は async 関数のため、Completer 待ちの await に到達するまでの
      // isSubmitting への代入は呼び出しと同一の同期区間で実行される。
      // ここで Future.delayed 等のマクロタスクを挟むと、リスナーを持たない
      // AutoDispose プロバイダが破棄され再生成されてしまい、
      // 初期状態（isSubmitting=false）に見えてしまうため挟まない。
      expect(container.read(flashcardModeViewModelProvider).isSubmitting, isTrue);

      completer.complete();
      await future;

      expect(
        container.read(flashcardModeViewModelProvider).isSubmitting,
        isFalse,
      );
    });

    test('保存が isSubmitting 中にもう一度呼ばれた場合、二重送信されない', () async {
      final completer = Completer<void>();
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        Right(_makeResult(totalCount: 1, correctCount: 1)),
        completer: completer,
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: [testWords[0]],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      final future = notifier.answer(isCorrect: true);
      expect(container.read(flashcardModeViewModelProvider).isSubmitting, isTrue);

      // isSubmitting 中の追加呼び出しはガードされ、UseCase は呼ばれない
      await notifier.answer(isCorrect: true);
      expect(fakeUseCase.callCount, 1);

      completer.complete();
      await future;
    });

    test('保存に失敗した場合（ネットワーク）、errorMessage が設定され終了状態にならない', () async {
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        const Left(Failure.network()),
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: [testWords[0]],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      await notifier.answer(isCorrect: true);

      final state = container.read(flashcardModeViewModelProvider);
      expect(state.isFinished, isFalse);
      expect(state.isSubmitting, isFalse);
      expect(state.errorMessage, '通信エラーが発生しました');
    });

    test('保存に失敗した場合（認証）、認証エラーメッセージが設定される', () async {
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        const Left(Failure.auth()),
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: [testWords[0]],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      await notifier.answer(isCorrect: true);

      expect(
        container.read(flashcardModeViewModelProvider).errorMessage,
        '認証エラーが発生しました',
      );
    });

    test('保存に失敗した場合（データ未検出）、未検出エラーメッセージが設定される', () async {
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        const Left(Failure.notFound()),
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: [testWords[0]],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      await notifier.answer(isCorrect: true);

      expect(
        container.read(flashcardModeViewModelProvider).errorMessage,
        'データが見つかりません',
      );
    });

    test('保存に失敗した場合（不明なエラー）、詳細メッセージ付きのエラーが設定される', () async {
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        const Left(Failure.unknown('boom')),
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: [testWords[0]],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );

      await notifier.answer(isCorrect: true);

      expect(
        container.read(flashcardModeViewModelProvider).errorMessage,
        'エラーが発生しました: boom',
      );
    });

    test('開始前に呼び出した場合、UseCase は呼ばれず state は変化しない', () async {
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        Right(_makeResult()),
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      final before = container.read(flashcardModeViewModelProvider);

      await notifier.answer(isCorrect: true);

      expect(fakeUseCase.callCount, 0);
      expect(container.read(flashcardModeViewModelProvider), before);
    });

    test('終了済みの場合、UseCase は呼ばれず state は変化しない', () async {
      final fakeUseCase = FakeSaveFlashcardResultUseCase(
        Right(_makeResult()),
      );
      final container = _makeContainer(saveFlashcardResultUseCase: fakeUseCase);
      final notifier = container.read(flashcardModeViewModelProvider.notifier);
      notifier.start(
        words: const [],
        shuffle: false,
        userId: _userId,
        folderId: _folderId,
      );
      final before = container.read(flashcardModeViewModelProvider);

      await notifier.answer(isCorrect: true);

      expect(fakeUseCase.callCount, 0);
      expect(container.read(flashcardModeViewModelProvider), before);
    });
  });
}
