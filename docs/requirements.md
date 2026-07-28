# WordStock — 要件定義書

## 1. アプリ概要

| 項目 | 内容 |
|------|------|
| アプリ名 | WordStock |
| 概要 | テスト機能付きスマートフォン向け単語帳アプリ |
| 対応プラットフォーム | iOS / Android（クロスプラットフォーム） |
| フロントエンド | Flutter |
| バックエンド | Firebase |

---

## 2. 技術スタック

### フロントエンド
- **フレームワーク**: Flutter（Dart）
- **対応機種**: スマホ(Android/iOS)

### パッケージ・ライブラリ（バージョン固定）

| カテゴリ | パッケージ | バージョン | 用途 |
|----------|------------|------------|------|
| 画面遷移 | `go_router` | 14.6.3 | ルーティング・リダイレクト処理 |
| 状態管理 | `flutter_riverpod` | 2.6.1 | 状態管理 |
| 状態管理 | `riverpod_annotation` | 2.6.1 | Riverpod ジェネレーター用アノテーション |
| モデル | `freezed_annotation` | 3.0.0 | イミュータブルなデータクラス生成 |
| モデル | `json_annotation` | 4.9.0 | JSON シリアライズ用アノテーション |
| エラーハンドリング | `fpdart` | 1.1.0 | Either 型によるエラー表現 |
| 国際化 | `intl` | 0.19.0 | 日付フォーマット等 |
| Firebase | `firebase_core` | 3.13.0 | Firebase 初期化 |
| Firebase | `firebase_auth` | 5.5.2 | 認証管理 |
| Firebase | `cloud_firestore` | 5.6.6 | データ保存 |
| Firebase | `firebase_storage` | 12.4.5 | ストレージ（将来用） |
| 認証 | `google_sign_in` | 6.2.2 | Google ログイン |
| オフライン同期 | `sqflite` | 2.3.0 | ローカルDB（SQLite） |
| オフライン同期 | `path` | 1.8.0 | SQLiteファイルパス解決 |
| オフライン同期 | `connectivity_plus` | 5.0.0 | ネットワーク状態監視 |
| オフライン同期 | `uuid` | 4.3.3 | ローカル生成IDの発行 |
| コード生成 | `build_runner` | 2.4.14 | コード自動生成（Freezed / Riverpod） |
| コード生成 | `freezed` | 3.0.0 | Freezed コード生成 |
| コード生成 | `riverpod_generator` | 2.6.5 | Riverpod コード生成 |
| コード生成 | `json_serializable` | 6.9.4 | JSON コード生成 |
| コード生成 | `go_router_builder` | 2.7.0〜2.9.0未満 | go_router 型安全ルート生成 |
| フォーマット | `flutter_lints` | 6.0.0 | コード品質・フォーマットチェック |
| テスト | `mockito` | 5.4.5 | モック生成ライブラリ |
| テスト | `sqflite_common_ffi` | 2.4.0+3 | テスト環境でのSQLite実行（FFI） |

### バックエンド / クラウド（Firebase）

| サービス | 用途 |
|----------|------|
| Firebase Authentication | ログイン・認証管理 |
| Cloud Firestore | 単語・フォルダ・成績・設定データの保存 |

---

## 3. アーキテクチャ設計

### 基本方針

DDD（ドメイン駆動設計）+ クリーンアーキテクチャを採用する。

### レイヤー構成

```
presentation/   # UI層：画面・ウィジェット・状態管理（Riverpod）
application/    # アプリケーション層：ユースケース
domain/         # ドメイン層：エンティティ・リポジトリインターフェース・値オブジェクト
infrastructure/ # インフラ層：Firebase実装・外部サービス
```

### 各レイヤーの責務

| レイヤー | 責務 | 主な構成要素 |
|----------|------|--------------|
| presentation | 画面表示・ユーザー操作の受付 | Page / Widget / ViewModel (Notifier) / State (Freezed) |
| application | ユースケースの実行・ドメインの調整 | UseCase クラス |
| domain | ビジネスロジック・ルールの定義 | Entity / Repository（interface） |
| infrastructure | 外部サービスとの通信・データ変換 | RepositoryImpl / DataSource（Firebase・SQLite・同期処理） |

### ディレクトリ構成（現状）

