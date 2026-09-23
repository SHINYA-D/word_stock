# auth_repository_impl_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/auth_repository_impl.dart |
| クラス名 | AuthRepositoryImpl |
| テスト対象メソッド | signInWithEmail() / signUpWithEmail() / signInWithGoogle() / signOut() / sendPasswordResetEmail() / authStateChanges / _toAppUser()(private、各メソッド経由で間接的に検証) / _mapFirebaseAuthException()(private、各メソッド経由で間接的に検証) |

## 実行環境について

`AuthRepositoryImpl` は `FirebaseAuthDataSource`（内部で `FirebaseAuth` / `GoogleSignIn` の
実インスタンスを要求する具象クラス）に依存するため、そのままではユニットテストで生成できない。
以下の方針で Dart Pure Test として実行できるようにしている。

- `FirebaseAuthDataSource` の公開メンバー（`authStateChanges` / `signInWithEmail` /
  `signUpWithEmail` / `signInWithGoogle` / `signOut` / `sendPasswordResetEmail`）のみを
  `implements` した手書きフェイク `test/helpers/fake_auth_infrastructure.dart` の
  `FakeFirebaseAuthDataSource` を使用する。各メソッドの戻り値/例外はテストごとに関数として注入する。
- firebase_auth パッケージの `User` / `UserCredential` は private コンストラクタしか持たない
  具象クラスのため、`noSuchMethod` にフォールバックする最小限のフェイク `FakeUser` /
  `FakeUserCredential` を用意し、`AuthRepositoryImpl` が実際に参照する
  `uid` / `email` / `displayName` / `user` のみを override する。
- `mockito` / `mocktail` や `firebase_auth_mocks` などの追加パッケージは使用しない
  （CLAUDE.md の方針に従い pubspec.yaml は変更しない）。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | メールとパスワードでのサインインに成功した場合、AppUserに変換されRightで返る | 正常系 | signInWithEmail() | ✅ |
| 2 | サインインしたユーザーのemail/displayNameがnullの場合、emailは空文字に変換されdisplayNameはnullのまま返る | 境界値 | signInWithEmail() | ✅ |
| 3 | FirebaseAuthExceptionのcodeがnetwork-request-failedの場合、Failure.networkが返る | 異常系 | signInWithEmail() | ✅ |
| 4 | FirebaseAuthExceptionのcodeがuser-not-foundの場合、Failure.authが返る | 異常系 | signInWithEmail() | ✅ |
| 5 | FirebaseAuthExceptionのcodeがwrong-passwordの場合、Failure.authが返る | 異常系 | signInWithEmail() | ✅ |
| 6 | FirebaseAuthExceptionのcodeがinvalid-credentialの場合、Failure.authが返る | 異常系 | signInWithEmail() | ✅ |
| 7 | FirebaseAuthExceptionのcodeがemail-already-in-useの場合、Failure.authが返る | 異常系 | signInWithEmail() | ✅ |
| 8 | FirebaseAuthExceptionのcodeが未知でmessageがある場合、Failure.unknown(message)が返る | 異常系 | signInWithEmail() | ✅ |
| 9 | FirebaseAuthExceptionのcodeが未知でmessageがnullの場合、Failure.unknown(code)が返る | 境界値 | signInWithEmail() | ✅ |
| 10 | FirebaseAuthException以外の例外が発生した場合、Failure.unknown(例外文字列)が返る | 異常系 | signInWithEmail() | ✅ |
| 11 | UserCredentialのuserがnullの場合、Failure.unknownが返る | 境界値 | signInWithEmail() | ✅ |
| 12 | サインアップに成功した場合、AppUserに変換されRightで返る | 正常系 | signUpWithEmail() | ✅ |
| 13 | FirebaseAuthExceptionのcodeがemail-already-in-useの場合、Failure.authが返る | 異常系 | signUpWithEmail() | ✅ |
| 14 | Google認証に成功した場合、AppUserに変換されRightで返る | 正常系 | signInWithGoogle() | ✅ |
| 15 | Google認証がキャンセルされた場合、未知のコードとしてFailure.unknownが返る | 異常系 | signInWithGoogle() | ✅ |
| 16 | サインアウトに成功した場合、Right(unit)が返る | 正常系 | signOut() | ✅ |
| 17 | サインアウト中にFirebaseAuthExceptionが発生した場合、対応するFailureが返る | 異常系 | signOut() | ✅ |
| 18 | パスワードリセットメール送信に成功した場合、Right(unit)が返る | 正常系 | sendPasswordResetEmail() | ✅ |
| 19 | FirebaseAuthExceptionのcodeがuser-not-foundの場合、Failure.authが返る | 異常系 | sendPasswordResetEmail() | ✅ |
| 20 | 認証状態変化のストリームにユーザーが流れた場合、AppUserに変換されて流れる | 正常系 | authStateChanges | ✅ |
| 21 | 認証状態変化のストリームにnullが流れた場合、nullがそのまま流れる | 境界値 | authStateChanges | ✅ |

