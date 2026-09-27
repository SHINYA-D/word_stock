# sample_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/sample/sample_view_model.dart |
| クラス名 | SampleViewModel |
| テスト対象メソッド | build() / refresh() / createSample() / updateSample() / deleteSample() |
| 仕様書 | docs/detailed_design/presentation/sample/sample_page.md |

## 実行環境について

`ProviderContainer(overrides: [...])` で `GetSamplesUseCase` / `CreateSampleUseCase` /
`UpdateSampleUseCase` / `DeleteSampleUseCase` / `currentUserProvider` を手書き Fake に
差し替え、`SampleViewModel` の notifier を直接操作する（Widget は pump しない）。
仕様書 4章の「ログイン中のユーザーは id が u1 のユーザーとする」に合わせ、テスト用ユーザーの
id は `u1` に統一している。

`build()` 内の `Future.microtask(() => _initState())` の完了は `await Future<void>.delayed(Duration.zero)`
で待つ。`sampleViewModelProvider` は AutoDispose のため、`container.listen(..., fireImmediately: true)`
でリスナーを保持し、初期読み込みが走る前に provider が破棄されないようにしている。

SMP-V43・SMP-V44（呼び出し順と完了順が食い違う同時実行）は、`GetSamplesUseCase` /
`CreateSampleUseCase` / `DeleteSampleUseCase` の Fake が内部に持つ `Completer` を
テストコードから直接 `complete()` することで、完了順を明示的に制御している。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | ViewModelを生成し、初期読み込みが完了していない場合、samples が AsyncLoading になる [SMP-V01 #7fe5c0] | SMP-V01 #7fe5c0 | 境界値 | build() | ✅ |
| 2 | ViewModelを生成し、getSamples が「A」「B」（作成日時が古い順）を返した場合、samples が AsyncData([A, B]) になり、Repository の getSamples が userId u1 で1回呼ばれる [SMP-V02 #741bef] | SMP-V02 #741bef | 正常系 | build() | ✅ |
| 3 | ViewModelを生成し、getSamples が空の一覧を返した場合、samples が AsyncData([]) になる [SMP-V03 #23dca6] | SMP-V03 #23dca6 | 正常系 | build() | ✅ |
| 4 | ViewModelを生成し、getSamples が UnknownFailure を返した場合、samples が AsyncError(UnknownFailure) になる [SMP-V04 #9f3345] | SMP-V04 #9f3345 | 異常系 | build() | ✅ |
| 5 | ViewModelを生成し、getSamples が NotFoundFailure を返した場合、samples が AsyncError(NotFoundFailure) になる [SMP-V05 #2d2b4c] | SMP-V05 #2d2b4c | 異常系 | build() | ✅ |
| 6 | ViewModelを生成し、getSamples が NetworkFailure を返した場合、operationFailure が NetworkFailure になり、samples が AsyncData([]) になる [SMP-V06 #d6a69b] | SMP-V06 #d6a69b | 異常系 | build() | ✅ |
| 7 | ViewModelを生成し、getSamples が AuthFailure を返した場合、operationFailure が AuthFailure になり、samples が AsyncData([]) になる [SMP-V07 #b65944] | SMP-V07 #b65944 | 異常系 | build() | ✅ |
| 8 | 初期読み込みが UnknownFailure で失敗した状態で、getSamples が「A」を返すようにして refresh を呼んだ場合、samples が AsyncData([A]) になり、Repository の getSamples が2回目の呼び出しでも userId u1 で呼ばれる [SMP-V08 #e2bf2c] | SMP-V08 #e2bf2c | 正常系 | refresh() | ✅ |
| 9 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、読み込みが完了していない場合、samples が AsyncLoading になる [SMP-V09 #0551fd] | SMP-V09 #0551fd | 境界値 | refresh() | ✅ |
| 10 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が再び UnknownFailure を返した場合、samples が AsyncError(UnknownFailure) になる [SMP-V10 #0e8d4b] | SMP-V10 #0e8d4b | 異常系 | refresh() | ✅ |
| 11 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples が AsyncError(NotFoundFailure) になる [SMP-V11 #86bf63] | SMP-V11 #86bf63 | 異常系 | refresh() | ✅ |
| 12 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NetworkFailure を返した場合、operationFailure が NetworkFailure になる [SMP-V12 #d97a68] | SMP-V12 #d97a68 | 異常系 | refresh() | ✅ |
| 13 | 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が AuthFailure を返した場合、operationFailure が AuthFailure になる [SMP-V13 #0ea055] | SMP-V13 #0ea055 | 異常系 | refresh() | ✅ |
| 14 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が「A」「B」を返した場合、samples が AsyncData([A, B]) になり、Repository の getSamples が userId u1 で呼ばれる [SMP-V14 #f3b21c] | SMP-V14 #f3b21c | 正常系 | refresh() | ✅ |
| 15 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が UnknownFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が UnknownFailure になる [SMP-V15 #e5b719] | SMP-V15 #e5b719 | 異常系 | refresh() | ✅ |
| 16 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が NotFoundFailure になる [SMP-V16 #21b3a4] | SMP-V16 #21b3a4 | 異常系 | refresh() | ✅ |
| 17 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NetworkFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が NetworkFailure になる [SMP-V17 #148c4b] | SMP-V17 #148c4b | 異常系 | refresh() | ✅ |
| 18 | samples が AsyncData([A]) の状態で refresh を呼び、getSamples が AuthFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が AuthFailure になる [SMP-V18 #ccb1d4] | SMP-V18 #ccb1d4 | 異常系 | refresh() | ✅ |
| 19 | samples が AsyncData([]) の状態で refresh を呼び、getSamples が「A」を返した場合、samples が AsyncData([A]) になる [SMP-V19 #e1bb86] | SMP-V19 #e1bb86 | 正常系 | refresh() | ✅ |
| 20 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples が AsyncData([A, B]) になり、Repository の createSample が userId u1、name 「B」で1回呼ばれる [SMP-V20 #ac3fa6] | SMP-V20 #ac3fa6 | 正常系 | createSample() | ✅ |
| 21 | samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples が AsyncData([B]) になり、Repository の createSample が userId u1、name 「B」で1回呼ばれる [SMP-V21 #74719e] | SMP-V21 #74719e | 正常系 | createSample() | ✅ |
| 22 | samples が AsyncData([A]) の状態で createSample（name: 「A」）を呼び、createSample が「A」と別の id を持つ新しいサンプル「A」を返した場合、samples は2件で、どちらの name も「A」、id は互いに異なる [SMP-V22 #ba49ae] | SMP-V22 #ba49ae | 境界値 | createSample() | ✅ |
| 23 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が UnknownFailure になる [SMP-V23 #0398ac] | SMP-V23 #0398ac | 異常系 | createSample() | ✅ |
| 24 | samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples が AsyncData([]) のままになり、operationFailure が UnknownFailure になる [SMP-V24 #b8ebc4] | SMP-V24 #b8ebc4 | 異常系 | createSample() | ✅ |
| 25 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が NetworkFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が NetworkFailure になる [SMP-V25 #08063d] | SMP-V25 #08063d | 異常系 | createSample() | ✅ |
| 26 | samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が AuthFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が AuthFailure になる [SMP-V26 #37e03f] | SMP-V26 #37e03f | 異常系 | createSample() | ✅ |
| 27 | samples が AsyncData([A, B, C]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が Bのid を持つ「X」を返した場合、samples が AsyncData([A, X, C]) になり、Repository の updateSample が userId u1、sampleId Bのid、name 「X」で1回呼ばれる [SMP-V27 #703d7d] | SMP-V27 #703d7d | 正常系 | updateSample() | ✅ |
| 28 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「A」）を呼び、updateSample が Bのid を持つ「A」を返した場合、samples は2件で、上から Aのidの「A」、Bのidの「A」になる [SMP-V28 #4211b1] | SMP-V28 #4211b1 | 境界値 | updateSample() | ✅ |
| 29 | samples が AsyncData([A]) の状態で updateSample（sampleId: Aのid、name: 「A」）を呼び、updateSample が Aのid を持つ「A」を返した場合、samples は1件で Aのidの「A」になる [SMP-V29 #4b8c44] | SMP-V29 #4b8c44 | 境界値 | updateSample() | ✅ |
| 30 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が UnknownFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が UnknownFailure になる [SMP-V30 #f37e41] | SMP-V30 #f37e41 | 異常系 | updateSample() | ✅ |
| 31 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が NotFoundFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NotFoundFailure になる [SMP-V31 #3fdfbf] | SMP-V31 #3fdfbf | 異常系 | updateSample() | ✅ |
| 32 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が NetworkFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NetworkFailure になる [SMP-V32 #1c4b53] | SMP-V32 #1c4b53 | 異常系 | updateSample() | ✅ |
| 33 | samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が AuthFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が AuthFailure になる [SMP-V33 #b2d978] | SMP-V33 #b2d978 | 異常系 | updateSample() | ✅ |
| 34 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples が AsyncData([B]) になり、Repository の deleteSample が userId u1、sampleId Aのidで1回呼ばれる [SMP-V34 #334f2e] | SMP-V34 #334f2e | 正常系 | deleteSample() | ✅ |
| 35 | samples が AsyncData([A, B, C]) の状態で deleteSample（sampleId: Bのid）を呼び、deleteSample が成功し、その後の getSamples が「A」「C」を返した場合、samples が AsyncData([A, C]) になる [SMP-V35 #7baf62] | SMP-V35 #7baf62 | 正常系 | deleteSample() | ✅ |
| 36 | samples が AsyncData([A]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が成功し、その後の getSamples が空の一覧を返した場合、samples が AsyncData([]) になる [SMP-V36 #e9b1d5] | SMP-V36 #e9b1d5 | 正常系 | deleteSample() | ✅ |
| 37 | samples が AsyncData([A, B])（Repository上ではAが既に削除されている）の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples が AsyncData([B]) になり、operationFailure が null になる [SMP-V37 #012201] | SMP-V37 #012201 | 正常系 | deleteSample() | ✅ |
| 38 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が UnknownFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が UnknownFailure になる [SMP-V38 #b32133] | SMP-V38 #b32133 | 異常系 | deleteSample() | ✅ |
| 39 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が NotFoundFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NotFoundFailure になる [SMP-V39 #da4019] | SMP-V39 #da4019 | 異常系 | deleteSample() | ✅ |
| 40 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が NetworkFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NetworkFailure になる [SMP-V40 #75c7ef] | SMP-V40 #75c7ef | 異常系 | deleteSample() | ✅ |
| 41 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が AuthFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が AuthFailure になる [SMP-V41 #a205ef] | SMP-V41 #a205ef | 異常系 | deleteSample() | ✅ |
| 42 | samples が AsyncData([A]) の状態で refresh を呼び、読み込みが完了していない場合、samples が AsyncData([A]) のままになる [SMP-V42 #e80659] | SMP-V42 #e80659 | 境界値 | refresh() | ✅ |
| 43 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、その完了前に createSample（name: 「C」）を呼んで、createSample が「C」を返し、deleteSample が成功し、削除後の getSamples が「B」「C」を返した場合、両方の完了後、samples が AsyncData([B, C]) になる [SMP-V43 #ab4762] | SMP-V43 #ab4762 | 境界値 | createSample() / deleteSample() | ✅ |
| 44 | samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、その完了前に refresh を呼んで、refresh の getSamples が「A」「B」を、削除後の getSamples が「B」を返し、refresh の方が後に完了した場合、両方の完了後、samples が AsyncData([B]) になる [SMP-V44 #3c8a70] | SMP-V44 #3c8a70 | 境界値 | refresh() / deleteSample() | ✅ |

## テストケース詳細

### テストケース1: ViewModelを生成し、初期読み込みが完了していない場合、samples が AsyncLoading になる [SMP-V01 #7fe5c0]
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: getSamples が「A」「B」を返すよう設定しているが、まだ解決していない
- **操作手順**: ViewModel を生成し、初期読み込みが完了していない状態で state を読む
- **期待結果**: samples は AsyncLoading

### テストケース2: ViewModelを生成し、getSamples が「A」「B」（作成日時が古い順）を返した場合、samples が AsyncData([A, B]) になり、Repository の getSamples が userId u1 で1回呼ばれる [SMP-V02 #741bef]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: getSamples が「A」「B」（作成日時が古い順）を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: samples は AsyncData([A, B])。Repository の getSamples が userId u1 で1回呼ばれる

### テストケース3: ViewModelを生成し、getSamples が空の一覧を返した場合、samples が AsyncData([]) になる [SMP-V03 #23dca6]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: getSamples が空の一覧を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: samples は AsyncData([])

### テストケース4: ViewModelを生成し、getSamples が UnknownFailure を返した場合、samples が AsyncError(UnknownFailure) になる [SMP-V04 #9f3345]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: getSamples が UnknownFailure を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: samples は AsyncError(UnknownFailure)

### テストケース5: ViewModelを生成し、getSamples が NotFoundFailure を返した場合、samples が AsyncError(NotFoundFailure) になる [SMP-V05 #2d2b4c]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: getSamples が NotFoundFailure を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: samples は AsyncError(NotFoundFailure)

### テストケース6: ViewModelを生成し、getSamples が NetworkFailure を返した場合、operationFailure が NetworkFailure になり、samples が AsyncData([]) になる [SMP-V06 #d6a69b]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: getSamples が NetworkFailure を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: operationFailure は NetworkFailure。samples は AsyncData([])

### テストケース7: ViewModelを生成し、getSamples が AuthFailure を返した場合、operationFailure が AuthFailure になり、samples が AsyncData([]) になる [SMP-V07 #b65944]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: getSamples が AuthFailure を返す
- **操作手順**: ViewModel を生成し、初期読み込みの完了を待つ
- **期待結果**: operationFailure は AuthFailure。samples は AsyncData([])

### テストケース8: 初期読み込みが UnknownFailure で失敗した状態で、getSamples が「A」を返すようにして refresh を呼んだ場合、samples が AsyncData([A]) になり、Repository の getSamples が2回目の呼び出しでも userId u1 で呼ばれる [SMP-V08 #e2bf2c]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗している
- **入力値・テスト条件**: refresh 時の getSamples が「A」を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A])。Repository の getSamples が2回目の呼び出しでも userId u1 で呼ばれる

### テストケース9: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、読み込みが完了していない場合、samples が AsyncLoading になる [SMP-V09 #0551fd]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗している
- **入力値・テスト条件**: refresh の getSamples がまだ解決していない
- **操作手順**: refresh() を呼び、完了を待たずに state を読む
- **期待結果**: samples は AsyncLoading

### テストケース10: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が再び UnknownFailure を返した場合、samples が AsyncError(UnknownFailure) になる [SMP-V10 #0e8d4b]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗している
- **入力値・テスト条件**: refresh 時の getSamples が再び UnknownFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncError(UnknownFailure)

### テストケース11: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples が AsyncError(NotFoundFailure) になる [SMP-V11 #86bf63]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗している
- **入力値・テスト条件**: refresh 時の getSamples が NotFoundFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncError(NotFoundFailure)

### テストケース12: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NetworkFailure を返した場合、operationFailure が NetworkFailure になる [SMP-V12 #d97a68]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗している
- **入力値・テスト条件**: refresh 時の getSamples が NetworkFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: operationFailure は NetworkFailure

### テストケース13: 初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が AuthFailure を返した場合、operationFailure が AuthFailure になる [SMP-V13 #0ea055]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗している
- **入力値・テスト条件**: refresh 時の getSamples が AuthFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: operationFailure は AuthFailure

### テストケース14: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が「A」「B」を返した場合、samples が AsyncData([A, B]) になり、Repository の getSamples が userId u1 で呼ばれる [SMP-V14 #f3b21c]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: refresh 時の getSamples が「A」「B」を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B])。Repository の getSamples が userId u1 で呼ばれる

### テストケース15: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が UnknownFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が UnknownFailure になる [SMP-V15 #e5b719]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: refresh 時の getSamples が UnknownFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A]) のまま。operationFailure は UnknownFailure

### テストケース16: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が NotFoundFailure になる [SMP-V16 #21b3a4]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: refresh 時の getSamples が NotFoundFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A]) のまま。operationFailure は NotFoundFailure

### テストケース17: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NetworkFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が NetworkFailure になる [SMP-V17 #148c4b]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: refresh 時の getSamples が NetworkFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A]) のまま。operationFailure は NetworkFailure

### テストケース18: samples が AsyncData([A]) の状態で refresh を呼び、getSamples が AuthFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が AuthFailure になる [SMP-V18 #ccb1d4]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: refresh 時の getSamples が AuthFailure を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A]) のまま。operationFailure は AuthFailure

### テストケース19: samples が AsyncData([]) の状態で refresh を呼び、getSamples が「A」を返した場合、samples が AsyncData([A]) になる [SMP-V19 #e1bb86]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: samples が AsyncData([])
- **入力値・テスト条件**: refresh 時の getSamples が「A」を返す
- **操作手順**: refresh() を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A])

### テストケース20: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples が AsyncData([A, B]) になり、Repository の createSample が userId u1、name 「B」で1回呼ばれる [SMP-V20 #ac3fa6]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: name「B」。createSample が「B」を返す
- **操作手順**: createSample(name: 'B') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B])。Repository の createSample が userId u1、name 「B」で1回呼ばれる

### テストケース21: samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples が AsyncData([B]) になり、Repository の createSample が userId u1、name 「B」で1回呼ばれる [SMP-V21 #74719e]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: samples が AsyncData([])
- **入力値・テスト条件**: name「B」。createSample が「B」を返す
- **操作手順**: createSample(name: 'B') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([B])。Repository の createSample が userId u1、name 「B」で1回呼ばれる

### テストケース22: samples が AsyncData([A]) の状態で createSample（name: 「A」）を呼び、createSample が「A」と別の id を持つ新しいサンプル「A」を返した場合、samples は2件で、どちらの name も「A」、id は互いに異なる [SMP-V22 #ba49ae]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: name「A」（既存と同名）。createSample が別 id の新しい「A」を返す
- **操作手順**: createSample(name: 'A') を呼び、完了を待つ
- **期待結果**: samples は2件で、どちらの name も「A」、id は互いに異なる

### テストケース23: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が UnknownFailure になる [SMP-V23 #0398ac]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: name「B」。createSample が UnknownFailure を返す
- **操作手順**: createSample(name: 'B') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A]) のまま。operationFailure は UnknownFailure

### テストケース24: samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples が AsyncData([]) のままになり、operationFailure が UnknownFailure になる [SMP-V24 #b8ebc4]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: samples が AsyncData([])
- **入力値・テスト条件**: name「B」。createSample が UnknownFailure を返す
- **操作手順**: createSample(name: 'B') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([]) のまま。operationFailure は UnknownFailure

### テストケース25: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が NetworkFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が NetworkFailure になる [SMP-V25 #08063d]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: name「B」。createSample が NetworkFailure を返す
- **操作手順**: createSample(name: 'B') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A]) のまま。operationFailure は NetworkFailure

### テストケース26: samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が AuthFailure を返した場合、samples が AsyncData([A]) のままになり、operationFailure が AuthFailure になる [SMP-V26 #37e03f]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: name「B」。createSample が AuthFailure を返す
- **操作手順**: createSample(name: 'B') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A]) のまま。operationFailure は AuthFailure

### テストケース27: samples が AsyncData([A, B, C]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が Bのid を持つ「X」を返した場合、samples が AsyncData([A, X, C]) になり、Repository の updateSample が userId u1、sampleId Bのid、name 「X」で1回呼ばれる [SMP-V27 #703d7d]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample()
- **事前条件**: samples が AsyncData([A, B, C])
- **入力値・テスト条件**: sampleId は B の id、name「X」。updateSample が B の id を持つ「X」を返す
- **操作手順**: updateSample(sampleId: B.id, name: 'X') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, X, C])。Repository の updateSample が userId u1、sampleId Bのid、name 「X」で1回呼ばれる

### テストケース28: samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「A」）を呼び、updateSample が Bのid を持つ「A」を返した場合、samples は2件で、上から Aのidの「A」、Bのidの「A」になる [SMP-V28 #4211b1]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は B の id、name「A」（既存と同名）。updateSample が B の id を持つ「A」を返す
- **操作手順**: updateSample(sampleId: B.id, name: 'A') を呼び、完了を待つ
- **期待結果**: samples は2件で、上から Aのidの「A」、Bのidの「A」

### テストケース29: samples が AsyncData([A]) の状態で updateSample（sampleId: Aのid、name: 「A」）を呼び、updateSample が Aのid を持つ「A」を返した場合、samples は1件で Aのidの「A」になる [SMP-V29 #4b8c44]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: sampleId は A の id、name「A」（変更なし）。updateSample が A の id を持つ「A」を返す
- **操作手順**: updateSample(sampleId: A.id, name: 'A') を呼び、完了を待つ
- **期待結果**: samples は1件で Aのidの「A」

### テストケース30: samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が UnknownFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が UnknownFailure になる [SMP-V30 #f37e41]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は B の id、name「X」。updateSample が UnknownFailure を返す
- **操作手順**: updateSample(sampleId: B.id, name: 'X') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は UnknownFailure

### テストケース31: samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が NotFoundFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NotFoundFailure になる [SMP-V31 #3fdfbf]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は B の id、name「X」。updateSample が NotFoundFailure を返す
- **操作手順**: updateSample(sampleId: B.id, name: 'X') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は NotFoundFailure

### テストケース32: samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が NetworkFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NetworkFailure になる [SMP-V32 #1c4b53]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は B の id、name「X」。updateSample が NetworkFailure を返す
- **操作手順**: updateSample(sampleId: B.id, name: 'X') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は NetworkFailure

### テストケース33: samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、updateSample が AuthFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が AuthFailure になる [SMP-V33 #b2d978]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は B の id、name「X」。updateSample が AuthFailure を返す
- **操作手順**: updateSample(sampleId: B.id, name: 'X') を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は AuthFailure

### テストケース34: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples が AsyncData([B]) になり、Repository の deleteSample が userId u1、sampleId Aのidで1回呼ばれる [SMP-V34 #334f2e]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は A の id。deleteSample が成功し、その後の getSamples が「B」を返す
- **操作手順**: deleteSample(sampleId: A.id) を呼び、内部の refresh の完了を待つ
- **期待結果**: samples は AsyncData([B])。Repository の deleteSample が userId u1、sampleId Aのidで1回呼ばれる

### テストケース35: samples が AsyncData([A, B, C]) の状態で deleteSample（sampleId: Bのid）を呼び、deleteSample が成功し、その後の getSamples が「A」「C」を返した場合、samples が AsyncData([A, C]) になる [SMP-V35 #7baf62]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A, B, C])
- **入力値・テスト条件**: sampleId は B の id。deleteSample が成功し、その後の getSamples が「A」「C」を返す
- **操作手順**: deleteSample(sampleId: B.id) を呼び、内部の refresh の完了を待つ
- **期待結果**: samples は AsyncData([A, C])

### テストケース36: samples が AsyncData([A]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が成功し、その後の getSamples が空の一覧を返した場合、samples が AsyncData([]) になる [SMP-V36 #e9b1d5]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: sampleId は A の id。deleteSample が成功し、その後の getSamples が空の一覧を返す
- **操作手順**: deleteSample(sampleId: A.id) を呼び、内部の refresh の完了を待つ
- **期待結果**: samples は AsyncData([])

### テストケース37: samples が AsyncData([A, B])（Repository上ではAが既に削除されている）の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples が AsyncData([B]) になり、operationFailure が null になる [SMP-V37 #012201]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A, B])。Repository上ではAが既に削除されている
- **入力値・テスト条件**: sampleId は A の id。deleteSample が成功し、その後の getSamples が「B」を返す
- **操作手順**: deleteSample(sampleId: A.id) を呼び、内部の refresh の完了を待つ
- **期待結果**: samples は AsyncData([B])。operationFailure は null

### テストケース38: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が UnknownFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が UnknownFailure になる [SMP-V38 #b32133]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は A の id。deleteSample が UnknownFailure を返す
- **操作手順**: deleteSample(sampleId: A.id) を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は UnknownFailure

### テストケース39: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が NotFoundFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NotFoundFailure になる [SMP-V39 #da4019]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は A の id。deleteSample が NotFoundFailure を返す
- **操作手順**: deleteSample(sampleId: A.id) を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は NotFoundFailure

### テストケース40: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が NetworkFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が NetworkFailure になる [SMP-V40 #75c7ef]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は A の id。deleteSample が NetworkFailure を返す
- **操作手順**: deleteSample(sampleId: A.id) を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は NetworkFailure

### テストケース41: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、deleteSample が AuthFailure を返した場合、samples が AsyncData([A, B]) のままになり、operationFailure が AuthFailure になる [SMP-V41 #a205ef]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: sampleId は A の id。deleteSample が AuthFailure を返す
- **操作手順**: deleteSample(sampleId: A.id) を呼び、完了を待つ
- **期待結果**: samples は AsyncData([A, B]) のまま。operationFailure は AuthFailure

### テストケース42: samples が AsyncData([A]) の状態で refresh を呼び、読み込みが完了していない場合、samples が AsyncData([A]) のままになる [SMP-V42 #e80659]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: samples が AsyncData([A])
- **入力値・テスト条件**: refresh の getSamples がまだ解決していない
- **操作手順**: refresh() を呼び、完了を待たずに state を読む
- **期待結果**: samples は AsyncData([A]) のまま

### テストケース43: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、その完了前に createSample（name: 「C」）を呼んで、createSample が「C」を返し、deleteSample が成功し、削除後の getSamples が「B」「C」を返した場合、両方の完了後、samples が AsyncData([B, C]) になる [SMP-V43 #ab4762]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample() / deleteSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: deleteSample(sampleId: A.id) 呼び出し中に createSample(name: 'C') を呼ぶ。createSample が「C」を返し、deleteSample が成功し、削除後の getSamples が「B」「C」を返す
- **操作手順**: deleteSample() を呼び（await しない）、続けて createSample() を呼ぶ（await しない）。createSample を先に完了させ、続けて deleteSample を完了させ、最後に削除後の getSamples を「B」「C」で完了させる
- **期待結果**: 両方の完了後、samples は AsyncData([B, C])

### テストケース44: samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、その完了前に refresh を呼んで、refresh の getSamples が「A」「B」を、削除後の getSamples が「B」を返し、refresh の方が後に完了した場合、両方の完了後、samples が AsyncData([B]) になる [SMP-V44 #3c8a70]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh() / deleteSample()
- **事前条件**: samples が AsyncData([A, B])
- **入力値・テスト条件**: deleteSample(sampleId: A.id) 呼び出し中に refresh() を呼ぶ。削除後の getSamples が「B」を先に返し、refresh の getSamples が「A」「B」を後から返す
- **操作手順**: deleteSample() を呼び（await しない）、続けて refresh() を呼ぶ（await しない）。deleteSample を完了させ、削除後の getSamples を「B」で先に完了させ、refresh の getSamples を「A」「B」で後から完了させる
- **期待結果**: 両方の完了後、samples は AsyncData([B])（refresh の結果は古い読み取りとして捨てられる）
