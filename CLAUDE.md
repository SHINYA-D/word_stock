# WordStock
Claude Code がこのリポジトリで事故らないための最小限の運用ルール集。

## 言語

ユーザーへの回答・報告・作業途中の状況報告は、必ず日本語で書く（コード・ファイルパス・識別子はそのまま）。長い作業のあとの報告で英語に戻りやすいので、報告を書く前に言語を確認する。

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

## テスト方針

単体テスト・Widgetテスト工程の自動生成パイプライン（`.claude/agents/test-*`, `.claude/skills/*-test-authoring`,
`.claude/skills/test-loop`, `scripts/test_harness.sh`）で運用する。

### テスト種別の使い分け

| 対象 | 種別 | 方式 |
|------|------|------|
| ViewModel のロジック（ステートマシン・楽観的更新・`result.fold` の分岐・ガード条件・境界値） | 単体テスト | `test()` + `ProviderContainer(overrides: [...])` + `addTearDown(container.dispose)`。Widget は pump しない |
| UseCase / Repository実装 / Entity の独自ロジック / 純粋関数 | 単体テスト | `test()` |
| Page の描画・ユーザー操作（タップ→遷移、ダイアログ表示、一覧表示） | Widgetテスト | `testWidgets()` + `buildWithMockRepositories()` |

- **Widgetテストでロジック網羅を狙わない**（ViewModel単体テストとの二重化を避ける）
- `mockito` / `mocktail` は使わない。手書き Fake（`test/helpers/fake_infrastructure.dart`）+
  Mock Repository（`lib/infrastructure/repositories/mock/`）+ ViewModel サブクラス override が標準
- SQLite 依存の単体テストは `sqflite_common_ffi`（`sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi`）
  を使い、テストファイルごとに `Directory.systemTemp.createTemp()` で DB ロック競合を避ける

### カバレッジ基準

- 分母は「限定分母」= `lib/domain/entities/` のうちロジックを持つもの・`lib/application/use_cases/`・
  `lib/infrastructure/repositories/`（`mock/` 除く）・`lib/infrastructure/sync/`・
  `lib/infrastructure/data_sources/local/`・`lib/presentation/**/*_view_model.dart`・`lib/core/utils/`
- 除外 = `*.freezed.dart` / `*.g.dart` / `router.g.dart` / `main.dart` / `firebase_options.dart` / 純粋UI Widget / Mock実装
- 限定分母に対して **90%+** を目標（対象ファイル単位）。計測は `bash scripts/test_harness.sh` が自動で行う。
  全体カバレッジは ⚠ 表示のみでハーネスの合否には使わない。90% 未満のファイルは Excel 項目書の
  「要確認一覧」シートに、項目書の `## 対象外` に理由があれば「90%未満（理由あり）」、無ければ赤字の
  「理由なし未達」として載る
- テスト工程（test-loop）は途中で止めず、Excel 生成まで必ずやり切る。解消しきれなかった問題
  （理由なし未達・テスト失敗・テスト漏れ・プロダクションコードのバグ）は「要確認一覧」で報告する。
  プロダクションコードのバグはテスト工程では修正しない
- **無価値テスト禁止**: カバレッジを満たすためだけの「コンストラクタを呼ぶだけ」「Freezed 生成物の getter/copyWith」
  「定数クラス」のテストは書かない。未カバー行が無価値分岐なら項目書に「対象外・理由」を記録する
- **テスト漏れゲート**: 限定分母のファイルは「テストがある（どれかのテストから読み込まれる）」か
  「`test/coverage_exclusions.txt` に `<パス> | <理由>` で登録」のいずれか必須。どちらも満たさない
  ファイルがあると `scripts/test_harness.sh`（全体実行）が `untested_files` として非 0 終了する
  （`harness_report.py` が `is_target()` の全対象を glob 列挙 → lcov と突き合わせて検出）。
  該当ファイルは Excel の「要確認一覧」に「テスト漏れ」として載る
- 対象外登録の理由は Excel 項目書の「対象外一覧」シートに集約される。テストを後から追加したり
  ファイルを消したら `coverage_exclusions.txt` の該当行も削除する（残ると `stale_exclusions` 警告。CI は落とさない）
- **項目書とテストコードの一致ゲート**: ハーネスは同じ実行で走った**全テスト名**（成功も含む）と
  項目書のケース一覧を突き合わせ、`doc_sync.doc_only`（項目書にあるがテストが無い）/
  `doc_sync.test_only`（テストはあるが項目書に無い）があると `verdict` を `continue` にする。
  仕様 ID の網羅（`spec.missing`）は項目書だけを見て判定しているため、この照合が無いと
  「項目書に書いてあるがテストコードに存在しない」ケースが素通りする
