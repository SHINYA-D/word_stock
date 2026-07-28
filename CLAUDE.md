# WordStock
Claude Code がこのリポジトリで事故らないための最小限の運用ルール集。

## コマンド

本プロジェクトは FVM でFlutter/Dartのバージョンを固定している（`.fvmrc`）。素の `flutter`/`dart` コマンドは使わず、必ず `fvm` 経由で実行する（パッケージ追加時も `fvm flutter pub add <package>`）。

```bash
# コード生成（Freezed / Riverpod）1回だけ
fvm dart run build_runner build --delete-conflicting-outputs

# コード生成を監視し続ける
fvm dart run build_runner watch --delete-conflicting-outputs

# テスト実行
fvm flutter test

# Firebase不要のモックモードで起動
fvm flutter run --dart-define=USE_MOCKS=true
```

## アーキテクチャ依存ルール

- `domain` 層は他のどの層にも依存しない
- `application` 層は `domain` 層のみに依存する
- `presentation` 層は `application` / `domain` 層に依存する
- `infrastructure` 層は `domain` 層のインターフェースを実装する
- レイヤーをまたいだ直接参照は行わない
- DI（依存性注入）は必ず Riverpod の Provider 経由で行う。`final x = ConcreteClass()` のようなクラス内部での直接生成は禁止（`core/di/` 配下にProvider定義）

## 生成ファイル不可侵

以下は `build_runner` が自動生成する。手で編集しない。

- `*.freezed.dart`
- `*.g.dart`
- `router.g.dart`

## コーディング判断基準

実装の判断に迷ったら「このコードはテストできるか？」を基準に選ぶ。
テスタブルであることを最優先とし、シンプルさを優先する（過剰なエラーハンドリングや複雑な設計より）。

## Freezed 3.x 構文

**必ず 3.x の構文を使うこと**（`@freezed abstract class` / `sealed class`）。旧構文（`@freezed class` 単体）は使わない。

```dart
@freezed
sealed class Failure with _$Failure {
  const factory Failure.network() = NetworkFailure;
  const factory Failure.unknown(String message) = UnknownFailure;
}
```

## エラーハンドリングパターン

- Repository は必ず `Either<Failure, T>`（fpdart）を返す。例外をそのままUIに伝播させない
- Notifier で `result.fold(...)` により成功/失敗を分岐する
- `NetworkFailure` / `AuthFailure` → `NetworkErrorDialog` 表示 → Firebase強制ログアウト → ログイン画面へリダイレクト
- `NotFoundFailure` / `UnknownFailure` → `ErrorScreen` 表示（初期読み込み失敗時のみ）

## SQLite / オフライン同期ルール

- データテーブルへの書き込み + `sync_queue` への登録は**必ず同一トランザクション**で行う
- **読み取りは常にSQLiteから行う**。UI層はオン/オフラインを意識しない
- DateTime ↔ String（ISO8601）の変換責任は `LocalDataSource` 層に集約する。それより上位の層は常に `DateTime` 型で扱う
- SQLiteトランザクション内でFirestore通信を行わない
- 同期フロー・競合解決・フェーズ計画の詳細は `docs/online_offline.md` を参照

## 既知の矛盾（要注意）

`docs/requirements.md` には「本アプリはオンライン必須。ローカルキャッシュ不採用」と書かれているが、これは古い記述。
現在は `docs/online_offline.md` に従いオフライン同期対応へ移行中のため、**実装判断に迷ったら `docs/online_offline.md` を優先**すること。

## コミットルール

| プレフィックス | 用途 |
|--------------|------|
| feat | 新機能の追加 |
| fix | バグの修正 |
| docs | ドキュメントの変更 |
| style | フォーマット変更（動作に影響しない） |
| refactor | リファクタリング（機能変更なし） |
| test | テストの追加・修正 |
| chore | ビルド設定・ツール関連の変更 |

## ドキュメント地図

| ファイル | 役割 |
|---------|------|
| `README.md` | 人間向け説明（設計思想・技術選定理由・環境構築手順） |
| `docs/requirements.md` | 元の要件定義書（一部オフライン関連の記述は古い） |
| `docs/online_offline.md` | オフライン同期機能の実装指示書（フェーズ別タスク） |
