# save_flashcard_result_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/flashcard_result/save_flashcard_result_use_case.dart |
| クラス名 | SaveFlashcardResultUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`SaveFlashcardResultUseCase` は `FlashcardResultRepository`（インターフェース）へ単純に委譲するだけで、
分岐や加工ロジックを持たない。手書きの `_FakeFlashcardResultRepository`
（`implements FlashcardResultRepository`）に差し込む戻り値を切り替え、引数
（`userId` / `folderId` / `totalCount` / `correctCount`）がそのまま渡ること・戻り値がそのまま
返ることのみを検証する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 正しい引数でRepositoryに委譲し、Rightがそのまま返る | 正常系 | call() | ✅ |
| 2 | Repositoryが失敗を返した場合、Leftがそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 正しい引数でRepositoryに委譲し、Rightがそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `_FakeFlashcardResultRepository.saveFlashcardResultResult` に `Right(FlashcardResult(...))` を設定。
- **入力値・テスト条件**: `userId: 'u1'`, `folderId: 'f1'`, `totalCount: 10`, `correctCount: 7`
- **操作手順**: `SaveFlashcardResultUseCase(repository)(userId: 'u1', folderId: 'f1', totalCount: 10, correctCount: 7)` を呼び出す。
- **期待結果**: `repository.capturedUserId` / `capturedFolderId` / `capturedTotalCount` / `capturedCorrectCount` が入力値と一致し、戻り値がフェイクの設定した `FlashcardResult` を含む `Right` とそのまま等しい。

### テストケース2: Repositoryが失敗を返した場合、Leftがそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `_FakeFlashcardResultRepository.saveFlashcardResultResult` に `Left(Failure.network())` を設定。
- **入力値・テスト条件**: `userId: 'u1'`, `folderId: 'f1'`, `totalCount: 10`, `correctCount: 7`
- **操作手順**: `SaveFlashcardResultUseCase(repository)(userId: 'u1', folderId: 'f1', totalCount: 10, correctCount: 7)` を呼び出す。
- **期待結果**: 戻り値が `Left(Failure.network())` とそのまま等しい。

## 対象外

分岐・加工ロジックが無いため対象外行なし（全行がテスト済み）。
