# sample_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/sample/sample_view_model.dart |
| クラス名 | SampleViewModel |
| テスト対象メソッド | build() / refresh() / createSample() / updateSample() / deleteSample() |
| 仕様書 | docs/detailed_design/presentation/sample/sample_page.md |

期待値はすべて仕様書 4章「状態管理仕様（SampleViewModel）」の SMP-V01〜SMP-V30 から作成した。
ログイン中のユーザー id は仕様書どおり「u1」に固定している。Repository は `test/helpers/fake_infrastructure.dart` の
`FakeSampleRepository`（失敗キュー・呼び出し記録を持つ手書き Fake）を使い、`sampleRepositoryProvider` を override した。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | ViewModelを生成した直後（取得が完了する前）の場合、samplesがAsyncLoadingになる [SMP-V01] | SMP-V01 | 正常系 | build() | ✅ |
| 2 | A・Bの2件がある状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([A, B])になりgetSamplesがuserId「u1」で1回呼ばれる [SMP-V02] | SMP-V02 | 正常系 | build() | ✅ |
| 3 | サンプルが0件の状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([])になる [SMP-V03] | SMP-V03 | 境界値 | build() | ✅ |
| 4 | ViewModelを生成し取得がUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V04] | SMP-V04 | 異常系 | build() | ✅ |
| 5 | ViewModelを生成し取得がNotFoundFailureで失敗した場合、samplesがAsyncError(NotFoundFailure)になる [SMP-V05] | SMP-V05 | 異常系 | build() | ✅ |
| 6 | ViewModelを生成し取得がNetworkFailureで失敗した場合、operationFailureがNetworkFailureになる [SMP-V06] | SMP-V06 | 異常系 | build() | ✅ |
| 7 | ViewModelを生成し取得がAuthFailureで失敗した場合、operationFailureがAuthFailureになる [SMP-V07] | SMP-V07 | 異常系 | build() | ✅ |
| 8 | samplesがAsyncError(UnknownFailure)の状態で、Aの1件が取得できるようにしてからrefreshを呼んだ場合、samplesがAsyncData([A])になる [SMP-V08] | SMP-V08 | 正常系 | refresh() | ✅ |
| 9 | samplesがAsyncError(UnknownFailure)の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V09] | SMP-V09 | 異常系 | refresh() | ✅ |
| 10 | samplesがAsyncData([A])の状態でRepositoryにBを追加しrefreshを呼んだ場合、samplesがAsyncData([A, B])になる [SMP-V10] | SMP-V10 | 正常系 | refresh() | ✅ |
| 11 | samplesがAsyncData([A])の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V11] | SMP-V11 | 異常系 | refresh() | ✅ |
| 12 | samplesがAsyncData([A])の状態でrefreshを呼び取得がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V12] | SMP-V12 | 異常系 | refresh() | ✅ |
| 13 | samplesがAsyncData([A])の状態でrefreshを呼び取得がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V13] | SMP-V13 | 異常系 | refresh() | ✅ |
| 14 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([A, B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V14] | SMP-V14 | 正常系 | createSample() | ✅ |
| 15 | samplesがAsyncData([])の状態で名前「A」の作成を呼び作成に成功した場合、samplesがAsyncData([A])になる [SMP-V15] | SMP-V15 | 境界値 | createSample() | ✅ |
| 16 | samplesがAsyncData([A])の状態で名前「A」の作成を呼び作成に成功した場合、samplesが名前「A」の要素を2つ持つAsyncDataになる [SMP-V16] | SMP-V16 | 境界値 | createSample() | ✅ |
| 17 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V17] | SMP-V17 | 異常系 | createSample() | ✅ |
| 18 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V18] | SMP-V18 | 異常系 | createSample() | ✅ |
| 19 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V19] | SMP-V19 | 異常系 | createSample() | ✅ |
| 20 | samplesがAsyncData([A, B])の状態でAの名前を「C」にする変更を呼び変更に成功した場合、samplesがAsyncData([C, B])になりupdateSampleがuserId「u1」・sampleId「Aのid」・name「C」で1回呼ばれる [SMP-V20] | SMP-V20 | 正常系 | updateSample() | ✅ |
| 21 | samplesがAsyncData([A])の状態でAの名前を「A」にする変更を呼び変更に成功した場合、samplesの要素は1件で名前は「A」になる [SMP-V21] | SMP-V21 | 境界値 | updateSample() | ✅ |
| 22 | samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V22] | SMP-V22 | 異常系 | updateSample() | ✅ |
| 23 | samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がNotFoundFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNotFoundFailureになる [SMP-V23] | SMP-V23 | 異常系 | updateSample() | ✅ |
| 24 | samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V24] | SMP-V24 | 異常系 | updateSample() | ✅ |
| 25 | samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V25] | SMP-V25 | 異常系 | updateSample() | ✅ |
| 26 | samplesがAsyncData([A, B])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりdeleteSampleがuserId「u1」・sampleId「Aのid」で1回呼ばれる [SMP-V26] | SMP-V26 | 正常系 | deleteSample() | ✅ |
| 27 | samplesがAsyncData([A])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([])になる [SMP-V27] | SMP-V27 | 境界値 | deleteSample() | ✅ |
| 28 | samplesがAsyncData([A, B])の状態でAの削除を呼び削除がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V28] | SMP-V28 | 異常系 | deleteSample() | ✅ |
| 29 | samplesがAsyncData([A])の状態でAの削除を呼び削除がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V29] | SMP-V29 | 異常系 | deleteSample() | ✅ |
| 30 | samplesがAsyncData([A])の状態でAの削除を呼び削除がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V30] | SMP-V30 | 異常系 | deleteSample() | ✅ |

