import 'package:flutter/services.dart';

/// フォルダ名の最大幅（半角換算）。半角20文字 or 全角10文字相当。
const int maxFolderNameWidth = 20;

/// 半角=1、全角=2として文字列の表示幅を計算する。
int calculateTextWidth(String text) {
  var width = 0;
  for (final rune in text.runes) {
    width += _isFullWidth(rune) ? 2 : 1;
  }
  return width;
}

bool isValidFolderNameWidth(String text) =>
    calculateTextWidth(text) <= maxFolderNameWidth;

bool _isFullWidth(int codeUnit) {
  return (codeUnit >= 0x1100 && codeUnit <= 0x115F) || // Hangul Jamo
      (codeUnit >= 0x2E80 && codeUnit <= 0xA4CF) || // CJK/部首/かな/カナ
      (codeUnit >= 0xAC00 && codeUnit <= 0xD7A3) || // ハングル音節
      (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) || // CJK互換漢字
      (codeUnit >= 0xFF00 && codeUnit <= 0xFF60) || // 全角形
      (codeUnit >= 0xFFE0 && codeUnit <= 0xFFE6);
}

/// 半角20/全角10相当を超える入力をブロックする [TextInputFormatter]。
class FolderNameLengthFormatter extends TextInputFormatter {
  const FolderNameLengthFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (isValidFolderNameWidth(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}