```
lib/
├── main.dart
├── app.dart                          # アプリのルート・テーマ・ルーティング設定
├── firebase_options.dart             # FlutterFire 自動生成
│
├── core/                             # 共通ユーティリティ・定数・エラー定義
│   ├── di/                           # Riverpod Provider 定義（DI）
│   │   ├── auth_providers.dart       # 認証関連 Provider・UseCase
│   │   ├── firebase_providers.dart   # Firebase インスタンス・DataSource Provider
│   │   ├── repository_providers.dart # Repository Provider（kUseMocks フラグあり）
│   │   ├── word_providers.dart       # 単語 UseCase Provider
│   │   ├── folder_providers.dart     # フォルダ UseCase Provider
│   │   ├── settings_providers.dart   # 設定 UseCase Provider
│   │   ├── test_result_providers.dart# 成績 UseCase Provider
│   │   ├── local_data_source_providers.dart # SQLite LocalDataSource Provider
│   │   └── sync_providers.dart       # 同期関連（SyncService 等）Provider
│   ├── error/
│   │   └── failure.dart              # Failure ユニオン型定義
│   ├── firebase/
│   │   └── firestore_path.dart       # Firestore パス生成ユーティリティ
│   ├── router/
│   │   └── router.dart               # go_router 設定・認証リダイレクト
│   ├── theme/
│   │   └── app_theme.dart            # Material 3 テーマ・カラーテーマ定義
│   ├── widgets/
│   │   ├── error_screen.dart         # エラー全画面ウィジェット
│   │   └── network_error_dialog.dart # 通信エラーダイアログウィジェット
│   └── app_lifecycle_observer.dart   # resumed検知によるオフライン差分同期トリガー
│
├── presentation/                     # UI層（MVVM）
│   ├── shell/
│   │   └── shell_page.dart           # ボトムナビゲーションバー（ShellRoute）
│   ├── auth/                         # 認証
│   │   ├── auth_state.dart           # AuthState（Freezed）
│   │   ├── splash/
│   │   │   └── splash_page.dart
│   │   ├── login/
│   │   │   ├── login_page.dart
│   │   │   └── login_view_model.dart
│   │   ├── sign_up/
│   │   │   ├── sign_up_page.dart
│   │   │   └── sign_up_view_model.dart
│   │   └── password_reset/
│   │       ├── password_reset_page.dart
│   │       └── password_reset_view_model.dart
│   ├── home/                         # ホーム（フォルダ一覧）
│   │   ├── home_page.dart
│   │   ├── home_view_model.dart
│   │   ├── home_state.dart           # HomeState（Freezed）
│   │   └── widgets/
│   │       └── folder_list_tile.dart
│   ├── word/                         # 単語管理
│   │   ├── word_list_page.dart
│   │   └── word_list_view_model.dart
│   ├── test_session/                 # 単語テスト
│   │   ├── test_settings_page.dart   # テスト設定画面
│   │   ├── test_page.dart            # テスト実施画面
│   │   ├── test_session_view_model.dart
│   │   ├── test_session_state.dart   # TestSessionState（Freezed）
│   │   └── test_result_page.dart     # テスト結果画面
│   ├── result/                       # 成績表
│   │   ├── result_page.dart
│   │   └── result_view_model.dart
│   └── settings/                     # 設定
│       ├── settings_page.dart
│       └── settings_view_model.dart
│
├── application/                      # アプリケーション層
│   └── use_cases/                    # ユースケース（1クラス1ユースケース）
│       ├── auth/
│       │   ├── sign_in_with_email_use_case.dart
│       │   ├── sign_up_use_case.dart
│       │   ├── sign_in_with_google_use_case.dart
│       │   ├── sign_out_use_case.dart
│       │   └── reset_password_use_case.dart
│       ├── folder/
│       │   ├── get_folders_use_case.dart
│       │   ├── create_folder_use_case.dart
│       │   ├── update_folder_use_case.dart
│       │   └── delete_folder_use_case.dart
│       ├── word/
│       │   ├── get_words_use_case.dart
│       │   ├── create_word_use_case.dart
│       │   ├── update_word_use_case.dart
│       │   └── delete_word_use_case.dart
│       ├── settings/
│       │   ├── get_settings_use_case.dart
│       │   └── update_settings_use_case.dart
│       └── test_result/
│           ├── get_test_results_use_case.dart
│           └── save_test_result_use_case.dart
│
├── domain/                           # ドメイン層
│   ├── entities/                     # エンティティ（Freezed）
│   │   ├── app_user.dart
│   │   ├── folder.dart
│   │   ├── word.dart
│   │   ├── test_result.dart
│   │   └── user_settings.dart
│   └── repositories/                 # リポジトリインターフェース（抽象クラス）
│       ├── auth_repository.dart
│       ├── folder_repository.dart
│       ├── word_repository.dart
│       ├── test_result_repository.dart
│       └── settings_repository.dart
│
└── infrastructure/                   # インフラ層
    ├── data_sources/
    │   ├── firebase_auth_data_source.dart # Firebase Auth との通信処理
    │   ├── firestore_data_source.dart     # Firestore との通信処理
    │   ├── local/                         # SQLite ローカルDB（オフライン同期用）
    │   │   ├── database_helper.dart       # DB接続・テーブル初期化
    │   │   ├── tables/                    # テーブル定義（CREATE文）
    │   │   │   ├── folder_table.dart
    │   │   │   ├── word_table.dart
    │   │   │   ├── test_result_table.dart
    │   │   │   ├── settings_table.dart
    │   │   │   ├── sync_queue_table.dart
    │   │   │   └── sync_meta_table.dart
    │   │   ├── folder_local_data_source.dart
    │   │   ├── word_local_data_source.dart
    │   │   ├── test_result_local_data_source.dart
    │   │   ├── settings_local_data_source.dart
    │   │   └── sync_queue_data_source.dart # sync_queue へのキュー登録・取得
    │   └── network/
    │       └── connectivity_monitor.dart  # connectivity_plus によるオンライン/オフライン検知
    ├── sync/                              # オンライン復帰時・ログイン時の同期処理
    │   ├── sync_service.dart              # ローカル⇔リモート同期本体（競合解決含む）
    │   └── auto_sync_service.dart         # オンライン復帰検知時の自動同期起動
    └── repositories/                 # Repository の実装（Firebase + SQLite）
        ├── auth_repository_impl.dart
        ├── folder_repository_impl.dart
        ├── word_repository_impl.dart
        ├── test_result_repository_impl.dart
        ├── settings_repository_impl.dart
        └── mock/                     # 開発用モックリポジトリ（kUseMocks = false）
            ├── mock_auth_repository.dart
            ├── mock_folder_repository.dart
            ├── mock_word_repository.dart
            ├── mock_settings_repository.dart
            └── mock_test_result_repository.dart
```

