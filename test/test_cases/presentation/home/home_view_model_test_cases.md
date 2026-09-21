# home_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/home/home_view_model.dart |
| クラス名 | HomeViewModel |
| テスト対象メソッド | build() / refresh() / createFolder() / updateFolder() / deleteFolder() |

## 実行環境について

`HomeViewModel` は `@riverpod class`（family ではない単一の `HomeState` を返す同期 Notifier）で、
`getFoldersUseCaseProvider` / `createFolderUseCaseProvider` / `updateFolderUseCaseProvider` /
`deleteFolderUseCaseProvider` / `currentUserProvider` に依存する。`ProviderContainer(overrides: [...])`
で各 UseCase を手書き Fake（`FakeGetFoldersUseCase` / `FakeCreateFolderUseCase` /
`FakeUpdateFolderUseCase` / `FakeDeleteFolderUseCase`）に差し替え、Widget は一切 pump せず
notifier を直接操作して検証する。

`build()` は他の `*ViewModel` と異なり `Future<HomeState>` ではなく **同期の `HomeState`** を返し、
初期ロードは `Future.microtask(() => _initState())` により状態内部の `HomeState.folders`
（`AsyncValue<List<Folder>>`）へ反映される。そのため `.future` は存在せず、テストでは
`state.folders.isLoading` が `false` になるまでマイクロタスクを消費して待つヘルパー
`_waitUntilNotLoading` を使用する。また `HomeViewModel` は `AutoDisposeNotifier` のため、
初期ロード完了前に破棄されないよう `container.listen(homeViewModelProvider, (_, __) {})` で
リスナーを張り続けている。

`FakeGetFoldersUseCase` は呼び出しごとに異なる `Either` を返せるようにし、`refresh()` /
`deleteFolder()` からの再取得（2回目呼び出し）の分岐を検証できるようにしている。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 取得に成功した場合、フォルダ一覧が state.folders に反映される | 正常系 | build() | ✅ |
| 2 | 取得結果が空リストの場合、空の folders になる | 境界値 | build() | ✅ |
| 3 | 取得に失敗した場合、folders が AsyncError になる | 異常系 | build() | ✅ |
| 4 | currentUser が null の場合、userId は空文字列として使用される | 境界値 | build() | ✅ |
| 5 | 再取得に成功した場合、最新のフォルダ一覧に更新される | 正常系 | refresh() | ✅ |
| 6 | 再取得に失敗した場合、folders が AsyncError に遷移する | 異常系 | refresh() | ✅ |
| 7 | 作成に成功した場合、新しいフォルダが現在のリストの末尾に追加される | 正常系 | createFolder() | ✅ |
| 8 | 現在のリストが空の場合に作成すると、作成したフォルダのみのリストになる | 境界値 | createFolder() | ✅ |
| 9 | 作成に失敗した場合、folders が AsyncError になり既存のリストは失われる | 異常系 | createFolder() | ✅ |
| 10 | 更新に成功した場合、該当する id のフォルダが置き換わる | 正常系 | updateFolder() | ✅ |
| 11 | 存在しない folderId を指定した場合、リストは変化しない | 境界値 | updateFolder() | ✅ |
| 12 | 更新に失敗した場合、folders が AsyncError になる | 異常系 | updateFolder() | ✅ |
| 13 | 削除に成功した場合、refresh() が呼ばれ最新のフォルダ一覧に更新される | 正常系 | deleteFolder() | ✅ |
| 14 | 削除に失敗した場合、folders が AsyncError になり refresh は呼ばれない | 異常系 | deleteFolder() | ✅ |

## テストケース詳細

