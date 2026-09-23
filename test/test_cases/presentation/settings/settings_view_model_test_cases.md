# settings_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/settings/settings_view_model.dart |
| クラス名 | SettingsViewModel |
| テスト対象メソッド | build() / updateSettings() |

## 実行環境について

`SettingsViewModel` は `@riverpod class`（family, `userId: String`）で `getSettingsUseCaseProvider` /
`updateSettingsUseCaseProvider` に依存する。`ProviderContainer(overrides: [...])` で各 UseCase を
手書き Fake（`FakeGetSettingsUseCase` / `FakeUpdateSettingsUseCase`）に差し替え、Widget は一切
pump せず notifier を直接操作して検証する。`currentUserProvider` への依存は無いため
`test/helpers/test_helpers.dart` の `testUser` は使用しない。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 取得に成功した場合、設定値が state に反映される | 正常系 | build() | ✅ |
| 2 | 取得に失敗した場合、AsyncError になる | 異常系 | build() | ✅ |
| 3 | 更新に成功した場合、state が更新後の設定値になる | 正常系 | updateSettings() | ✅ |
| 4 | 更新に失敗した場合、AsyncError になり呼び出し前の設定値は失われる | 異常系 | updateSettings() | ✅ |
| 5 | build 失敗後に updateSettings を呼んでも _userId は build 時の引数のまま使われる | 境界値 | build() / updateSettings() | ✅ |

## テストケース詳細

### テストケース1: 取得に成功した場合、設定値が state に反映される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `settingsViewModelProvider(userId)` が未 build（コンテナ生成直後）。
- **入力値・テスト条件**: `getSettingsUseCaseProvider` が `Right(UserSettings(colorTheme: 'indigo', darkMode: false))` を返す。
- **操作手順**: `container.read(settingsViewModelProvider(userId).future)` を呼ぶ。
- **期待結果**: 結果が取得した `UserSettings` と一致し、`state.value` も同じ。`getSettingsUseCase` の呼び出し引数 `userId` が build 時の `userId` と一致する。

### テストケース2: 取得に失敗した場合、AsyncError になる
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: `settingsViewModelProvider(userId)` が未 build。
- **入力値・テスト条件**: `getSettingsUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `container.read(settingsViewModelProvider(userId).future)` を呼ぶ。
- **期待結果**: `build()` 内の `fold((f) => throw f, ...)` により例外が送出され、state が `AsyncError(Failure.network())` になる。

### テストケース3: 更新に成功した場合、state が更新後の設定値になる
- **カテゴリ**: 正常系
- **対象メソッド**: updateSettings()
- **事前条件**: build 済みで `state.value` が初期設定値。
- **入力値・テスト条件**: `updateSettingsUseCaseProvider` が `Right(unit)` を返す。渡す `settings` は `colorTheme: 'red', darkMode: true`。
- **操作手順**: `notifier.updateSettings(newSettings)` を呼ぶ。
- **期待結果**: `state.value` が `newSettings` になる（UseCase の戻り値ではなく引数の `settings` がそのまま state に反映される）。`updateSettingsUseCase` に渡された `userId` / `settings` が期待通り。

### テストケース4: 更新に失敗した場合、AsyncError になり呼び出し前の設定値は失われる
- **カテゴリ**: 異常系
- **対象メソッド**: updateSettings()
- **事前条件**: build 済みで `state.value` が初期設定値。
- **入力値・テスト条件**: `updateSettingsUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `notifier.updateSettings(newSettings)` を呼ぶ。
- **期待結果**: `state` が `AsyncError(Failure.network())` になる。

### テストケース5: build 失敗後に updateSettings を呼んでも _userId は build 時の引数のまま使われる
- **カテゴリ**: 境界値
- **対象メソッド**: build() / updateSettings()
- **事前条件**: `getSettingsUseCaseProvider` が `Left(Failure.unknown('boom'))` を返し、build が失敗して state が `AsyncError` になっている。
- **入力値・テスト条件**: build 失敗後に `updateSettingsUseCaseProvider` が `Right(unit)` を返す設定で `updateSettings()` を呼ぶ。
- **操作手順**: `container.read(settingsViewModelProvider(userId).future)` を失敗させた後、`notifier.updateSettings(newSettings)` を呼ぶ。
- **期待結果**: `build()` 冒頭で `_userId = userId` が例外送出前に代入されているため、`updateSettings()` は正しい `_userId` を使って UseCase を呼び出し、成功時は `state.value` が `newSettings` に更新される。

## 対象外

なし（`bash scripts/test_harness.sh test/presentation/settings/settings_view_model_test.dart` の
実行はメイン側に委譲。静的読解上、`build()` の成功/失敗、`updateSettings()` の成功/失敗の
全分岐を上記5ケースで網羅している）。
