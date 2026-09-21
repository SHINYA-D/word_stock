# get_folders_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/folder/get_folders_use_case.dart |
| クラス名 | GetFoldersUseCase |
| テスト対象メソッド | call() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 正常系の場合、Repository.getFoldersに引数がそのまま委譲される | 正常系 | call() | ✅ |
| 2 | Repositoryが成功を返した場合、フォルダ一覧のRightがそのまま返る | 正常系 | call() | ✅ |
| 3 | Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 正常系の場合、Repository.getFoldersに引数がそのまま委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeFolderRepository`を注入した`GetFoldersUseCase`を用意する。
- **入力値・テスト条件**: `userId: 'user-1'`
- **操作手順**: `useCase(userId: ...)`を呼ぶ。
- **期待結果**: `repository.getFoldersCallCount`が1、`lastUserId`が入力値と一致する。

### テストケース2: Repositoryが成功を返した場合、フォルダ一覧のRightがそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `repository.getFoldersResult`にフォルダ1件を含む`Right(folders)`を設定する。
- **入力値・テスト条件**: `userId: 'user-1'`
- **操作手順**: `useCase(userId: ...)`を呼ぶ。
- **期待結果**: 戻り値が設定した`Right(folders)`とイコールになる。

### テストケース3: Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `repository.getFoldersResult`に`Left(Failure.unknown('error'))`を設定する。
- **入力値・テスト条件**: `userId: 'user-1'`
- **操作手順**: `useCase(userId: ...)`を呼ぶ。
- **期待結果**: 戻り値が`Left(Failure.unknown('error'))`とイコールになる。

## 対象外

対象外なし。`GetFoldersUseCase`はRepositoryへの単純委譲のみで分岐が無いため、
上記3ケースで全行がカバーされる想定。
