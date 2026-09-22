# テスト自動生成パイプライン（test-loop）解説

## このドキュメントについて

本ドキュメントは `.claude/skills/test-loop/SKILL.md` が定義するテスト自動生成パイプラインの
全体フローを人間が読める形で整理したものです。仕組みそのものの定義（正）は
`.claude/skills/test-loop/SKILL.md` にあり、本ドキュメントはその解説・補助資料です。
仕様変更時は `.claude/skills/test-loop/SKILL.md` を先に更新し、本ドキュメントを追従させること。

## 全体構成

`test-loop` は大きく2部構成です。手順の番号は `.claude/skills/test-loop/SKILL.md` と同じです。

1. **個別ループ（手順1〜7）**: 対象ファイルを1つ選び、生成 → 検証 → 合否判定を行う。対象ファイルの数だけ繰り返す
2. **仕上げ工程（手順8〜12）**: 全対象が完了した後に1回だけ実行するレビュー・成果物生成の工程

**テスト工程は途中で止めず、必ず手順11（Excel生成）までやり切る。** 解消しきれなかった問題は
Excel の「要確認一覧」シートに載せて報告する（詳細は後述「要確認一覧」）。

承認済みの詳細設計書（仕様書、`docs/detailed_design/**`）がある対象は、**仕様書を期待値の正とする**。
コードを読んで期待値を作らないので、仕様書どおりの期待値で落ちたテストは、プロダクションコードのバグとして扱う。

---

## 個別ループ（1対象あたり／手順1〜7）

対象ファイルは以下の Tier 順に消化する（`.claude/skills/test-loop/SKILL.md` の対象一覧）。

| Tier | 対象 | 担当エージェント |
|------|------|-----------------|
| 1 | `lib/infrastructure/sync/**`、`lib/infrastructure/repositories/{word,settings,auth,flashcard_result}_repository_impl.dart` | test-unit-test-generator |
| 2 | `lib/presentation/**/*_view_model.dart`、`lib/application/use_cases/**` | test-unit-test-generator |
| 3 | `lib/domain/entities/**`（独自ロジックがある場合のみ）、`lib/core/utils/folder_name_validator.dart` | test-unit-test-generator |
| 4 | 未カバー / 手薄な `lib/presentation/**/*_page.dart` | test-widget-test-generator |

Tier1〜3（単体テスト）を全ファイル完了してから、Tier4（Widgetテスト）に着手する。

### 手順

**1. 範囲宣言（部分依頼のときだけ）**
ユーザーが一部のファイルだけを依頼した場合、最初に `python3 scripts/loop_state.py start-session --scope <libパス...>` で
対象範囲を宣言する。宣言しないと Stop フックが全対象の消化を要求する。全体依頼なら不要。

**2. 計画**
`python3 scripts/loop_state.py show` の `done` に無い、最上位 Tier の対象を1つ選ぶ。
その対象の承認済み仕様書（`status: approved`、`targets` に対象が載っている）があれば、
章ごとの振り分け（3章→Widget テスト、4章→ViewModel 単体テスト …）で担当する仕様 ID の一覧を作る。

既存のテストがある対象は、生成の前に一度ハーネスを回し、`python3 scripts/loop_state.py can-skip <libパス>` で
「既存のテストだけで基準を満たしているか」を判定する。満たしていれば手順3〜6を飛ばして手順7（記録）へ進む。
判定条件は ①ループ判定が stop（上限による打ち切りを除く）②テストの無い仕様 ID が無い ③境界値のテストが足りない仕様 ID が無い
④レポートが対象ファイル・テスト・項目書より新しい、の4つで、スクリプトが判定する。
これは「コードもテストも変えずに2回目を実行したとき、成果物が変わらない」ようにするための仕組み。

**3. エージェント起動**
起動の直前に `python3 scripts/loop_state.py begin-attempt <libパス>` を叩く（これが外部ループのカウント）。

対応するサブエージェント（Tier1〜3は `test-unit-test-generator`、Tier4は `test-widget-test-generator`）を
Agentツールで起動する。プロンプトには対象ファイルパス1つを渡す。仕様書がある場合は、仕様書のパスと
担当する仕様 ID の一覧も渡し、「期待値は仕様書から作り、コードは呼び出し方を知るためだけに読む」と明記する。

**4. テスト生成（サブエージェント）**
サブエージェントは以下を行い、結果をメインへ返す。
- テストコード生成（`test/**/*_test.dart`）
- 項目書MD生成（`test/test_cases/**/*_test_cases.md`）。「仕様ID」列に、各テストケースが引用する仕様 ID を書く
- 自前でのハーネス実行と、`harness_report.json` の `loop.verdict` が `stop` になるまでの内部リトライ
  （回数はハーネスが数える。上限到達時は打ち切り、現状と原因の見立てを報告に明記する）

