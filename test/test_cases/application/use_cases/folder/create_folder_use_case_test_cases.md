# create_folder_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/folder/create_folder_use_case.dart |
| クラス名 | CreateFolderUseCase |
| テスト対象メソッド | call() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 正常系の場合、Repository.createFolderに引数がそのまま委譲される | 正常系 | call() | ✅ |
| 2 | Repositoryが成功を返した場合、戻り値のRightがそのまま返る | 正常系 | call() | ✅ |
| 3 | Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 正常系の場合、Repository.createFolderに引数がそのまま委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeFolderRepository`を注入した`CreateFolderUseCase`を用意する。
- **入力値・テスト条件**: `userId: 'user-1'`, `name: 'フォルダA'`, `parentFolderId: 'parent-1'`
- **操作手順**: `useCase(userId: ..., name: ..., parentFolderId: ...)`を呼ぶ。
- **期待結果**: `repository.createFolderCallCount`が1、`lastUserId`/`lastName`/`lastParentFolderId`が入力値と一致する。

### テストケース2: Repositoryが成功を返した場合、戻り値のRightがそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `repository.createFolderResult`に`Right(folder)`を設定する。
- **入力値・テスト条件**: `userId: 'user-1'`, `name: 'フォルダA'`
- **操作手順**: `useCase(userId: ..., name: ...)`を呼ぶ。
- **期待結果**: 戻り値が設定した`Right(folder)`とイコールになる（加工されずそのまま返る）。

### テストケース3: Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `repository.createFolderResult`に`Left(Failure.network())`を設定する。
- **入力値・テスト条件**: `userId: 'user-1'`, `name: 'フォルダA'`
- **操作手順**: `useCase(userId: ..., name: ...)`を呼ぶ。
- **期待結果**: 戻り値が`Left(Failure.network())`とイコールになる。

## 対象外

対象外なし。`CreateFolderUseCase`はRepositoryへの単純委譲のみで分岐が無いため、
上記3ケースで全行がカバーされる想定。
