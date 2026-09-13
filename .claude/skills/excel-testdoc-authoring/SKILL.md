---
name: excel-testdoc-authoring
description: WordStockのテスト項目書MD（test/test_cases/**/*_test_cases.md）のフォーマット規約と、scripts/gen_test_excel.pyでExcel（デスクトップ）に変換する手順。テスト項目書を書く/直すとき、またはExcel項目書を生成するときに参照する。
---

# テスト項目書 MD → Excel（WordStock）

テストコードと**ペア**で作る項目書 MD のフォーマットと、Excel 変換手順。
`scripts/gen_test_excel.py` はこの規約に依存してパースするので、**構造を崩さないこと**。

正となる実例: `test/test_cases/infrastructure/repositories/folder_repository_impl_test_cases.md`

## 置き場所

`test/test_cases/[lib からの対象パス]_test_cases.md`

- `lib/infrastructure/repositories/word_repository_impl.dart`
  → `test/test_cases/infrastructure/repositories/word_repository_impl_test_cases.md`
- Widget（Page）: `test/test_cases/presentation/[ページ名]/[ページ名]_page_test_cases.md`
  → ファイル名が `_page_test_cases.md` で終わると Excel の「Widgetテスト」シートに分類される。それ以外は「単体テスト」

## 必須セクション

### 1. `## 対象クラス / メソッド`（縦持ち表）

```markdown
## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/word_repository_impl.dart |
| クラス名 | WordRepositoryImpl |
| テスト対象メソッド | createWord() / updateWord() / deleteWord() |
```

- `ファイルパス` 行は **必須**（Excel の「対象ファイル」列 & カバレッジ突き合わせキー）。`lib/...` 形式で書く
- Page の項目書では対象 Page の `lib/presentation/.../xxx_page.dart` を入れる

### 2. `## テストケース一覧`（マトリクス表）

```markdown
## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 有効な単語を作成した場合、Right が返りローカルとリモートに保存される | 正常系 | createWord() | ✅ |
| 2 | オフライン時に作成した場合、sync_queue に insert が登録される | 正常系 | createWord() | ✅ |
| 3 | Firestore が unavailable の場合、Failure.network が返る | 異常系 | createWord() | ✅ |
| 4 | front が空文字の場合の扱い | 境界値 | createWord() | ✅ |
```

- 列は固定: `# / テスト名 / カテゴリ / 対象メソッド / 状態`
- **カテゴリは「正常系 / 異常系 / 境界値」に統一**（「エッジケース」も可だが「境界値」推奨）
- Widget 項目書では「対象メソッド」列に検証項目（例: `スピナー表示`）を書いてよい

### 3. `## テストケース詳細`

ケースごとに、**事前条件 / 入力値・テスト条件 / 操作手順 / 期待結果** の4項目を書く
（Excel の「単体テスト項目書」「Widgetテスト項目書」シートの列に対応する）:

```markdown
### テストケース1: 有効な単語を作成した場合、Right が返りローカルとリモートに保存される
- **カテゴリ**: 正常系
- **対象メソッド**: createWord()
- **事前条件**: オンライン状態。フォルダ`root`が作成済み
- **入力値・テスト条件**: front='apple', back='りんご'
- **操作手順**: `createWord(front: 'apple', back: 'りんご', folderId: 'root')` を呼ぶ
- **期待結果**: Right(word)。ローカル DB に1件、fakeRemote.writtenWords に1件
```

- 旧フィールド名（`入力条件` → 入力値・テスト条件 / `期待値` → 期待結果）が書かれた既存 MD も
  `gen_test_excel.py` 側でフォールバック解釈されるが、**新規作成時は必ず新フィールド名（4項目）を使う**
- `事前条件` `操作手順` を省略した場合、Excel では該当列が空欄になる（パースエラーにはならない）

### 4. `## 対象外`（任意だが推奨）

**テスト済みファイル内の**カバレッジを埋めなかった行の理由を残す。Excel の「対象外一覧」シートに集約される。
ファイルをまるごと単体テスト対象外にする場合は MD ではなく `test/coverage_exclusions.txt` に
`<lib/ からのパス> | <理由>`（こちらも「対象外一覧」シートに集約される）。

```markdown
## 対象外

- L142-145：_mapException の default 分岐。到達不能（Firestore は必ず code を持つ）
- L88：toString() オーバーライド。Freezed 生成物のためテスト不要
```

書式は `- 項目：理由`（全角コロン）または `- 項目 - 理由`。

**項目には未カバー行の行番号を必ず書く。** `scripts/loop_state.py` が行番号を lcov の未カバー行と
照合し、「全ての未カバー行に理由が付いているか」を機械判定してループの継続/終了を決めるため。

