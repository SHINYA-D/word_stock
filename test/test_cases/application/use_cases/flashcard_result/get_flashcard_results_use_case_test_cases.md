# get_flashcard_results_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/flashcard_result/get_flashcard_results_use_case.dart |
| クラス名 | GetFlashcardResultsUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`GetFlashcardResultsUseCase` は `FlashcardResultRepository`（インターフェース）へ単純に委譲するだけで、
分岐や加工ロジックを持たない。手書きの `_FakeFlashcardResultRepository`
（`implements FlashcardResultRepository`）に差し込む戻り値を切り替え、引数がそのまま渡ること・
戻り値がそのまま返ることのみを検証する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 正しい引数でRepositoryに委譲し、Rightがそのまま返る | 正常系 | call() | ✅ |
| 2 | Repositoryが失敗を返した場合、Leftがそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 正しい引数でRepositoryに委譲し、Rightがそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `_FakeFlashcardResultRepository.getFlashcardResultsResult` に `Right([FlashcardResult(...)])` を設定。
- **入力値・テスト条件**: `userId: 'u1'`
- **操作手順**: `GetFlashcardResultsUseCase(repository)(userId: 'u1')` を呼び出す。
- **期待結果**: `repository.capturedUserId` が `'u1'` であり、戻り値がフェイクの設定したリストを含む `Right` とそのまま等しい。

### テストケース2: Repositoryが失敗を返した場合、Leftがそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `_FakeFlashcardResultRepository.getFlashcardResultsResult` に `Left(Failure.notFound())` を設定。
- **入力値・テスト条件**: `userId: 'u1'`
- **操作手順**: `GetFlashcardResultsUseCase(repository)(userId: 'u1')` を呼び出す。
- **期待結果**: 戻り値が `Left(Failure.notFound())` とそのまま等しい。

## 対象外

分岐・加工ロジックが無いため対象外行なし（全行がテスト済み）。
