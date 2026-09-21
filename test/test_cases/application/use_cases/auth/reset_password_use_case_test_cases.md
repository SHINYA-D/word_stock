# reset_password_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/auth/reset_password_use_case.dart |
| クラス名 | ResetPasswordUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`ResetPasswordUseCase` は `AuthRepository` への薄い委譲のみを行うため、
`test/helpers/fake_auth_use_case_repositories.dart` の `FakeAuthRepository`
（手書きフェイク、呼び出し内容の記録・任意の `Either<Failure, T>` 返却が可能）を使用する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | メールアドレスを指定して呼び出した場合、Repositoryに同じメールアドレスで委譲される | 正常系 | call() | ✅ |
| 2 | Repositoryが成功を返した場合、その値がそのまま返る | 正常系 | call() | ✅ |
| 3 | Repositoryが失敗を返した場合、その値がそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: メールアドレスを指定して呼び出した場合、Repositoryに同じメールアドレスで委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository` を注入した `ResetPasswordUseCase` を生成
- **入力値・テスト条件**: `email: 'user@example.com'`
- **操作手順**: `useCase.call(email: 'user@example.com')` を呼ぶ
- **期待結果**: `FakeAuthRepository.sendPasswordResetEmailCallCount` が1になり、`receivedResetPasswordEmail` が `'user@example.com'` と一致する

### テストケース2: Repositoryが成功を返した場合、その値がそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.sendPasswordResetEmailResult` に `Right(unit)` を設定
- **入力値・テスト条件**: `email: 'user@example.com'`
- **操作手順**: `useCase.call(email: 'user@example.com')` を呼ぶ
- **期待結果**: 戻り値が `Right(unit)` と一致する

### テストケース3: Repositoryが失敗を返した場合、その値がそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.sendPasswordResetEmailResult` に `Left(Failure.network())` を設定
- **入力値・テスト条件**: `email: 'user@example.com'`
- **操作手順**: `useCase.call(email: 'user@example.com')` を呼ぶ
- **期待結果**: 戻り値が `Left(Failure.network())` と一致する
