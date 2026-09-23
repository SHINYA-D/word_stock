# sample_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/sample/sample_view_model.dart |
| クラス名 | SampleViewModel |
| テスト対象メソッド | build() / refresh() / createSample() / updateSample() / deleteSample() |
| 仕様書 | docs/detailed_design/presentation/sample/sample_page.md |

期待値はすべて仕様書 4章「状態管理仕様（SampleViewModel）」の SMP-V01〜SMP-V44（44件すべて）から作成した。
ログイン中のユーザー id は仕様書どおり「u1」に固定している。Repository は `test/helpers/fake_infrastructure.dart` の
`FakeSampleRepository`（失敗キュー・ゲート・呼び出し記録を持つ手書き Fake）を使い、`sampleRepositoryProvider` を override した。
SMP-V43・SMP-V44（削除の完了前に別の操作が割り込む競合ケース）は `FakeSampleRepository` の `deleteGate` /
`getResponses`（呼び出し順ごとに個別のゲート・戻り値を割り当てるキュー）で完了タイミングを制御している。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | ViewModelを生成した直後（取得が完了する前）の場合、samplesがAsyncLoadingになる [SMP-V01] | SMP-V01 #7fe5c0 | 正常系 | build() | ✅ |
| 2 | A・Bの2件がある状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([A, B])になりgetSamplesがuserId「u1」で1回呼ばれる [SMP-V02] | SMP-V02 #741bef | 正常系 | build() | ✅ |
| 3 | サンプルが0件の状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([])になる [SMP-V03] | SMP-V03 #23dca6 | 境界値 | build() | ✅ |
| 4 | ViewModelを生成し取得がUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V04] | SMP-V04 #9f3345 | 異常系 | build() | ✅ |
| 5 | ViewModelを生成し取得がNotFoundFailureで失敗した場合、samplesがAsyncError(NotFoundFailure)になる [SMP-V05] | SMP-V05 #2d2b4c | 異常系 | build() | ✅ |
| 6 | ViewModelを生成し取得がNetworkFailureで失敗した場合、operationFailureがNetworkFailureになる [SMP-V06] | SMP-V06 #d6a69b | 異常系 | build() | ✅ |
| 7 | ViewModelを生成し取得がAuthFailureで失敗した場合、operationFailureがAuthFailureになる [SMP-V07] | SMP-V07 #b65944 | 異常系 | build() | ✅ |
| 8 | samplesがAsyncError(UnknownFailure)の状態で、Aの1件が取得できるようにしてからrefreshを呼んだ場合、samplesがAsyncData([A])になりgetSamplesが2回目の呼び出しでもuserId「u1」で呼ばれる [SMP-V08] | SMP-V08 #e2bf2c | 正常系 | refresh() | ✅ |
| 9 | 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び、読み込みが完了していない場合、samplesがAsyncLoadingになる [SMP-V09] | SMP-V09 #0551fd | 境界値 | refresh() | ✅ |
| 10 | 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得が再びUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V10] | SMP-V10 #0e8d4b | 異常系 | refresh() | ✅ |
| 11 | 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がNotFoundFailureで失敗した場合、samplesがAsyncError(NotFoundFailure)になる [SMP-V11] | SMP-V11 #86bf63 | 異常系 | refresh() | ✅ |
| 12 | 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がNetworkFailureで失敗した場合、operationFailureがNetworkFailureになる [SMP-V12] | SMP-V12 #d97a68 | 異常系 | refresh() | ✅ |
| 13 | 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がAuthFailureで失敗した場合、operationFailureがAuthFailureになる [SMP-V13] | SMP-V13 #0ea055 | 異常系 | refresh() | ✅ |
| 14 | samplesがAsyncData([A])の状態でrefreshを呼びgetSamplesが「A」「B」を返した場合、samplesがAsyncData([A, B])になりgetSamplesがuserId「u1」で呼ばれる [SMP-V14] | SMP-V14 #f3b21c | 正常系 | refresh() | ✅ |
| 15 | samplesがAsyncData([A])の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V15] | SMP-V15 #e5b719 | 異常系 | refresh() | ✅ |
| 16 | samplesがAsyncData([A])の状態でrefreshを呼び取得がNotFoundFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNotFoundFailureになる [SMP-V16] | SMP-V16 #21b3a4 | 異常系 | refresh() | ✅ |
| 17 | samplesがAsyncData([A])の状態でrefreshを呼び取得がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V17] | SMP-V17 #148c4b | 異常系 | refresh() | ✅ |
| 18 | samplesがAsyncData([A])の状態でrefreshを呼び取得がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V18] | SMP-V18 #ccb1d4 | 異常系 | refresh() | ✅ |
| 19 | samplesがAsyncData([])の状態でrefreshを呼びgetSamplesが「A」を返した場合、samplesがAsyncData([A])になる [SMP-V19] | SMP-V19 #e1bb86 | 境界値 | refresh() | ✅ |
| 20 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([A, B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V20] | SMP-V20 #ac3fa6 | 正常系 | createSample() | ✅ |
| 21 | samplesがAsyncData([])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V21] | SMP-V21 #74719e | 境界値 | createSample() | ✅ |
| 22 | samplesがAsyncData([A])の状態で名前「A」の作成を呼び作成に成功した場合、samplesは2件でどちらもname「A」でidが互いに異なる [SMP-V22] | SMP-V22 #ba49ae | 境界値 | createSample() | ✅ |
| 23 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V23] | SMP-V23 #0398ac | 異常系 | createSample() | ✅ |
| 24 | samplesがAsyncData([])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([])のままでoperationFailureがUnknownFailureになる [SMP-V24] | SMP-V24 #b8ebc4 | 異常系 | createSample() | ✅ |
| 25 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V25] | SMP-V25 #08063d | 異常系 | createSample() | ✅ |
| 26 | samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V26] | SMP-V26 #37e03f | 異常系 | createSample() | ✅ |
| 27 | samplesがAsyncData([A, B, C])の状態でBの名前を「X」にする変更を呼び変更に成功した場合、samplesがAsyncData([A, X, C])になりupdateSampleがuserId「u1」・sampleId「Bのid」・name「X」で1回呼ばれる [SMP-V27] | SMP-V27 #703d7d | 正常系 | updateSample() | ✅ |
| 28 | samplesがAsyncData([A, B])の状態でBの名前を「A」にする変更を呼び変更に成功した場合、samplesは2件で上からAのidの「A」、Bのidの「A」になる [SMP-V28] | SMP-V28 #4211b1 | 境界値 | updateSample() | ✅ |
| 29 | samplesがAsyncData([A])の状態でAの名前を「A」にする変更を呼び変更に成功した場合、samplesの要素は1件でAのidの「A」になる [SMP-V29] | SMP-V29 #4b8c44 | 境界値 | updateSample() | ✅ |
| 30 | samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V30] | SMP-V30 #f37e41 | 異常系 | updateSample() | ✅ |
| 31 | samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がNotFoundFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNotFoundFailureになる [SMP-V31] | SMP-V31 #3fdfbf | 異常系 | updateSample() | ✅ |
| 32 | samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がNetworkFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNetworkFailureになる [SMP-V32] | SMP-V32 #1c4b53 | 異常系 | updateSample() | ✅ |
| 33 | samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がAuthFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがAuthFailureになる [SMP-V33] | SMP-V33 #b2d978 | 異常系 | updateSample() | ✅ |
| 34 | samplesがAsyncData([A, B])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりdeleteSampleがuserId「u1」・sampleId「Aのid」で1回呼ばれる [SMP-V34] | SMP-V34 #334f2e | 正常系 | deleteSample() | ✅ |
| 35 | samplesがAsyncData([A, B, C])の状態でBの削除を呼び削除に成功した場合、samplesがAsyncData([A, C])になる [SMP-V35] | SMP-V35 #7baf62 | 正常系 | deleteSample() | ✅ |
| 36 | samplesがAsyncData([A])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([])になる [SMP-V36] | SMP-V36 #e9b1d5 | 境界値 | deleteSample() | ✅ |
| 37 | samplesがAsyncData([A, B])でRepository上ではAが既に削除されている状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりoperationFailureがnullになる [SMP-V37] | SMP-V37 #012201 | 境界値 | deleteSample() | ✅ |
| 38 | samplesがAsyncData([A, B])の状態でAの削除を呼び削除がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V38] | SMP-V38 #b32133 | 異常系 | deleteSample() | ✅ |
| 39 | samplesがAsyncData([A, B])の状態でAの削除を呼び削除がNotFoundFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNotFoundFailureになる [SMP-V39] | SMP-V39 #da4019 | 異常系 | deleteSample() | ✅ |
| 40 | samplesがAsyncData([A, B])の状態でAの削除を呼び削除がNetworkFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNetworkFailureになる [SMP-V40] | SMP-V40 #75c7ef | 異常系 | deleteSample() | ✅ |
| 41 | samplesがAsyncData([A, B])の状態でAの削除を呼び削除がAuthFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがAuthFailureになる [SMP-V41] | SMP-V41 #a205ef | 異常系 | deleteSample() | ✅ |
| 42 | samplesがAsyncData([A])の状態でrefreshを呼び、読み込みが完了していない場合、samplesはAsyncData([A])のままになる [SMP-V42] | SMP-V42 #e80659 | 境界値 | refresh() | ✅ |
| 43 | samplesがAsyncData([A, B])の状態でAの削除を呼び、その完了前にCの作成を呼んで、作成がCを返し削除も成功した場合、両方の完了後にsamplesがAsyncData([B, C])になる [SMP-V43] | SMP-V43 #ab4762 | 境界値 | deleteSample() / createSample() | ✅ |
| 44 | samplesがAsyncData([A, B])の状態でAの削除を呼び、その完了前にrefreshを呼び、refreshのgetSamplesが「A」「B」を、削除後のgetSamplesが「B」を返し、refreshの方が後に完了した場合、両方の完了後にsamplesがAsyncData([B])になる [SMP-V44] | SMP-V44 #3c8a70 | 境界値 | deleteSample() / refresh() | ✅ |

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

