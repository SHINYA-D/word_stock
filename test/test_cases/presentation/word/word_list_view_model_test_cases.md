# word_list_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/word/word_list_view_model.dart |
| クラス名 | WordListViewModel |
| テスト対象メソッド | build() / refresh() / createWord() / updateWord() / deleteWord() |

## 実行環境について

`WordListViewModel` は `@riverpod class`（family, `folderId: String`）で `getWordsUseCaseProvider` /
`createWordUseCaseProvider` / `updateWordUseCaseProvider` / `deleteWordUseCaseProvider` /
`currentUserProvider` に依存する。`ProviderContainer(overrides: [...])` で各 UseCase を
手書き Fake（`FakeGetWordsUseCase` / `FakeCreateWordUseCase` / `FakeUpdateWordUseCase` /
`FakeDeleteWordUseCase`）に差し替え、Widget は一切 pump せず notifier を直接操作して検証する。
`FakeGetWordsUseCase` は呼び出しごとに異なる `Either` を返せるようにし、`refresh()` の
2回目呼び出し（build 成功後の再取得）の分岐を検証できるようにしている。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 取得に成功した場合、単語一覧が state に反映される | 正常系 | build() | ✅ |
| 2 | 取得結果が空リストの場合、空の state になる | 境界値 | build() | ✅ |
| 3 | 取得に失敗した場合、AsyncError になる | 異常系 | build() | ✅ |
| 4 | 再取得に成功した場合、最新の単語一覧に更新される | 正常系 | refresh() | ✅ |
| 5 | 再取得に失敗した場合、AsyncError に遷移する | 異常系 | refresh() | ✅ |
| 6 | 作成に成功した場合、新しい単語が現在のリストの末尾に追加される | 正常系 | createWord() | ✅ |
| 7 | 現在のリストが空の場合に作成すると、作成した単語のみのリストになる | 境界値 | createWord() | ✅ |
| 8 | 作成に失敗した場合、AsyncError になり既存のリストは失われる | 異常系 | createWord() | ✅ |
| 9 | 更新に成功した場合、該当する id の単語が置き換わる | 正常系 | updateWord() | ✅ |
| 10 | 存在しない wordId を指定した場合、リストは変化せず更新結果は反映されない | 境界値 | updateWord() | ✅ |
| 11 | 更新に失敗した場合、AsyncError になる | 異常系 | updateWord() | ✅ |
| 12 | 削除に成功した場合、該当する id の単語がリストから除外される | 正常系 | deleteWord() | ✅ |
| 13 | 残り1件を削除した場合、空リストになる | 境界値 | deleteWord() | ✅ |
| 14 | 存在しない wordId を指定した場合、リストは変化しない | 境界値 | deleteWord() | ✅ |
| 15 | 削除に失敗した場合、AsyncError になる | 異常系 | deleteWord() | ✅ |

## テストケース詳細

### テストケース1: 取得に成功した場合、単語一覧が state に反映される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `wordListViewModelProvider(folderId)` が未 build（コンテナ生成直後）。
- **入力値・テスト条件**: `getWordsUseCaseProvider` が `Right(testWords)`（3件）を返す。
- **操作手順**: `container.read(wordListViewModelProvider(folderId).future)` を呼ぶ。
- **期待結果**: 結果が `testWords` と一致し、state.value も同じ。

### テストケース2: 取得結果が空リストの場合、空の state になる
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: `wordListViewModelProvider(folderId)` が未 build。
- **入力値・テスト条件**: `getWordsUseCaseProvider` が `Right([])` を返す。
- **操作手順**: `container.read(wordListViewModelProvider(folderId).future)` を呼ぶ。
- **期待結果**: 結果が空リストになる。

### テストケース3: 取得に失敗した場合、AsyncError になる
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: `wordListViewModelProvider(folderId)` が未 build。
- **入力値・テスト条件**: `getWordsUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `container.read(wordListViewModelProvider(folderId).future)` を呼ぶ。
- **期待結果**: `build()` 内の `fold((f) => throw f, ...)` により例外が送出され、state が `AsyncError(Failure.network())` になる。

### テストケース4: 再取得に成功した場合、最新の単語一覧に更新される
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: 初回 build 成功済みで `state.value == testWords`。
- **入力値・テスト条件**: `refresh()` 呼び出し時に `getWordsUseCaseProvider` が `Right([testWords.first])` を返す。
- **操作手順**: `notifier.refresh()` を呼ぶ。
- **期待結果**: 呼び出し直後は state が `AsyncLoading`、完了後は `state.value` が更新後のリストになる。

### テストケース5: 再取得に失敗した場合、AsyncError に遷移する
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初回 build 成功済みで `state.value == testWords`。
- **入力値・テスト条件**: `refresh()` 呼び出し時に `getWordsUseCaseProvider` が `Left(Failure.unknown('boom'))` を返す。
- **操作手順**: `await notifier.refresh()` を呼ぶ。
- **期待結果**: 完了後、state が `AsyncError(Failure.unknown('boom'))` になる（`AsyncValue.guard` による捕捉）。

### テストケース6: 作成に成功した場合、新しい単語が現在のリストの末尾に追加される
- **カテゴリ**: 正常系
- **対象メソッド**: createWord()
- **事前条件**: build 済みで `state.value == testWords`（3件）。
- **入力値・テスト条件**: `createWordUseCaseProvider` が新規 `Word('word-new', front: 'grape', back: 'ぶどう')` を返す。
- **操作手順**: `notifier.createWord(front: 'grape', back: 'ぶどう')` を呼ぶ。
- **期待結果**: `state.value` が `[...testWords, newWord]` になる。

### テストケース7: 現在のリストが空の場合に作成すると、作成した単語のみのリストになる
- **カテゴリ**: 境界値
- **対象メソッド**: createWord()
- **事前条件**: build 済みで `state.value` が空リスト。
- **入力値・テスト条件**: `createWordUseCaseProvider` が新規 `Word` を返す。
- **操作手順**: `notifier.createWord(front: 'grape', back: 'ぶどう')` を呼ぶ。
- **期待結果**: `state.value` が `[newWord]` になる（`state.valueOrNull ?? []` の空リスト分岐を確認）。

### テストケース8: 作成に失敗した場合、AsyncError になり既存のリストは失われる
- **カテゴリ**: 異常系
- **対象メソッド**: createWord()
- **事前条件**: build 済みで `state.value == testWords`。
- **入力値・テスト条件**: `createWordUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `notifier.createWord(front: 'grape', back: 'ぶどう')` を呼ぶ。
- **期待結果**: `state` が `AsyncError(Failure.network())` になる。

