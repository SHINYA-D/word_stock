# sign_up_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/auth/sign_up_use_case.dart |
| クラス名 | SignUpUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`SignUpUseCase` は `AuthRepository` と `SyncService`（登録成功時の同期）に依存する。

- **AuthRepository**: `test/helpers/fake_auth_use_case_repositories.dart` の `FakeAuthRepository` を使用する。
- **SyncService**: 具象クラスのため、テストケース1〜4は `test/helpers/fake_auth_use_case_repositories.dart` の
  `FakeSyncServiceForLogin`（`syncRemoteToLocalOnLogin()` のみオーバーライド）を使用する。
  実際の Firestore/SQLite 通信は発生しない。
- **テストケース5〜7（SYN-L07〜L09）**: `docs/detailed_design/online_offline/online_offline.md`
  （接頭辞 SYN、6章「ユースケース」）の期待値を、本物の `SyncService` + 手書きフェイク
  `SyncRemoteDataSource`（`_FakeSignUpSyncRemoteDataSource`）+ 本物の SQLite（`sqflite_common_ffi`、
  このテストファイル専用の一時ディレクトリ）で確かめる。`FolderRepositoryImpl` 経由で
  `getFolders` の戻り値を検証する。`SignUpUseCase` / `SyncService` の実装は「どう呼ぶか」を
  知るためだけに読み、期待値は仕様書だけから作った。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | email/passwordを指定して呼び出した場合、Repositoryに同じ値で委譲される | 正常系 | call() | ✅ |
| 2 | 登録に成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される | 正常系 | call() | ✅ |
| 3 | 登録に失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない | 異常系 | call() | ✅ |
| 4 | 登録成功後の同期処理で例外が発生した場合、例外は握りつぶされ登録結果はそのまま返る | 異常系 | call() | ✅ |
| 5 | 新規登録に成功した（リモートにデータなし）場合、戻り値がRight(AppUser)になり、getFoldersの戻り値が空になる [SYN-L07 #415518] | 正常系 | call() | ✅ |
| 6 | 新規登録に成功し、その後の取得がリモートの失敗で失敗した場合、戻り値がRight(AppUser)になる [SYN-L08 #886495] | 異常系 | call() | ✅ |
| 7 | 新規登録がAuthFailureで失敗した場合、戻り値がLeft(AuthFailure)になり、リモートへのデータの読み取りが呼ばれない [SYN-L09 #bbca22] | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: email/passwordを指定して呼び出した場合、Repositoryに同じ値で委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository` / `FakeSyncServiceForLogin` を注入した `SignUpUseCase` を生成
- **入力値・テスト条件**: `email: 'new@example.com'`, `password: 'password123'`
- **操作手順**: `useCase.call(email: ..., password: ...)` を呼ぶ
- **期待結果**: `FakeAuthRepository.signUpWithEmailCallCount` が1になり、`receivedSignUpWithEmail` が指定した値と一致する

### テストケース2: 登録に成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signUpWithEmailResult` に `Right(AppUser)` を設定
- **入力値・テスト条件**: 有効な email/password
- **操作手順**: `useCase.call(...)` を呼ぶ
- **期待結果**: 戻り値が設定した `Right(AppUser)` と一致し、`syncRemoteToLocalOnLoginCallCount` が1になる

### テストケース3: 登録に失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signUpWithEmailResult` に `Left(Failure.unknown('already exists'))` を設定
- **入力値・テスト条件**: 既に使われているメールアドレス
- **操作手順**: `useCase.call(...)` を呼ぶ
- **期待結果**: 戻り値が `Left(Failure.unknown('already exists'))` と一致し、`syncRemoteToLocalOnLoginCallCount` は0のまま

### テストケース4: 登録成功後の同期処理で例外が発生した場合、例外は握りつぶされ登録結果はそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signUpWithEmailResult` に `Right(AppUser)`、
  `FakeSyncServiceForLogin.exceptionToThrow` に `Exception('sync failed')` を設定
- **入力値・テスト条件**: 有効な email/password
- **操作手順**: `useCase.call(...)` を呼ぶ
- **期待結果**: `useCase.call()` は例外を投げず、戻り値は設定した `Right(AppUser)` のまま。`syncRemoteToLocalOnLoginCallCount` は1

### テストケース5: 新規登録に成功した（リモートにデータなし）場合、戻り値がRight(AppUser)になり、getFoldersの戻り値が空になる [SYN-L07 #415518]
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: 本物の `SyncService` + `_FakeSignUpSyncRemoteDataSource`（リモートにデータを seed しない）+
  本物の SQLite（一時ディレクトリ）。`FakeAuthRepository.signUpWithEmailResult` に `Right(AppUser)` を設定
- **入力値・テスト条件**: 有効な email/password。リモートにフォルダ・単語のデータなし
- **操作手順**: `realUseCase.call(email: ..., password: ...)` を呼ぶ
- **期待結果**: 戻り値が `Right(AppUser)` になり、`FolderRepositoryImpl.getFolders(userId: userId)` の戻り値が空になる

### テストケース6: 新規登録に成功し、その後の取得がリモートの失敗で失敗した場合、戻り値がRight(AppUser)になる [SYN-L08 #886495]
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: 本物の `SyncService` + `_FakeSignUpSyncRemoteDataSource`（`failFetch = true`）。
  `FakeAuthRepository.signUpWithEmailResult` に `Right(AppUser)` を設定
- **入力値・テスト条件**: 有効な email/password。リモートの `fetchChanges` が例外を投げる
- **操作手順**: `realUseCase.call(email: ..., password: ...)` を呼ぶ
- **期待結果**: 戻り値が `Right(AppUser)` になる（同期の失敗が登録結果に影響しない）

### テストケース7: 新規登録がAuthFailureで失敗した場合、戻り値がLeft(AuthFailure)になり、リモートへのデータの読み取りが呼ばれない [SYN-L09 #bbca22]
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signUpWithEmailResult` に `Left(Failure.auth())` を設定。
  リモートにフォルダFを seed 済み
- **入力値・テスト条件**: 有効な email/password（登録が AuthFailure で失敗する状況）
- **操作手順**: `realUseCase.call(email: ..., password: ...)` を呼ぶ
- **期待結果**: 戻り値が `Left(Failure.auth())` になり、`getFolders` の戻り値は空のまま、
  `_FakeSignUpSyncRemoteDataSource.fetchCallCount` は0のまま（リモートへのデータの読み取りが呼ばれない）