## テストケース詳細

### テストケース1: ViewModelを生成した直後（取得が完了する前）の場合、samplesがAsyncLoadingになる [SMP-V01]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: なし
- **入力値・テスト条件**: ViewModel を生成した直後（取得が完了する前）
- **操作手順**: `ProviderContainer` を生成し `sampleViewModelProvider` を read する
- **期待結果**: `samples` は `AsyncLoading`

### テストケース2: A・Bの2件がある状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([A, B])になりgetSamplesがuserId「u1」で1回呼ばれる [SMP-V02]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: Repository に「A」「B」の2件がある
- **入力値・テスト条件**: ViewModel を生成し、取得が完了した
- **操作手順**: `ProviderContainer` を生成し初期ロードの完了を待つ
- **期待結果**: `samples` は `AsyncData([A, B])`。Repository の getSamples が userId「u1」で1回呼ばれる

### テストケース3: サンプルが0件の状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([])になる [SMP-V03]
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: サンプルが0件
- **入力値・テスト条件**: ViewModel を生成し、取得が完了した
- **操作手順**: `ProviderContainer` を生成し初期ロードの完了を待つ
- **期待結果**: `samples` は `AsyncData([])`

### テストケース4: ViewModelを生成し取得がUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V04]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: Repository の getSamples が `UnknownFailure` を返すよう設定
- **入力値・テスト条件**: ViewModel を生成した
- **操作手順**: `ProviderContainer` を生成し初期ロードの完了を待つ
- **期待結果**: `samples` は `AsyncError`（エラーは `UnknownFailure`）

### テストケース5: ViewModelを生成し取得がNotFoundFailureで失敗した場合、samplesがAsyncError(NotFoundFailure)になる [SMP-V05]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: Repository の getSamples が `NotFoundFailure` を返すよう設定
- **入力値・テスト条件**: ViewModel を生成した
- **操作手順**: `ProviderContainer` を生成し初期ロードの完了を待つ
- **期待結果**: `samples` は `AsyncError`（エラーは `NotFoundFailure`）

### テストケース6: ViewModelを生成し取得がNetworkFailureで失敗した場合、operationFailureがNetworkFailureになる [SMP-V06]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: Repository の getSamples が `NetworkFailure` を返すよう設定
- **入力値・テスト条件**: ViewModel を生成した
- **操作手順**: `ProviderContainer` を生成し初期ロードの完了を待つ
- **期待結果**: `operationFailure` は `NetworkFailure`

### テストケース7: ViewModelを生成し取得がAuthFailureで失敗した場合、operationFailureがAuthFailureになる [SMP-V07]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: Repository の getSamples が `AuthFailure` を返すよう設定
- **入力値・テスト条件**: ViewModel を生成した
- **操作手順**: `ProviderContainer` を生成し初期ロードの完了を待つ
- **期待結果**: `operationFailure` は `AuthFailure`

### テストケース8: samplesがAsyncError(UnknownFailure)の状態で、Aの1件が取得できるようにしてからrefreshを呼んだ場合、samplesがAsyncData([A])になる [SMP-V08]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: Repository が「A」の1件を返せるようにしてから refresh を呼ぶ
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])`

### テストケース9: samplesがAsyncError(UnknownFailure)の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V09]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: refresh を呼び、取得が `UnknownFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncError`（エラーは `UnknownFailure`）

### テストケース10: samplesがAsyncData([A])の状態でRepositoryにBを追加しrefreshを呼んだ場合、samplesがAsyncData([A, B])になる [SMP-V10]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: Repository に「B」を追加してから refresh を呼ぶ
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A, B])`