### テストケース8: samplesがAsyncError(UnknownFailure)の状態で、Aの1件が取得できるようにしてからrefreshを呼んだ場合、samplesがAsyncData([A])になりgetSamplesが2回目の呼び出しでもuserId「u1」で呼ばれる [SMP-V08]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: Repository が「A」の1件を返せるようにしてから refresh を呼ぶ
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])`。getSamples が2回目の呼び出しでも userId「u1」で呼ばれる

### テストケース9: 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び、読み込みが完了していない場合、samplesがAsyncLoadingになる [SMP-V09]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: getSamples を `getGate` で止めたまま refresh を呼ぶ（読み込みが完了していない）
- **操作手順**: `notifier.refresh()` を呼び、await せずに状態を確認した後、ゲートを解放して待つ
- **期待結果**: `samples` は `AsyncLoading`

### テストケース10: 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得が再びUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V10]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: refresh を呼び、取得が再び `UnknownFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncError`（エラーは `UnknownFailure`）

### テストケース11: 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がNotFoundFailureで失敗した場合、samplesがAsyncError(NotFoundFailure)になる [SMP-V11]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: refresh を呼び、取得が `NotFoundFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncError`（エラーは `NotFoundFailure`）

### テストケース12: 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がNetworkFailureで失敗した場合、operationFailureがNetworkFailureになる [SMP-V12]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: refresh を呼び、取得が `NetworkFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `operationFailure` は `NetworkFailure`
- **実際の結果**: `samples` が `AsyncError(NetworkFailure)` になり `operationFailure` は変化しない（テスト失敗）。詳細は本ファイル末尾「プロダクションコードのバグ疑い」を参照

