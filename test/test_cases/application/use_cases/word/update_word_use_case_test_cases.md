# update_word_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/word/update_word_use_case.dart |
| クラス名 | UpdateWordUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`UpdateWordUseCase` は `WordRepository`（インターフェース）にのみ依存する単純な委譲クラス。
`WordRepository` を `implements` した手書きフェイク `_FakeWordRepository`（テストファイル内）を使用し、
渡された引数と戻り値をそのまま検証する。SQLite・Firestore 等の実インフラには依存しない。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 正しい引数でRepositoryに委譲し、Rightがそのまま返る | 正常系 | call() | ✅ |
| 2 | Repositoryが失敗を返した場合、Leftがそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 正しい引数でRepositoryに委譲し、Rightがそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `_FakeWordRepository.updateWordResult` に `Right(Word)` を設定済み。
- **入力値・テスト条件**: `userId: 'u1'`, `folderId: 'f1'`, `wordId: 'w1'`, `front: 'apple'`, `back: 'りんご'`
- **操作手順**: `UpdateWordUseCase(repository)(userId:.., folderId:.., wordId:.., front:.., back:..)` を呼ぶ。
- **期待結果**: `repository.updateWord` が同じ引数で呼ばれ（`capturedUserId`/`capturedFolderId`/`capturedWordId`/`capturedFront`/`capturedBack` が一致）、戻り値の `Either` がフェイクの設定した `Right(Word)` とそのまま一致する。

### テストケース2: Repositoryが失敗を返した場合、Leftがそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `_FakeWordRepository.updateWordResult` に `Left(Failure.notFound())` を設定済み。
- **入力値・テスト条件**: `userId: 'u1'`, `folderId: 'f1'`, `wordId: 'w1'`, `front: 'apple'`, `back: 'りんご'`
- **操作手順**: `UpdateWordUseCase(repository)(userId:.., folderId:.., wordId:.., front:.., back:..)` を呼ぶ。
- **期待結果**: 戻り値が `Left(Failure.notFound())` とそのまま一致する。
