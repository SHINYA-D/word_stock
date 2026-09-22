---
name: test-loop
description: WordStockの単体テスト/Widgetテスト自動生成を「計画→生成→ハーネス実行→分析→再生成」で基準達成まで反復し、最後に網羅性・必要性レビューとExcel項目書生成まで行うループ手順。「テスト生成を回して」「単体テストを自動生成して」等の依頼で使う。
---

# テスト自動生成ループ（WordStock）

ハーネス（`scripts/test_harness.sh`）の結果を各テストエージェントに差し戻し、
対象ファイルごとにカバレッジ 90%+ かつ green になるまで反復する。CLAUDE.md「## テスト方針」が最優先。

**大原則: テスト工程は必ず最後（手順10 Excel 生成）までやり切る。**
解消しきれなかった問題（90% 未満・テスト失敗・テスト漏れ・プロダクションコードのバグ）は
途中で止めずに記録し、Excel の「要確認一覧」シートで報告する。

**大原則: 承認済みの詳細設計書（仕様書）がある対象は、仕様書を期待値の正とする。**
コードを読んで期待値を作らない（バグがそのまま正解になり、テストがバグを検出できなくなるため）。
仕様書どおりの期待値でテストが落ちたら、それはプロダクションコードのバグであり、期待値をコードに合わせない。

## 詳細設計書（仕様書）との関係

仕様書の書き方・ID の意味は `.claude/skills/spec-authoring/SKILL.md` が正。ここではテスト工程での使い方だけを定める。

### 仕様書の見つけ方

`scripts/loop_state.py` の `find_spec_for()` と同じ規則で探す。
項目書 MD に `| 仕様書 |` 行があればその仕様書、無ければ `docs/detailed_design/**/*.md` のうち、frontmatter が次の両方を満たすもの:

- `status: approved`（`draft` の仕様書は期待値の根拠にしない）
- `targets` に対象ファイル、または対象ファイルを含むディレクトリが載っている

```bash
grep -rl "^status: approved" docs/detailed_design | xargs grep -l "<対象ファイルのパス or ディレクトリ>"
```

仕様書が見つからない対象は、従来どおりの方式（コードを読んでテストを設計する）で進める。

### 章ごとのテストの振り分け

| 仕様書の章（ID の種別） | テスト | エージェント | 対象ファイル |
|------------------------|--------|-------------|-------------|
| 3章 画面仕様（D / C / U / X / E と `kinds` の追加種別） | Widget テスト | test-widget-test-generator | `targets` の `*_page.dart` |
| 4章 状態管理仕様（V） | ViewModel 単体テスト | test-unit-test-generator | `targets` の `*_view_model.dart` |
| 5章 リポジトリ契約（R） | Repository 単体テスト | test-unit-test-generator | Repository の実装ファイル（実装が `mock/` だけなら Mock。下記） |
| 6章 ユースケース（項目があるときだけ） | UseCase 単体テスト | test-unit-test-generator | `lib/application/use_cases/...` |
| 2.2 入力ルール（N） | 「守る層」列の層のテスト（画面 → Widget、ViewModel → ViewModel 単体 …）。境界値1つにつき1件 | 守る層に対応するエージェント | 守る層のファイル |

- 各エージェントには、担当する章の ID だけを渡す。`廃止` の ID は渡さない
- 仕様書の各 ID は1件以上のテストケースから引用されなければならない（仕様 ID の網羅。行カバレッジとは別の基準）。
  2.2 の ID は**境界値1つにつき1件**のテストケースが必要（境界値の数は仕様書の「境界値」列の値の数）
- **Repository の実装が `mock/` にしか無い場合**は、その Mock を5章の対象にする
  （例: 仕様書 SMP の `lib/infrastructure/repositories/mock/mock_sample_repository.dart`）。
  テストは `test/infrastructure/repositories/mock/<名前>_test.dart`、項目書には `| 仕様書 |` 行を必ず入れる
  （Mock は仕様書の `targets` に載らないため、この行で仕様書を見つける）。
  `mock/` は限定分母の外なので、カバレッジは判定に使わず green だけで判定される

