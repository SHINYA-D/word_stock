# login_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/auth/login/login_view_model.dart |
| クラス名 | LoginViewModel |
| テスト対象メソッド | build() / signInWithEmail() / signInWithGoogle() / resetState() |

## 実行環境について

`LoginViewModel` は `@riverpod class`（非 family）で `signInWithEmailUseCaseProvider` /
`signInWithGoogleUseCaseProvider` / `authSyncInProgressProvider` に依存する。
`ProviderContainer(overrides: [...])` で各 UseCase を手書き Fake
（`FakeSignInWithEmailUseCase` / `FakeSignInWithGoogleUseCase`）に差し替え、
Widget は一切 pump せず notifier を直接操作して検証する。
`SignInWithEmailUseCase` / `SignInWithGoogleUseCase` は具象クラスだが公開メンバーが
`call()` のみのため、Fake は `implements` で実装し（コンストラクタ引数を渡す必要がない）、
`results` を呼び出しごとに消費できるようにして「失敗後に再度成功」のような状態遷移も検証する。
呼び出し中の中間状態（`isLoading` / `authSyncInProgressProvider`）を検証するケースでは
`Completer` で UseCase の応答を保留し、`await Future<void>.delayed(Duration.zero)` で
`signInWithEmail` 内の `await` 直前までの同期処理を進めてから state を確認する。
`LoginViewModel` は `@riverpod`（autoDispose）のため、`container.read(...notifier)` だけでは
リスナーが存在せず、`Duration.zero` の待機中にプロバイダが破棄・再生成され state が
`initial` に戻ってしまう。中間状態を検証するケースでは
`container.listen(loginViewModelProvider, (_, __) {}, fireImmediately: true)` を先に呼んで
購読を保持し、非同期処理の途中で破棄されないようにしている。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 初期状態は isLoading/isSuccess が false で errorMessage が null になる | 正常系 | build() | ✅ |
| 2 | 成功した場合、isLoading が false・isSuccess が true になる | 正常系 | signInWithEmail() | ✅ |
| 3 | 呼び出し中は isLoading が true になり同期フラグが立ち、完了後にフラグが戻る | 正常系 | signInWithEmail() | ✅ |
| 4 | NetworkFailure の場合、通信エラーメッセージになる | 異常系 | signInWithEmail() | ✅ |
| 5 | AuthFailure の場合、メール/パスワード不一致メッセージになる | 異常系 | signInWithEmail() | ✅ |
| 6 | NotFoundFailure の場合、アカウントが見つからないメッセージになる | 異常系 | signInWithEmail() | ✅ |
| 7 | UnknownFailure の場合、元のメッセージを含んだエラーメッセージになる | 異常系 | signInWithEmail() | ✅ |
| 8 | 失敗後に再度成功した場合、errorMessage がクリアされ isSuccess が true になる | 境界値 | signInWithEmail() | ✅ |
| 9 | 成功した場合、isLoading が false・isSuccess が true になる | 正常系 | signInWithGoogle() | ✅ |
| 10 | 呼び出し中は isLoading が true になり同期フラグが立ち、完了後にフラグが戻る | 正常系 | signInWithGoogle() | ✅ |
| 11 | NetworkFailure の場合、通信エラーメッセージになる | 異常系 | signInWithGoogle() | ✅ |
| 12 | AuthFailure の場合、Google ログイン失敗メッセージになる（Emailとは異なる文言） | 異常系 | signInWithGoogle() | ✅ |
| 13 | NotFoundFailure の場合、アカウントが見つからないメッセージになる | 異常系 | signInWithGoogle() | ✅ |
| 14 | UnknownFailure の場合、元のメッセージを含んだエラーメッセージになる | 異常系 | signInWithGoogle() | ✅ |
| 15 | 呼び出すと state が初期状態に戻る | 正常系 | resetState() | ✅ |

## テストケース詳細

### テストケース1: 初期状態は isLoading/isSuccess が false で errorMessage が null になる
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `ProviderContainer` 生成直後（UseCase override なし）。
- **入力値・テスト条件**: なし。
- **操作手順**: `container.read(loginViewModelProvider)` を読む。
- **期待結果**: `AuthState.initial()` と同じ値（`isLoading: false, isSuccess: false, errorMessage: null`）。

### テストケース2: 成功した場合、isLoading が false・isSuccess が true になる
- **カテゴリ**: 正常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: build 済みで初期状態。
- **入力値・テスト条件**: `signInWithEmailUseCaseProvider` が `Right(_testAppUser)` を返す。
- **操作手順**: `notifier.signInWithEmail(email: ..., password: ...)` を await する。
- **期待結果**: `state.isLoading == false`, `state.isSuccess == true`, `state.errorMessage == null`。

### テストケース3: 呼び出し中は isLoading が true になり同期フラグが立ち、完了後にフラグが戻る
- **カテゴリ**: 正常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: build 済みで初期状態。UseCase が `Completer` で保留される。
  autoDispose のプロバイダ破棄を防ぐため `container.listen(loginViewModelProvider, (_, __) {}, fireImmediately: true)`
  で事前に購読しておく。
