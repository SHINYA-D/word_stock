# sign_in_with_email_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/auth/sign_in_with_email_use_case.dart |
| クラス名 | SignInWithEmailUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`SignInWithEmailUseCase` は `AuthRepository` と domain 層の `SyncRepository` インターフェース
（`lib/domain/repositories/sync_repository.dart`。ログイン成功時の同期）に依存する。

- **AuthRepository**: `test/helpers/fake_auth_use_case_repositories.dart` の `FakeAuthRepository`
  （手書きフェイク、呼び出し内容の記録・任意の `Either<Failure, T>` 返却が可能）を使用する。
- **SyncRepository（呼び出し回数の確認・ケース1〜4）**: `test/helpers/fake_auth_use_case_repositories.dart`
  の `FakeSyncServiceForLogin` が `SyncRepository` を直接実装した手書きフェイク
  （呼び出し回数の記録・例外の注入のみ）を使用する。実際の SQLite/リモート通信は発生しない。
- **本物の SyncService を使う確認（SYN-L01〜L03・ケース5〜7）**: 仕様書の期待値（取得結果への反映・
  取得失敗時の戻り値・認証失敗時に読み取りが呼ばれないこと）は呼び出し回数だけでは確かめられないため、
  本物の `lib/infrastructure/sync/sync_service.dart`（`SyncRepository` の実装）と、
  `SyncRemoteDataSource` を実装したテストファイル内の手書きフェイク
  `_FakeLoginSyncRemoteDataSource`（`fetchChanges` の呼び出し回数を記録できる）、
  `sqflite_common_ffi`（このファイル専用の一時ディレクトリ）による実 SQLite を組み合わせる。
  取得結果は `FolderRepositoryImpl` / `WordRepositoryImpl`（`onLocalChanged: () {}`）の
  `getFolders` / `getWords` で観測する。オンラインは
  `test/helpers/fake_infrastructure.dart` の `FakeConnectivityMonitor(online: true)` を使う
  （`test/infrastructure/sync/sync_service_test.dart` の構成を参考にした）。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|-------|---------|-----------|------|
| 1 | email/passwordを指定して呼び出した場合、Repositoryに同じ値で委譲される | | 正常系 | call() | ✅ |
| 2 | ログインに成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される | | 正常系 | call() | ✅ |
| 3 | ログインに失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない | | 異常系 | call() | ✅ |
| 4 | ログイン成功後の同期処理で例外が発生した場合、例外は握りつぶされログイン結果はそのまま返る | | 異常系 | call() | ✅ |
| 5 | ローカルが空で、リモートにフォルダFとFの中の単語Wがある状態でメールログインに成功した場合、戻り値がRight(AppUser)になり、戻り値を返した時点でgetFoldersにF、getWords(F)にWが含まれる [SYN-L01] | SYN-L01 #41ebed | 正常系 | call() | ✅ |
| 6 | メールログインに成功し、その後の取得がリモートの失敗で失敗した場合、戻り値がRight(AppUser)になる [SYN-L02] | SYN-L02 #95da2c | 異常系 | call() | ✅ |
| 7 | メールログインがAuthFailureで失敗した場合、戻り値がLeft(AuthFailure)になり、リモートへのデータの読み取りが呼ばれない [SYN-L03] | SYN-L03 #33b5e5 | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: email/passwordを指定して呼び出した場合、Repositoryに同じ値で委譲される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository` / `FakeSyncServiceForLogin` を注入した `SignInWithEmailUseCase` を生成
- **入力値・テスト条件**: `email: 'user@example.com'`, `password: 'password123'`
- **操作手順**: `useCase.call(email: ..., password: ...)` を呼ぶ
- **期待結果**: `FakeAuthRepository.signInWithEmailCallCount` が1になり、`receivedSignInWithEmail` が指定した値と一致する

