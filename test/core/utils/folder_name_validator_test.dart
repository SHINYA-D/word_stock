import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/utils/folder_name_validator.dart';

void main() {
  group('calculateTextWidth', () {
    test('空文字の場合、幅は0になる', () {
      expect(calculateTextWidth(''), 0);
    });

    test('半角英数字のみの場合、文字数と同じ幅になる', () {
      expect(calculateTextWidth('abcDE12345'), 10);
    });

    test('全角文字（漢字）のみの場合、文字数の2倍の幅になる', () {
      expect(calculateTextWidth('日本語漢字'), 10);
    });

    test('半角と全角が混在する場合、それぞれの幅を合算する', () {
      // 半角5 + 全角3(=6) = 11
      expect(calculateTextWidth('abcde日本語'), 11);
    });
  });

  group('isValidFolderNameWidth', () {
    test('半角20文字ちょうどの場合、trueを返す（境界値）', () {
      final text = 'a' * 20;
      expect(isValidFolderNameWidth(text), isTrue);
    });

    test('半角21文字の場合、falseを返す（境界値+1）', () {
      final text = 'a' * 21;
      expect(isValidFolderNameWidth(text), isFalse);
    });

    test('全角10文字ちょうど（幅20相当）の場合、trueを返す（境界値）', () {
      final text = '日' * 10;
      expect(isValidFolderNameWidth(text), isTrue);
    });

    test('全角11文字（幅22相当）の場合、falseを返す（境界値+1）', () {
      final text = '日' * 11;
      expect(isValidFolderNameWidth(text), isFalse);
    });
  });

  group('FolderNameLengthFormatter.formatEditUpdate', () {
    const formatter = FolderNameLengthFormatter();

    test('制限幅以内の入力の場合、newValueをそのまま返す', () {
      const oldValue = TextEditingValue(text: 'abc');
      const newValue = TextEditingValue(text: 'abcd');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result, newValue);
    });

    test('制限幅を超える入力の場合、oldValueを返して入力をブロックする', () {
      final oldValue = TextEditingValue(text: 'a' * 20);
      final newValue = TextEditingValue(text: 'a' * 21);

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result, oldValue);
    });
  });
}