### テストケース1: 取得に成功した場合、フォルダ一覧が state.folders に反映される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `homeViewModelProvider` が未 build（コンテナ生成直後）。
- **入力値・テスト条件**: `getFoldersUseCaseProvider` が `Right(testFolders)`（2件）を返す。
- **操作手順**: コンテナ生成直後に `state.folders.isLoading` を確認し、`_waitUntilNotLoading` で初期ロード完了を待つ。
- **期待結果**: 生成直後は `folders.isLoading == true`。完了後は `folders.value == testFolders`、`getFoldersUseCase.lastUserId == testUser.id`。

### テストケース2: 取得結果が空リストの場合、空の folders になる
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: `homeViewModelProvider` が未 build。
- **入力値・テスト条件**: `getFoldersUseCaseProvider` が `Right([])` を返す。
- **操作手順**: `_waitUntilNotLoading` で初期ロード完了を待つ。
- **期待結果**: `folders.value` が空リストになる。

### テストケース3: 取得に失敗した場合、folders が AsyncError になる
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: `homeViewModelProvider` が未 build。
- **入力値・テスト条件**: `getFoldersUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `_waitUntilNotLoading` で初期ロード完了を待つ。
- **期待結果**: `_initState()` の `fold` により `folders` が `AsyncValue.error(Failure.network())` になる。

### テストケース4: currentUser が null の場合、userId は空文字列として使用される
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: `currentUserProvider` を `null` に上書き。
- **入力値・テスト条件**: `getFoldersUseCaseProvider` が `Right(testFolders)` を返す。
- **操作手順**: `_waitUntilNotLoading` で初期ロード完了を待つ。
- **期待結果**: `_userId = ref.watch(currentUserProvider)?.id ?? ''` の `??` 分岐により `getFoldersUseCase.lastUserId == ''` になる。

### テストケース5: 再取得に成功した場合、最新のフォルダ一覧に更新される
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: 初回 build 成功済みで `folders.value == testFolders`。
- **入力値・テスト条件**: `refresh()` 呼び出し時に `getFoldersUseCaseProvider` が `Right([testFolders.first])` を返す。
- **操作手順**: `notifier.refresh()` を呼ぶ。
- **期待結果**: 呼び出し直後は `folders.isLoading == true`、完了後は `folders.value` が更新後のリストになる。

### テストケース6: 再取得に失敗した場合、folders が AsyncError に遷移する
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初回 build 成功済みで `folders.value == testFolders`。
- **入力値・テスト条件**: `refresh()` 呼び出し時に `getFoldersUseCaseProvider` が `Left(Failure.unknown('boom'))` を返す。
- **操作手順**: `await notifier.refresh()` を呼ぶ。
- **期待結果**: 完了後、`folders` が `AsyncError(Failure.unknown('boom'))` になる（`AsyncValue.guard` による捕捉）。

### テストケース7: 作成に成功した場合、新しいフォルダが現在のリストの末尾に追加される
- **カテゴリ**: 正常系
- **対象メソッド**: createFolder()
- **事前条件**: build 済みで `folders.value == testFolders`（2件）。
- **入力値・テスト条件**: `createFolderUseCaseProvider` が新規 `Folder('folder-new', name: '新フォルダ')` を返す。
- **操作手順**: `notifier.createFolder(name: '新フォルダ')` を呼ぶ。
- **期待結果**: `folders.value` が `[...testFolders, newFolder]` になる。

### テストケース8: 現在のリストが空の場合に作成すると、作成したフォルダのみのリストになる
- **カテゴリ**: 境界値
- **対象メソッド**: createFolder()
- **事前条件**: build 済みで `folders.value` が空リスト。
- **入力値・テスト条件**: `createFolderUseCaseProvider` が新規 `Folder` を返す。
- **操作手順**: `notifier.createFolder(name: '新フォルダ')` を呼ぶ。
- **期待結果**: `folders.value` が `[newFolder]` になる（`state.folders.value ?? []` の空リスト分岐を確認）。

### テストケース9: 作成に失敗した場合、folders が AsyncError になり既存のリストは失われる
- **カテゴリ**: 異常系
- **対象メソッド**: createFolder()
- **事前条件**: build 済みで `folders.value == testFolders`。
- **入力値・テスト条件**: `createFolderUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `notifier.createFolder(name: '新フォルダ')` を呼ぶ。
- **期待結果**: `folders` が `AsyncError(Failure.network())` になる。