### 仕様 ID の網羅チェック（自動・警告のみ）

ハーネスは対象の項目書 MD の `仕様ID` 列を仕様書と突き合わせ、結果を `harness_report.json` の `spec` に書く。
漏れがあれば `loop.warnings` に「仕様漏れ …」が出る（**verdict には影響しない**。Excel の「要確認一覧」に黄で載る）。

| `spec` の項目 | 意味 |
|--------------|------|
| `required` | この対象が担当する仕様 ID（章ごとの振り分けどおり。廃止を除く） |
| `missing` | どのテストケースからも引用されていない ID |
| `boundary_short` | 2.2 の ID で、テストケースが境界値の数より少ないもの（`have` / `need`） |

## 対象一覧（Tier 順に消化）

| Tier | 対象 | エージェント |
|------|------|-------------|
| 1 | `lib/infrastructure/sync/sync_service.dart` | test-unit-test-generator |
| 1 | `lib/infrastructure/sync/auto_sync_service.dart` | test-unit-test-generator |
| 1 | `lib/infrastructure/repositories/{word,settings,auth,flashcard_result}_repository_impl.dart` | test-unit-test-generator |
| 1 | `lib/infrastructure/repositories/mock/mock_sample_repository.dart`（仕様書 SMP の5章。実装が `mock/` だけの Repository） | test-unit-test-generator |
| 2 | `lib/presentation/**/*_view_model.dart`（flashcard_mode, home, word_list, login, sign_up, password_reset, result, settings, sample） | test-unit-test-generator |
| 2 | `lib/application/use_cases/**`（18、軽量） | test-unit-test-generator |
| 3 | `lib/domain/entities/**`（独自ロジックがある場合のみ） | test-unit-test-generator |
| 3 | `lib/core/utils/folder_name_validator.dart` | test-unit-test-generator |
| 4 | 未カバー / 手薄な `lib/presentation/**/*_page.dart` | test-widget-test-generator |

### 対象ファイルの正は `harness_report.py`
Tier 一覧は消化順の目安。テストがあるべきファイルの正式な定義は `scripts/harness_report.py`
の `is_target()`。`bash scripts/test_harness.sh`（全体）が `harness_report.json` の
`coverage.untested_files`（テストも対象外登録も無い対象ファイル）を非 0 で落とす。
個別ループの目標は「対象ファイル 90%+ かつ green」。全体カバレッジはハーネスの合否に使わない
（⚠ 表示のみ。未カバー行の正当な理由は項目書 MD にあり、スクリプトは計算に反映できないため）。

ファイルをまるごと単体テスト対象外にする場合は `test/coverage_exclusions.txt` に
`<lib/ からのパス> | <理由>` を追記する（項目書 MD の `## 対象外` は "テスト済みファイル内の
未カバー行" の理由に使う、という粒度の違い）。`lib/core/app_lifecycle_observer.dart` も
これに該当。

## 進捗管理

進捗とループ回数は `scripts/loop_state.py` が `.test_loop/state.json` に管理する。
**JSON を直接編集しない。回数を自分で数えない。** 必ずコマンド経由で操作する。

```bash
python3 scripts/loop_state.py start-session --scope <lib パス...>  # 部分依頼のとき範囲を宣言
python3 scripts/loop_state.py scope <lib パス...>        # 途中で範囲を設定（引数なしで全対象）
python3 scripts/loop_state.py begin-attempt <lib パス>   # 外部ループ1周（内部カウンタはリセット）
python3 scripts/loop_state.py finish <lib パス> --status done
python3 scripts/loop_state.py finish <lib パス> --status skipped --reason "プロダクションコードのバグ"
python3 scripts/loop_state.py bug --path lib/... --line 42 --symptom "症状" \
        --evidence "失敗したテスト名" --recommendation "推奨対応"
python3 scripts/loop_state.py show                       # 現在の状態を確認
python3 scripts/loop_state.py end-session                # セッション破棄（手順10の後のみ通る）
```

TodoWrite でも Tier 一覧を可視化する。

### ステートの寿命

