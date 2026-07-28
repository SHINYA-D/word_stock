import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:word_stock/domain/entities/word.dart';

part 'flashcard_mode_state.freezed.dart';

@freezed
abstract class FlashcardModeState with _$FlashcardModeState {
  const factory FlashcardModeState({
    required bool isStarted,
    required bool isFinished,
    Word? currentWord,
    required int currentIndex,
    required int total,
    required bool isFlipped,
    required int correctCount,
    @Default(false) bool isSubmitting,
    String? errorMessage,
  }) = _FlashcardModeState;

  factory FlashcardModeState.initial() => const FlashcardModeState(
        isStarted: false,
        isFinished: false,
        currentIndex: 0,
        total: 0,
        isFlipped: false,
        correctCount: 0,
      );
}
