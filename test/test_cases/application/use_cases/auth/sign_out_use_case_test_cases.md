# sign_out_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/auth/sign_out_use_case.dart |
| クラス名 | SignOutUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`SignOutUseCase` は `AuthRepository` への薄い委譲のみを行うため、
`test/helpers/fake_auth_use_case_repositories.dart` の `FakeAuthRepository` を使用する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 呼び出した場合、Repository.signOutに委譲される | 正常系 | call() | ✅ |
| 2 | Repositoryが成功を返した場合、その値がそのまま返る | 正常系 | call() | ✅ |
| 3 | Repositoryが失敗を返した場合、その値がそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 呼び出した場合、Repository.signOutに委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository` を注入した `SignOutUseCase` を生成
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: `FakeAuthRepository.signOutCallCount` が1になる

### テストケース2: Repositoryが成功を返した場合、その値がそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signOutResult` に `Right(unit)` を設定
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: 戻り値が `Right(unit)` と一致する

### テストケース3: Repositoryが失敗を返した場合、その値がそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signOutResult` に `Left(Failure.auth())` を設定
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: 戻り値が `Left(Failure.auth())` と一致する
