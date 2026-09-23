# sign_up_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/auth/sign_up/sign_up_view_model.dart |
| クラス名 | SignUpViewModel |
| テスト対象メソッド | build() / signUp() / resetState() |

## 実行環境について

`SignUpViewModel` は `SignUpUseCase`（`Provider<SignUpUseCase>`）と
`authSyncInProgressProvider`（`StateProvider<bool>`）に依存する。

`SignUpUseCase` はインターフェースではなく具象クラスのため、テストでは
`test/presentation/auth/sign_up/sign_up_view_model_test.dart` 内に手書きの
`FakeSignUpUseCase`（`SignUpUseCase` を継承し `call()` のみをオーバーライド）を定義した。
コンストラクタの型要件を満たすために `MockAuthRepository`（既存の開発用モック）と
`fake_cloud_firestore` の `FakeFirebaseFirestore` / 実 `DatabaseHelper` を渡しているが、
`call()` を完全に上書きしているためこれらは実際には使用されない
（`test/infrastructure/sync/auto_sync_service_test.dart` の `FakeSyncService` と同じ手法）。

`ProviderContainer(overrides: [signUpUseCaseProvider.overrideWithValue(...)])` で
DI し、Widget は一切 pump しない。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 初期状態は isLoading/isSuccess が false で errorMessage が null | 正常系 | build() | ✅ |
| 2 | 成功した場合、isSuccess が true になり isLoading は false に戻る | 正常系 | signUp() | ✅ |
| 3 | 成功した場合、SignUpUseCase に email と password がそのまま渡される | 正常系 | signUp() | ✅ |
| 4 | 呼び出し中は isLoading が true になり isSuccess/errorMessage はリセットされる | 境界値 | signUp() | ✅ |
| 5 | 呼び出し中は authSyncInProgressProvider が true になり、完了後に false へ戻る | 正常系 | signUp() | ✅ |
| 6 | NetworkFailure の場合、通信エラーメッセージが設定される | 異常系 | signUp() | ✅ |
| 7 | AuthFailure の場合、メール重複エラーメッセージが設定される | 異常系 | signUp() | ✅ |
| 8 | NotFoundFailure の場合、汎用エラーメッセージが設定される | 異常系 | signUp() | ✅ |
| 9 | UnknownFailure の場合、メッセージ付きの汎用エラーメッセージが設定される | 異常系 | signUp() | ✅ |
| 10 | 失敗した場合でも authSyncInProgressProvider は false に戻る | 異常系 | signUp() | ✅ |
| 11 | 成功状態から呼び出すと初期状態に戻る | 正常系 | resetState() | ✅ |
| 12 | エラー状態から呼び出すと errorMessage がクリアされる | 正常系 | resetState() | ✅ |

## テストケース詳細

### テストケース1: 初期状態は isLoading/isSuccess が false で errorMessage が null
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `ProviderContainer` を作成し `signUpViewModelProvider` を読む
- **入力値・テスト条件**: なし
- **操作手順**: `container.read(signUpViewModelProvider)`
- **期待結果**: `AuthState.initial()` 相当（`isLoading: false, isSuccess: false, errorMessage: null`）

### テストケース2: 成功した場合、isSuccess が true になり isLoading は false に戻る
- **カテゴリ**: 正常系
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` が `Right(_testUser)` を返す
- **入力値・テスト条件**: email='new@example.com', password='password123'
- **操作手順**: `notifier.signUp(email:, password:)` を await
- **期待結果**: `isLoading: false, isSuccess: true, errorMessage: null`

### テストケース3: 成功した場合、SignUpUseCase に email と password がそのまま渡される
- **カテゴリ**: 正常系
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` が呼び出し引数を記録する
- **入力値・テスト条件**: email='foo@example.com', password='secret'
- **操作手順**: `notifier.signUp(...)` を await し `useCase.receivedCalls` を検証
- **期待結果**: `callCount == 1`、渡された email/password が入力値と一致（委譲の検証）