### テストケース13: 初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がAuthFailureで失敗した場合、operationFailureがAuthFailureになる [SMP-V13]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncError(UnknownFailure)`
- **入力値・テスト条件**: refresh を呼び、取得が `AuthFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `operationFailure` は `AuthFailure`
- **実際の結果**: `samples` が `AsyncError(AuthFailure)` になり `operationFailure` は変化しない（テスト失敗）。詳細は本ファイル末尾「プロダクションコードのバグ疑い」を参照

### テストケース14: samplesがAsyncData([A])の状態でrefreshを呼びgetSamplesが「A」「B」を返した場合、samplesがAsyncData([A, B])になりgetSamplesがuserId「u1」で呼ばれる [SMP-V14]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: Repository に「B」を追加してから refresh を呼ぶ
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A, B])`。getSamples が userId「u1」で呼ばれる

### テストケース15: samplesがAsyncData([A])の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V15]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: refresh を呼び、取得が `UnknownFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `UnknownFailure`

### テストケース16: samplesがAsyncData([A])の状態でrefreshを呼び取得がNotFoundFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNotFoundFailureになる [SMP-V16]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: refresh を呼び、取得が `NotFoundFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NotFoundFailure`

### テストケース17: samplesがAsyncData([A])の状態でrefreshを呼び取得がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V17]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: refresh を呼び、取得が `NetworkFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース18: samplesがAsyncData([A])の状態でrefreshを呼び取得がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V18]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: refresh を呼び、取得が `AuthFailure` で失敗する
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