> オフライン同期の詳細な設計（SQLiteテーブル定義・sync_queueによるキューイング・競合解決方式など）は `docs/online_offline.md` を参照。

### 依存関係ルール

- `domain` 層は他のどの層にも依存しない
- `application` 層は `domain` 層のみに依存する
- `presentation` 層は `application` / `domain` 層に依存する
- `infrastructure` 層は `domain` 層のインターフェースを実装する
- 依存性の注入（DI）は Riverpod で管理する（`core/di/` 配下の Provider 経由）

### テスト方針

| テスト種別 | 対象 | 使用ツール |
|------------|------|------------|
| ユニットテスト | UseCase / Entity / Repository | `flutter_test` + `mockito` |
| ユニットテスト | LocalDataSource / SyncService（オフライン同期） | `flutter_test` + `sqflite_common_ffi`（インメモリSQLite） |
| ウィジェットテスト | 各画面・ウィジェット | `flutter_test` |
| 統合テスト | 画面遷移・E2Eフロー | `integration_test` |

### コーディング指針

本プロジェクトのコーディングにおいて、以下の4つを最優先とする。

#### 1. ベースはクリーンアーキテクチャ

- 各レイヤーの責務を厳守し、レイヤーをまたいだ直接参照は行わない
- `domain` 層にビジネスロジックを集約し、Flutter / Firebase などの外部依存を持ち込まない
- Repository はかならず `domain` 層でインターフェース（抽象クラス）を定義し、`infrastructure` 層で実装する
- UseCase は単一責任の原則に従い、1クラス1ユースケースを基本とする

#### 2. Riverpod の良さを活かす

- Provider の粒度を適切に保ち、再構築範囲を最小化する
- `riverpod_generator`（`@riverpod` アノテーション）を活用してボイラープレートを削減する
- UseCase や Repository の DI は Riverpod の Provider 経由で行い、コンストラクタ直接生成はしない
- 非同期処理は `AsyncNotifier` / `FutureProvider` を適切に使い分ける
- `keepAlive: true` はアプリ全体で共有すべき Provider（認証・Repository・UseCase）に付与する

