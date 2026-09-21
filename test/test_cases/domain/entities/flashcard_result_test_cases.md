# flashcard_result_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/domain/entities/flashcard_result.dart |
| クラス名 | FlashcardResult |
| テスト対象メソッド | correctRate（getter） |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 出題数が0の場合、0を返す（ゼロ除算しない） | 境界値 | correctRate | ✅ |
| 2 | 全問正解の場合、1.0を返す | 境界値 | correctRate | ✅ |
| 3 | 全問不正解の場合、0.0を返す | 境界値 | correctRate | ✅ |
| 4 | 一部正解の場合、正解数÷出題数を返す | 正常系 | correctRate | ✅ |
| 5 | 割り切れない場合、double として端数を保持する | 正常系 | correctRate | ✅ |

## テストケース詳細

### テストケース1: 出題数が0の場合、0を返す（ゼロ除算しない）
- **カテゴリ**: 境界値
- **対象メソッド**: correctRate
- **入力条件**: `totalCount = 0`, `correctCount = 0`
- **期待値**: `0`（`totalCount == 0` の分岐に入り、除算を行わない）

### テストケース2: 全問正解の場合、1.0を返す
- **カテゴリ**: 境界値
- **対象メソッド**: correctRate
- **入力条件**: `totalCount = 10`, `correctCount = 10`
- **期待値**: `1.0`

### テストケース3: 全問不正解の場合、0.0を返す
- **カテゴリ**: 境界値
- **対象メソッド**: correctRate
- **入力条件**: `totalCount = 10`, `correctCount = 0`
- **期待値**: `0.0`

### テストケース4: 一部正解の場合、正解数÷出題数を返す
- **カテゴリ**: 正常系
- **対象メソッド**: correctRate
- **入力条件**: `totalCount = 4`, `correctCount = 1`
- **期待値**: `0.25`

### テストケース5: 割り切れない場合、double として端数を保持する
- **カテゴリ**: 正常系
- **対象メソッド**: correctRate
- **入力条件**: `totalCount = 3`, `correctCount = 1`
- **期待値**: `0.3333333333333333`（許容誤差 1e-12）

## 対象外

- なし（Freezed 生成物の getter / copyWith は CLAUDE.md の方針により対象外。手書きロジックは `correctRate` のみで全分岐をカバー済み）