### テストケース9: 更新に成功した場合、該当する id の単語が置き換わる
- **カテゴリ**: 正常系
- **対象メソッド**: updateWord()
- **事前条件**: build 済みで `state.value == testWords`（word-1〜3）。
- **入力値・テスト条件**: `updateWordUseCaseProvider` が `word-1` を更新した `Word` を返す。
- **操作手順**: `notifier.updateWord(wordId: 'word-1', front: 'apple-updated', back: 'りんご(更新)')` を呼ぶ。
- **期待結果**: `state.value` の `word-1` のみが更新後の `Word` に置き換わり、他は変化しない。

### テストケース10: 存在しない wordId を指定した場合、リストは変化せず更新結果は反映されない
- **カテゴリ**: 境界値
- **対象メソッド**: updateWord()
- **事前条件**: build 済みで `state.value == testWords`。
- **入力値・テスト条件**: `updateWordUseCaseProvider` が `id: 'not-exist'` の `Word` を返す。
- **操作手順**: `notifier.updateWord(wordId: 'not-exist', front: 'x', back: 'y')` を呼ぶ。
- **期待結果**: `current.map((w) => w.id == wordId ? updated : w)` の条件に一致する要素が無いため、`state.value` は build 時の `testWords` のまま変化しない。

### テストケース11: 更新に失敗した場合、AsyncError になる
- **カテゴリ**: 異常系
- **対象メソッド**: updateWord()
- **事前条件**: build 済みで `state.value == testWords`。
- **入力値・テスト条件**: `updateWordUseCaseProvider` が `Left(Failure.auth())` を返す。
- **操作手順**: `notifier.updateWord(wordId: 'word-1', front: 'a', back: 'b')` を呼ぶ。
- **期待結果**: `state` が `AsyncError(Failure.auth())` になる。

### テストケース12: 削除に成功した場合、該当する id の単語がリストから除外される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteWord()
- **事前条件**: build 済みで `state.value == testWords`（3件）。
- **入力値・テスト条件**: `deleteWordUseCaseProvider` が `Right(unit)` を返す。
- **操作手順**: `notifier.deleteWord(wordId: 'word-2')` を呼ぶ。
- **期待結果**: `state.value` が `[testWords[0], testWords[2]]` になる。

### テストケース13: 残り1件を削除した場合、空リストになる
- **カテゴリ**: 境界値
- **対象メソッド**: deleteWord()
- **事前条件**: build 済みで `state.value` が1件のみのリスト。
- **入力値・テスト条件**: `deleteWordUseCaseProvider` が `Right(unit)` を返す。
- **操作手順**: `notifier.deleteWord(wordId: testWords.first.id)` を呼ぶ。
- **期待結果**: `state.value` が空リストになる。

### テストケース14: 存在しない wordId を指定した場合、リストは変化しない
- **カテゴリ**: 境界値
- **対象メソッド**: deleteWord()
- **事前条件**: build 済みで `state.value == testWords`。
- **入力値・テスト条件**: `deleteWordUseCaseProvider` が `Right(unit)` を返すが、指定した `wordId` がリストに存在しない。
- **操作手順**: `notifier.deleteWord(wordId: 'not-exist')` を呼ぶ。
- **期待結果**: `current.where((w) => w.id != wordId)` が全件通過するため、`state.value` は build 時の `testWords` のまま変化しない。

### テストケース15: 削除に失敗した場合、AsyncError になる
- **カテゴリ**: 異常系
- **対象メソッド**: deleteWord()
- **事前条件**: build 済みで `state.value == testWords`。
- **入力値・テスト条件**: `deleteWordUseCaseProvider` が `Left(Failure.notFound())` を返す。
- **操作手順**: `notifier.deleteWord(wordId: 'word-1')` を呼ぶ。
- **期待結果**: `state` が `AsyncError(Failure.notFound())` になる。

## 対象外

なし（`bash scripts/test_harness.sh test/presentation/word/word_list_view_model_test.dart` で
対象ファイル `lib/presentation/word/word_list_view_model.dart` は 100.0% カバレッジを達成）。