- **仕様のずれゲート**: 項目書の `仕様ID` 列には仕様内容の指紋を `SMP-D12 #a3f1c2` の形で書く。
  ハーネスが現在の仕様書と突き合わせ、食い違い（`spec.drifted`）があれば `continue` にする。
  `移動`（内容が別 ID に移った＝ ID の振り直し）はタグの貼り替えだけで済み、
  `内容変更`（ID は同じで中身が変わった）はその ID のテストを作り直す
- **仕様書が未承認（`draft`）のときは `can-skip` が必ず「生成が必要」を返す。**
  `draft` だと仕様 ID の網羅も境界値も判定されず、行カバレッジだけで合格してしまうため
  （fail-open）。この場合はループを進めず、承認するかをユーザーに確認する
- **失敗理由は自動分類される。** `tests.failures[].likely_cause` が `test`
  （操作対象が見つからない・タップが当たらない・テスト環境の不備）のものは、
  プロダクションコードのバグとして登録しても `verdict` から除外されない
  （＝誤登録でループを抜けられない）。一覧は `python3 scripts/loop_state.py triage`

### 作法

- 正常系・異常系・境界値を各対象で網羅する
- テスト名は「○○の場合、△△が起きる」形式
- テストコードを生成・変更したら、対応する項目書 MD（`test/test_cases/**/*_test_cases.md`）を必ずペアで更新する
  （フォーマットは `.claude/skills/excel-testdoc-authoring/SKILL.md`、既存の
  `test/test_cases/infrastructure/repositories/folder_repository_impl_test_cases.md` を正とする）。
  **項目書の行とテストコードのケースは 1 対 1。** ハーネスの `doc_sync` が機械的に照合する。
  なお項目書の `状態` 列（✅/❌）は自己申告の参考値で、実行結果が正（Excel が上書きする）
- **依頼範囲（`start-session --scope`）の外のテスト関連ファイルを変更すると記録される**
  （`scripts/hooks/record_test_scope.py` → `out_of_scope_writes`）。拒否はしないが、
  ハーネスの警告・最終報告・Excel の「要確認一覧」に載る。共有ヘルパー
  （`test/helpers/**`）は他の画面のテストも使うので、既存のフィールド・関数は壊さず追加だけにする
- テスト実行・カバレッジ計測は `fvm flutter test` の直叩きではなく `bash scripts/test_harness.sh [<path>]` 経由で行う
- **ループの継続/終了は自分で判断せず、回数も数えない。** `harness_report.json` の `loop.verdict`
  （`scripts/loop_state.py` が算出）に従う。内部・外部のループ回数は `.test_loop/state.json` で
  スクリプトが管理する（手で編集しない＝`.test_loop/` への Edit/Write はフックが拒否する。
  1依頼＝1セッションで `end-session` / TTL 24h により破棄）
- **テスト工程は Excel 生成まで機構で強制される。** Stop フック
  （`scripts/hooks/require_test_loop_completion.py`）が、`.test_loop/state.json` に
  `completed_at` が立つまでターンの終了を拒否する。`completed_at` は
  `gen_test_excel.py` が Excel の保存に成功したときにのみ記録され、
  `end-session` も同じ条件を要求する（緊急脱出は `end-session --force`）
- 項目書の `## 対象外` は `- L142-145：理由` のように**行番号を付ける**。ハーネスが lcov の
  未カバー行と照合して「理由あり」を判定するため
- 項目書 Excel は `.claude/agents/test-doc-excel-generator` が `scripts/gen_test_excel.py` 経由で
  `~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx` に生成する

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
- 同期フロー・競合解決・フェーズ計画の詳細は `docs/high_level_design/online_offline.md` を参照

## 既知の矛盾（要注意）

`docs/high_level_design/requirements.md` には「本アプリはオンライン必須。ローカルキャッシュ不採用」と書かれているが、これは古い記述。
現在は `docs/high_level_design/online_offline.md` に従いオフライン同期対応へ移行中のため、**実装判断に迷ったら `docs/high_level_design/online_offline.md` を優先**すること。

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
| `docs/high_level_design/requirements.md` | 元の要件定義書（一部オフライン関連の記述は古い） |
| `docs/high_level_design/online_offline.md` | オフライン同期機能の実装指示書（フェーズ別タスク） |
| `docs/detailed_design/**/*.md` | 機能ごとの振る舞い仕様書（詳細設計）。画面が主体なら `lib/presentation/` と同じ階層に Page と同じファイル名（`sample_page.md`）、画面が主体でなければ `docs/detailed_design/<機能名>/<機能名>.md` に置く。テストの期待値の根拠。書き方は `.claude/skills/spec-authoring/SKILL.md` |
| `docs/development/common_principles.md` | 全画面共通の振る舞い原則。各仕様書から `原則-<番号>` で引用される |