`.test_loop/state.json` は**ユーザーの1依頼＝1セッション**のスコープで、手順10の後に
`end-session` で破棄する。破棄し忘れても 24 時間で自動的に破棄される（`LOOP_SESSION_TTL_HOURS`）。
寿命を超えて `done` が残らないので、実装変更後に古い `done` でスキップされる事故が起きない。

### 上限回数はハーネスが管理する

| ループ | 上限 | カウントされる契機 |
|--------|------|------------------|
| 外部（サブエージェントの再起動） | 3回 | `begin-attempt` を叩いたとき |
| 内部（1起動内でのハーネス再実行） | 3回 | `test_harness.sh` が実行されたとき（自動） |

内部カウントはハーネス実行に紐づくため、エージェントが申告する必要も、回避する余地もない。

上限は `continue` が続く（＝回しすぎる）のを止めるためのもので、判定が `continue` のときにだけ効く。
目標に達した `stop`（記録済みのバグで説明できる失敗だけが残っている場合を含む）は、カウンタが上限を
超えていても「上限に到達」で上書きされず、本当の理由がそのまま出る。上限で打ち切ったときは、
未達の理由が `loop.warnings` の「未達のまま打ち切り: …」に残る。

カウントされるのは test-loop のセッション中（`start-session` / `begin-attempt` の後）だけ。
セッションが無いときにハーネスを回しても（動作確認など）、ステートは作られず、Stop フックも動かない。

`production_bugs` は `scripts/gen_test_excel.py` が読み、Excel の「要確認一覧」シートに載せる。

## 1 対象あたりのループ

0. **範囲宣言（部分依頼のときだけ）**: ユーザーが特定のファイルだけを依頼した場合、
   最初に対象範囲を宣言する。宣言しないと Stop フックが全対象の消化を要求する。
   ```bash
   python3 scripts/loop_state.py start-session --scope lib/a.dart lib/b.dart
   ```
   全体依頼（Tier 1〜4 をすべて回す）なら不要。途中で気づいた場合は
   `python3 scripts/loop_state.py scope <lib パス...>`（引数なしで全対象に戻る）
1. **計画**: `loop_state.py show` の `done` に無い最上位 Tier の対象を1つ選ぶ
   - 「仕様書の見つけ方」で、その対象の承認済み仕様書を探す。見つかったら「章ごとのテストの振り分け」で、
     この対象が担当する仕様 ID の一覧を作る
2. **生成**: 対応エージェントを Agent ツールで起動（プロンプトに対象ファイルパス1つを渡す）
   - 仕様書がある場合は、プロンプトに**仕様書のパス**と**担当する仕様 ID の一覧**も渡し、
     「期待値は仕様書から作り、コードは呼び出し方を知るためだけに読む」と明記する
   - **起動の直前に** `python3 scripts/loop_state.py begin-attempt <lib パス>` を叩く
     （これが外部ループのカウント。叩かないと外部上限が効かない）
3. **実行**:
   ```bash
   bash scripts/test_harness.sh <生成テストファイルパス>
   ```
   `coverage/harness_report.json` を読む