#### 3. Freezed ユニオン型で状態を表現する

- UI の状態は Freezed のユニオン型で定義し、「ありえない状態」が生まれない設計にする
- `AsyncValue` で表現できるシンプルな非同期状態はそのまま活用する
- 複数の状態を持つ複雑な画面（テスト画面など）は独自のユニオン型 State を定義する
- `when` / `map` による網羅的な状態ハンドリングを徹底し、処理漏れを防ぐ
- **Freezed 3.x の構文を使用すること（`@freezed abstract class`、`sealed class`）**

```dart
// Freezed 3.x の構文例
@freezed
abstract class TestSessionState with _$TestSessionState {
  const factory TestSessionState({
    required bool isStarted,
    required bool isFinished,
    Word? currentWord,
    required int currentIndex,
    required int total,
    required bool isFlipped,
    required int correctCount,
  }) = _TestSessionState;
}

// sealed class の使用例（Failure など）
@freezed
sealed class Failure with _$Failure {
  const factory Failure.network() = NetworkFailure;
  const factory Failure.auth() = AuthFailure;
  const factory Failure.notFound() = NotFoundFailure;
  const factory Failure.unknown(String message) = UnknownFailure;
}
```

#### 4. テスタブルなコーディングを最優先とする（最重要）

- **DI（依存性の注入）を徹底する** — クラスが依存するオブジェクトはすべてコンストラクタ or Provider 経由で注入し、クラス内部でのインスタンス生成（`final x = ConcreteClass()`）は行わない
- Repository・DataSource などの外部依存はすべて抽象クラス（`abstract class`）で定義し、テスト時に `mockito` でモックに差し替えられる設計にする
- 副作用（Firebase・端末ストレージ・BGMなど）はかならず infrastructure 層に閉じ込め、domain / application 層は純粋な Dart コードで完結させる
- 開発時は `repository_providers.dart` の `kUseMocks` フラグで実装をモックに切り替え可能にする
- Provider のオーバーライド（`overrideWithValue`）を活用し、ウィジェットテストでも依存を差し替えやすい構造を意識する
- テストしやすさを優先した結果、設計が複雑になる場合はシンプルな設計を選ぶ

#### まとめ（Claude への指示）

> クリーンアーキテクチャを土台にしつつ、Riverpod の Provider 設計を活かした実装を行うこと。
> UI の状態は Freezed ユニオン型で表現し、ありえない状態を型レベルで排除すること。
> **Freezed 3.x の構文（`@freezed abstract class`）を必ず使用すること。**
> ただし、**何よりもテスタブルであることを最優先**とし、DIを徹底して、すべての外部依存が差し替え可能な設計を維持すること。
> 実装の判断に迷った場合は「このコードはテストできるか？」を基準に選択すること。


---

## 4. エラーハンドリング方針

### 基本方針

- エラーは `Failure` クラスで統一的に表現し、例外（Exception）をそのままUIに伝播させない
- Repository インターフェースは `Either<Failure, T>` を返す（`fpdart` パッケージを使用）
- Notifier（VM相当）で `fold` によりエラー / 成功を分岐してUIに反映する
- `Failure` は Freezed で sealed クラスとして定義する

### Failure 定義

```dart
@freezed
sealed class Failure with _$Failure {
  const factory Failure.network() = NetworkFailure;            // 通信エラー
  const factory Failure.auth() = AuthFailure;                  // 認証エラー
  const factory Failure.notFound() = NotFoundFailure;          // データなし
  const factory Failure.unknown(String message) = UnknownFailure; // 予期せぬエラー
}
```

### エラーUIの種類

#### 1. エラー全画面（`ErrorScreen`）

| 項目 | 内容 |
|------|------|
| 表示タイミング | 画面の**初期データ読み込み失敗時**のみ |
| 対象 | `NotFoundFailure` / `UnknownFailure` など通信系以外のエラー |
| 表示内容 | エラーメッセージ + 再試行ボタン |
| 実装場所 | `core/widgets/error_screen.dart` |

#### 2. 通信エラーダイアログ（`NetworkErrorDialog`）

| 項目 | 内容 |
|------|------|
| 表示タイミング | Firebase などの**通信系エラー発生時** |
| 対象 | `NetworkFailure` / `AuthFailure` |
| 表示内容 | エラーメッセージ + 「OK」ボタン |
| OK押下後の動作 | Firebase 強制ログアウト → `go_router` でログイン画面へリダイレクト |
| 実装場所 | `core/widgets/network_error_dialog.dart` |