### テストケース11: samplesがAsyncData([A])の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V11]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: refresh を呼び、取得が `UnknownFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `UnknownFailure`

### テストケース12: samplesがAsyncData([A])の状態でrefreshを呼び取得がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V12]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: refresh を呼び、取得が `NetworkFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース13: samplesがAsyncData([A])の状態でrefreshを呼び取得がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V13]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: refresh を呼び、取得が `AuthFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

### テストケース14: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([A, B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V14]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A, B])`。Repository の createSample が userId「u1」・name「B」で1回呼ばれる

### テストケース15: samplesがAsyncData([])の状態で名前「A」の作成を呼び作成に成功した場合、samplesがAsyncData([A])になる [SMP-V15]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([])`
- **入力値・テスト条件**: name「A」
- **操作手順**: `notifier.createSample(name: 'A')` を await する
- **期待結果**: `samples` は `AsyncData([A])`

### テストケース16: samplesがAsyncData([A])の状態で名前「A」の作成を呼び作成に成功した場合、samplesが名前「A」の要素を2つ持つAsyncDataになる [SMP-V16]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「A」（既存と同じ名前）
- **操作手順**: `notifier.createSample(name: 'A')` を await する
- **期待結果**: `samples` は名前が「A」の要素を2つ持つ `AsyncData`

### テストケース17: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V17]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」。作成が `UnknownFailure` で失敗する
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `UnknownFailure`

### テストケース18: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V18]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」。作成が `NetworkFailure` で失敗する
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース19: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V19]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」。作成が `AuthFailure` で失敗する
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

### テストケース20: samplesがAsyncData([A, B])の状態でAの名前を「C」にする変更を呼び変更に成功した場合、samplesがAsyncData([C, B])になりupdateSampleがuserId「u1」・sampleId「Aのid」・name「C」で1回呼ばれる [SMP-V20]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」、name「C」
- **操作手順**: `notifier.updateSample(sampleId: a.id, name: 'C')` を await する
- **期待結果**: `samples` は `AsyncData([C, B])`（C は A と同じ id）。Repository の updateSample が userId「u1」・sampleId「A の id」・name「C」で1回呼ばれる

### テストケース21: samplesがAsyncData([A])の状態でAの名前を「A」にする変更を呼び変更に成功した場合、samplesの要素は1件で名前は「A」になる [SMP-V21]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」、name「A」（変更なし）
- **操作手順**: `notifier.updateSample(sampleId: a.id, name: 'A')` を await する
- **期待結果**: `samples` の要素は1件で、名前は「A」

### テストケース22: samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V22]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」、name「C」。変更が `UnknownFailure` で失敗する
- **操作手順**: `notifier.updateSample(sampleId: a.id, name: 'C')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `UnknownFailure`

### テストケース23: samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がNotFoundFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNotFoundFailureになる [SMP-V23]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」、name「C」。変更が `NotFoundFailure` で失敗する
- **操作手順**: `notifier.updateSample(sampleId: a.id, name: 'C')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NotFoundFailure`

### テストケース24: samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V24]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」、name「C」。変更が `NetworkFailure` で失敗する
- **操作手順**: `notifier.updateSample(sampleId: a.id, name: 'C')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース25: samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V25]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」、name「C」。変更が `AuthFailure` で失敗する
- **操作手順**: `notifier.updateSample(sampleId: a.id, name: 'C')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

### テストケース26: samplesがAsyncData([A, B])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりdeleteSampleがuserId「u1」・sampleId「Aのid」で1回呼ばれる [SMP-V26]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await し、内部の refresh が完了するのを待つ
- **期待結果**: `samples` は `AsyncData([B])`。Repository の deleteSample が userId「u1」・sampleId「A の id」で1回呼ばれる

### テストケース27: samplesがAsyncData([A])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([])になる [SMP-V27]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await し、内部の refresh が完了するのを待つ
- **期待結果**: `samples` は `AsyncData([])`

### テストケース28: samplesがAsyncData([A, B])の状態でAの削除を呼び削除がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V28]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」。削除が `UnknownFailure` で失敗する
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `UnknownFailure`

### テストケース29: samplesがAsyncData([A])の状態でAの削除を呼び削除がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V29]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」。削除が `NetworkFailure` で失敗する
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース30: samplesがAsyncData([A])の状態でAの削除を呼び削除がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V30]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」。削除が `AuthFailure` で失敗する
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

## 対象外

該当なし（担当する仕様 ID SMP-V01〜SMP-V30 をすべてテスト済み。対象ファイルのカバレッジは100%）。