### テストケース10: 更新に成功した場合、該当する id のフォルダが置き換わる
- **カテゴリ**: 正常系
- **対象メソッド**: updateFolder()
- **事前条件**: build 済みで `folders.value == testFolders`（folder-1, folder-2）。
- **入力値・テスト条件**: `updateFolderUseCaseProvider` が `folder-1` を更新した `Folder` を返す。
- **操作手順**: `notifier.updateFolder(folderId: 'folder-1', name: '英単語(更新)')` を呼ぶ。
- **期待結果**: `folders.value` の `folder-1` のみが更新後の `Folder` に置き換わり、`folder-2` は変化しない。

### テストケース11: 存在しない folderId を指定した場合、リストは変化しない
- **カテゴリ**: 境界値
- **対象メソッド**: updateFolder()
- **事前条件**: build 済みで `folders.value == testFolders`。
- **入力値・テスト条件**: `updateFolderUseCaseProvider` が `id: 'not-exist'` の `Folder` を返す。
- **操作手順**: `notifier.updateFolder(folderId: 'not-exist', name: 'x')` を呼ぶ。
- **期待結果**: `current.map((f) => f.id == folderId ? updated : f)` の条件に一致する要素が無いため、`folders.value` は build 時の `testFolders` のまま変化しない。

### テストケース12: 更新に失敗した場合、folders が AsyncError になる
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder()
- **事前条件**: build 済みで `folders.value == testFolders`。
- **入力値・テスト条件**: `updateFolderUseCaseProvider` が `Left(Failure.auth())` を返す。
- **操作手順**: `notifier.updateFolder(folderId: 'folder-1', name: 'x')` を呼ぶ。
- **期待結果**: `folders` が `AsyncError(Failure.auth())` になる。

### テストケース13: 削除に成功した場合、refresh() が呼ばれ最新のフォルダ一覧に更新される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **事前条件**: build 済みで `folders.value == testFolders`（2件）。
- **入力値・テスト条件**: `deleteFolderUseCaseProvider` が `Right(unit)` を返し、続く `refresh()` 内の `getFoldersUseCaseProvider`（2回目呼び出し）が `Right([testFolders.first])` を返す。
- **操作手順**: `await notifier.deleteFolder(folderId: 'folder-2')` の後、`_waitUntilNotLoading` で `refresh()` の完了を待つ。
- **期待結果**: `deleteFolder()` 自身はローカルの `folders` を直接書き換えず、成功時のコールバックで `refresh()` を呼び出す（fire-and-forget）ため、最終的に `folders.value` が `refresh()` 後のリストになり、`getFoldersUseCase.callCount == 2` になる。

### テストケース14: 削除に失敗した場合、folders が AsyncError になり refresh は呼ばれない
- **カテゴリ**: 異常系
- **対象メソッド**: deleteFolder()
- **事前条件**: build 済みで `folders.value == testFolders`。
- **入力値・テスト条件**: `deleteFolderUseCaseProvider` が `Left(Failure.notFound())` を返す。
- **操作手順**: `await notifier.deleteFolder(folderId: 'folder-1')` を呼ぶ。
- **期待結果**: `folders` が `AsyncError(Failure.notFound())` になり、`getFoldersUseCase.callCount` は build 時の1回のまま増えない（`refresh()` が呼ばれていないことの確認）。

## 対象外

なし。全ての分岐（`_initState()` の成功/失敗、`refresh()`/`createFolder()`/`updateFolder()`/`deleteFolder()`
各メソッドの成功/失敗コールバックおよび `current` の空リスト・id 一致/不一致分岐、`currentUserProvider`
の null 分岐）をテストケースで網羅している。
