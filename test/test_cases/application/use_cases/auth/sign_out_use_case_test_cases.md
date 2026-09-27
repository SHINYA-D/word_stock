# sign_out_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/auth/sign_out_use_case.dart |
| クラス名 | SignOutUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`SignOutUseCase` は `AuthRepository` と `SyncRepository` の2つに依存し、
「送信してからログアウトする」という順序を持つ薄いユースケースである。
`test/helpers/fake_auth_use_case_repositories.dart` の `FakeAuthRepository` と
`FakeSyncServiceForLogin` を使用する。呼び出し順を確認するテストケースのみ、
共有ヘルパーは変更せず、このテストファイル内に `FakeAuthRepository` /
`FakeSyncServiceForLogin` を継承した順序記録用の薄いラッパー
（`_RecordingAuthRepository` / `_RecordingSyncService`）を用意する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 呼び出した場合、Repository.signOutに委譲される | 正常系 | call() | ✅ |
| 2 | Repositoryが成功を返した場合、その値がそのまま返る | 正常系 | call() | ✅ |
| 3 | Repositoryが失敗を返した場合、その値がそのまま返る | 異常系 | call() | ✅ |
| 4 | 呼び出した場合、ログアウト前の送信(pushBeforeSignOut)が1回呼ばれる | 正常系 | call() | ✅ |
| 5 | 呼び出した場合、送信(pushBeforeSignOut)がRepository.signOutより先に呼ばれる | 正常系 | call() | ✅ |
| 6 | 未送信が残っていても(pendingCountAfterPush > 0)、ログアウトする | 境界値 | call() | ✅ |

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

### テストケース4: 呼び出した場合、ログアウト前の送信(pushBeforeSignOut)が1回呼ばれる
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository` / `FakeSyncServiceForLogin` を注入した `SignOutUseCase` を生成
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: `FakeSyncServiceForLogin.pushBeforeSignOutCallCount` が1になる

### テストケース5: 呼び出した場合、送信(pushBeforeSignOut)がRepository.signOutより先に呼ばれる
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: 呼び出し順を記録する `_RecordingAuthRepository` / `_RecordingSyncService` を注入した `SignOutUseCase` を生成
- **入力値・テスト条件**: なし
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: 呼び出し順の記録が `['pushBeforeSignOut', 'signOut']` の順になる

### テストケース6: 未送信が残っていても(pendingCountAfterPush > 0)、ログアウトする
- **カテゴリ**: 境界値
- **対象メソッド**: call()
- **事前条件**: `FakeSyncServiceForLogin.pendingCountAfterPush` に `3`（0より大きい値）を設定
- **入力値・テスト条件**: 送信しきれなかった変更が残っている状態（`pendingCountAfterPush = 3`）
- **操作手順**: `useCase.call()` を呼ぶ
- **期待結果**: `FakeAuthRepository.signOutCallCount` が1になり、戻り値が `Right(unit)` になる（未送信が残っていてもログアウト自体は行われる）