## テストケース詳細

### テストケース1: メールとパスワードでのサインインに成功した場合、AppUserに変換されRightで返る
- **カテゴリ**: 正常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `FakeFirebaseAuthDataSource.signInWithEmailImpl`がuid/email/displayNameを持つUserCredentialを返すよう設定済み
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(email: ..., password: ...)` を呼ぶ
- **期待結果**: `Right(AppUser(id: 'uid-1', email: 'user@example.com', displayName: 'テストユーザー'))`

### テストケース2: サインインしたユーザーのemail/displayNameがnullの場合、emailは空文字に変換されdisplayNameはnullのまま返る
- **カテゴリ**: 境界値
- **対象メソッド**: signInWithEmail()
- **事前条件**: FakeUserのemail/displayNameを共にnullに設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `user.email == ''`、`user.displayName == null`

### テストケース3: FirebaseAuthExceptionのcodeがnetwork-request-failedの場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`FirebaseAuthException(code: 'network-request-failed')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.network())`

### テストケース4: FirebaseAuthExceptionのcodeがuser-not-foundの場合、Failure.authが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`FirebaseAuthException(code: 'user-not-found')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.auth())`

### テストケース5: FirebaseAuthExceptionのcodeがwrong-passwordの場合、Failure.authが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`FirebaseAuthException(code: 'wrong-password')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.auth())`

### テストケース6: FirebaseAuthExceptionのcodeがinvalid-credentialの場合、Failure.authが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`FirebaseAuthException(code: 'invalid-credential')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.auth())`

### テストケース7: FirebaseAuthExceptionのcodeがemail-already-in-useの場合、Failure.authが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`FirebaseAuthException(code: 'email-already-in-use')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.auth())`

### テストケース8: FirebaseAuthExceptionのcodeが未知でmessageがある場合、Failure.unknown(message)が返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`FirebaseAuthException(code: 'some-unmapped-code', message: '想定外のエラーメッセージ')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.unknown('想定外のエラーメッセージ'))`

### テストケース9: FirebaseAuthExceptionのcodeが未知でmessageがnullの場合、Failure.unknown(code)が返る
- **カテゴリ**: 境界値
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`FirebaseAuthException(code: 'some-unmapped-code')`（message未指定）をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.unknown('some-unmapped-code'))`（messageがnullのためcodeが使われる）

### テストケース10: FirebaseAuthException以外の例外が発生した場合、Failure.unknown(例外文字列)が返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`StateError('予期しないエラー')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.unknown(e.toString()))`

### テストケース11: UserCredentialのuserがnullの場合、Failure.unknownが返る
- **カテゴリ**: 境界値
- **対象メソッド**: signInWithEmail()
- **事前条件**: `signInWithEmailImpl`が`user`がnullの`FakeUserCredential`を返すよう設定（`result.user!`のnull check operatorが例外を投げる）
- **入力値・テスト条件**: email='user@example.com', password='password'
- **操作手順**: `repository.signInWithEmail(...)` を呼ぶ
- **期待結果**: `Left`が返り、`UnknownFailure`型であること（catch(e)ブロックがnull check例外を捕捉する）

### テストケース12: サインアップに成功した場合、AppUserに変換されRightで返る
- **カテゴリ**: 正常系
- **対象メソッド**: signUpWithEmail()
- **事前条件**: `signUpWithEmailImpl`がuid/emailを持つUserCredentialを返すよう設定
- **入力値・テスト条件**: email='new@example.com', password='password'
- **操作手順**: `repository.signUpWithEmail(...)` を呼ぶ
- **期待結果**: `Right(AppUser(id: 'uid-3', email: 'new@example.com'))`

### テストケース13: FirebaseAuthExceptionのcodeがemail-already-in-useの場合、Failure.authが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signUpWithEmail()
- **事前条件**: `signUpWithEmailImpl`が`FirebaseAuthException(code: 'email-already-in-use')`をthrowするよう設定
- **入力値・テスト条件**: email='new@example.com', password='password'
- **操作手順**: `repository.signUpWithEmail(...)` を呼ぶ
- **期待結果**: `Left(Failure.auth())`

