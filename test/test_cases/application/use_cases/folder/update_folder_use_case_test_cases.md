# update_folder_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/folder/update_folder_use_case.dart |
| クラス名 | UpdateFolderUseCase |
| テスト対象メソッド | call() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 正常系の場合、Repository.updateFolderに引数がそのまま委譲される | 正常系 | call() | ✅ |
| 2 | Repositoryが成功を返した場合、更新後フォルダのRightがそのまま返る | 正常系 | call() | ✅ |
| 3 | Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 正常系の場合、Repository.updateFolderに引数がそのまま委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeFolderRepository`を注入した`UpdateFolderUseCase`を用意する。
- **入力値・テスト条件**: `userId: 'user-1'`, `folderId: 'folder-1'`, `name: '新しい名前'`
- **操作手順**: `useCase(userId: ..., folderId: ..., name: ...)`を呼ぶ。
- **期待結果**: `repository.updateFolderCallCount`が1、`lastUserId`/`lastFolderId`/`lastName`が入力値と一致する。

### テストケース2: Repositoryが成功を返した場合、更新後フォルダのRightがそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `repository.updateFolderResult`に更新後の`Folder`を含む`Right(folder)`を設定する。
- **入力値・テスト条件**: `userId: 'user-1'`, `folderId: 'folder-1'`, `name: '新しい名前'`
- **操作手順**: `useCase(userId: ..., folderId: ..., name: ...)`を呼ぶ。
- **期待結果**: 戻り値が設定した`Right(folder)`とイコールになる。

### テストケース3: Repositoryが失敗を返した場合、戻り値のLeftがそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `repository.updateFolderResult`に`Left(Failure.network())`を設定する。
- **入力値・テスト条件**: `userId: 'user-1'`, `folderId: 'folder-1'`, `name: '新しい名前'`
- **操作手順**: `useCase(userId: ..., folderId: ..., name: ...)`を呼ぶ。
- **期待結果**: 戻り値が`Left(Failure.network())`とイコールになる。

## 対象外

対象外なし。`UpdateFolderUseCase`はRepositoryへの単純委譲のみで分岐が無いため、
上記3ケースで全行がカバーされる想定。