4. **分析** — まず `loop.verdict` を読む。**継続するかどうかはここで決まっている**:
   | `loop.verdict` | 対応 |
   |---------------|------|
   | `continue` | `loop.reason` の不足を解消して 2〜4 を繰り返す |
   | `stop` | 手順5へ進む。`reason` が「内部上限」「外部上限」なら未達のまま次の対象へ |
   | `n/a` | 全体実行または対象を特定できないとき。個別ループでは出ない |

   **仕様書がある対象では、分類の前に** `loop.warnings` の「仕様漏れ」（= `harness_report.json` の `spec`）を見る。
   漏れていたら、その ID のテスト追加を同エージェントに差し戻す（バグを見つけていても、全 ID のテストが揃うまでは次の対象へ進まない）。

   その上で `tests.failures` と `coverage.files[].uncovered_lines` を分類:
   | 分類 | 対応 |
   |------|------|
   | **仕様書どおりの期待値で落ちた**（仕様書がある対象） | プロダクションコードのバグとして扱う。**期待値をコードに合わせて直さない**。原因ごとに `loop_state.py bug` で記録し、`--symptom` の**先頭に、そのバグで落ちるテストの仕様 ID をすべて書く**（例: `SMP-V17〜V19, SMP-V22: 失敗すると一覧が消える`。範囲は `〜` で書いてよい）。`--evidence` は失敗したテスト名。記録してからハーネスを再実行すると、記録済みのバグの仕様 ID で説明できる失敗は verdict から除外され、残りが無ければ `stop` になる（上限まで回し続けない）。その後 `finish --status skipped --reason "プロダクションコードのバグ"` |
   | 期待値が仕様書と食い違っている（仕様書がある対象） | テストコードのバグ。仕様書の該当 ID を添えて同エージェントに差し戻す |
   | 仕様書が曖昧・矛盾していて期待値を決められない | 仕様書もテストも直さない。その ID と論点を最終報告の「仕様書の不備」に書く（仕様書の改訂は spec-authoring で行う） |
   | 仕様書のすべての ID をテストしても残る未カバー行（仕様書にない振る舞いのコード） | コードから期待値を作ってテストを足さない。項目書 `## 対象外` に `- L142-145：仕様書に記載なし（仕様書への追記候補）` と記録し、最終報告の「仕様書の不備」にも書く |
   | テストコードのバグ（Fake 設定ミス・期待値誤り） | 同エージェントに `harness_report.json` の該当部を添えて差し戻し |
   | プロダクションコードのバグ | **プロダクションコードは修正しない**。`loop_state.py bug` で記録し、`finish --status skipped --reason "プロダクションコードのバグ"` にして**次の対象へ進む**。バグを示すテストは削除せず残す（既存 folder_repository のデッドロック例あり） |
   | エージェントが返した「判断保留」の未カバー行 | メインが「テストすべき → テスト追加を差し戻し」か「無価値 → 行番号付きの理由を `## 対象外` に確定」かを決める。決めきれないまま上限に達した行は判断保留のまま残り、Excel では「理由なし未達」になる |
   | 未カバー行がテスト価値のある分岐 | 同エージェントに「この分岐のテスト追加」を差し戻し |
   | 未カバー行が無価値（到達不能・防御・ログ） | エージェントに項目書 `## 対象外` へ `- L142-145：理由` の形式で記録させる。**行番号が無いとハーネスが照合できず、`verdict` が `continue` に倒れ続ける** |
   | 対象ファイルがまるごと未テスト（`untested_files` に出る） | テストを生成する。真に不要なら `test/coverage_exclusions.txt` に理由付きで登録 |
   | `stale_exclusions` に出る | 不要になった `coverage_exclusions.txt` の行を削除（警告のみ・CI は落ちない） |
5. **反復**: `loop.verdict` が `stop` になるまで 2〜4 を繰り返す
   - **上限との比較はハーネスが行う。自分で回数を数えない**
   - 内部上限（3回）で止まったら、同じ対象で手順2からやり直す（＝外部ループが1周進む）。
     バグを記録した直後の再実行は、内部カウンタが上限を超えていても、記録済みのバグで説明できれば
     `stop` になる（外部ループを余分に回す必要はない）
   - 外部上限（3回）で止まったら未達のまま次の対象へ（止めずに進む。未達分は Excel の「要確認一覧」に載る）
6. **記録**: `loop_state.py finish <lib パス> --status done`（or `--status skipped --reason ...`）

## 全 Tier 消化後：レビュー工程