| 記法 | 例 |
|------|-----|
| 単一行 | `L88` / `88行` / `lib/foo.dart:88` |
| 範囲 | `L142-145` / `L142〜L145` / `142-145行` |
| 複数 | `L10, L12` |

行番号が無いと照合できないため、Excel の「要確認一覧」に **対象外に行番号なし**（黄）として載る。
既存の行番号なし項目書も当面は「理由あり」として扱われる（段階移行）が、順次書き直すこと。

対象ファイルのカバレッジが 90% 未満のとき、`gen_test_excel.py` はこの節を見て「要確認一覧」シートの区分を決める。

- 理由付きの行がある → 「90%未満（理由あり）」（黄）
- 行が無い / 理由が空 / 理由に `判断保留` を含む → 「理由なし未達」（赤字）

サブエージェントが内部リトライ上限で打ち切った行は `- 項目：判断保留（内部リトライ上限到達、要判断）` と書く。
`判断保留` は理由として扱われないので、メインが確定させない限り赤字で残る。

## Excel 生成手順

```bash
# 初回のみ
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install -r scripts/requirements.txt

# 最新のハーネス結果を反映したい場合は先に（終了コードが非 0 でも Excel 生成は続けてよい）
bash scripts/test_harness.sh

# 生成（~/Desktop/WordStock_テスト項目書_YYYYMMDD.xlsx）
scripts/.venv/bin/python3 scripts/gen_test_excel.py
# 出力先変更: --out <path>  /  MD 位置変更: --cases-dir <dir>

# 今回の依頼対象ファイルだけに限定する場合（既存の他ファイル分の項目書を混ぜない）
scripts/.venv/bin/python3 scripts/gen_test_excel.py --only word_list_view_model.dart
# 複数指定も可: --only word_list_view_model.dart folder_repository_impl.dart
```

**依頼が特定ファイル（群）に限定されている場合は必ず `--only` を使う**。
`test/test_cases/` には過去のセッションで作った他ファイル分の項目書 MD が残っているため、
`--only` を付けずに実行すると依頼範囲外のファイルまで Excel に混入する。
「全部まとめて」「全対象で」等、明示的に全件集約を求められた場合のみ `--only` を省略する。

生成物のシート（左から7シート）:

| シート | 内容 |
|--------|------|
| 表紙 | タイトル・基本情報・実施状況サマリ（単体テスト項目書 + Widgetテスト項目書 を合算した自動集計数式） |
| 記載要領・観点一覧 | 各列の意味、観点分類（正常系/異常系/境界値）の考え方 |
| サマリ | 対象ファイル × テスト総数 × 正常系/異常系/境界·エッジ 内訳 × カバレッジ（90% 未満は赤字）× 項目書パス。冒頭にハーネス結果・限定分母カバレッジ・要確認の区分別件数 |
| 要確認一覧 | テスト工程で解消しきれなかった問題。赤字: 理由なし未達 / プロダクションコードのバグ（`.test_loop/state.json` の `production_bugs`）/ テスト失敗 / テスト漏れ、黄: 90%未満（理由あり） / 対象外に行番号なし |
| 単体テスト項目書 | `test()` 系の全ケース（1テストケース=1行。No/テストID/大分類/中分類/観点分類/テスト観点/事前条件/入力値・テスト条件/操作手順/期待結果/実施日/実施者/結果/備考。「結果」「実施日」「実施者」はMDの「状態」列（✅=ハーネスでテスト到達）から自動設定） |
| Widgetテスト項目書 | `testWidgets()` 系の全ケース（列構成は単体テスト項目書と同じ、テストIDは `WT-` 接頭辞） |
| 対象外一覧 | `test/coverage_exclusions.txt` + 各 MD の `## 対象外`（`区分` 列で識別） |

出力フォーマットは `/Users/a12345/Desktop/chousa/generate_test_item_template.py` の表紙／記載要領・観点一覧／
テスト項目書シートのレイアウトに統一している（スタイル・列構成を `scripts/gen_test_excel.py` に移植済み）。

## よくある不備

- 一覧表のヘッダに「テスト名」が無い → パースできず 0 件になる
- `| 項目 | 値 |` 表に `ファイルパス` 行が無い → 対象ファイルが MD の相対パスになる
- カテゴリ表記ゆれ（「正常」「OK」「Success」等）→ サマリの内訳がずれる。「正常系/異常系/境界値」で統一
- `## テストケース詳細` に事前条件・操作手順が無い → Excel の該当列は空欄になるだけでエラーにはならないが、
  新規作成時は極力4項目とも埋めること