**5. 実行**
`bash scripts/test_harness.sh <生成テストファイルパス>` を実行し、`coverage/harness_report.json` を読む。
仕様書がある対象は、ハーネスが項目書の「仕様ID」列を仕様書と突き合わせ、テストの無い ID や境界値の不足を
「仕様漏れ」として警告する（判定には影響しない）。

**6. 判定**
まず `loop.verdict` を読む。`continue` なら不足を解消して手順3〜5 を繰り返し（差し戻し）、`stop` なら手順7へ進む。
**継続するかどうかの判断も、回数のカウントもスクリプトが行う**（後述）。
その上で、`tests.failures` と `coverage.files[].uncovered_lines` を以下に分類する。

| 分類 | 対応 |
|------|------|
| 仕様書どおりの期待値で落ちた（仕様書がある対象） | プロダクションコードのバグ。期待値もコードも直さない。`loop_state.py bug` で、症状の先頭に仕様 ID を書いて記録する。再実行すると、その ID の失敗は判定から除外されて `stop` になる |
| テストコードのバグ（Fake設定ミス・期待値誤り） | 同エージェントに `harness_report.json` の該当部を添えて差し戻し |
| プロダクションコードのバグ | コードは修正せず `loop_state.py bug` で記録し、`finish --status skipped` にして次の対象へ進む（Excel の「要確認一覧」に載る） |
| エージェントが返した「判断保留」の未カバー行 | メインが「テスト追加を差し戻す」か「理由を書いて対象外に確定する」かを決める。決まらなければExcelで「理由なし未達」になる |
| 未カバー行がテスト価値のある分岐 | 同エージェントに「この分岐のテスト追加」を差し戻し |
| 未カバー行が無価値（到達不能・防御・ログ） | エージェントに項目書「## 対象外」へ行番号付きで記録させ、カウント外扱い |
| 対象ファイルがまるごと未テスト（`untested_files`） | テストを生成する。真に不要なら `test/coverage_exclusions.txt` に理由付きで登録 |
| `stale_exclusions` に出る | 不要になった `coverage_exclusions.txt` の行を削除（警告のみ・CIは落ちない） |

外部上限に達したら現状を `skipped` に理由付きで記録し、止めずに次の対象へ進む。

**7. 記録**
`python3 scripts/loop_state.py finish <libパス> --status done`
（または `--status skipped --reason ...`）でコミット可能な状態にする。

→ この1〜7を、Tier順に全対象ファイルが `done`/`skipped` になるまで繰り返す（手順1 は最初の1回だけ）。

### リトライの二重構造

| 階層 | 上限 | 内容 | カウントされる契機 |
|------|------|------|------------------|
| 外側（test-loop、手順3） | 最大3回 | サブエージェントをコールドスタートで再起動する回数 | `loop_state.py begin-attempt` |
| 内側（サブエージェント自身） | 最大3回 | 1回の起動内で「ハーネス再実行→分析→追加」を試みる回数 | `test_harness.sh` の実行（自動） |

1対象あたりの最大試行回数は 外側3回 × 内側3回 = **最大9回のハーネス実行**。
これを超えてもなお基準未達の場合は `skipped` として次の対象に進む。

カウントされるのは test-loop のセッション中（`start-session` / `begin-attempt` の後）だけ。
セッションが無いときに動作確認のためにハーネスを回しても、ステートは作られず、Stop フックも動かない。

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
  "outer": 1, "outer_max": 3,
  "warnings": []
}
```

判定順（まず目標に達したかを判定し、`continue` のときだけ上限を当てはめる）:

| # | 条件 | verdict |
|---|------|---------|
| 1 | 対象のテストが失敗している（記録済みのバグで説明できる失敗は除く） | continue |
| 2 | 限定分母外（Page 等）で全テスト green | **stop**（カバレッジは見ない） |
| 3 | カバレッジ 90%+ | **stop** |
| 4 | 未カバー行が全て項目書 `## 対象外` の理由（行番号付き）に紐づく | **stop** |
| 5 | それ以外 | continue |
| 上限 | 1〜5 の結果が continue で、内部上限または外部上限に到達している | **stop**（未達の理由は `warnings` に残す） |

上限は `continue` が続く（＝回しすぎる）のを止めるためのもので、目標に達した `stop` は上書きしない。
そのため、バグを記録した直後の再実行は、内部カウンタが上限を超えていても、記録済みのバグで説明できれば `stop` になる。