### テストケース19: samplesがAsyncData([])の状態でrefreshを呼びgetSamplesが「A」を返した場合、samplesがAsyncData([A])になる [SMP-V19]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([])`
- **入力値・テスト条件**: Repository に「A」を追加してから refresh を呼ぶ
- **操作手順**: `notifier.refresh()` を await する
- **期待結果**: `samples` は `AsyncData([A])`

### テストケース20: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([A, B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V20]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A, B])`。Repository の createSample が userId「u1」・name「B」で1回呼ばれる

### テストケース21: samplesがAsyncData([])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V21]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([])`
- **入力値・テスト条件**: name「B」
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([B])`。Repository の createSample が userId「u1」・name「B」で1回呼ばれる

### テストケース22: samplesがAsyncData([A])の状態で名前「A」の作成を呼び作成に成功した場合、samplesは2件でどちらもname「A」でidが互いに異なる [SMP-V22]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「A」（既存と同じ名前）
- **操作手順**: `notifier.createSample(name: 'A')` を await する
- **期待結果**: `samples` は2件で、どちらの name も「A」、id は互いに異なる

### テストケース23: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V23]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」。作成が `UnknownFailure` で失敗する
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `UnknownFailure`

### テストケース24: samplesがAsyncData([])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([])のままでoperationFailureがUnknownFailureになる [SMP-V24]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([])`
- **入力値・テスト条件**: name「B」。作成が `UnknownFailure` で失敗する
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([])` のまま。`operationFailure` は `UnknownFailure`

### テストケース25: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V25]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」。作成が `NetworkFailure` で失敗する
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `NetworkFailure`

### テストケース26: samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V26]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: name「B」。作成が `AuthFailure` で失敗する
- **操作手順**: `notifier.createSample(name: 'B')` を await する
- **期待結果**: `samples` は `AsyncData([A])` のまま。`operationFailure` は `AuthFailure`

### テストケース27: samplesがAsyncData([A, B, C])の状態でBの名前を「X」にする変更を呼び変更に成功した場合、samplesがAsyncData([A, X, C])になりupdateSampleがuserId「u1」・sampleId「Bのid」・name「X」で1回呼ばれる [SMP-V27]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B, C])`
- **入力値・テスト条件**: sampleId「B の id」、name「X」
- **操作手順**: `notifier.updateSample(sampleId: b.id, name: 'X')` を await する
- **期待結果**: `samples` は `AsyncData([A, X, C])`（X は B と同じ id）。Repository の updateSample が userId「u1」・sampleId「B の id」・name「X」で1回呼ばれる

