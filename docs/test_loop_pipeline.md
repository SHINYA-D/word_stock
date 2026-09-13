# テスト自動生成パイプライン（test-loop）解説

## このドキュメントについて

本ドキュメントは `.claude/skills/test-loop/SKILL.md` が定義するテスト自動生成パイプラインの
全体フローを人間が読める形で整理したものです。仕組みそのものの定義（正）は
`.claude/skills/test-loop/SKILL.md` にあり、本ドキュメントはその解説・補助資料です。
仕様変更時は `.claude/skills/test-loop/SKILL.md` を先に更新し、本ドキュメントを追従させること。

## 全体構成

`test-loop` は大きく2部構成です。

1. **個別ループ（手順1〜6）**: 対象ファイルを1つ選び、生成 → 検証 → 合否判定を行う。対象ファイルの数だけ繰り返す
2. **仕上げ工程（手順7〜11）**: 全対象が完了した後に1回だけ実行するレビュー・成果物生成の工程

**テスト工程は途中で止めず、必ず手順10（Excel生成）までやり切る。** 解消しきれなかった問題は
Excel の「要確認一覧」シートに載せて報告する（詳細は後述「要確認一覧」）。

---

## 個別ループ（1対象あたり／手順1〜6）

対象ファイルは以下の Tier 順に消化する（`.claude/skills/test-loop/SKILL.md` の対象一覧）。

| Tier | 対象 | 担当エージェント |
|------|------|-----------------|
| 1 | `lib/infrastructure/sync/**`、`lib/infrastructure/repositories/{word,settings,auth,flashcard_result}_repository_impl.dart` | test-unit-test-generator |
| 2 | `lib/presentation/**/*_view_model.dart`、`lib/application/use_cases/**` | test-unit-test-generator |
| 3 | `lib/domain/entities/**`（独自ロジックがある場合のみ）、`lib/core/utils/folder_name_validator.dart` | test-unit-test-generator |
| 4 | 未カバー / 手薄な `lib/presentation/**/*_page.dart` | test-widget-test-generator |

Tier1〜3（単体テスト）を全ファイル完了してから、Tier4（Widgetテスト）に着手する。

### 手順

**1. 計画**
`python3 scripts/loop_state.py show` の `done` に無い、最上位 Tier の対象を1つ選ぶ。

**2. 生成**
起動の直前に `python3 scripts/loop_state.py begin-attempt <libパス>` を叩く（これが外部ループのカウント）。

対応するサブエージェント（Tier1〜3は `test-unit-test-generator`、Tier4は `test-widget-test-generator`）を
Agentツールで起動する。プロンプトには対象ファイルパス1つだけを渡す。

サブエージェントは内部で以下を行い、結果をメインへ返す。
- テストコード生成（`test/**/*_test.dart`）
- 項目書MD生成（`test/test_cases/**/*_test_cases.md`）
- 自前でのハーネス実行と、`harness_report.json` の `loop.verdict` が `stop` になるまでの内部リトライ
  （回数はハーネスが数える。上限到達時は打ち切り、現状と原因の見立てを報告に明記する）

**3. 実行**
メイン側でも `bash scripts/test_harness.sh <生成テストファイルパス>` を実行し、
`coverage/harness_report.json` を読む。

**4. 分析**
`tests.failures` と `coverage.files[].uncovered_lines` を以下に分類する。

| 分類 | 対応 |
|------|------|
| テストコードのバグ（Fake設定ミス・期待値誤り） | 同エージェントに `harness_report.json` の該当部を添えて差し戻し |
| プロダクションコードのバグ | コードは修正せず `loop_state.py bug` で記録し、`finish --status skipped` にして次の対象へ進む（Excel の「要確認一覧」に載る） |
| エージェントが返した「判断保留」の未カバー行 | メインが「テスト追加を差し戻す」か「理由を書いて対象外に確定する」かを決める。決まらなければExcelで「理由なし未達」になる |
| 未カバー行がテスト価値のある分岐 | 同エージェントに「この分岐のテスト追加」を差し戻し |
| 未カバー行が無価値（到達不能・防御・ログ） | エージェントに項目書「## 対象外」へ記録させ、カウント外扱い |
| 対象ファイルがまるごと未テスト（`untested_files`） | テストを生成する。真に不要なら `test/coverage_exclusions.txt` に理由付きで登録 |
| `stale_exclusions` に出る | 不要になった `coverage_exclusions.txt` の行を削除（警告のみ・CIは落ちない） |

