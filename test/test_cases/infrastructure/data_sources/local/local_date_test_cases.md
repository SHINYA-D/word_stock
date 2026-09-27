## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/local_date.dart |
| クラス名 | （トップレベル関数） |
| テスト対象メソッド | toDateColumn() / toNullableDateColumn() / fromDateColumn() / fromNullableDateColumn() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 端末ローカルのDateTimeを渡した場合、末尾がZのUTC文字列になる | 正常系 | toDateColumn() | ✅ |
| 2 | UTCのDateTimeを渡した場合、そのままの時刻でZ付き文字列になる | 境界値 | toDateColumn() | ✅ |
| 3 | nullを渡した場合、nullが返る（保存側） | 異常系 | toNullableDateColumn() | ✅ |
| 4 | 値を渡した場合、toDateColumnと同じ結果が返る | 正常系 | toNullableDateColumn() | ✅ |
| 5 | Z付きの文字列を渡した場合、同じ時刻でisUtcがfalseのDateTimeが返る | 正常系 | fromDateColumn() | ✅ |
| 6 | バージョン1のZなし文字列を渡した場合、端末のタイムゾーンの時刻として読む | 境界値 | fromDateColumn() | ✅ |
| 7 | nullを渡した場合、nullが返る（読み出し側） | 異常系 | fromNullableDateColumn() | ✅ |
| 8 | 値を渡した場合、fromDateColumnと同じ結果が返る | 正常系 | fromNullableDateColumn() | ✅ |
| 9 | 保存してから読み出した場合、同じ時刻に戻る | 正常系 | toDateColumn() / fromDateColumn() | ✅ |

## テストケース詳細

### テストケース1: 端末ローカルのDateTimeを渡した場合、末尾がZのUTC文字列になる
- **カテゴリ**: 正常系
- **対象メソッド**: toDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = DateTime(2024, 1, 1, 9, 0, 0)（端末ローカル時刻）
- **操作手順**: `toDateColumn(value)` を呼ぶ
- **期待結果**: 戻り値が`Z`で終わる文字列で、`DateTime.parse(result)`が入力値と同じ時刻（isAtSameMomentAs）になる

### テストケース2: UTCのDateTimeを渡した場合、そのままの時刻でZ付き文字列になる
- **カテゴリ**: 境界値
- **対象メソッド**: toDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = DateTime.utc(2024, 1, 1, 9, 0, 0)
- **操作手順**: `toDateColumn(value)` を呼ぶ
- **期待結果**: 戻り値が`2024-01-01T09:00:00.000Z`（時刻が変換されずそのまま）

### テストケース3: nullを渡した場合、nullが返る（保存側）
- **カテゴリ**: 異常系
- **対象メソッド**: toNullableDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = null
- **操作手順**: `toNullableDateColumn(null)` を呼ぶ
- **期待結果**: 戻り値がnull

### テストケース4: 値を渡した場合、toDateColumnと同じ結果が返る
- **カテゴリ**: 正常系
- **対象メソッド**: toNullableDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = DateTime(2024, 1, 1, 9, 0, 0)
- **操作手順**: `toNullableDateColumn(value)` を呼び、`toDateColumn(value)` と比較する
- **期待結果**: 両者が同じ文字列になる

### テストケース5: Z付きの文字列を渡した場合、同じ時刻でisUtcがfalseのDateTimeが返る
- **カテゴリ**: 正常系
- **対象メソッド**: fromDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = '2024-01-01T09:00:00.000Z'
- **操作手順**: `fromDateColumn(value)` を呼ぶ
- **期待結果**: 戻り値が`DateTime.parse(value)`と同じ時刻（isAtSameMomentAs）で、isUtcがfalse（端末のタイムゾーンに変換されている）

### テストケース6: バージョン1のZなし文字列を渡した場合、端末のタイムゾーンの時刻として読む
- **カテゴリ**: 境界値
- **対象メソッド**: fromDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = '2024-01-01T09:00:00.000'（`Z`なし）
- **操作手順**: `fromDateColumn(value)` を呼ぶ
- **期待結果**: 戻り値が`DateTime(2024, 1, 1, 9, 0, 0)`（端末のタイムゾーンの時刻として解釈される）で、isUtcがfalse

### テストケース7: nullを渡した場合、nullが返る（読み出し側）
- **カテゴリ**: 異常系
- **対象メソッド**: fromNullableDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = null
- **操作手順**: `fromNullableDateColumn(null)` を呼ぶ
- **期待結果**: 戻り値がnull

### テストケース8: 値を渡した場合、fromDateColumnと同じ結果が返る
- **カテゴリ**: 正常系
- **対象メソッド**: fromNullableDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: value = '2024-01-01T09:00:00.000Z'
- **操作手順**: `fromNullableDateColumn(value)` を呼び、`fromDateColumn(value)` と比較する
- **期待結果**: 両者が同じDateTimeになる

### テストケース9: 保存してから読み出した場合、同じ時刻に戻る
- **カテゴリ**: 正常系
- **対象メソッド**: toDateColumn() / fromDateColumn()
- **事前条件**: なし
- **入力値・テスト条件**: original = DateTime(2024, 6, 15, 12, 34, 56)（端末ローカル時刻）
- **操作手順**: `fromDateColumn(toDateColumn(original))` を呼ぶ
- **期待結果**: 戻り値がoriginalと同じ時刻（isAtSameMomentAs）