### テストケース4: 呼び出し中は isLoading が true になり isSuccess/errorMessage はリセットされる
- **カテゴリ**: 境界値
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` に `Completer` を渡し、`call()` が完了を待つようにする
- **入力値・テスト条件**: `signUp()` を呼んだ直後（`await` 完了前）の中間状態
- **操作手順**: `signUp()` を呼び出しつつ即座に `container.read(signUpViewModelProvider)` を確認 → `Completer.complete()` → 後片付けの await
- **期待結果**: `isLoading: true, isSuccess: false, errorMessage: null`

### テストケース5: 呼び出し中は authSyncInProgressProvider が true になり、完了後に false へ戻る
- **カテゴリ**: 正常系
- **対象メソッド**: signUp()
- **事前条件**: `Completer` で `call()` を保留した状態
- **入力値・テスト条件**: signUp() 呼び出し中／完了後
- **操作手順**: 呼び出し直後に `authSyncInProgressProvider` を確認 → `Completer.complete()` → await 後に再確認
- **期待結果**: 呼び出し中は `true`、完了後は `false`

### テストケース6: NetworkFailure の場合、通信エラーメッセージが設定される
- **カテゴリ**: 異常系
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` が `Left(Failure.network())` を返す
- **入力値・テスト条件**: email='new@example.com', password='password123'
- **操作手順**: `notifier.signUp(...)` を await
- **期待結果**: `isLoading: false, isSuccess: false, errorMessage: '通信エラーが発生しました'`

### テストケース7: AuthFailure の場合、メール重複エラーメッセージが設定される
- **カテゴリ**: 異常系
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` が `Left(Failure.auth())` を返す
- **入力値・テスト条件**: email='dup@example.com', password='password123'
- **操作手順**: `notifier.signUp(...)` を await
- **期待結果**: `errorMessage: 'このメールアドレスはすでに使用されています'`

### テストケース8: NotFoundFailure の場合、汎用エラーメッセージが設定される
- **カテゴリ**: 異常系
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` が `Left(Failure.notFound())` を返す
- **入力値・テスト条件**: email='new@example.com', password='password123'
- **操作手順**: `notifier.signUp(...)` を await
- **期待結果**: `errorMessage: 'エラーが発生しました'`

### テストケース9: UnknownFailure の場合、メッセージ付きの汎用エラーメッセージが設定される
- **カテゴリ**: 異常系
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` が `Left(Failure.unknown('boom'))` を返す
- **入力値・テスト条件**: email='new@example.com', password='password123'
- **操作手順**: `notifier.signUp(...)` を await
- **期待結果**: `errorMessage: 'エラーが発生しました: boom'`

### テストケース10: 失敗した場合でも authSyncInProgressProvider は false に戻る
- **カテゴリ**: 異常系
- **対象メソッド**: signUp()
- **事前条件**: `FakeSignUpUseCase` が `Left(Failure.network())` を返す
- **入力値・テスト条件**: email='new@example.com', password='password123'
- **操作手順**: `notifier.signUp(...)` を await 後に `authSyncInProgressProvider` を確認
- **期待結果**: `false`（成功・失敗どちらでも必ず解除される）

### テストケース11: 成功状態から呼び出すと初期状態に戻る
- **カテゴリ**: 正常系
- **対象メソッド**: resetState()
- **事前条件**: signUp() が成功し `isSuccess: true` の状態
- **入力値・テスト条件**: なし
- **操作手順**: `notifier.resetState()`
- **期待結果**: `isLoading: false, isSuccess: false, errorMessage: null`（`AuthState.initial()`相当）

### テストケース12: エラー状態から呼び出すと errorMessage がクリアされる
- **カテゴリ**: 正常系
- **対象メソッド**: resetState()
- **事前条件**: signUp() が失敗し `errorMessage` が設定された状態
- **入力値・テスト条件**: なし
- **操作手順**: `notifier.resetState()`
- **期待結果**: `errorMessage: null, isSuccess: false`

## 対象外

なし（対象ファイルは `build()` / `signUp()` / `resetState()` の全行が上記12ケースで到達する）