### テストケース2: ログインに成功した場合、Right(AppUser)がそのまま返り、ログイン時同期が1回実行される
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signInWithEmailResult` に `Right(AppUser)` を設定
- **入力値・テスト条件**: 有効な email/password
- **操作手順**: `useCase.call(...)` を呼ぶ
- **期待結果**: 戻り値が設定した `Right(AppUser)` と一致し、`FakeSyncServiceForLogin.syncRemoteToLocalOnLoginCallCount` が1になる

### テストケース3: ログインに失敗した場合、Left(Failure)がそのまま返り、ログイン時同期は実行されない
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signInWithEmailResult` に `Left(Failure.auth())` を設定
- **入力値・テスト条件**: 誤ったパスワード
- **操作手順**: `useCase.call(...)` を呼ぶ
- **期待結果**: 戻り値が `Left(Failure.auth())` と一致し、`syncRemoteToLocalOnLoginCallCount` は0のまま

### テストケース4: ログイン成功後の同期処理で例外が発生した場合、例外は握りつぶされログイン結果はそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signInWithEmailResult` に `Right(AppUser)`、
  `FakeSyncServiceForLogin.exceptionToThrow` に `Exception('sync failed')` を設定
- **入力値・テスト条件**: 有効な email/password
- **操作手順**: `useCase.call(...)` を呼ぶ
- **期待結果**: `useCase.call()` は例外を投げず、戻り値は設定した `Right(AppUser)` のまま。`syncRemoteToLocalOnLoginCallCount` は1（呼ばれたが失敗した）

### テストケース5: ローカルが空で、リモートにフォルダFとFの中の単語Wがある状態でメールログインに成功した場合、戻り値がRight(AppUser)になり、戻り値を返した時点でgetFoldersにF、getWords(F)にWが含まれる [SYN-L01]
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: 実 SQLite（空）、本物の `SyncService`（`FolderRepositoryImpl` / `WordRepositoryImpl` と共有）、
  `_FakeLoginSyncRemoteDataSource` にフォルダ F（`createdAt` あり）と F の中の単語 W をシード、
  `FakeConnectivityMonitor(online: true)`、`FakeAuthRepository.signInWithEmailResult` に `Right(AppUser)` を設定
- **入力値・テスト条件**: 有効な email/password
- **操作手順**: `realUseCase.call(email: ..., password: ...)` を呼び、戻り値を受け取った後に
  `folderRepo.getFolders(userId: ...)` / `wordRepo.getWords(userId: ..., folderId: 'F')` を呼ぶ
- **期待結果**: `realUseCase.call()` の戻り値が `Right(AppUser)`。その時点で `getFolders` の戻り値に F が、
  `getWords('F')` の戻り値に W が含まれる

### テストケース6: メールログインに成功し、その後の取得がリモートの失敗で失敗した場合、戻り値がRight(AppUser)になる [SYN-L02]
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `_FakeLoginSyncRemoteDataSource.failFetch = true`（`fetchChanges` が例外を投げる）、
  `FakeAuthRepository.signInWithEmailResult` に `Right(AppUser)` を設定
- **入力値・テスト条件**: 有効な email/password
- **操作手順**: `realUseCase.call(...)` を呼ぶ
- **期待結果**: 戻り値が `Right(AppUser)`（同期失敗はログインの成否に影響しない）

### テストケース7: メールログインがAuthFailureで失敗した場合、戻り値がLeft(AuthFailure)になり、リモートへのデータの読み取りが呼ばれない [SYN-L03]
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `FakeAuthRepository.signInWithEmailResult` に `Left(Failure.auth())` を設定、
  `_FakeLoginSyncRemoteDataSource` にフォルダ F をシード
- **入力値・テスト条件**: 誤ったパスワード
- **操作手順**: `realUseCase.call(...)` を呼ぶ
- **期待結果**: 戻り値が `Left(Failure.auth())`。`_FakeLoginSyncRemoteDataSource.fetchCallCount` が0のまま
  （リモートへのデータの読み取りが呼ばれない）、`getFolders` の戻り値も空のまま
