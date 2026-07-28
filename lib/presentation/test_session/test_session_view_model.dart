import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/core/di/test_result_providers.dart';
import 'package:word_stock/presentation/test_session/test_session_state.dart';

part 'test_session_view_model.g.dart';

@riverpod
class TestSessionViewModel extends _$TestSessionViewModel {
  late List<Word> _words;
  late String _userId;
  late String _folderId;

  @override
  TestSessionState build() => TestSessionState.initial();

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
      state = const TestSessionState(
        isStarted: true,
        isFinished: true,
        currentIndex: 0,
        total: 0,
        isFlipped: false,
        correctCount: 0,
      );
      return;
    }

    state = TestSessionState(
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
    if (!state.isStarted || state.isFinished) return;

    final newCorrect = state.correctCount + (isCorrect ? 1 : 0);
    final nextIndex = state.currentIndex + 1;

    if (nextIndex >= _words.length) {
      await ref.read(saveTestResultUseCaseProvider).call(
            userId: _userId,
            folderId: _folderId,
            totalCount: _words.length,
            correctCount: newCorrect,
          );
      state = state.copyWith(
        isFinished: true,
        correctCount: newCorrect,
        total: _words.length,
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