```dart
// 使用イメージ
result.fold(
  (failure) => failure.when(
    network: () => showNetworkErrorDialog(context), // ダイアログ → 強制ログアウト → ログイン画面
    auth:    () => showNetworkErrorDialog(context),
    notFound: () => state = AsyncError(...),        // エラー全画面
    unknown:  () => state = AsyncError(...),        // エラー全画面
  ),
  (data) => state = AsyncData(data),
);
```

### エラーハンドリングの全体フロー

```
Infrastructure層
  Firebase で例外発生
      ↓
  catch → Failure に変換 → Left(Failure) を返す

Application層（UseCase）
  Either をそのまま返す

Presentation層（Notifier）
  result.fold(
    (failure) → NetworkFailure / AuthFailure
                  → NetworkErrorDialog 表示
                  → FirebaseAuth.signOut()
                  → go_router でログイン画面へリダイレクト
              → NotFoundFailure / UnknownFailure
                  → ErrorScreen 表示（全画面・初期読み込み失敗時のみ）
    (data)    → AsyncData(data) → 正常表示
  )
```

---

## 5. 認証機能

### ログイン方法
- メール＆パスワード認証
- Google ログイン（OAuth）
- ~~Apple ログイン（OAuth）~~ → **削除済み**

### 画面構成
- スプラッシュ画面（`splash_page.dart`）
- ログイン画面（`login_page.dart`）
- 新規登録画面（`sign_up_page.dart`）
- パスワードリセット画面（`password_reset_page.dart`）

### 認証状態の管理フロー

`go_router` のリダイレクト機能（`core/router/router.dart`）を使い、認証状態に応じて画面遷移を制御する。

| 状態 | 遷移先 |
|------|--------|
| 未ログイン でアプリ起動 | ログイン画面へリダイレクト |
| ログイン済み でアプリ起動 | ホーム画面へリダイレクト |
| 通信 / 認証エラー発生 | 強制ログアウト → ログイン画面へリダイレクト |
| オフライン検知 | 通信エラーダイアログ → 強制ログアウト → ログイン画面へリダイレクト |

```dart
// go_router リダイレクト処理のイメージ
redirect: (context, state) {
  final isLoggedIn = authState.isLoggedIn;
  final isAuthRoute = state.matchedLocation == '/login';

  if (!isLoggedIn && !isAuthRoute) return '/login'; // 未ログイン → ログイン画面
  if (isLoggedIn && isAuthRoute) return '/home';    // ログイン済み → ホーム画面
  return null; // そのまま
}
```

### AuthState 定義

```dart
@freezed
abstract class AuthState with _$AuthState {
  const factory AuthState({
    required bool isLoading,
    required bool isSuccess,
    String? errorMessage,
  }) = _AuthState;

  factory AuthState.initial() => const AuthState(isLoading: false, isSuccess: false);
}
```

### オフライン時の挙動

> **注意:** 本セクションはオフライン同期対応（SQLite + `sync_queue`）への移行に伴い更新されている。旧バージョンでは「オンライン必須・ローカルキャッシュ不採用」としていたが、現在はログイン・新規登録・パスワード変更を除くコア機能（フォルダ・単語・成績・設定の作成/更新/削除、および閲覧）はオフラインでも継続利用できる。詳細な同期アーキテクチャ・フェーズ計画は `docs/online_offline.md` を参照。

- **認証系操作（ログイン・新規登録・パスワードリセット）は Firebase Auth 依存のためオフライン対応の対象外。** これらの操作時に通信不可を検知した場合 → `NetworkErrorDialog` を表示 → OK押下で `FirebaseAuth.signOut()` により強制ログアウト → `go_router` でログイン画面へリダイレクト
- **ログイン後のデータ操作（フォルダ・単語・成績・設定）はオフラインでも継続利用可能。** 読み取りは常にSQLiteから行い、書き込みはオフライン時にSQLiteへ保存すると同時に `sync_queue` テーブルへ同一トランザクションで登録する
- オンライン復帰時（`connectivity_plus` で検知）に `sync_queue` の内容を古い順にFirestoreへ自動同期する
- ログイン成功時・アプリ再開（resumed）時にはFirestoreからSQLiteへの差分同期も行われる（resumedは前回同期から5分以上経過時のみ）

---

## 6. コア機能