**5. 反復**
`harness_report.json` の `loop.verdict` が `stop` になるまで 2〜4 を繰り返す。
**継続するかどうかの判断も、回数のカウントもスクリプトが行う**（後述）。
外部上限に達したら現状を `skipped` に理由付きで記録し、止めずに次の対象へ進む。

**6. 記録**
`python3 scripts/loop_state.py finish <libパス> --status done`
（または `--status skipped --reason ...`）でコミット可能な状態にする。

→ この1〜6を、Tier順に全対象ファイルが `done`/`skipped` になるまで繰り返す。

### リトライの二重構造

| 階層 | 上限 | 内容 | カウントされる契機 |
|------|------|------|------------------|
| 外側（test-loop、手順2） | 最大5回 | サブエージェントをコールドスタートで再起動する回数 | `loop_state.py begin-attempt` |
| 内側（サブエージェント自身） | 最大3回 | 1回の起動内で「ハーネス再実行→分析→追加」を試みる回数 | `test_harness.sh` の実行（自動） |

1対象あたりの最大試行回数は 外側5回 × 内側3回 = **最大15回のハーネス実行**。
これを超えてもなお基準未達の場合は `skipped` として次の対象に進む。

### 継続判定はスクリプトが行う

回数を数えるのも上限と比べるのも `scripts/loop_state.py` の責務で、LLM は判断しない。
`harness_report.py` がハーネス実行のたびに内部カウントを進め、判定結果を
`harness_report.json` の `loop` に書き出す。

```json
"loop": {
  "target": "lib/infrastructure/sync/sync_service.dart",
  "verdict": "continue",
  "reason": "カバレッジ 72.4%。未カバー行 12 行のうち 9 行に理由がない（88, 144, 145 …）",
  "inner": 2, "inner_max": 3,
  "outer": 1, "outer_max": 5,
  "warnings": []
}
```

判定順（暴走を止めるのが最優先なので上限を先に見る）:

| # | 条件 | verdict |
|---|------|---------|
| 1 | 内部上限に到達 | **stop** |
| 2 | 外部上限に到達 | **stop** |
| 3 | 対象のテストが失敗している | continue |
| 4 | 限定分母外（Page 等）で全テスト green | **stop**（カバレッジは見ない） |
| 5 | カバレッジ 90%+ | **stop** |
| 6 | 未カバー行が全て項目書 `## 対象外` の理由（行番号付き）に紐づく | **stop** |
| 7 | それ以外 | continue |

全体実行（引数なし）や対象を特定できないときは `verdict: "n/a"` で何も判断しない。
**`loop.verdict` は次アクションの指示であって合否ではなく、ハーネスの終了コードには影響しない**
（カバレッジをハードゲート化すると水増しテストを誘発するため）。

内部カウントはハーネス実行そのものに紐づくため、エージェントが申告する必要も、
数えずに回り続ける余地もない。

### ステートの寿命

`.test_loop/state.json` は **ユーザーの1依頼＝1セッション**のスコープ。

1. 仕上げ工程の最後に `loop_state.py end-session` で明示的に破棄する
2. 破棄し忘れても `created_at` から24時間（`LOOP_SESSION_TTL_HOURS`）で自動破棄される

寿命を超えて `done` が残らないので、実装を変更した後に古い `done` でスキップされる事故が起きない。
観測データ（`coverage/` 配下）とはディレクトリを分けてあり、`flutter clean` でも飛ばない。

---

## 仕上げ工程（全Tier消化後・1回だけ／手順7〜11）

**7. 回帰確認**
引数なしの `bash scripts/test_harness.sh`（全体実行、テスト漏れゲート適用）を**1回だけ**実行して
`harness_report.json` を最新化する。**ここでは再実行・差し戻しをしない**。終了コードが非0でも手順8へ進み、
問題はすべてExcelの「要確認一覧」に載せる。全体カバレッジはハーネスの合否に使わない（⚠表示のみ）。

**8. 規約レビュー**
`architecture-guard` エージェントを起動し、生成した全テストコードがCLAUDE.mdのアーキテクチャ/コーディングルールに
違反していないか確認する。

**9. 網羅性・必要性の自己監査**
各項目書MDと対応テストに対して以下を確認する。指摘があれば該当エージェントに差し戻して修正する。
- 正常系・異常系・境界値が揃っているか（どれかゼロなら理由が妥当か）
- 同じ振る舞いを検証する重複テストがないか
- 無価値テスト（コンストラクタのみ / Freezed生成物 / 単純委譲の過剰検証）が紛れていないか
- 「## 対象外」の理由が「本当にテスト不要」か（サボりの言い訳になっていないか）
- Widgetテストがロジック網羅に踏み込んでViewModel単体テストと二重化していないか