7. **回帰確認**: `bash scripts/test_harness.sh`（引数なし＝全体、テスト漏れゲート適用）を**1回だけ**実行し、
   `harness_report.json` を最新化する。
   - **ここでは再実行・差し戻し・個別ループへの巻き戻しを一切しない。** 終了コードが非 0 でも手順8へ進む
   - 例外: 手順8・9の指摘でテストコード（`test/**/*_test.dart`）を変更した場合だけ、手順10の直前に
     全体ハーネスを**もう1回だけ**実行し、`harness_report.json` を最新にする（Excel が古い結果を読まないようにするため）。
     このときも差し戻し・ループへの巻き戻しはしない。項目書 MD だけの変更なら再実行しない
   - 全体実行では `loop.verdict` は `n/a`（判定しない）。ここでループを回し直さない
   - 次の問題は `scripts/gen_test_excel.py` が `harness_report.json` / `.test_loop/state.json` / 項目書 MD から
     自動で拾い、Excel の「要確認一覧」シートに載せる。メインが個別に転記する必要はない
     | 問題 | 要確認一覧の区分 |
     |------|----------------|
     | 90% 未満で、項目書の `## 対象外` に理由がある | 90%未満（理由あり）※黄 |
     | 90% 未満で、理由に行番号が無い | 対象外に行番号なし ※黄 |
     | 90% 未満で、理由が無い / 判断保留のまま / 項目書が無い | **理由なし未達**（赤字） |
     | テスト失敗（`tests.failures`） | **テスト失敗**（赤字） |
     | `coverage.untested_files` | **テスト漏れ**（赤字） |
     | `.test_loop/state.json` の `production_bugs` | **プロダクションコードのバグ**（赤字）。仕様 ID で結び付いたテスト失敗は「関連」列に件数が出る |
     | 仕様書のある対象で、テストの無い仕様 ID・境界値のテスト不足 | 仕様漏れ ※黄 |
   - ⑦で新たにプロダクションコードのバグと判断したものがあれば、`loop_state.py bug` で追記だけする
   - `stale_exclusions` に出た行は `coverage_exclusions.txt` から削除してよい（警告のみ）
8. **規約レビュー**: `architecture-guard` エージェントを起動し、生成テストコードの規約違反を確認
9. **網羅性・必要性の自己監査**（各項目書 MD と対応テストに対して）:
   - [ ] 正常系・異常系・境界値が揃っているか（どれかゼロなら理由が妥当か）
   - [ ] 同じ振る舞いを検証する重複テストがないか
   - [ ] 無価値テスト（コンストラクタのみ / Freezed 生成物 / 単純委譲の過剰検証）が紛れていないか
   - [ ] `## 対象外` の理由が「本当にテスト不要」か（サボりの言い訳になっていないか）
         ※ 行番号との照合はハーネスが済ませている。ここで見るのは**理由の質**
   - [ ] Widget テストがロジック網羅に踏み込んで ViewModel 単体テストと二重化していないか
   - [ ] （仕様書がある対象）Excel の「仕様との対応」シートに「未テスト」・境界値不足（黄）の行が無いか
   - [ ] （仕様書がある対象）仕様 ID を引用しているテストが、その ID の条件と期待される動作を**すべて**確かめているか
         （ID の引用はハーネスが確かめるが、中身の一部しかテストしていない漏れは機械では分からない）
   - [ ] （仕様書がある対象）期待結果が、引用した仕様 ID の「期待される動作」と一致しているか（コードの動作に寄せていないか）
   - [ ] （仕様書がある対象）`仕様ID` が空のケースが、仕様書にない振る舞いをコードから推測してテストしていないか
   - 指摘は該当エージェントに差し戻して修正
   - 手順8・9の修正でテストコードを変更したら、手順10の前に全体ハーネスをもう1回だけ実行する（手順7の例外）
10. **Excel 生成**: `test-doc-excel-generator` エージェントを起動
    → `~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx`
    - 手順7〜9で問題が残っていても**必ず実行する**（問題は「要確認一覧」シートに載る）
    - 起動プロンプトには**今回のループで実際に対象にしたファイル一覧**（`done` + `skipped` のキー）を
      明記して渡す。全Tier消化後の実行であれば「全対象」と明示してよい
    - ユーザーから1ファイル（または一部）のみを対象に依頼された場合は、その対象ファイルのみを
      一覧として渡す（`test/test_cases/` に残っている他ファイル分の既存項目書は Excel に含めない）
11. **セッション破棄**: `python3 scripts/loop_state.py end-session`
    - Excel 生成が終わってから実行する（`production_bugs` を Excel が読むため）
    - 手順10 が成功していないと**拒否される**（`completed_at` が立っていないため）。
      先に手順10 をやり切ること。緊急脱出が必要なときだけ `--force`
    - 忘れても 24 時間で自動破棄されるが、明示的に消すのが正

