import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:word_stock/domain/entities/word.dart';

part 'test_session_state.freezed.dart';

@freezed
abstract class TestSessionState with _$TestSessionState {
  const factory TestSessionState({
    required bool isStarted,
    required bool isFinished,
    Word? currentWord,
    required int currentIndex,
    required int total,
    required bool isFlipped,
    required int correctCount,
  }) = _TestSessionState;

  factory TestSessionState.initial() => const TestSessionState(
        isStarted: false,
        isFinished: false,
        currentIndex: 0,
        total: 0,
        isFlipped: false,
        correctCount: 0,
      );
}