**10. Excel生成**
`test-doc-excel-generator` エージェントを起動し、`~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx` を生成する。
手順7〜9で問題が残っていても必ず実行する。

**11. セッション破棄**
`python3 scripts/loop_state.py end-session` で `.test_loop/state.json` を破棄する。
Excel が `production_bugs` を読むため、必ず手順10の後に実行する。

→ 完了後、最終報告フォーマット（`.claude/skills/test-loop/SKILL.md` 参照）で報告する。

### 要確認一覧（Excelシート）

`scripts/gen_test_excel.py` が `harness_report.json`・`.test_loop/state.json`・項目書MDから自動で集める。

| 区分 | 表示 | 条件 |
|------|------|------|
| 理由なし未達 | 赤字 | 対象ファイルが90%未満で、項目書の `## 対象外` に理由が無い（空・`判断保留` のまま・項目書が無い） |
| プロダクションコードのバグ | 赤字 | `.test_loop/state.json` の `production_bugs` |
| テスト失敗 | 赤字 | `harness_report.json` の `tests.failures` |
| テスト漏れ | 赤字 | `harness_report.json` の `coverage.untested_files` |
| 90%未満（理由あり） | 黄 | 対象ファイルが90%未満で、`## 対象外` に理由がある |
| 対象外に行番号なし | 黄 | 上記のうち、理由に行番号が無く未カバー行と照合できない（段階移行中） |

---

## 全体フロー図

```
[Tier1] file1(1〜6) → file2(1〜6) → ...
[Tier2] file1(1〜6) → file2(1〜6) → ...
[Tier3] file1(1〜6) → file2(1〜6) → ...
[Tier4] file1(1〜6) → file2(1〜6) → ...
  ↓ 全ファイル done
7. 回帰確認 → 8. 規約レビュー → 9. 自己監査 → 10. Excel生成 → 11. セッション破棄
  ↓
完了報告
```

## 呼び出し方

- 単発で最後まで通しで回す場合: `/test-loop`
- 1対象ずつターンを区切って回す場合（`/loop` と併用）: `/loop /test-loop`
  - 1回の起動で「1対象分の手順1〜6」のみ実行し、`.test_loop/state.json` で進捗を引き継ぐ
  - 全Tier `done` になったら仕上げ工程（7〜11）を1回だけ実行して終了する

## 生成される可能性のあるファイル一覧

test-loop 実行中に生成・更新されうるファイルを、発生元ごとに整理する。

### テストコード（サブエージェントが生成、Gitで管理する）

| パス | 生成元 | 内容 |
|------|--------|------|
| `test/**/*_test.dart` | test-unit-test-generator | 単体テストコード（対象ファイル名 + `_test.dart`） |
| `test/presentation/**/*_page_test.dart` | test-widget-test-generator | Widgetテストコード |
| `test/helpers/fake_infrastructure.dart` | test-unit-test-generator（既存に追記） | 複数テストで共有するFake実装の追記先 |

### 項目書MD（サブエージェントが生成、Gitで管理する）

| パス | 生成元 | 内容 |
|------|--------|------|
| `test/test_cases/[対象パス]_test_cases.md` | test-unit-test-generator | 単体テストの項目書（`.claude/skills/excel-testdoc-authoring/SKILL.md` 準拠） |
| `test/test_cases/presentation/[ページ名]/[ページ名]_page_test_cases.md` | test-widget-test-generator | Widgetテストの項目書（ファイル名が `_page_test_cases.md` で終わることでExcelの「Widgetテスト項目書」シートに分類される） |

### 対象外登録簿（手動運用・Gitで管理する）

| パス | 生成元 | 内容 |
|------|--------|------|
| `test/coverage_exclusions.txt` | ループ手順4／各エージェント | ファイル丸ごとテスト対象外にする場合の登録簿。`<lib/ からのパス> \| <理由>` 形式 |

### 進捗状態（`scripts/loop_state.py` が管理・Git管理外／セッション限り）

| パス | 生成元 | 内容 |
|------|--------|------|
| `.test_loop/state.json` | `scripts/loop_state.py`（メインがコマンド経由で操作） | `{ "session_id", "created_at", "done": [...], "skipped": {path: reason}, "outer": {path: n}, "inner": {path: n}, "production_bugs": [...] }`。ループ回数・進捗管理と、見つけたプロダクションコードのバグの記録（Excelの要確認一覧に載る）。**手で編集しない**。1依頼＝1セッションで、`end-session` かTTL(24h)で破棄される |

### ハーネス実行結果（`scripts/test_harness.sh` が生成、`.gitignore` で除外＝`coverage/`）