### テストケース14: Google認証に成功した場合、AppUserに変換されRightで返る
- **カテゴリ**: 正常系
- **対象メソッド**: signInWithGoogle()
- **事前条件**: `signInWithGoogleImpl`がuid/emailを持つUserCredentialを返すよう設定
- **入力値・テスト条件**: なし
- **操作手順**: `repository.signInWithGoogle()` を呼ぶ
- **期待結果**: `Right(AppUser(id: 'uid-4', email: 'google@example.com'))`

### テストケース15: Google認証がキャンセルされた場合、未知のコードとしてFailure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithGoogle()
- **事前条件**: `signInWithGoogleImpl`が`FirebaseAuthException(code: 'sign_in_cancelled', message: 'Google sign in was cancelled.')`をthrowするよう設定（`_mapFirebaseAuthException`のdefault分岐に該当）
- **入力値・テスト条件**: なし
- **操作手順**: `repository.signInWithGoogle()` を呼ぶ
- **期待結果**: `Left(Failure.unknown('Google sign in was cancelled.'))`

### テストケース16: サインアウトに成功した場合、Right(unit)が返る
- **カテゴリ**: 正常系
- **対象メソッド**: signOut()
- **事前条件**: `signOutImpl`未設定（デフォルトで正常終了）
- **入力値・テスト条件**: なし
- **操作手順**: `repository.signOut()` を呼ぶ
- **期待結果**: `Right(unit)`

### テストケース17: サインアウト中にFirebaseAuthExceptionが発生した場合、対応するFailureが返る
- **カテゴリ**: 異常系
- **対象メソッド**: signOut()
- **事前条件**: `signOutImpl`が`FirebaseAuthException(code: 'network-request-failed')`をthrowするよう設定
- **入力値・テスト条件**: なし
- **操作手順**: `repository.signOut()` を呼ぶ
- **期待結果**: `Left(Failure.network())`

### テストケース18: パスワードリセットメール送信に成功した場合、Right(unit)が返る
- **カテゴリ**: 正常系
- **対象メソッド**: sendPasswordResetEmail()
- **事前条件**: `sendPasswordResetEmailImpl`未設定（デフォルトで正常終了）
- **入力値・テスト条件**: email='user@example.com'
- **操作手順**: `repository.sendPasswordResetEmail(email: ...)` を呼ぶ
- **期待結果**: `Right(unit)`

### テストケース19: FirebaseAuthExceptionのcodeがuser-not-foundの場合、Failure.authが返る
- **カテゴリ**: 異常系
- **対象メソッド**: sendPasswordResetEmail()
- **事前条件**: `sendPasswordResetEmailImpl`が`FirebaseAuthException(code: 'user-not-found')`をthrowするよう設定
- **入力値・テスト条件**: email='user@example.com'
- **操作手順**: `repository.sendPasswordResetEmail(email: ...)` を呼ぶ
- **期待結果**: `Left(Failure.auth())`

### テストケース20: 認証状態変化のストリームにユーザーが流れた場合、AppUserに変換されて流れる
- **カテゴリ**: 正常系
- **対象メソッド**: authStateChanges
- **事前条件**: `authStateChangesOverride`にuid/emailを持つFakeUserの単一値ストリームを設定
- **入力値・テスト条件**: なし
- **操作手順**: `repository.authStateChanges.first` を待つ
- **期待結果**: `AppUser(id: 'uid-5', email: 'stream@example.com')`

### テストケース21: 認証状態変化のストリームにnullが流れた場合、nullがそのまま流れる
- **カテゴリ**: 境界値
- **対象メソッド**: authStateChanges
- **事前条件**: `authStateChangesOverride`にnullの単一値ストリームを設定
- **入力値・テスト条件**: なし
- **操作手順**: `repository.authStateChanges.first` を待つ
- **期待結果**: `null`

## 対象外

- L52, L64, L76, L90：`signUpWithEmail` / `signInWithGoogle` / `signOut` / `sendPasswordResetEmail` の
  `catch (e) => Failure.unknown(...)` 防御的フォールバック。FirebaseAuthException 以外の例外を
  DataSource が投げる経路は実際には存在せず、同一構造の分岐は `signInWithEmail` のケースで
  網羅済みのため対象外とする。