全体実行（引数なし）や対象を特定できないときは `verdict: "n/a"` で何も判断しない。
**`loop.verdict` は次アクションの指示であって合否ではなく、ハーネスの終了コードには影響しない**
（カバレッジをハードゲート化すると水増しテストを誘発するため）。

内部カウントはハーネス実行そのものに紐づくため、エージェントが申告する必要も、
数えずに回り続ける余地もない。

### ステートの寿命

`.test_loop/state.json` は **ユーザーの1依頼＝1セッション**のスコープ。

1. 仕上げ工程の最後に `loop_state.py end-session` で明示的に破棄する
   （`completed_at` が立っていないと拒否される。緊急時のみ `--force`）
2. 破棄し忘れても `created_at` から24時間（`LOOP_SESSION_TTL_HOURS`）で自動破棄される

寿命を超えて `done` が残らないので、実装を変更した後に古い `done` でスキップされる事故が起きない。
観測データ（`coverage/` 配下）とはディレクトリを分けてあり、`flutter clean` でも飛ばない。

---

## 仕上げ工程（全Tier消化後・1回だけ／手順8〜12）

**8. 回帰確認**
引数なしの `bash scripts/test_harness.sh`（全体実行、テスト漏れゲート適用）を**1回だけ**実行して
`harness_report.json` を最新化する。**ここでは再実行・差し戻しをしない**。終了コードが非0でも手順9へ進み、
問題はすべてExcelの「要確認一覧」に載せる。全体カバレッジはハーネスの合否に使わない（⚠表示のみ）。
例外として、手順9・10の指摘でテストコードを直した場合だけ、手順11の直前にもう1回だけ実行する
（Excel が古い結果を読まないようにするため）。

**9. 規約レビュー**
`architecture-guard` エージェントを起動し、生成した全テストコードがCLAUDE.mdのアーキテクチャ/コーディングルールに
違反していないか確認する。

**10. 網羅性・必要性の自己監査**
各項目書MDと対応テストに対して以下を確認する。指摘があれば該当エージェントに差し戻して修正する。
- 正常系・異常系・境界値が揃っているか（どれかゼロなら理由が妥当か）
- 同じ振る舞いを検証する重複テストがないか
- 無価値テスト（コンストラクタのみ / Freezed生成物 / 単純委譲の過剰検証）が紛れていないか
- 「## 対象外」の理由が「本当にテスト不要」か（サボりの言い訳になっていないか）
- Widgetテストがロジック網羅に踏み込んでViewModel単体テストと二重化していないか
- （仕様書がある対象）引用した仕様 ID の条件と期待される動作をすべて確かめているか、
  期待値をコードの動作に寄せていないか、仕様書にない操作手段を使っていないか

**11. Excel生成**
`test-doc-excel-generator` エージェントを起動し、`~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx` を生成する。
手順8〜10で問題が残っていても必ず実行する。

**12. セッション破棄**
`python3 scripts/loop_state.py end-session` で `.test_loop/state.json` を破棄する。
Excel が `production_bugs` を読むため、必ず手順11の後に実行する。

手順11 が成功すると `gen_test_excel.py` が `completed_at` / `excel_path` を state に記録する。
`completed_at` が無いまま `end-session` を打つと拒否される（手順11 を飛ばして工程を畳めないようにする関所）。
Stop フック `scripts/hooks/require_test_loop_completion.py` も同じ `completed_at` を解除条件にしている。

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
| 仕様漏れ | 黄 | 仕様書がある対象で、テストの無い仕様 ID・境界値のテスト不足 |

仕様書がある対象は、別シート「仕様との対応」に、仕様 ID ごとのテスト件数と OK / NG が載る。

---

## 全体フロー図

```
1. 範囲宣言（部分依頼のときだけ）
  ↓
[Tier1] file1(2〜7) → file2(2〜7) → ...
[Tier2] file1(2〜7) → file2(2〜7) → ...
[Tier3] file1(2〜7) → file2(2〜7) → ...
[Tier4] file1(2〜7) → file2(2〜7) → ...
  ↓ 全ファイル done / skipped
8. 回帰確認 → 9. 規約レビュー → 10. 自己監査 → 11. Excel生成 → 12. セッション破棄
  ↓
完了報告
```

## 呼び出し方

- `/test-loop` で起動し、Excel 生成まで1回で通して回す

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
| `test/coverage_exclusions.txt` | ループ手順6／各エージェント | ファイル丸ごとテスト対象外にする場合の登録簿。`<lib/ からのパス> \| <理由>` 形式 |

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

### 最終成果物（仕上げ工程・手順11）

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

全Tier完了後、手順11で1回だけ:
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