### テストケース28: samplesがAsyncData([A, B])の状態でBの名前を「A」にする変更を呼び変更に成功した場合、samplesは2件で上からAのidの「A」、Bのidの「A」になる [SMP-V28]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「B の id」、name「A」（既存の別要素と同じ名前）
- **操作手順**: `notifier.updateSample(sampleId: b.id, name: 'A')` を await する
- **期待結果**: `samples` は2件で、上から A の id の「A」、B の id の「A」

### テストケース29: samplesがAsyncData([A])の状態でAの名前を「A」にする変更を呼び変更に成功した場合、samplesの要素は1件でAのidの「A」になる [SMP-V29]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」、name「A」（変更なし）
- **操作手順**: `notifier.updateSample(sampleId: a.id, name: 'A')` を await する
- **期待結果**: `samples` の要素は1件で、A の id の「A」

### テストケース30: samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V30]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「B の id」、name「X」。変更が `UnknownFailure` で失敗する
- **操作手順**: `notifier.updateSample(sampleId: b.id, name: 'X')` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `UnknownFailure`

### テストケース31: samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がNotFoundFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNotFoundFailureになる [SMP-V31]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「B の id」、name「X」。変更が `NotFoundFailure` で失敗する（B が既に削除されていた想定）
- **操作手順**: `notifier.updateSample(sampleId: b.id, name: 'X')` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NotFoundFailure`

### テストケース32: samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がNetworkFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNetworkFailureになる [SMP-V32]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「B の id」、name「X」。変更が `NetworkFailure` で失敗する
- **操作手順**: `notifier.updateSample(sampleId: b.id, name: 'X')` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NetworkFailure`

### テストケース33: samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がAuthFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがAuthFailureになる [SMP-V33]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「B の id」、name「X」。変更が `AuthFailure` で失敗する
- **操作手順**: `notifier.updateSample(sampleId: b.id, name: 'X')` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `AuthFailure`

### テストケース34: samplesがAsyncData([A, B])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりdeleteSampleがuserId「u1」・sampleId「Aのid」で1回呼ばれる [SMP-V34]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await し、内部の refresh が完了するのを待つ
- **期待結果**: `samples` は `AsyncData([B])`。Repository の deleteSample が userId「u1」・sampleId「A の id」で1回呼ばれる

### テストケース35: samplesがAsyncData([A, B, C])の状態でBの削除を呼び削除に成功した場合、samplesがAsyncData([A, C])になる [SMP-V35]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B, C])`
- **入力値・テスト条件**: sampleId「B の id」
- **操作手順**: `notifier.deleteSample(sampleId: b.id)` を await し、内部の refresh が完了するのを待つ
- **期待結果**: `samples` は `AsyncData([A, C])`

### テストケース36: samplesがAsyncData([A])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([])になる [SMP-V36]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: sampleId「A の id」
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await し、内部の refresh が完了するのを待つ
- **期待結果**: `samples` は `AsyncData([])`

### テストケース37: samplesがAsyncData([A, B])でRepository上ではAが既に削除されている状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりoperationFailureがnullになる [SMP-V37]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`。Repository 上では A が既に削除されている
- **入力値・テスト条件**: sampleId「A の id」（Repository 上に存在しない）
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await し、内部の refresh が完了するのを待つ
- **期待結果**: `samples` は `AsyncData([B])`。`operationFailure` は null

### テストケース38: samplesがAsyncData([A, B])の状態でAの削除を呼び削除がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V38]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」。削除が `UnknownFailure` で失敗する
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `UnknownFailure`

