import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/core/di/flashcard_result_providers.dart';
import 'package:word_stock/presentation/flashcard_mode/flashcard_mode_state.dart';

part 'flashcard_mode_view_model.g.dart';

@riverpod
class FlashcardModeViewModel extends _$FlashcardModeViewModel {
  late List<Word> _words;
  late String _userId;
  late String _folderId;

  @override
  FlashcardModeState build() => FlashcardModeState.initial();

  void start({
    required List<Word> words,
    required bool shuffle,
    required String userId,
    required String folderId,
  }) {
    _userId = userId;
    _folderId = folderId;
    _words = shuffle ? (List.of(words)..shuffle()) : List.of(words);

    if (_words.isEmpty) {
      state = const FlashcardModeState(
        isStarted: true,
        isFinished: true,
        currentIndex: 0,
        total: 0,
        isFlipped: false,
        correctCount: 0,
      );
      return;
    }

    state = FlashcardModeState(
      isStarted: true,
      isFinished: false,
      currentWord: _words[0],
      currentIndex: 0,
      total: _words.length,
      isFlipped: false,
      correctCount: 0,
    );
  }

  void flip() {
    if (!state.isStarted || state.isFinished) return;
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  Future<void> answer({required bool isCorrect}) async {
    if (!state.isStarted || state.isFinished || state.isSubmitting) return;

    final newCorrect = state.correctCount + (isCorrect ? 1 : 0);
    final nextIndex = state.currentIndex + 1;

    if (nextIndex >= _words.length) {
      state = state.copyWith(isSubmitting: true, errorMessage: null);
      final result = await ref.read(saveFlashcardResultUseCaseProvider).call(
            userId: _userId,
            folderId: _folderId,
            totalCount: _words.length,
            correctCount: newCorrect,
          );
      result.fold(
        (failure) => state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.when(
            network: () => '通信エラーが発生しました',
            auth: () => '認証エラーが発生しました',
            notFound: () => 'データが見つかりません',
            unknown: (msg) => 'エラーが発生しました: $msg',
          ),
        ),
        (_) => state = state.copyWith(
          isFinished: true,
          isSubmitting: false,
          correctCount: newCorrect,
          total: _words.length,
        ),
      );
    } else {
      state = state.copyWith(
        currentWord: _words[nextIndex],
        currentIndex: nextIndex,
        isFlipped: false,
        correctCount: newCorrect,
      );
    }
  }
}