- **入力値・テスト条件**: `signInWithEmailUseCaseProvider` が保留後に `Right(_testAppUser)` を返す。
- **操作手順**: `notifier.signInWithEmail(...)` を await せず呼び、`Future<void>.delayed(Duration.zero)` で
  メソッド冒頭の同期処理（`state = ...isLoading:true...` と `authSyncInProgressProvider` への書き込み）
  まで進めてから state を確認する。その後 `completer.complete()` して await する。
- **期待結果**: 保留中は `state.isLoading == true`, `state.isSuccess == false`,
  `authSyncInProgressProvider == true`。完了後は `authSyncInProgressProvider == false` に戻る。

### テストケース4: NetworkFailure の場合、通信エラーメッセージになる
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: build 済みで初期状態。
- **入力値・テスト条件**: `signInWithEmailUseCaseProvider` が `Left(Failure.network())` を返す。
- **操作手順**: `notifier.signInWithEmail(...)` を await する。
- **期待結果**: `state.errorMessage == '通信エラーが発生しました'`、`state.isLoading == false`, `state.isSuccess == false`。

### テストケース5: AuthFailure の場合、メール/パスワード不一致メッセージになる
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: build 済みで初期状態。
- **入力値・テスト条件**: `signInWithEmailUseCaseProvider` が `Left(Failure.auth())` を返す。
- **操作手順**: `notifier.signInWithEmail(...)` を await する。
- **期待結果**: `state.errorMessage == 'メールアドレスまたはパスワードが正しくありません'`。

### テストケース6: NotFoundFailure の場合、アカウントが見つからないメッセージになる
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: build 済みで初期状態。
- **入力値・テスト条件**: `signInWithEmailUseCaseProvider` が `Left(Failure.notFound())` を返す。
- **操作手順**: `notifier.signInWithEmail(...)` を await する。
- **期待結果**: `state.errorMessage == 'アカウントが見つかりません'`。

### テストケース7: UnknownFailure の場合、元のメッセージを含んだエラーメッセージになる
- **カテゴリ**: 異常系
- **対象メソッド**: signInWithEmail()
- **事前条件**: build 済みで初期状態。
- **入力値・テスト条件**: `signInWithEmailUseCaseProvider` が `Left(Failure.unknown('boom'))` を返す。
- **操作手順**: `notifier.signInWithEmail(...)` を await する。
- **期待結果**: `state.errorMessage == 'エラーが発生しました: boom'`（文字列補間の確認）。

### テストケース8: 失敗後に再度成功した場合、errorMessage がクリアされ isSuccess が true になる
- **カテゴリ**: 境界値
- **対象メソッド**: signInWithEmail()
- **事前条件**: build 済みで初期状態。Fake は1回目 `Left(Failure.network())`、2回目 `Right(_testAppUser)` を順に返す。
- **入力値・テスト条件**: 同じ notifier に対して `signInWithEmail(...)` を2回連続で呼ぶ。
- **操作手順**: 1回目 await 後 `errorMessage` が非 null であることを確認 → 2回目 await。
- **期待結果**: `signInWithEmail` 冒頭で `errorMessage: null` にリセットされるため、2回目成功後は
  `state.errorMessage == null` かつ `state.isSuccess == true`。

### テストケース9〜14: signInWithGoogle() の正常系・異常系
- **カテゴリ**: 正常系（9,10）/ 異常系（11〜14）
- **対象メソッド**: signInWithGoogle()
- **事前条件**: build 済みで初期状態。
- **入力値・テスト条件**: `signInWithGoogleUseCaseProvider` の戻り値を
  `Right(_testAppUser)` / `Left(Failure.network())` / `Left(Failure.auth())` /
  `Left(Failure.notFound())` / `Left(Failure.unknown('boom'))` に差し替える。
  ケース10は signInWithEmail のケース3と同様に `Completer` で中間状態を検証し、
  同じ理由で `container.listen(...)` により購読を保持する。
- **操作手順**: `notifier.signInWithGoogle()` を await する。
- **期待結果**:
  - 成功時: `isLoading == false`, `isSuccess == true`, `errorMessage == null`
  - 中間状態: `isLoading == true` かつ `authSyncInProgressProvider == true`、完了後は `false` に戻る
  - NetworkFailure: `通信エラーが発生しました`
  - AuthFailure: `Google ログインに失敗しました`（signInWithEmail の `AuthFailure` メッセージとは異なる文言であることを確認）
  - NotFoundFailure: `アカウントが見つかりません`
  - UnknownFailure: `エラーが発生しました: boom`

### テストケース15: 呼び出すと state が初期状態に戻る
- **カテゴリ**: 正常系
- **対象メソッド**: resetState()
- **事前条件**: `signInWithEmail(...)` が失敗し `errorMessage` が非 null な状態。
- **入力値・テスト条件**: なし。
- **操作手順**: `notifier.resetState()` を呼ぶ。
- **期待結果**: `state` が `AuthState.initial()` と同じ値（`isLoading: false, isSuccess: false, errorMessage: null`）に戻る。

## 対象外

なし（`bash scripts/test_harness.sh test/presentation/auth/login/login_view_model_test.dart`
実行結果: 15 passed / 0 failed、`lib/presentation/auth/login/login_view_model.dart` カバレッジ 100%）。
