# Claude Code hooks 解説（WordStock）

## このドキュメントについて

`.claude/settings.json` の `hooks` は JSON のためコメントを書けない。
そのため、各フックが「何を」「なぜ」ブロックしているのかを本ドキュメントに解説として残す。
仕様そのものの正は `.claude/settings.json` と `scripts/hooks/*.sh`（コメント付き）にあり、
本ドキュメントはその補助資料。フック追加・変更時は本ドキュメントも追従させること。

## 全体像

`PreToolUse` フックは「ツールを実際に実行する直前」に発火し、渡されたJSON入力（実行しようとしている
コマンドやファイルパス）を検査して、問題があれば `decision: "block"` を返してツール実行そのものを止める。

`.claude/settings.json` では3種類のツール呼び出しにフックを挟んでいる。

| matcher | 対象ツール | 挟んでいるスクリプト |
|---------|-----------|---------------------|
| `Bash` | Bashコマンド実行 | `block_direct_flutter_test.sh` |
| `Agent\|Task` | サブエージェント起動 | `require_test_loop_skill.sh` |
| `Edit\|Write` | ファイル編集・新規作成 | `block_generated_file_edit.sh` |

同一matcherに複数フックを登録した場合は配列の順番通りに実行される（現状は各matcher 1本ずつ）。

図解: [images/hooks_overview.svg](images/hooks_overview.svg)（フック単体）/
[images/test_pipeline_overview.svg](images/test_pipeline_overview.svg)（テスト工程のどこで発火するか）

---

## `scripts/hooks/block_direct_flutter_test.sh`（Bash用）

**発火条件**: Bashツール呼び出し前（毎回）

**根拠**: CLAUDE.md「テスト実行・カバレッジ計測は `fvm flutter test` の直叩きではなく
`bash scripts/test_harness.sh [<path>]` 経由で行う」

**やっていること**:
実行しようとしているコマンド文字列に `fvm flutter test` または `flutter test`（fvm なし）が含まれていたら
（間の空白は問わず正規表現でマッチ）、
`decision: "block"` を返してコマンド実行を拒否する。拒否理由には `scripts/test_harness.sh` を使うよう促す
メッセージが含まれる。

**なぜ必要か**:
`test_harness.sh` はハーネス実行の結果を `coverage/harness_report.json` という機械可読な形に整形し、
test-loop（[test_loop_pipeline.md](test_loop_pipeline.md)）やExcel生成エージェントがそれを読む前提で
パイプライン全体が組まれている。`fvm flutter test` を直接叩いてしまうと、この機械可読レポートが
更新されず、ループの合否判定やカバレッジ集計が壊れる。人間・Claude双方が誤って直叩きしないための
機械的なガード。fvm なしの `flutter test` も、レポートが更新されないうえに `.fvmrc` で固定した
バージョンを外れるため同様にブロックする。

**注意（文字列ベースの判定）**:
`test_harness.sh` 内部の `fvm flutter test` はツール呼び出しではないため検査対象外（＝ハーネス経由なら通る）。
逆に、実行するつもりがなくてもコマンド文字列にこの語が含まれていれば（grep の検索語など）ブロックされる。

---

## `scripts/hooks/require_test_loop_skill.sh`（Agent/Task用）

**発火条件**: Agent（Task）ツールによるサブエージェント起動前（毎回）

**根拠**: CLAUDE.md「テスト方針」— テスト生成は `.claude/skills/test-loop` のパイプラインで運用する

**やっていること**:
`tool_input.subagent_type` が `test-unit-test-generator` / `test-widget-test-generator` /
`test-doc-excel-generator` のいずれかの場合のみ判定する（それ以外のエージェントは即通過）。
`transcript_path`（このセッションのJSONL）に test-loop スキルの読み込み痕跡
（Skill呼び出し `"skill":"test-loop"` / `/test-loop` のスラッシュ起動 / `SKILL.md` の直接読み込み）が
無ければ `decision: "block"` を返し、先に test-loop を読み込むよう促す。
`transcript_path` が無い・読めない場合はブロックしない（フェイルオープン）。

**なぜ必要か**:
Skill は description を見てモデルが呼ぶかどうかを判断する仕組みで、必ず読まれる保証がない。
test-loop を読まずにテストエージェントを起動すると、Tier順の消化・`.test_loop/state.json` での進捗管理・
ハーネス差し戻し（対象ファイル90%+ / green）・Excel生成（未解消の問題は要確認一覧に記載）が丸ごと抜け落ちるため、
「テストエージェントの起動」という入口で手順書の読み込みを強制する。

---

## `scripts/hooks/block_generated_file_edit.sh`（Edit/Write用）

**発火条件**: Edit または Write ツール呼び出し前（毎回）

**根拠**: CLAUDE.md「生成ファイル不可侵」— `*.freezed.dart` / `*.g.dart` / `router.g.dart` は
`build_runner` が自動生成するため手で編集しない

**やっていること**:
Edit/Writeで指定されたファイルパスの拡張子・ファイル名が `*.freezed.dart` / `*.g.dart` / `router.g.dart`
のいずれかに該当すれば、`decision: "block"` を返して編集・作成そのものを拒否する。拒否理由には
`fvm dart run build_runner build --delete-conflicting-outputs` で更新するよう促すメッセージが含まれる。

**なぜ必要か**:
生成ファイルを手で編集しても、次に `build_runner` を実行した瞬間に上書きされて変更が消える。
気づかないまま作業を進めると、実装したはずの変更が消失する事故につながるため、編集を試みた
その場でブロックする。

---

## この3つのフックが対象にしていないこと

- 「どのスキル/エージェントを呼ぶべきか」というタスクの意味的な判断はhooksでは強制できない
  （hooksはツール呼び出しイベントに対する機械的なパターン検知しかできない）。
  `require_test_loop_skill.sh` も「test-loop を読んだか」を事後的に検査するだけで、Skill 選択そのものを
  強制するわけではない。確実に test-loop から始めたい場合は `/test-loop` を明示的に呼ぶ。
- PreToolUse の入力JSONには `agent_type` が含まれないため、「どのサブエージェントがBashを呼んだか」で
  振り分けるフックは作れない。サブエージェントの判定は Agent/Task 呼び出し時の `tool_input.subagent_type` で行う。
- `gen_test_excel.py` 実行前の venv チェックはフックでは行わない。`openpyxl` が無ければスクリプト自身が
  セットアップ手順を表示して終了する。

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `.claude/settings.json` | hooks・permissionsの設定本体 |
| `scripts/hooks/block_direct_flutter_test.sh` | Bash用フック（`fvm flutter test` / `flutter test` 直叩き禁止） |
| `scripts/hooks/require_test_loop_skill.sh` | Agent/Task用フック（test-loop 未読込でのテストエージェント起動禁止） |
| `scripts/hooks/block_generated_file_edit.sh` | Edit/Write用フック（生成ファイル編集禁止） |
| `scripts/test_harness.sh` | テスト実行・カバレッジ計測ハーネス（直叩き禁止の代替手段） |
| `docs/test_loop_pipeline.md` | テスト自動生成パイプライン全体の解説 |