### 6-1. 単語管理機能

ユーザーが単語を自由に作成・編集・削除できる機能。

| 項目 | 詳細 |
|------|------|
| 単語（表面） | 任意のテキスト入力（言語制限なし） |
| 意味（裏面） | 任意のテキスト入力（言語制限なし） |
| 操作 | 作成 / 編集 / 削除 |

#### Word エンティティ

```dart
@freezed
abstract class Word with _$Word {
  const factory Word({
    required String id,
    required String front,
    required String back,
    required DateTime createdAt,
    required DateTime updatedAt, // オフライン同期の競合解決（Last-Write-Wins）に使用
  }) = _Word;
}
```

### 6-1-1. 単語検索機能

Firestoreは部分一致検索が非対応のため、**フロント側（Dart）でフィルタリング**する方式を採用する。

| 検索種別 | 内容 | 実装方針 |
|----------|------|----------|
| フォルダ内検索 | 開いているフォルダ内の単語を絞り込む | そのフォルダの単語リストをDart側でフィルタ |
| 全フォルダ横断検索 | 全フォルダをまたいで単語を検索する | 全単語を取得してDart側でフィルタ |

```dart
// フロント側フィルタリングのイメージ
final filtered = words.where((w) =>
  w.front.contains(query) || w.back.contains(query)
).toList();
```

**方針の理由:**
- 単語帳アプリの性質上、1フォルダあたりの単語数は数十〜数百程度に収まる想定
- その規模であればDart側フィルタリングでパフォーマンス上の問題は生じない
- Algolia等の外部検索サービスは今回の規模にはオーバースペックのため不採用
- 実装がシンプルになりテストも書きやすい

### 6-2. フォルダ管理機能

単語をフォルダ単位で分類・管理する機能。

- フォルダの作成 / 編集 / 削除
- フォルダ内に複数の単語を格納
- フォルダ一覧画面からフォルダを選択して単語を表示
- **フォルダのネスト（入れ子）対応** — フォルダの中にサブフォルダを作成可能（`parentFolderId` で管理）
- フォルダ削除時は配下の単語・サブフォルダ・成績データをすべて削除する（カスケード削除）

#### Folder エンティティ

```dart
@freezed
abstract class Folder with _$Folder {
  const factory Folder({
    required String id,
    required String name,
    String? parentFolderId,     // null = ルートフォルダ
    required DateTime createdAt,
    required DateTime updatedAt, // オフライン同期の競合解決（Last-Write-Wins）に使用
  }) = _Folder;

  factory Folder.fromJson(Map<String, dynamic> json) => _$FolderFromJson(json);
}
```

### 6-3. 単語テスト機能

カード形式（フラッシュカード）でテストを行う機能。

| 項目 | 詳細 |
|------|------|
| テスト形式 | カード形式（表面: 単語、裏面: 意味） |
| 正誤判定 | ユーザーが自分で正解 / 不正解を選択（自己採点） |
| 出題範囲 | フォルダ単位で選択 |
| 出題順 | ランダム or 順番（選択式） |

**テストの流れ:**
1. フォルダを選択してテスト設定画面へ
2. 出題順（ランダム/順番）を設定してテスト開始
3. カードの表面（単語）が表示される
4. ユーザーが意味を思い出す
5. カードをタップして裏面（意味）を確認
6. 「正解」または「不正解」ボタンで自己採点
7. 全カード終了後に結果画面へ遷移

**テスト中断時の挙動:**

| ケース | 挙動 |
|--------|------|
| テスト中にバックボタン / 中断操作 | テスト前の画面（テスト設定画面）に戻る |
| 中断時の成績 | 保存しない（成績結果に一切反映しない） |
| 再開機能 | なし（最初からやり直し） |

#### TestSessionState 定義

```dart
@freezed
abstract class TestSessionState with _$TestSessionState {
  const factory TestSessionState({
    required bool isStarted,
    required bool isFinished,
    Word? currentWord,
    required int currentIndex,
    required int total,
    required bool isFlipped,
    required int correctCount,
  }) = _TestSessionState;
}
```

### 6-4. 成績表機能

テスト結果を記録・表示する機能。

- テストごとの結果（正解数 / 問題数 / 正答率）を保存
- 履歴一覧の表示
- フォルダ別の成績確認
- 成績データはフォルダに紐づく — **フォルダ削除時に成績データも自動削除**される
- 成績の個別削除・リセット機能は**提供しない**