## 最終報告フォーマット

```
## テスト自動生成 完了報告
### 生成ファイル
- 単体テスト: N ファイル / M ケース
- Widgetテスト: N ファイル / M ケース
- 項目書 MD: N ファイル
### カバレッジ（限定分母）
- 全体: X%（参考値。合否には使わない）
### 要確認（Excel「要確認一覧」シートと同じ内容）
- 理由なし未達: N 件 … path（X%）
- プロダクションコードのバグ: N 件 … path:line 症状 / 推奨対応（コードは変更していない）
- テスト失敗: N 件 … テスト名
- テスト漏れ: N 件 … path
- 90%未満（理由あり）: N 件 … path（X%）: 理由
- 対象外に行番号なし: N 件 … path（項目書の `## 対象外` を行番号付きに直す必要がある）
### 仕様書との対応（仕様書がある対象のみ）
- 仕様書: docs/detailed_design/...md … 仕様 ID N 件中 M 件をテスト済み（未引用の ID: ...）
- 仕様どおりの期待値で落ちたテスト: N 件 … 仕様 ID / テスト名
### 仕様書の不備
- 仕様 ID or path:line … 曖昧・矛盾・記載なしの内容（仕様書の改訂候補）
### 対象外にしたファイル / 行
- path: 理由
### レビュー指摘と対応
- （architecture-guard / 自己監査の指摘と対応）
### Excel
- ~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx
```

要確認が 0 件でない場合も「完了報告」として出す（工程は最後までやり切った、という扱い）。
赤字区分（理由なし未達 / プロダクションコードのバグ / テスト失敗 / テスト漏れ）が 1 件でもあれば、
報告の冒頭で件数を明示する。

## やり切りは Stop フックが強制する

`/goal`（Haiku が会話を読んで完了判定）は使わない。
判定器は `loop_state.compute_verdict()` として既にあり、外部の評価モデルより正確なため。

代わりに `scripts/hooks/require_test_loop_completion.py`（`Stop` フック）が、
**ターンを終えようとする瞬間**に `compute_verdict()` を呼び、工程が残っていれば終了を拒否する。

| 状態 | フックの挙動 |
|------|-------------|
| `.test_loop/state.json` が無い | 通す（テスト工程ではない） |
| `completed_at` が立っている | 通す（Excel 生成済み＝工程完了） |
| 進行中の対象の `verdict` が `continue` | 拒否。`reason` を次ターンの指示として返す |
| `verdict` が `stop` なのに `finish` 未実行 | 拒否。手順6を促す |
| 未消化の対象が残っている | 拒否。手順1へ戻す |
| 全対象 done / skipped だが `completed_at` 無し | 拒否。手順7〜11 を促す |

### 出口は `completed_at` ただ1つ

`completed_at` は `gen_test_excel.py` が **Excel の保存に成功した直後にのみ**
`loop_state.mark_completed()` で記録する（`record_run()` と同じ「成果物を作った本人が
記録する」方式）。したがって関所を解除する手段は手順10 の完走しかない。

- `.test_loop/` への Edit/Write は `block_generated_file_edit.sh` が拒否する（捏造不可）
- `completed_at` が無いまま `end-session` を打っても拒否される（近道の封鎖）
- 緊急脱出は `end-session --force`（警告が出る。通常は使わない）

SKILL.md 冒頭の「大原則」はこの経路で機構化されている。

無限ループ対策: ハーネスを回さず押し戻されただけ（＝進捗なし）が 3 回続くと関所を解除して
制御を返す（`TEST_LOOP_NO_PROGRESS_MAX`）。セッション通算 60 回でも解除（`TEST_LOOP_TOTAL_MAX`）。
上限（内部3/外部3）に達すると `compute_verdict()` は `continue` を必ず `stop` に変えるため、
カウンタ経由の暴走は起きない。一時的に無効化するなら `TEST_LOOP_STOP_GATE=0`。

ステートは**セッション（＝ユーザーの1依頼）を超えて残さない**。手順11の `end-session` で破棄すること
（忘れても 24 時間の TTL で破棄され、同時にフックも解除される）。
