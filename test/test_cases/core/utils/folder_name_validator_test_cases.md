# folder_name_validator_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/core/utils/folder_name_validator.dart |
| クラス名 | FolderNameLengthFormatter（関数: calculateTextWidth / isValidFolderNameWidth） |
| テスト対象メソッド | calculateTextWidth() / isValidFolderNameWidth() / FolderNameLengthFormatter.formatEditUpdate() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 空文字の場合、幅は0になる | 境界値 | calculateTextWidth() | ✅ |
| 2 | 半角英数字のみの場合、文字数と同じ幅になる | 正常系 | calculateTextWidth() | ✅ |
| 3 | 全角文字（漢字）のみの場合、文字数の2倍の幅になる | 正常系 | calculateTextWidth() | ✅ |
| 4 | 半角と全角が混在する場合、それぞれの幅を合算する | 正常系 | calculateTextWidth() | ✅ |
| 5 | 半角20文字ちょうどの場合、trueを返す | 境界値 | isValidFolderNameWidth() | ✅ |
| 6 | 半角21文字の場合、falseを返す | 境界値 | isValidFolderNameWidth() | ✅ |
| 7 | 全角10文字ちょうど（幅20相当）の場合、trueを返す | 境界値 | isValidFolderNameWidth() | ✅ |
| 8 | 全角11文字（幅22相当）の場合、falseを返す | 境界値 | isValidFolderNameWidth() | ✅ |
| 9 | 制限幅以内の入力の場合、newValueをそのまま返す | 正常系 | FolderNameLengthFormatter.formatEditUpdate() | ✅ |
| 10 | 制限幅を超える入力の場合、oldValueを返して入力をブロックする | 異常系 | FolderNameLengthFormatter.formatEditUpdate() | ✅ |

## テストケース詳細

### テストケース1: 空文字の場合、幅は0になる
- **カテゴリ**: 境界値
- **対象メソッド**: calculateTextWidth()
- **入力条件**: `''`
- **期待値**: `0`

### テストケース2: 半角英数字のみの場合、文字数と同じ幅になる
- **カテゴリ**: 正常系
- **対象メソッド**: calculateTextWidth()
- **入力条件**: `'abcDE12345'`（10文字、すべて半角）
- **期待値**: `10`

### テストケース3: 全角文字（漢字）のみの場合、文字数の2倍の幅になる
- **カテゴリ**: 正常系
- **対象メソッド**: calculateTextWidth()
- **入力条件**: `'日本語漢字'`（5文字、すべて全角）
- **期待値**: `10`

### テストケース4: 半角と全角が混在する場合、それぞれの幅を合算する
- **カテゴリ**: 正常系
- **対象メソッド**: calculateTextWidth()
- **入力条件**: `'abcde日本語'`（半角5 + 全角3）
- **期待値**: `11`（5 + 3*2）

### テストケース5: 半角20文字ちょうどの場合、trueを返す
- **カテゴリ**: 境界値
- **対象メソッド**: isValidFolderNameWidth()
- **入力条件**: `'a' * 20`
- **期待値**: `true`

### テストケース6: 半角21文字の場合、falseを返す
- **カテゴリ**: 境界値
- **対象メソッド**: isValidFolderNameWidth()
- **入力条件**: `'a' * 21`
- **期待値**: `false`

### テストケース7: 全角10文字ちょうど（幅20相当）の場合、trueを返す
- **カテゴリ**: 境界値
- **対象メソッド**: isValidFolderNameWidth()
- **入力条件**: `'日' * 10`
- **期待値**: `true`

### テストケース8: 全角11文字（幅22相当）の場合、falseを返す
- **カテゴリ**: 境界値
- **対象メソッド**: isValidFolderNameWidth()
- **入力条件**: `'日' * 11`
- **期待値**: `false`

### テストケース9: 制限幅以内の入力の場合、newValueをそのまま返す
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter.formatEditUpdate()
- **入力条件**: oldValue=`'abc'`, newValue=`'abcd'`
- **期待値**: `newValue`がそのまま返る

### テストケース10: 制限幅を超える入力の場合、oldValueを返して入力をブロックする
- **カテゴリ**: 異常系
- **対象メソッド**: FolderNameLengthFormatter.formatEditUpdate()
- **入力条件**: oldValue=`'a' * 20`, newValue=`'a' * 21`
- **期待値**: `oldValue`が返り、入力がブロックされる