#### TestResult エンティティ

```dart
@freezed
abstract class TestResult with _$TestResult {
  const factory TestResult({
    required String id,
    required String folderId,
    required int totalCount,
    required int correctCount,
    required DateTime date,
    required DateTime updatedAt, // オフライン同期の競合解決（Last-Write-Wins）に使用
  }) = _TestResult;

  const TestResult._();
  double get correctRate => totalCount == 0 ? 0 : correctCount / totalCount;
}
```

### 6-5. 設定機能

| 設定項目 | 詳細 | 実装状況 |
|----------|------|----------|
| カラーテーマ | カラーテーマの変更（indigo / blue / teal / green / orange / pink / purple） | 実装済み |
| ダークモード | ダークモード / ライトモード 切り替え | 実装済み |
| BGM | BGMのオン / オフ、BGM選択 | **未実装（将来フェーズ）** |

#### UserSettings エンティティ（現状）

```dart
@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    @Default('indigo') String colorTheme,
    @Default(false) bool darkMode,
    DateTime? updatedAt, // オフライン同期の競合解決（Last-Write-Wins）に使用
  }) = _UserSettings;
}
```

---

## 7. 画面一覧

### ボトムナビゲーションバー

テスト画面・テスト結果画面を除く全画面にボトムナビゲーションバーを表示する。
実装は `presentation/shell/shell_page.dart` の `ShellRoute` で管理。

| タブ | 画面 | アイコン |
|------|------|----------|
| ホーム | フォルダ一覧画面 | Icons.home |
| 成績 | 成績表画面 | Icons.bar_chart |
| 設定 | 設定画面 | Icons.settings |

### 画面一覧

| 画面名 | BottomNav | ファイル |
|--------|-----------|---------|
| スプラッシュ画面 | なし | `presentation/auth/splash/splash_page.dart` |
| ログイン画面 | なし | `presentation/auth/login/login_page.dart` |
| 新規登録画面 | なし | `presentation/auth/sign_up/sign_up_page.dart` |
| パスワードリセット画面 | なし | `presentation/auth/password_reset/password_reset_page.dart` |
| ホーム画面（フォルダ一覧） | あり | `presentation/home/home_page.dart` |
| 単語一覧画面 | あり | `presentation/word/word_list_page.dart` |
| テスト設定画面 | あり | `presentation/test_session/test_settings_page.dart` |
| テスト画面 | **なし** | `presentation/test_session/test_page.dart` |
| テスト結果画面 | **なし** | `presentation/test_session/test_result_page.dart` |
| 成績表画面 | あり | `presentation/result/result_page.dart` |
| 設定画面 | あり | `presentation/settings/settings_page.dart` |

### ルーティング（go_router）

| ルート | パス | 備考 |
|--------|------|------|
| SplashRoute | `/` | 認証状態確認後リダイレクト |
| LoginRoute | `/login` | 未ログイン時のデフォルト |
| SignUpRoute | `/sign-up` | |
| PasswordResetRoute | `/password-reset` | |
| TestSettingsRoute | `/test-settings/:folderId` | |
| TestRoute | `/test/:folderId` | |
| TestResultRoute | `/test-result` | |
| AppShellRoute | ShellRoute | BottomNav配下 |
| HomeRoute | `/home` | ShellRoute 内 |
| FolderRoute | `/folder/:folderId` | ShellRoute 内（単語一覧画面） |
| ResultsRoute | `/results` | ShellRoute 内 |
| SettingsRoute | `/settings` | ShellRoute 内 |

---

## 8. Firestore データ構造

フォルダのネスト対応のため、`parentFolderId` フィールドで親子関係を管理する。
各ドキュメントには、オフライン同期の競合解決（Last-Write-Wins）に使用する `updatedAt` フィールドを持たせる。

```
users/
  {userId}/
    folders/
      {folderId}/
        name: string
        parentFolderId: string | null  // null = ルートフォルダ
        createdAt: timestamp
        updatedAt: timestamp           // 競合解決用
        words/
          {wordId}/
            front: string              // 単語（表面）
            back: string               // 意味（裏面）
            createdAt: timestamp
            updatedAt: timestamp       // 競合解決用
    test_results/
      {resultId}/
        folderId: string               // 紐づくフォルダID
        totalCount: number
        correctCount: number
        date: timestamp
        updatedAt: timestamp           // 競合解決用
    settings/
      config/
        colorTheme: string             // カラーテーマ（デフォルト: 'indigo'）
        darkMode: boolean              // ダークモード（デフォルト: false）
        updatedAt: timestamp           // 競合解決用
```

