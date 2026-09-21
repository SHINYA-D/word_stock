# result_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/result/result_view_model.dart |
| クラス名 | ResultViewModel / folderNames（トップレベル関数プロバイダ） |
| テスト対象メソッド | ResultViewModel.build() / ResultViewModel.refresh() / folderNames() |

## 実行環境について

`ResultViewModel` は `@riverpod class`（`AutoDisposeAsyncNotifier`）で `getFlashcardResultsUseCaseProvider` /
`currentUserProvider` に依存する。`folderNames` は同ファイル内のトップレベル `@riverpod` 関数プロバイダで
`getFoldersUseCaseProvider` / `currentUserProvider` に依存する。
`ProviderContainer(overrides: [...])` で各 UseCase を手書き Fake
（`FakeGetFlashcardResultsUseCase` / `FakeGetFoldersUseCase`）に差し替え、Widget は一切 pump せず
notifier / provider を直接読み取って検証する。
`FakeGetFlashcardResultsUseCase` は呼び出しごとに異なる `Either` を返せるようにし、`refresh()` の
2回目呼び出し（build 成功後の再取得）の分岐を検証できるようにしている。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 取得に成功した場合、成績一覧が state に反映される | 正常系 | build() | ✅ |
| 2 | 取得結果が空リストの場合、空の state になる | 境界値 | build() | ✅ |
| 3 | 取得に失敗した場合、AsyncError になる | 異常系 | build() | ✅ |
| 4 | 再取得に成功した場合、最新の成績一覧に更新される | 正常系 | refresh() | ✅ |
| 5 | folderId を指定して再取得しても、UseCase には userId のみが渡される | 境界値 | refresh() | ✅ |
| 6 | 再取得に失敗した場合、AsyncError に遷移する | 異常系 | refresh() | ✅ |
| 7 | 取得に成功した場合、id をキーに name を値とする Map になる | 正常系 | folderNames() | ✅ |
| 8 | フォルダが0件の場合、空の Map になる | 境界値 | folderNames() | ✅ |
| 9 | 取得に失敗した場合、例外を投げず空の Map になる | 異常系 | folderNames() | ✅ |

## テストケース詳細

### テストケース1: 取得に成功した場合、成績一覧が state に反映される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `resultViewModelProvider` が未 build（コンテナ生成直後）。
- **入力値・テスト条件**: `getFlashcardResultsUseCaseProvider` が `Right(testResults)`（2件）を返す。
- **操作手順**: `container.read(resultViewModelProvider.future)` を呼ぶ。
- **期待結果**: 結果が `testResults` と一致し、`state.value` も同じ。

### テストケース2: 取得結果が空リストの場合、空の state になる
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: `resultViewModelProvider` が未 build。
- **入力値・テスト条件**: `getFlashcardResultsUseCaseProvider` が `Right([])` を返す。
- **操作手順**: `container.read(resultViewModelProvider.future)` を呼ぶ。
- **期待結果**: 結果が空リストになる。

### テストケース3: 取得に失敗した場合、AsyncError になる
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: `resultViewModelProvider` が未 build。
- **入力値・テスト条件**: `getFlashcardResultsUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `container.read(resultViewModelProvider.future)` を呼ぶ。
- **期待結果**: `build()` 内の `fold((f) => throw f, ...)` により例外が送出され、state が `AsyncError(Failure.network())` になる。

### テストケース4: 再取得に成功した場合、最新の成績一覧に更新される
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: 初回 build 成功済みで `state.value == testResults`。
- **入力値・テスト条件**: `refresh()` 呼び出し時に `getFlashcardResultsUseCaseProvider` が `Right([testResults.first])` を返す。
- **操作手順**: `notifier.refresh()` を呼ぶ。
- **期待結果**: 呼び出し直後は state が `AsyncLoading`、完了後は `state.value` が更新後のリストになる。

### テストケース5: folderId を指定して再取得しても、UseCase には userId のみが渡される
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: 初回 build 成功済みで `state.value == testResults`。
- **入力値・テスト条件**: `refresh(folderId: 'folder-1')` を呼ぶ（`folderId` は現状の実装では UseCase 呼び出しに使われない引数）。
- **操作手順**: `await notifier.refresh(folderId: 'folder-1')` を呼ぶ。
- **期待結果**: `folderId` の有無に関わらず `getFlashcardResultsUseCaseProvider` の戻り値がそのまま `state.value` に反映される（`folderId` 未使用であることの確認）。

### テストケース6: 再取得に失敗した場合、AsyncError に遷移する
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初回 build 成功済みで `state.value == testResults`。
- **入力値・テスト条件**: `refresh()` 呼び出し時に `getFlashcardResultsUseCaseProvider` が `Left(Failure.unknown('boom'))` を返す。
- **操作手順**: `await notifier.refresh()` を呼ぶ。
- **期待結果**: 完了後、state が `AsyncError(Failure.unknown('boom'))` になる（`AsyncValue.guard` による捕捉）。

### テストケース7: 取得に成功した場合、id をキーに name を値とする Map になる
- **カテゴリ**: 正常系
- **対象メソッド**: folderNames()
- **事前条件**: `folderNamesProvider` が未 build。
- **入力値・テスト条件**: `getFoldersUseCaseProvider` が `Right(testFolders)`（2件: folder-1=英単語, folder-2=TOEIC 頻出）を返す。
- **操作手順**: `container.read(folderNamesProvider.future)` を呼ぶ。
- **期待結果**: `{'folder-1': '英単語', 'folder-2': 'TOEIC 頻出'}` が返る。

### テストケース8: フォルダが0件の場合、空の Map になる
- **カテゴリ**: 境界値
- **対象メソッド**: folderNames()
- **事前条件**: `folderNamesProvider` が未 build。
- **入力値・テスト条件**: `getFoldersUseCaseProvider` が `Right([])` を返す。
- **操作手順**: `container.read(folderNamesProvider.future)` を呼ぶ。
- **期待結果**: 空の Map が返る。

### テストケース9: 取得に失敗した場合、例外を投げず空の Map になる
- **カテゴリ**: 異常系
- **対象メソッド**: folderNames()
- **事前条件**: `folderNamesProvider` が未 build。
- **入力値・テスト条件**: `getFoldersUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `container.read(folderNamesProvider.future)` を呼ぶ。
- **期待結果**: `fold((f) => {}, ...)` により例外を送出せず空の Map が返り、`folderNamesProvider` の state は `AsyncError` にならない（`ResultViewModel.build()` の `fold((f) => throw f, ...)` とは異なる、失敗時サイレントフォールバックの分岐であることを確認）。

## 対象外

なし（`resultViewModelProvider` の build()/refresh() と `folderNamesProvider` の全分岐
（成功・空・失敗）を網羅しているため、`lib/presentation/result/result_view_model.dart` の
実行可能行はすべてケース内でカバーされる見込み）。