| パス | 生成元 | 内容 |
|------|--------|------|
| `coverage/test_machine.jsonl` | `fvm flutter test --machine` の生出力 | テスト成否の機械可読ログ（`harness_report.py` の入力） |
| `coverage/lcov.info` | `fvm flutter test --coverage` | Flutter生成の生lcovカバレッジデータ |
| `coverage/lcov.filtered.info` | `harness_report.py` | 限定分母（テスト対象）でフィルタ後のlcov |
| `coverage/harness_report.json` | `harness_report.py` | 機械可読レポート本体。`tests.failures`・`coverage.files[].uncovered_lines`・`coverage.untested_files`・`stale_exclusions` 等を含み、ループとExcel生成エージェントが読む |

### 最終成果物（仕上げ工程・手順10）

| パス | 生成元 | 内容 |
|------|--------|------|
| `~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx` | test-doc-excel-generator（`scripts/gen_test_excel.py` 経由） | 「表紙」「記載要領・観点一覧」「サマリ」「要確認一覧」「単体テスト項目書」「Widgetテスト項目書」「対象外一覧」の7シート構成。入力は `test/test_cases/**/*.md`・`coverage/harness_report.json`・`.test_loop/state.json` |

### まとめ図

```
lib/xxx.dart（対象）
  ├→ test/xxx_test.dart                      … テストコード
  ├→ test/test_cases/xxx_test_cases.md       … 項目書MD
  └→ (対象外にする行/ファイルがあれば)
       test/coverage_exclusions.txt に追記

scripts/test_harness.sh 実行のたびに coverage/ 配下を上書き:
  coverage/test_machine.jsonl
  coverage/lcov.info
  coverage/lcov.filtered.info
  coverage/harness_report.json

.test_loop/state.json        … ループ進捗・回数（loop_state.py が管理）

全Tier完了後、手順10で1回だけ:
  ~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx
```

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `.claude/skills/test-loop/SKILL.md` | 本パイプラインの正式な定義（仕様変更時はここを更新） |
| `.claude/agents/test-unit-test-generator.md` | 単体テスト生成エージェント |
| `.claude/agents/test-widget-test-generator.md` | Widgetテスト生成エージェント |
| `.claude/agents/test-doc-excel-generator.md` | Excel項目書生成エージェント |
| `.claude/skills/unit-test-authoring/SKILL.md` | 単体テストの作法・雛形 |
| `.claude/skills/widget-test-authoring/SKILL.md` | Widgetテストの作法・雛形 |
| `.claude/skills/excel-testdoc-authoring/SKILL.md` | 項目書MDのフォーマット規約 |
| `scripts/test_harness.sh` | テスト実行・カバレッジ計測ハーネス |
| `.test_loop/state.json` | ループの進捗状態とループ回数（done/skipped/outer/inner） |

## 生成ファイルパス一覧（フラット版・テストコード除く）

```
test/test_cases/**/*_test_cases.md
  … 単体テストの項目書MD（対象クラス/メソッド、テストケース一覧、正常系・異常系・境界値、対象外）

test/test_cases/presentation/**/*_page_test_cases.md
  … Widgetテストの項目書MD（内容は上と同形式。ファイル名で単体テストと区別しExcelのシート振り分けに使う）

test/coverage_exclusions.txt
  … ファイル丸ごとをテスト対象外にする登録簿。`<lib/ からのパス> | <理由>` の形式

.test_loop/state.json
  … test-loopの進捗状態。`{ "done": [...], "skipped": {path: 理由}, "attempts": {path: 試行回数}, "production_bugs": [...] }`

coverage/test_machine.jsonl
  … `fvm flutter test --machine` の生出力。各テストの成功/失敗が1行ずつJSONで並ぶ機械可読ログ

coverage/lcov.info
  … Flutterが出力する生のlcovカバレッジデータ（プロジェクト全体、フィルタ前）

coverage/lcov.filtered.info
  … 上記を「限定分母」（テスト対象と定義されたファイルのみ）でフィルタしたlcov

coverage/harness_report.json
  … 機械可読な最終レポート。テスト失敗一覧(`tests.failures`)、ファイルごとの未カバー行(`coverage.files[].uncovered_lines`)、
    テストが無い対象ファイル(`coverage.untested_files`)、不要になった対象外登録(`stale_exclusions`)などを含む。
    ループの合否判定とExcel生成はこのファイルを読んで行う

~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx
  … 最終成果物のExcel項目書。「表紙」「記載要領・観点一覧」「サマリ」「要確認一覧」「単体テスト項目書」「Widgetテスト項目書」「対象外一覧」の7シート構成
```
