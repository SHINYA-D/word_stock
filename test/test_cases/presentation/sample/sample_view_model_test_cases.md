# sample_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/sample/sample_view_model.dart |
| クラス名 | SampleViewModel |
| テスト対象メソッド | build() / refresh() / createSample() / updateSample() / deleteSample() |
| 仕様書 | docs/detailed_design/presentation/sample/sample_page.md |

## 実行環境について

`SampleViewModel` は `GetSamplesUseCase` / `CreateSampleUseCase` / `UpdateSampleUseCase` /
`DeleteSampleUseCase` にのみ依存する `@riverpod` の同期 Notifier（`build()` は `SampleState` を
同期的に返し、内部で `Future.microtask` により初期ロードを行う）。
`ProviderContainer(overrides: [...])` と手書き Fake（Riverpod Provider 経由で注入）で検証する。
仕様書 4章の「ログイン中のユーザーは id が `u1` のユーザーとする」に合わせ、
`currentUserProvider` を `id: 'u1'` のテスト用ユーザーで上書きしている。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | 生成した直後、初期読み込みが完了していない場合、samples は AsyncLoading になる [SMP-V01 #7fe5c0] | SMP-V01 #7fe5c0 | 境界値 | build() | ✅ |
| 2 | getSamples が「A」「B」（作成日時が古い順）を返した場合、samples は AsyncData([A, B]) になり、getSamples が userId u1 で1回呼ばれる [SMP-V02 #741bef] | SMP-V02 #741bef | 正常系 | build() | ✅ |
| 3 | getSamples が空の一覧を返した場合、samples は AsyncData([]) になる [SMP-V03 #23dca6] | SMP-V03 #23dca6 | 正常系 | build() | ✅ |
| 4 | getSamples が UnknownFailure を返した場合、samples は AsyncError(UnknownFailure) になる [SMP-V04 #9f3345] | SMP-V04 #9f3345 | 異常系 | build() | ✅ |
| 5 | getSamples が NotFoundFailure を返した場合、samples は AsyncError(NotFoundFailure) になる [SMP-V05 #2d2b4c] | SMP-V05 #2d2b4c | 異常系 | build() | ✅ |
| 6 | getSamples が NetworkFailure を返した場合、operationFailure は NetworkFailure になり、samples は AsyncData([]) になる [SMP-V06 #d6a69b] | SMP-V06 #d6a69b | 異常系 | build() | ✅ |
| 7 | getSamples が AuthFailure を返した場合、operationFailure は AuthFailure になり、samples は AsyncData([]) になる [SMP-V07 #b65944] | SMP-V07 #b65944 | 異常系 | build() | ✅ |
| 8 | 初期読み込みが UnknownFailure で失敗した状態で、getSamples が「A」を返すようにして refresh を呼んだ場合、samples は AsyncData([A]) になり、getSamples が2回目の呼び出しでも userId u1 で呼ばれる [SMP-V08 #e2bf2c] | SMP-V08 #e2bf2c | 正常系 | refresh() | ✅ |
| 9 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、読み込みが完了していない場合、samples は AsyncLoading になる [SMP-V09 #0551fd] | SMP-V09 #0551fd | 境界値 | refresh() | ✅ |
| 10 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が再び UnknownFailure を返した場合、samples は AsyncError(UnknownFailure) になる [SMP-V10 #0e8d4b] | SMP-V10 #0e8d4b | 異常系 | refresh() | ✅ |
| 11 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples は AsyncError(NotFoundFailure) になる [SMP-V11 #86bf63] | SMP-V11 #86bf63 | 異常系 | refresh() | ✅ |
| 12 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NetworkFailure を返した場合、operationFailure は NetworkFailure になる [SMP-V12 #d97a68] | SMP-V12 #d97a68 | 異常系 | refresh() | ✅ |
| 13 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が AuthFailure を返した場合、operationFailure は AuthFailure になる [SMP-V13 #0ea055] | SMP-V13 #0ea055 | 異常系 | refresh() | ✅ |
| 14 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が「A」「B」を返した場合、samples は AsyncData([A, B]) になり、getSamples が userId u1 で呼ばれる [SMP-V14 #f3b21c] | SMP-V14 #f3b21c | 正常系 | refresh() | ✅ |
| 15 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が UnknownFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は UnknownFailure になる [SMP-V15 #e5b719] | SMP-V15 #e5b719 | 異常系 | refresh() | ✅ |
| 16 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NotFoundFailure になる [SMP-V16 #21b3a4] | SMP-V16 #21b3a4 | 異常系 | refresh() | ✅ |
| 17 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NetworkFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NetworkFailure になる [SMP-V17 #148c4b] | SMP-V17 #148c4b | 異常系 | refresh() | ✅ |
| 18 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が AuthFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は AuthFailure になる [SMP-V18 #ccb1d4] | SMP-V18 #ccb1d4 | 異常系 | refresh() | ✅ |
| 19 | samples が AsyncData([]) の状態で refresh を呼び、getSamples が「A」を返した場合、samples は AsyncData([A]) になる [SMP-V19 #e1bb86] | SMP-V19 #e1bb86 | 正常系 | refresh() | ✅ |
| 20 | samples が AsyncData([A]) の状態で refresh を呼び、読み込みが完了していない場合、samples は AsyncData([A]) のままである [SMP-V42 #e80659] | SMP-V42 #e80659 | 境界値 | refresh() | ✅ |
| 21 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples は AsyncData([A, B]) になり、createSample が userId u1、name 「B」で1回呼ばれる [SMP-V20 #ac3fa6] | SMP-V20 #ac3fa6 | 正常系 | createSample() | ✅ |
| 22 | samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples は AsyncData([B]) になり、createSample が userId u1、name 「B」で1回呼ばれる [SMP-V21 #74719e] | SMP-V21 #74719e | 正常系 | createSample() | ✅ |
| 23 | samples が AsyncData([A]) の状態で createSample（name: 「A」）を呼び、createSample が「A」と別の id を持つ新しいサンプル「A」を返した場合、samples は2件で、どちらの name も「A」、id は互いに異なる [SMP-V22 #ba49ae] | SMP-V22 #ba49ae | 境界値 | createSample() | ✅ |
| 24 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は UnknownFailure になる [SMP-V23 #0398ac] | SMP-V23 #0398ac | 異常系 | createSample() | ✅ |
| 25 | samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples は AsyncData([]) のままで、operationFailure は UnknownFailure になる [SMP-V24 #b8ebc4] | SMP-V24 #b8ebc4 | 異常系 | createSample() | ✅ |
| 26 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が NetworkFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NetworkFailure になる [SMP-V25 #08063d] | SMP-V25 #08063d | 異常系 | createSample() | ✅ |
| 27 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が AuthFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は AuthFailure になる [SMP-V26 #37e03f] | SMP-V26 #37e03f | 異常系 | createSample() | ✅ |
| 28 | samples が AsyncData([A, B, C]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が B の id を持つ「X」を返した場合、samples は AsyncData([A, X, C]) になり、updateSample が userId u1、sampleId B の id、name 「X」で1回呼ばれる [SMP-V27 #703d7d] | SMP-V27 #703d7d | 正常系 | updateSample() | ✅ |
| 29 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「A」）を呼び、updateSample が B の id を持つ「A」を返した場合、samples は2件で、上から A の id の「A」、B の id の「A」になる [SMP-V28 #4211b1] | SMP-V28 #4211b1 | 境界値 | updateSample() | ✅ |
| 30 | samples が AsyncData([A]) の状態で updateSample（sampleId: A の id、name: 「A」）を呼び、updateSample が A の id を持つ「A」を返した場合、samples は1件で、A の id の「A」になる [SMP-V29 #4b8c44] | SMP-V29 #4b8c44 | 境界値 | updateSample() | ✅ |
| 31 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が UnknownFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は UnknownFailure になる [SMP-V30 #f37e41] | SMP-V30 #f37e41 | 異常系 | updateSample() | ✅ |
| 32 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が NotFoundFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NotFoundFailure になる [SMP-V31 #3fdfbf] | SMP-V31 #3fdfbf | 異常系 | updateSample() | ✅ |
| 33 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が NetworkFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NetworkFailure になる [SMP-V32 #1c4b53] | SMP-V32 #1c4b53 | 異常系 | updateSample() | ✅ |
| 34 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が AuthFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は AuthFailure になる [SMP-V33 #b2d978] | SMP-V33 #b2d978 | 異常系 | updateSample() | ✅ |
| 35 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples は AsyncData([B]) になり、deleteSample が userId u1、sampleId A の id で1回呼ばれる [SMP-V34 #334f2e] | SMP-V34 #334f2e | 正常系 | deleteSample() | ✅ |
| 36 | samples が AsyncData([A, B, C]) の状態で deleteSample（sampleId: B の id）を呼び、deleteSample が成功し、その後の getSamples が「A」「C」を返した場合、samples は AsyncData([A, C]) になる [SMP-V35 #7baf62] | SMP-V35 #7baf62 | 正常系 | deleteSample() | ✅ |
| 37 | samples が AsyncData([A]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が空の一覧を返した場合、samples は AsyncData([]) になる [SMP-V36 #e9b1d5] | SMP-V36 #e9b1d5 | 正常系 | deleteSample() | ✅ |
| 38 | samples が AsyncData([A, B]) で、Repository 上では A が既に削除されている状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples は AsyncData([B]) になり、operationFailure は null になる [SMP-V37 #012201] | SMP-V37 #012201 | 境界値 | deleteSample() | ✅ |
| 39 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が UnknownFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は UnknownFailure になる [SMP-V38 #b32133] | SMP-V38 #b32133 | 異常系 | deleteSample() | ✅ |
| 40 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が NotFoundFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NotFoundFailure になる [SMP-V39 #da4019] | SMP-V39 #da4019 | 異常系 | deleteSample() | ✅ |
| 41 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が NetworkFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NetworkFailure になる [SMP-V40 #75c7ef] | SMP-V40 #75c7ef | 異常系 | deleteSample() | ✅ |
| 42 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が AuthFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は AuthFailure になる [SMP-V41 #a205ef] | SMP-V41 #a205ef | 異常系 | deleteSample() | ✅ |
| 43 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、その完了前に createSample（name: 「C」）を呼んで、createSample が「C」を返し、deleteSample が成功し、削除後の getSamples が「B」「C」を返した場合、両方の完了後 samples は AsyncData([B, C]) になる [SMP-V43 #ab4762] | SMP-V43 #ab4762 | 境界値 | deleteSample() | ✅ |
| 44 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、その完了前に refresh を呼んで、refresh の getSamples が「A」「B」を、削除後の getSamples が「B」を返し、refresh の方が後に完了した場合、両方の完了後 samples は AsyncData([B]) になる [SMP-V44 #3c8a70] | SMP-V44 #3c8a70 | 境界値 | deleteSample() | ✅ |

## テストケース詳細

### テストケース1: 生成した直後、初期読み込みが完了していない場合、samples は AsyncLoading になる [SMP-V01 #7fe5c0]
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: ViewModel を生成した直後（`Future.microtask` の初期ロードが未実行）
- **操作手順**: `container.read(sampleViewModelProvider)` を呼ぶ
- **期待結果**: `samples` は `AsyncLoading`

### テストケース2: getSamples が「A」「B」（作成日時が古い順）を返した場合、samples は AsyncData([A, B]) になり、getSamples が userId u1 で1回呼ばれる [SMP-V02 #741bef]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: `GetSamplesUseCase` が `Right([A, B])`（作成日時が古い順）を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])`。`getSamples` が userId `u1` で1回呼ばれる

### テストケース3: getSamples が空の一覧を返した場合、samples は AsyncData([]) になる [SMP-V03 #23dca6]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: `GetSamplesUseCase` が `Right([])` を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: `samples` は `AsyncData([])`

### テストケース4: getSamples が UnknownFailure を返した場合、samples は AsyncError(UnknownFailure) になる [SMP-V04 #9f3345]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: `GetSamplesUseCase` が `Left(Failure.unknown('boom'))` を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: `samples` は `AsyncError(UnknownFailure)`

### テストケース5: getSamples が NotFoundFailure を返した場合、samples は AsyncError(NotFoundFailure) になる [SMP-V05 #2d2b4c]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: `GetSamplesUseCase` が `Left(Failure.notFound())` を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: `samples` は `AsyncError(NotFoundFailure)`

### テストケース6: getSamples が NetworkFailure を返した場合、operationFailure は NetworkFailure になり、samples は AsyncData([]) になる [SMP-V06 #d6a69b]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: `GetSamplesUseCase` が `Left(Failure.network())` を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: `operationFailure` は `NetworkFailure`。`samples` は `AsyncData([])`

### テストケース7: getSamples が AuthFailure を返した場合、operationFailure は AuthFailure になり、samples は AsyncData([]) になる [SMP-V07 #b65944]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: `GetSamplesUseCase` が `Left(Failure.auth())` を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: `operationFailure` は `AuthFailure`。`samples` は `AsyncData([])`

### テストケース8: 初期読み込みが UnknownFailure で失敗した状態で、getSamples が「A」を返すようにして refresh を呼んだ場合、samples は AsyncData([A]) になり、getSamples が2回目の呼び出しでも userId u1 で呼ばれる [SMP-V08 #e2bf2c]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが `UnknownFailure` で失敗している
- **入力値・テスト条件**: 2回目の `getSamples` が `Right([A])` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])`。`getSamples` が2回目の呼び出しでも userId `u1` で呼ばれる

### テストケース9: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、読み込みが完了していない場合、samples は AsyncLoading になる [SMP-V09 #0551fd]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが `UnknownFailure` で失敗している
- **入力値・テスト条件**: 2回目の `getSamples` の完了を Completer でゲートし、完了していない状態を作る
- **操作手順**: `refresh()` を呼び、完了前に state を確認する
- **期待結果**: `samples` は `AsyncLoading`

### テストケース10: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が再び UnknownFailure を返した場合、samples は AsyncError(UnknownFailure) になる [SMP-V10 #0e8d4b]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが `UnknownFailure` で失敗している
- **入力値・テスト条件**: 2回目の `getSamples` も `Left(Failure.unknown('boom'))` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncError(UnknownFailure)`

### テストケース11: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples は AsyncError(NotFoundFailure) になる [SMP-V11 #86bf63]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが `UnknownFailure` で失敗している
- **入力値・テスト条件**: 2回目の `getSamples` が `Left(Failure.notFound())` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncError(NotFoundFailure)`

### テストケース12: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NetworkFailure を返した場合、operationFailure は NetworkFailure になる [SMP-V12 #d97a68]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが `UnknownFailure` で失敗している
- **入力値・テスト条件**: 2回目の `getSamples` が `Left(Failure.network())` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `operationFailure` は `NetworkFailure`

### テストケース13: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が AuthFailure を返した場合、operationFailure は AuthFailure になる [SMP-V13 #0ea055]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが `UnknownFailure` で失敗している
- **入力値・テスト条件**: 2回目の `getSamples` が `Left(Failure.auth())` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `operationFailure` は `AuthFailure`

### テストケース14: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が「A」「B」を返した場合、samples は AsyncData([A, B]) になり、getSamples が userId u1 で呼ばれる [SMP-V14 #f3b21c]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: 2回目の `getSamples` が `Right([A, B])` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])`。`getSamples` が userId `u1` で呼ばれる

### テストケース15: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が UnknownFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は UnknownFailure になる [SMP-V15 #e5b719]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: 2回目の `getSamples` が `Left(Failure.unknown('boom'))` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `UnknownFailure`

### テストケース16: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NotFoundFailure になる [SMP-V16 #21b3a4]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: 2回目の `getSamples` が `Left(Failure.notFound())` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NotFoundFailure`

### テストケース17: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NetworkFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NetworkFailure になる [SMP-V17 #148c4b]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: 2回目の `getSamples` が `Left(Failure.network())` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース18: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が AuthFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は AuthFailure になる [SMP-V18 #ccb1d4]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: 2回目の `getSamples` が `Left(Failure.auth())` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

### テストケース19: samples が AsyncData([]) の状態で refresh を呼び、getSamples が「A」を返した場合、samples は AsyncData([A]) になる [SMP-V19 #e1bb86]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([])`
- **入力値・テスト条件**: 2回目の `getSamples` が `Right([A])` を返す
- **操作手順**: `refresh()` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])`

### テストケース20: samples が AsyncData([A]) の状態で refresh を呼び、読み込みが完了していない場合、samples は AsyncData([A]) のままである [SMP-V42 #e80659]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: 2回目の `getSamples` の完了を Completer でゲートし、完了していない状態を作る
- **操作手順**: `refresh()` を呼び、完了前に state を確認する
- **期待結果**: `samples` は `AsyncData([A])` のまま

### テストケース21: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples は AsyncData([A, B]) になり、createSample が userId u1、name 「B」で1回呼ばれる [SMP-V20 #ac3fa6]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: `createSample(name: 'B')`。`CreateSampleUseCase` が `Right(B)` を返す
- **操作手順**: `createSample(name: 'B')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])`。`createSample` が userId `u1`、name 「B」で1回呼ばれる

### テストケース22: samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples は AsyncData([B]) になり、createSample が userId u1、name 「B」で1回呼ばれる [SMP-V21 #74719e]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([])`
- **入力値・テスト条件**: `createSample(name: 'B')`。`CreateSampleUseCase` が `Right(B)` を返す
- **操作手順**: `createSample(name: 'B')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([B])`。`createSample` が userId `u1`、name 「B」で1回呼ばれる

### テストケース23: samples が AsyncData([A]) の状態で createSample（name: 「A」）を呼び、createSample が「A」と別の id を持つ新しいサンプル「A」を返した場合、samples は2件で、どちらの name も「A」、id は互いに異なる [SMP-V22 #ba49ae]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: `createSample(name: 'A')`。`CreateSampleUseCase` が A とは別の id を持つ name「A」のサンプルを返す
- **操作手順**: `createSample(name: 'A')` を呼び、完了を待つ
- **期待結果**: `samples` は2件で、どちらの `name` も「A」、`id` は互いに異なる

### テストケース24: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は UnknownFailure になる [SMP-V23 #0398ac]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: `createSample(name: 'B')`。`CreateSampleUseCase` が `Left(Failure.unknown('boom'))` を返す
- **操作手順**: `createSample(name: 'B')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `UnknownFailure`

### テストケース25: samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples は AsyncData([]) のままで、operationFailure は UnknownFailure になる [SMP-V24 #b8ebc4]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([])`
- **入力値・テスト条件**: `createSample(name: 'B')`。`CreateSampleUseCase` が `Left(Failure.unknown('boom'))` を返す
- **操作手順**: `createSample(name: 'B')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([])` のまま。`operationFailure` は `UnknownFailure`

### テストケース26: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が NetworkFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NetworkFailure になる [SMP-V25 #08063d]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: `createSample(name: 'B')`。`CreateSampleUseCase` が `Left(Failure.network())` を返す
- **操作手順**: `createSample(name: 'B')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース27: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が AuthFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は AuthFailure になる [SMP-V26 #37e03f]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: `createSample(name: 'B')`。`CreateSampleUseCase` が `Left(Failure.auth())` を返す
- **操作手順**: `createSample(name: 'B')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

### テストケース28: samples が AsyncData([A, B, C]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が B の id を持つ「X」を返した場合、samples は AsyncData([A, X, C]) になり、updateSample が userId u1、sampleId B の id、name 「X」で1回呼ばれる [SMP-V27 #703d7d]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B, C])`
- **入力値・テスト条件**: `updateSample(sampleId: B.id, name: 'X')`。`UpdateSampleUseCase` が B の id を持つ「X」を返す
- **操作手順**: `updateSample(sampleId: B.id, name: 'X')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, X, C])`。`updateSample` が userId `u1`、sampleId B の id、name 「X」で1回呼ばれる

### テストケース29: samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「A」）を呼び、updateSample が B の id を持つ「A」を返した場合、samples は2件で、上から A の id の「A」、B の id の「A」になる [SMP-V28 #4211b1]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `updateSample(sampleId: B.id, name: 'A')`。`UpdateSampleUseCase` が B の id を持つ「A」を返す
- **操作手順**: `updateSample(sampleId: B.id, name: 'A')` を呼び、完了を待つ
- **期待結果**: `samples` は2件で、上から A の id の「A」、B の id の「A」

### テストケース30: samples が AsyncData([A]) の状態で updateSample（sampleId: A の id、name: 「A」）を呼び、updateSample が A の id を持つ「A」を返した場合、samples は1件で、A の id の「A」になる [SMP-V29 #4b8c44]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: `updateSample(sampleId: A.id, name: 'A')`。`UpdateSampleUseCase` が A の id を持つ「A」を返す
- **操作手順**: `updateSample(sampleId: A.id, name: 'A')` を呼び、完了を待つ
- **期待結果**: `samples` は1件で、A の id の「A」

### テストケース31: samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が UnknownFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は UnknownFailure になる [SMP-V30 #f37e41]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `updateSample(sampleId: B.id, name: 'X')`。`UpdateSampleUseCase` が `Left(Failure.unknown('boom'))` を返す
- **操作手順**: `updateSample(sampleId: B.id, name: 'X')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `UnknownFailure`

### テストケース32: samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が NotFoundFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NotFoundFailure になる [SMP-V31 #3fdfbf]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `updateSample(sampleId: B.id, name: 'X')`。`UpdateSampleUseCase` が `Left(Failure.notFound())` を返す
- **操作手順**: `updateSample(sampleId: B.id, name: 'X')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NotFoundFailure`

### テストケース33: samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が NetworkFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NetworkFailure になる [SMP-V32 #1c4b53]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `updateSample(sampleId: B.id, name: 'X')`。`UpdateSampleUseCase` が `Left(Failure.network())` を返す
- **操作手順**: `updateSample(sampleId: B.id, name: 'X')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NetworkFailure`

### テストケース34: samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が AuthFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は AuthFailure になる [SMP-V33 #b2d978]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `updateSample(sampleId: B.id, name: 'X')`。`UpdateSampleUseCase` が `Left(Failure.auth())` を返す
- **操作手順**: `updateSample(sampleId: B.id, name: 'X')` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `AuthFailure`

### テストケース35: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples は AsyncData([B]) になり、deleteSample が userId u1、sampleId A の id で1回呼ばれる [SMP-V34 #334f2e]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)`。`DeleteSampleUseCase` が `Right(unit)` を返し、削除後の `getSamples` が `Right([B])` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼び、内部の再取得（`refresh()`）の完了を待つ
- **期待結果**: `samples` は `AsyncData([B])`。`deleteSample` が userId `u1`、sampleId A の id で1回呼ばれる

### テストケース36: samples が AsyncData([A, B, C]) の状態で deleteSample（sampleId: B の id）を呼び、deleteSample が成功し、その後の getSamples が「A」「C」を返した場合、samples は AsyncData([A, C]) になる [SMP-V35 #7baf62]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B, C])`
- **入力値・テスト条件**: `deleteSample(sampleId: B.id)`。削除後の `getSamples` が `Right([A, C])` を返す
- **操作手順**: `deleteSample(sampleId: B.id)` を呼び、内部の再取得の完了を待つ
- **期待結果**: `samples` は `AsyncData([A, C])`

### テストケース37: samples が AsyncData([A]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が空の一覧を返した場合、samples は AsyncData([]) になる [SMP-V36 #e9b1d5]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)`。削除後の `getSamples` が `Right([])` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼び、内部の再取得の完了を待つ
- **期待結果**: `samples` は `AsyncData([])`

### テストケース38: samples が AsyncData([A, B]) で、Repository 上では A が既に削除されている状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples は AsyncData([B]) になり、operationFailure は null になる [SMP-V37 #012201]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`。リポジトリ契約（SMP-R12）どおり、対象が既に存在しない削除は `Right(unit)` になる
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)`。`DeleteSampleUseCase` が `Right(unit)` を返し、削除後の `getSamples` が `Right([B])` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼び、内部の再取得の完了を待つ
- **期待結果**: `samples` は `AsyncData([B])`。`operationFailure` は `null`

### テストケース39: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が UnknownFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は UnknownFailure になる [SMP-V38 #b32133]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)`。`DeleteSampleUseCase` が `Left(Failure.unknown('boom'))` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `UnknownFailure`

### テストケース40: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が NotFoundFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NotFoundFailure になる [SMP-V39 #da4019]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)`。`DeleteSampleUseCase` が `Left(Failure.notFound())` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NotFoundFailure`

### テストケース41: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が NetworkFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NetworkFailure になる [SMP-V40 #75c7ef]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)`。`DeleteSampleUseCase` が `Left(Failure.network())` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NetworkFailure`

### テストケース42: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が AuthFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は AuthFailure になる [SMP-V41 #a205ef]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)`。`DeleteSampleUseCase` が `Left(Failure.auth())` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼び、完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `AuthFailure`

### テストケース43: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、その完了前に createSample（name: 「C」）を呼んで、createSample が「C」を返し、deleteSample が成功し、削除後の getSamples が「B」「C」を返した場合、両方の完了後 samples は AsyncData([B, C]) になる [SMP-V43 #ab4762]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)` の完了（`DeleteSampleUseCase` の応答）を Completer で保留し、その間に `createSample(name: 'C')` を実行して「C」を反映させてから deleteSample を完了させる。削除後の `getSamples` は `Right([B, C])` を返す
- **操作手順**: `deleteSample(sampleId: A.id)` を呼ぶ（未完了） → `createSample(name: 'C')` を呼んで完了を待つ → delete の完了をゲート解放し、内部の再取得の完了を待つ
- **期待結果**: 両方の完了後、`samples` は `AsyncData([B, C])`

### テストケース44: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、その完了前に refresh を呼んで、refresh の getSamples が「A」「B」を、削除後の getSamples が「B」を返し、refresh の方が後に完了した場合、両方の完了後 samples は AsyncData([B]) になる [SMP-V44 #3c8a70]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteSample(sampleId: A.id)` の直後に `refresh()` を呼ぶ。両方が内部で発行する `getSamples` の完了を Completer で個別にゲートし、削除起因の `getSamples`（`Right([B])`）を先に完了させ、手動 `refresh()` 側の `getSamples`（`Right([A, B])`）を後から完了させる
- **操作手順**: `deleteSample(sampleId: A.id)` を呼ぶ（未完了） → `refresh()` を呼ぶ（未完了） → 削除起因の `getSamples` のゲートを解放して完了を待つ → 手動 `refresh()` 側の `getSamples` のゲートを解放して両方の完了を待つ
- **期待結果**: 両方の完了後、`samples` は `AsyncData([B])`（後から完了した手動 `refresh()` の結果は、実行時に既に古い世代のものとして無視される）
