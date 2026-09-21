# password_reset_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/auth/password_reset/password_reset_view_model.dart |
| クラス名 | PasswordResetViewModel |
| テスト対象メソッド | build() / sendResetEmail() / resetState() |

## 実行環境について

`PasswordResetViewModel` は `@riverpod class`（非 family）で `resetPasswordUseCaseProvider` にのみ
依存する。`ProviderContainer(overrides: [...])` で `resetPasswordUseCaseProvider` を手書き Fake
（`FakeResetPasswordUseCase`）に差し替え、Widget は一切 pump せず notifier を直接操作して検証する。
`sendResetEmail()` は `Future<void>` を返すため、途中経過（`isLoading: true` かつ
`isSuccess`/`errorMessage` がリセットされる瞬間）は `await` する前の `Future` を保持して確認する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 初期状態の場合、isLoading/isSuccess が false で errorMessage が null になる | 正常系 | build() | ✅ |
| 2 | 送信に成功した場合、isSuccess が true になり isLoading が false に戻る | 正常系 | sendResetEmail() | ✅ |
| 3 | 通信エラーの場合、errorMessage に通信エラー文言が設定される | 異常系 | sendResetEmail() | ✅ |
| 4 | 認証エラーの場合、errorMessage にメールアドレスが見つからない旨の文言が設定される | 異常系 | sendResetEmail() | ✅ |
| 5 | アカウント未検出の場合、errorMessage にアカウントが見つからない旨の文言が設定される | 異常系 | sendResetEmail() | ✅ |
| 6 | 不明なエラーの場合、errorMessage に元のメッセージを含む文言が設定される | 異常系 | sendResetEmail() | ✅ |
| 7 | 呼び出し直後は isLoading が true になり isSuccess/errorMessage がリセットされる | 境界値 | sendResetEmail() | ✅ |
| 8 | email 引数が UseCase にそのまま渡される | 正常系 | sendResetEmail() | ✅ |
| 9 | 成功状態からリセットした場合、初期状態に戻る | 正常系 | resetState() | ✅ |
| 10 | 失敗状態からリセットした場合、errorMessage がクリアされる | 正常系 | resetState() | ✅ |

## テストケース詳細

### テストケース1: 初期状態の場合、isLoading/isSuccess が false で errorMessage が null になる
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `ProviderContainer` 生成直後（`sendResetEmail` 未呼び出し）。
- **入力値・テスト条件**: なし。
- **操作手順**: `container.read(passwordResetViewModelProvider)` を呼ぶ。
- **期待結果**: `AuthState.initial()` と同等（`isLoading: false`, `isSuccess: false`, `errorMessage: null`）。

### テストケース2: 送信に成功した場合、isSuccess が true になり isLoading が false に戻る
- **カテゴリ**: 正常系
- **対象メソッド**: sendResetEmail()
- **事前条件**: 初期状態。
- **入力値・テスト条件**: `resetPasswordUseCaseProvider` が `Right(unit)` を返す。
- **操作手順**: `await notifier.sendResetEmail(email: 'test@example.com')` を呼ぶ。
- **期待結果**: `state.isLoading == false`, `state.isSuccess == true`, `state.errorMessage == null`。

### テストケース3: 通信エラーの場合、errorMessage に通信エラー文言が設定される
- **カテゴリ**: 異常系
- **対象メソッド**: sendResetEmail()
- **事前条件**: 初期状態。
- **入力値・テスト条件**: `resetPasswordUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `await notifier.sendResetEmail(email: 'test@example.com')` を呼ぶ。
- **期待結果**: `state.errorMessage == '通信エラーが発生しました'`、`state.isSuccess == false`。

### テストケース4: 認証エラーの場合、errorMessage にメールアドレスが見つからない旨の文言が設定される
- **カテゴリ**: 異常系
- **対象メソッド**: sendResetEmail()
- **事前条件**: 初期状態。
- **入力値・テスト条件**: `resetPasswordUseCaseProvider` が `Left(Failure.auth())` を返す。
- **操作手順**: `await notifier.sendResetEmail(email: 'test@example.com')` を呼ぶ。
- **期待結果**: `state.errorMessage == 'メールアドレスが見つかりません'`。

### テストケース5: アカウント未検出の場合、errorMessage にアカウントが見つからない旨の文言が設定される
- **カテゴリ**: 異常系
- **対象メソッド**: sendResetEmail()
- **事前条件**: 初期状態。
- **入力値・テスト条件**: `resetPasswordUseCaseProvider` が `Left(Failure.notFound())` を返す。
- **操作手順**: `await notifier.sendResetEmail(email: 'test@example.com')` を呼ぶ。
- **期待結果**: `state.errorMessage == 'アカウントが見つかりません'`。

### テストケース6: 不明なエラーの場合、errorMessage に元のメッセージを含む文言が設定される
- **カテゴリ**: 異常系
- **対象メソッド**: sendResetEmail()
- **事前条件**: 初期状態。
- **入力値・テスト条件**: `resetPasswordUseCaseProvider` が `Left(Failure.unknown('boom'))` を返す。
- **操作手順**: `await notifier.sendResetEmail(email: 'test@example.com')` を呼ぶ。
- **期待結果**: `state.errorMessage == 'エラーが発生しました: boom'`。

### テストケース7: 呼び出し直後は isLoading が true になり isSuccess/errorMessage がリセットされる
- **カテゴリ**: 境界値
- **対象メソッド**: sendResetEmail()
- **事前条件**: 事前に1回失敗させ `errorMessage` が設定済みの状態。
- **入力値・テスト条件**: `resetPasswordUseCaseProvider` が `Left(Failure.network())` を返す（Fake は毎回同じ結果を返す）。
- **操作手順**: `notifier.sendResetEmail(email: 'retry@example.com')` を呼び出した直後（`await` する前）に state を確認し、その後 `await` する。
- **期待結果**: 呼び出し直後は `isLoading == true`、`isSuccess == false`、`errorMessage == null`（メソッド冒頭の `copyWith(isLoading: true, isSuccess: false, errorMessage: null)` によるリセットを確認）。

### テストケース8: email 引数が UseCase にそのまま渡される
- **カテゴリ**: 正常系
- **対象メソッド**: sendResetEmail()
- **事前条件**: 初期状態。
- **入力値・テスト条件**: `email: 'user@example.com'`。
- **操作手順**: `await notifier.sendResetEmail(email: 'user@example.com')` を呼ぶ。
- **期待結果**: `FakeResetPasswordUseCase.lastEmail == 'user@example.com'`、`callCount == 1`（委譲されていることの確認）。

### テストケース9: 成功状態からリセットした場合、初期状態に戻る
- **カテゴリ**: 正常系
- **対象メソッド**: resetState()
- **事前条件**: `sendResetEmail()` 成功済みで `isSuccess == true`。
- **入力値・テスト条件**: なし。
- **操作手順**: `notifier.resetState()` を呼ぶ。
- **期待結果**: `state` が `AuthState.initial()` と同等になる。

### テストケース10: 失敗状態からリセットした場合、errorMessage がクリアされる
- **カテゴリ**: 正常系
- **対象メソッド**: resetState()
- **事前条件**: `sendResetEmail()` 失敗済みで `errorMessage` が設定されている。
- **入力値・テスト条件**: なし。
- **操作手順**: `notifier.resetState()` を呼ぶ。
- **期待結果**: `state.errorMessage == null` かつ `isLoading == false`, `isSuccess == false`。

## 対象外

なし（分岐は `sendResetEmail()` の `Failure.when` 4パターンと `resetState()` のみで、
全て上記ケースでカバーされる想定）。
