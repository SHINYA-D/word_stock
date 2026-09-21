# sign_in_with_google_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/auth/sign_in_with_google_use_case.dart |
| クラス名 | SignInWithGoogleUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`SignInWithGoogleUseCase` は `AuthRepository` と `SyncService`（ログイン成功時の同期）に依存する。

- **AuthRepository**: `test/helpers/fake_auth_use_case_repositories.dart` の `FakeAuthRepository` を使用する。
- **SyncService**: 具象クラスのため、`test/helpers/fake_auth_use_case_repositories.dart` の
  `FakeSyncServiceForLogin`（`syncRemoteToLocalOnLogin()` のみオーバーライド）を使用する。
  実際の Firestore/SQLite 通信は発生しない。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 呼び出した場合、Repository.signInWithGoogleに委譲される | 正常系 | call() | ✅ |
| 2 | ログインに成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される | 正常系 | call() | ✅ |
| 3 | ログインに失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない | 異常系 | call() | ✅ |
| 4 | ログイン成功後の同期処理で例外が発生した場合、例外は握りつぶされログイン結果はそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 呼び出した場合、Repository.signInWithGoogleに委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository` / `FakeSyncServiceForLogin` を注入した `SignInWithGoogleUseCase` を生成
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: `FakeAuthRepository.signInWithGoogleCallCount` が1になる

### テストケース2: ログインに成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signInWithGoogleResult` に `Right(AppUser)` を設定
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: 戻り値が設定した `Right(AppUser)` と一致し、`syncRemoteToLocalOnLoginCallCount` が1になる

### テストケース3: ログインに失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signInWithGoogleResult` に `Left(Failure.auth())` を設定
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: 戻り値が `Left(Failure.auth())` と一致し、`syncRemoteToLocalOnLoginCallCount` は0のまま

### テストケース4: ログイン成功後の同期処理で例外が発生した場合、例外は握りつぶされログイン結果はそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signInWithGoogleResult` に `Right(AppUser)`、
  `FakeSyncServiceForLogin.exceptionToThrow` に `Exception('sync failed')` を設定
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: `useCase.call()` は例外を投げず、戻り値は設定した `Right(AppUser)` のまま。`syncRemoteToLocalOnLoginCallCount` は1
