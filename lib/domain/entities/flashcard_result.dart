import 'package:freezed_annotation/freezed_annotation.dart';

part 'flashcard_result.freezed.dart';

@freezed
abstract class FlashcardResult with _$FlashcardResult {
  const factory FlashcardResult({
    required String id,
    required String folderId,
    required int totalCount,
    required int correctCount,
    required DateTime date,
    required DateTime updatedAt,
  }) = _FlashcardResult;

  const FlashcardResult._();

  double get correctRate =>
      totalCount == 0 ? 0 : correctCount / totalCount;
}