### テストケース39: samplesがAsyncData([A, B])の状態でAの削除を呼び削除がNotFoundFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNotFoundFailureになる [SMP-V39]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」。削除が `NotFoundFailure` で失敗する
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NotFoundFailure`

### テストケース40: samplesがAsyncData([A, B])の状態でAの削除を呼び削除がNetworkFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNetworkFailureになる [SMP-V40]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」。削除が `NetworkFailure` で失敗する
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `NetworkFailure`

### テストケース41: samplesがAsyncData([A, B])の状態でAの削除を呼び削除がAuthFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがAuthFailureになる [SMP-V41]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: sampleId「A の id」。削除が `AuthFailure` で失敗する
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を await する
- **期待結果**: `samples` は `AsyncData([A, B])` のまま。`operationFailure` は `AuthFailure`

### テストケース42: samplesがAsyncData([A])の状態でrefreshを呼び、読み込みが完了していない場合、samplesはAsyncData([A])のままになる [SMP-V42]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: `samples` が `AsyncData([A])`
- **入力値・テスト条件**: getSamples を `getGate` で止めたまま refresh を呼ぶ（読み込みが完了していない）
- **操作手順**: `notifier.refresh()` を呼び、await せずに状態を確認した後、ゲートを解放して待つ
- **期待結果**: `samples` は `AsyncData([A])` のまま

### テストケース43: samplesがAsyncData([A, B])の状態でAの削除を呼び、その完了前にCの作成を呼んで、作成がCを返し削除も成功した場合、両方の完了後にsamplesがAsyncData([B, C])になる [SMP-V43]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample() / createSample()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `deleteGate` で A の削除の repo 呼び出しを止めたまま、その間に name「C」の作成を行う
- **操作手順**: `notifier.deleteSample(sampleId: a.id)` を呼び（await しない）、`notifier.createSample(name: 'C')` を await し、その後 `deleteGate` を解放して削除の完了・内部の refresh の完了を待つ
- **期待結果**: 両方の完了後、`samples` は `AsyncData([B, C])`（name の集合が `{B, C}`）

### テストケース44: samplesがAsyncData([A, B])の状態でAの削除を呼び、その完了前にrefreshを呼び、refreshのgetSamplesが「A」「B」を、削除後のgetSamplesが「B」を返し、refreshの方が後に完了した場合、両方の完了後にsamplesがAsyncData([B])になる [SMP-V44]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample() / refresh()
- **事前条件**: `samples` が `AsyncData([A, B])`
- **入力値・テスト条件**: `FakeSampleRepository.getResponses` で、1回目の getSamples 呼び出し（外側の refresh）をゲートで止めて戻り値を「A」「B」に、2回目の getSamples 呼び出し（削除の内部の refresh）をゲートなしで戻り値「B」に設定する
- **操作手順**: `notifier.refresh()` を呼び（await しない）、`notifier.deleteSample(sampleId: a.id)` を await し、内部の refresh（2回目の getSamples）の完了を待ってから refresh 側のゲートを解放し、外側の refresh の完了を待つ
- **期待結果**: 両方の完了後、`samples` は `AsyncData([B])`
- **実際の結果**: `samples` は `AsyncData([A, B])` になる（後に完了した refresh が上書きするため）。詳細は本ファイル末尾「プロダクションコードのバグ疑い」を参照

## 対象外

該当なし（担当する仕様 ID SMP-V01〜SMP-V44（44件）をすべてテスト済み。対象ファイルのカバレッジは100%）。

## プロダクションコードのバグ疑い

仕様書 §8「要確認事項」の確定（2026-09-23・全件 案A）を受けて、下記はすべて修正済み。
テストの期待値は仕様どおりのまま変えていない。担当する SMP-V01〜V44 は現在すべて green。

- **SMP-V44**（修正済み・2026-09-23）: `SampleViewModel` に世代番号 `_revision` を入れ、読み取り中に
  データを変える操作（作成・変更・削除）が完了していたら、その読み取り結果を捨てるようにした。
  削除したアイテムが古い読み取り結果で一覧に復活する問題を解消（画面では `SMP-X16`）。
- **SMP-V12, SMP-V13**（修正済み・2026-09-23）: `refresh()` が `hasList == false`（`ErrorScreen` 表示中の
  「再試行」）のときに `NetworkFailure` / `AuthFailure` を特別扱いせず、`operationFailure` に入らなかった。
  `_initState()` と `refresh()` で扱いがずれないよう、失敗の処理を `_applyLoadFailure()` に共通化した
  （画面では `SMP-E07`〜`SMP-E10`）。
