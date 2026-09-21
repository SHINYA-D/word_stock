import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';

FlashcardResult _result({required int totalCount, required int correctCount}) {
  final now = DateTime(2026, 1, 1);
  return FlashcardResult(
    id: 'result-1',
    folderId: 'folder-1',
    totalCount: totalCount,
    correctCount: correctCount,
    date: now,
    updatedAt: now,
  );
}

void main() {
  group('FlashcardResult.correctRate', () {
    test('出題数が0の場合、0を返す（ゼロ除算しない）', () {
      expect(_result(totalCount: 0, correctCount: 0).correctRate, 0);
    });

    test('全問正解の場合、1.0を返す', () {
      expect(_result(totalCount: 10, correctCount: 10).correctRate, 1.0);
    });

    test('全問不正解の場合、0.0を返す', () {
      expect(_result(totalCount: 10, correctCount: 0).correctRate, 0.0);
    });

    test('一部正解の場合、正解数÷出題数を返す', () {
      expect(_result(totalCount: 4, correctCount: 1).correctRate, 0.25);
    });

    test('割り切れない場合、double として端数を保持する', () {
      expect(
        _result(totalCount: 3, correctCount: 1).correctRate,
        closeTo(0.3333333333333333, 1e-12),
      );
    });
  });
}