> **カスケード削除について:** Firestoreはカスケード削除を自動では行わない。フォルダ削除時はアプリ側（infrastructure層 `firestore_data_source.dart`）で配下の words / サブフォルダ / testResults を再帰的に削除する処理を実装すること。

> **ローカルDB（SQLite）とのミラーリングについて:** 本アプリはオフライン同期対応のため、上記Firestore構造とほぼ同一のスキーマを持つSQLiteテーブル（`folders` / `words` / `test_results` / `settings`）をローカルに保持し、UI層は常にSQLiteを読み取り元とする。加えて未同期の変更操作を記録する `sync_queue` テーブル、最終同期時刻を記録する `sync_meta` テーブルを持つ。SQLite側のテーブル定義・カラム（`syncStatus` 等）の詳細は `docs/online_offline.md` を参照。

---

## 9. デザイン方針

| 項目 | 方針 |
|------|------|
| UIフレームワーク | Material 3（`useMaterial3: true`） |
| テーマ | ダークモード対応（ライト / ダーク 切り替え） |
| カラーテーマ | ユーザーが設定から変更可能（`ColorScheme.fromSeed` で動的生成） |
| カラーバリエーション | indigo / blue / teal / green / orange / pink / purple |
| フォント | システムフォント（日本語・英語対応） |
| アニメーション | カードめくりアニメーション（テスト画面） |

---

## 10. 非機能要件

| 項目 | 内容 |
|------|------|
| 対応OS | iOS 15以上 / Android 10以上 |
| オフライン対応 | **オフライン同期対応（移行済み）** — ログイン後のコア機能（フォルダ・単語・成績・設定）はSQLite + `sync_queue` によりオフラインでも継続利用可能。オンライン復帰時に自動同期。ログイン・新規登録・パスワード変更はFirebase Auth依存のためオフライン対応対象外（通信不可検知時は通信エラーダイアログを表示し強制ログアウト → ログイン画面へリダイレクト）。詳細は `docs/online_offline.md` を参照 |
| セキュリティ | Firebase Security Rules でユーザーデータを保護（自分のデータのみ読み書き可） |
| 多言語 | 単語の入力言語は制限なし（UI言語は日本語を基本とする） |
| 開発補助 | `kUseMocks = false` フラグで Firebase 不要のモック実装に切り替え可能 |

---

## 11. Firebase セキュリティルール

ユーザーは自分のデータのみ読み書き可能とする。他ユーザーのデータへのアクセスは一切禁止。

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 自分の配下データのみ読み書き可
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

---

## 12. pubspec.yaml（パッケージ構成）

```yaml
name: word_stock
description: テスト機能付き単語帳アプリ
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.3.3 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

  # 画面遷移
  go_router: ^14.6.3

  # 状態管理
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # モデル
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0

  # エラーハンドリング
  fpdart: ^1.1.0

  # Firebase
  firebase_core: ^3.13.0
  firebase_auth: ^5.5.2
  cloud_firestore: ^5.6.6
  firebase_storage: ^12.4.5
  google_sign_in: ^6.2.2

  # 日付フォーマット
  intl: ^0.19.0

  # ローカルDB・ネットワーク監視（オフライン同期）
  sqflite: ^2.3.0
  path: ^1.8.0
  connectivity_plus: ^5.0.0
  uuid: ^4.3.3

  # スプラッシュ画面
  flutter_native_splash: ^2.4.3

  # アプリアイコン生成
  flutter_launcher_icons: ^0.14.3

dev_dependencies:
  flutter_test:
    sdk: flutter

  # コード生成
  build_runner: ^2.4.14
  freezed: ^3.0.0
  riverpod_generator: ^2.6.5
  json_serializable: ^6.9.4
  go_router_builder: ">=2.7.0 <2.9.0"

  # フォーマット
  flutter_lints: ^6.0.0

  # テスト
  mockito: ^5.4.5
  sqflite_common_ffi: ^2.4.0+3
```

> 上記は `pubspec.yaml` の `dependencies` / `dev_dependencies` を反映したもの。`flutter:` セクション（アセット指定）や `flutter_native_splash:` / `flutter_launcher_icons:` の設定値は `pubspec.yaml` 本体を参照。

---
