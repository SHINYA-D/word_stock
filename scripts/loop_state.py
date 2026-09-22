#!/usr/bin/env python3
"""test-loop のセッションステート管理 + ループ継続判定（verdict）。

## 役割

test-loop の二重ループ（外部＝サブエージェント再起動／内部＝1起動内での再試行）の
**カウントと継続判断をスクリプト側に持たせる**ためのモジュール兼 CLI。
LLM は回数を数えず、`harness_report.json` の `loop.verdict` に従うだけでよい。

## カウントの流れ

    メイン        : loop_state.py begin-attempt <lib path>   → outer++ / inner=0
    サブエージェント: bash scripts/test_harness.sh <test path>
                     └ harness_report.py が内部で record_run() → compute_verdict()
                       → harness_report.json の "loop" に結果を書き込む

テスト結果を得るにはハーネスを通すしかないため、内部カウントは回避できない。

## ステートの寿命

`.test_loop/state.json`（repo root）。ユーザーの1依頼＝1セッションの想定で、

1. `end-session` で明示的に破棄（Excel 生成後）
2. `created_at` から LOOP_SESSION_TTL_HOURS（既定 24h）経過していたら次アクセス時に自動破棄

の二重で寿命を区切る。寿命を超えて `done` が残らないので、実装変更後に
古い `done` でスキップされる（stale）問題が構造的に起きない。

観測データ（lcov / test_machine.jsonl / harness_report.json）は従来どおり
`coverage/` に置き、消えては困る進捗ステートとはディレクトリを分けている。

## 環境変数

    LOOP_INNER_MAX           内部ループ上限（既定 3）
    LOOP_OUTER_MAX           外部ループ上限（既定 3）
    LOOP_SESSION_TTL_HOURS   セッションの自動破棄時間（既定 24）
    LOOP_STATE_PATH          ステートファイルのパス（既定 .test_loop/state.json）
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

INNER_MAX = int(os.environ.get("LOOP_INNER_MAX", "3"))
OUTER_MAX = int(os.environ.get("LOOP_OUTER_MAX", "3"))
TTL_HOURS = float(os.environ.get("LOOP_SESSION_TTL_HOURS", "24"))
STATE_PATH = os.environ.get(
    "LOOP_STATE_PATH", os.path.join(REPO, ".test_loop", "state.json")
)

# 旧パス（coverage/ 同居時代）。読み込みのみ後方互換で見る。
LEGACY_STATE_PATH = os.path.join(REPO, "coverage", "test_loop_state.json")

TEST_CASES_DIR = os.path.join(REPO, "test", "test_cases")

# サブエージェントが内部リトライ上限で打ち切った未カバー行に付ける目印。
# 理由が確定していないので「理由あり」とは扱わない（gen_test_excel.py と共有）。
PENDING_MARK = "判断保留"

_NO_LINE_WARNING = "項目書の「## 対象外」に行番号が書かれていない（段階移行中）"


# --------------------------------------------------------------------------- #
# ステートの読み書き
# --------------------------------------------------------------------------- #
def _now() -> datetime:
    return datetime.now(timezone.utc)


def _new_state() -> dict:
    now = _now()
    return {
        "session_id": now.strftime("%Y%m%d-%H%M%S"),
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
        "current": None,
        "outer": {},
        "inner": {},
        "done": [],
        "skipped": {},
        "production_bugs": [],
        "completed_at": None,
        "excel_path": None,
        "scope": None,
    }


def _expired(state: dict) -> bool:
    raw = state.get("created_at")
    if not raw:
        return True
    try:
        created = datetime.fromisoformat(raw)
    except ValueError:
        return True
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)
    return _now() - created > timedelta(hours=TTL_HOURS)


def load_state(path: str = STATE_PATH, *, create: bool = True) -> dict:
    """現在のセッションステートを返す。

    TTL を過ぎていれば破棄して新しいセッションを始める（stderr に通知）。
    `create=False` のときは、無ければ空のセッション（未保存）を返すだけで
    ファイルは作らない。
    """
    if not os.path.exists(path) and os.path.exists(LEGACY_STATE_PATH):
        # 旧 coverage/test_loop_state.json からの引き継ぎ（読み込みのみ）
        path = LEGACY_STATE_PATH

    if not os.path.exists(path):
        return _new_state()

    try:
        with open(path, encoding="utf-8") as f:
            state = json.load(f)
    except (json.JSONDecodeError, OSError):
        print(f"⚠ {path} を読めないため新しいセッションを開始します", file=sys.stderr)
        return _new_state()

    if _expired(state):
        print(
            f"⚠ 前回のセッション {state.get('session_id')} は "
            f"{TTL_HOURS:g} 時間を超えたため破棄し、新しいセッションを開始します",
            file=sys.stderr,
        )
        fresh = _new_state()
        if create:
            save_state(fresh)
        return fresh

    # 旧スキーマ（attempts しか無い）からの移行
    state.setdefault("outer", state.pop("attempts", {}) or {})
    state.setdefault("inner", {})
    state.setdefault("done", [])
    state.setdefault("skipped", {})
    state.setdefault("production_bugs", [])
    state.setdefault("current", None)
    state.setdefault("completed_at", None)
    state.setdefault("excel_path", None)
    state.setdefault("scope", None)
    return state


def save_state(state: dict, path: str = STATE_PATH) -> None:
    state["updated_at"] = _now().isoformat()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def clear_state(path: str = STATE_PATH) -> bool:
    removed = False
    for p in (path, LEGACY_STATE_PATH):
        if os.path.exists(p):
            os.remove(p)
            removed = True
    return removed


# --------------------------------------------------------------------------- #
# カウント操作
# --------------------------------------------------------------------------- #
def begin_attempt(target: str, path: str = STATE_PATH) -> dict:
    """外部ループを1周進める（サブエージェント起動の直前にメインが呼ぶ）。

    内部カウンタはここでリセットされる（内部ループは外部試行の内側でのみ意味を持つ）。
    """
    state = load_state(path)
    state["outer"][target] = state["outer"].get(target, 0) + 1
    state["inner"][target] = 0
    state["current"] = target
    save_state(state, path)
    widen_scope(target, path)
    return state


def session_active(path: str = STATE_PATH) -> bool:
    """test-loop のセッションが進行中か（ステートファイルがあり、TTL を過ぎていない）。"""
    if not os.path.exists(path):
        return False
    try:
        with open(path, encoding="utf-8") as f:
            return not _expired(json.load(f))
    except (json.JSONDecodeError, OSError):
        return False


def record_run(target: str, path: str = STATE_PATH) -> dict:
    """ハーネス1実行を内部試行として記録する（harness_report.py が自動で呼ぶ）。

    セッションが無いとき（test-loop の外で動作確認のためにハーネスを回したとき）は
    何も記録せず、ステートファイルも作らない。作ると範囲「全対象」のセッションが
    勝手に始まり、Stop フックが全 Tier の消化を要求してしまうため。
    セッションは start-session / begin-attempt でだけ始まる。
    """
    if not session_active(path):
        return load_state(path, create=False)
    state = load_state(path)
    state["inner"][target] = state["inner"].get(target, 0) + 1
    if not state["outer"].get(target):
        # セッション中に begin-attempt を経ずにハーネスが回った場合も外部1周目として扱う
        state["outer"][target] = 1
    state["current"] = target
    save_state(state, path)
    return state


def finish(target: str, status: str, reason: str = "",
           path: str = STATE_PATH) -> dict:
    state = load_state(path)
    if status == "done":
        if target not in state["done"]:
            state["done"].append(target)
        state["skipped"].pop(target, None)
    else:
        state["skipped"][target] = reason or "理由未記入"
        if target in state["done"]:
            state["done"].remove(target)
    state["inner"][target] = 0
    save_state(state, path)
    return state


def add_bug(bug: dict, path: str = STATE_PATH) -> dict:
    state = load_state(path)
    state["production_bugs"].append(bug)
    save_state(state, path)
    return state


def set_scope(targets: list[str] | None, path: str = STATE_PATH) -> dict:
    """このセッションで扱う対象ファイルを限定する（部分依頼のとき）。

    `None` / 空リスト = 全対象（`harness_report.is_target()` の全件）。
    ユーザーが「この2ファイルだけテストして」と依頼した場合にここへ記録すると、
    Stop フックが「残り48件やれ」と押し戻すのを防げる。

    ユーザーの依頼内容そのものなので機構化はできない（LLM が宣言する）。
    ただし限定した事実は Excel と最終報告に出るため、意図せぬ範囲の絞り込みは
    ユーザーが目視で気づける。
    """
    state = load_state(path)
    state["scope"] = sorted({t.replace("\\", "/") for t in targets}) if targets else None
    save_state(state, path)
    return state


def widen_scope(target: str, path: str = STATE_PATH) -> None:
    """scope 限定中に範囲外の対象へ着手したら、その対象を scope に加える。

    scope と実際の作業がずれて「終われない / 終わりすぎる」のを防ぐ。
    """
    state = load_state(path)
    scope = state.get("scope")
    if scope is None:
        return
    t = target.replace("\\", "/")
    if t not in scope:
        state["scope"] = sorted(set(scope) | {t})
        save_state(state, path)


def mark_completed(excel_path: str, path: str = STATE_PATH) -> dict:
    """Excel 項目書の生成完了を記録する（gen_test_excel.py が保存直後に呼ぶ）。

    `completed_at` が立っているかどうかが「テスト工程をやり切ったか」の唯一の
    機械的な証拠であり、

    * Stop フック（scripts/hooks/require_test_loop_completion.py）の解除条件
    * `end-session` を許可する条件

    の両方がこれを見る。`record_run()` と同じく **成果物を作った本人が記録する**
    のが要点で、`wb.save()` が成功しなければこの関数には到達しない。
    手で書き込む経路は block_generated_file_edit.sh が塞いでいる。
    """
    state = load_state(path)
    state["completed_at"] = _now().isoformat()
    state["excel_path"] = excel_path
    save_state(state, path)
    return state


# --------------------------------------------------------------------------- #
# テストパス → lib 対象の推定
# --------------------------------------------------------------------------- #
def _stem(path: str) -> str:
    """`lib/a/b.dart` / `test/a/b_test.dart` → `b`（対象の突き合わせ用）。"""
    name = os.path.basename(path or "")
    if name.endswith(".dart"):
        name = name[: -len(".dart")]
    if name.endswith("_test"):
        name = name[: -len("_test")]
    return name


def resolve_target(test_paths: list[str], target_files: list[str]) -> str | None:
    """ハーネスに渡されたテストパスから、対象の lib ファイルを1つ推定する。

    限定分母（`is_target`）に入らない Page（Widget テストの対象）も返す。
    Page はカバレッジ判定の対象外だが、ループ回数の管理と green 判定は必要なため。

    テストパスが複数（＝複数対象）のときは特定できないので None を返し、
    verdict は n/a になる（1エージェント1ファイルの運用が前提）。
    """
    dart_paths = [p for p in test_paths if p.endswith(".dart")]
    if len(dart_paths) != 1:
        return None

    p = dart_paths[0].replace("\\", "/")
    i = p.find("test/")
    rel = p[i:] if i != -1 else p

    # 規約どおりのミラー構成（test/x/y_test.dart → lib/x/y.dart）を最優先
    if rel.startswith("test/") and rel.endswith("_test.dart"):
        guess = "lib/" + rel[len("test/"):-len("_test.dart")] + ".dart"
        if guess in target_files or os.path.exists(os.path.join(REPO, guess)):
            return guess

    # ミラーで当たらなければファイル名（stem）で突き合わせる
    stem = _stem(rel)
    hits = [t for t in target_files if _stem(t) == stem]
    if len(hits) == 1:
        return hits[0]

    # 限定分母外（Page 等。lib/presentation/auth/login/login_page.dart のように
    # test/ 側とディレクトリ構造がずれる）は lib/ 全体から探す
    if not hits:
        cwd = os.getcwd()
        try:
            os.chdir(REPO)
            hits = [
                p.replace("\\", "/")
                for p in glob.glob("lib/**/*.dart", recursive=True)
                if _stem(p) == stem and not p.endswith((".freezed.dart", ".g.dart"))
            ]
        finally:
            os.chdir(cwd)
        if len(hits) == 1:
            return hits[0]
    return None


def doc_path_for(target: str) -> str | None:
    """対象 lib ファイルに対応する項目書 MD のパス。無ければ None。"""
    if not target.startswith("lib/"):
        return None
    rel = target[len("lib/"):-len(".dart")] + "_test_cases.md"
    conventional = os.path.join(TEST_CASES_DIR, rel)
    if os.path.exists(conventional):
        return conventional

    hits = glob.glob(
        os.path.join(TEST_CASES_DIR, "**", f"{_stem(target)}_test_cases.md"),
        recursive=True,
    )
    return hits[0] if len(hits) == 1 else None


# --------------------------------------------------------------------------- #
# 「## 対象外」のパースと行番号抽出
# --------------------------------------------------------------------------- #
def parse_offtargets(text: str) -> list[tuple[str, str]]:
    """「対象外」を含む見出し配下の箇条書きを (項目, 理由) で返す。

    gen_test_excel.py と共有する（あちらはここから import する）。
    """
    out: list[tuple[str, str]] = []
    capture = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("#"):
            capture = "対象外" in s
            continue
        if capture and (s.startswith("- ") or s.startswith("* ")):
            body = s[2:].strip()
            if "：" in body:
                item, reason = body.split("：", 1)
            elif " - " in body:
                item, reason = body.split(" - ", 1)
            else:
                item, reason = body, ""
            out.append((item.strip(), reason.strip()))
    return out


_DASH = r"[-–〜~]"
# 「L142-145」「:142-145」形式（2つ目の L は省略可）
_RANGE_PREFIX_RE = re.compile(rf"(?:[Ll]|:)\s*(\d+)\s*{_DASH}\s*(?:[Ll])?\s*(\d+)")
# 「142-145行」形式
_RANGE_SUFFIX_RE = re.compile(rf"(?<!\d)(\d+)\s*{_DASH}\s*(\d+)\s*行")
# 「L88」「foo.dart:42」形式。数字の途中で切れないよう (?!\d)、
# 範囲の一部を単独で拾わないよう後続の区切りも見る
_SINGLE_PREFIX_RE = re.compile(rf"(?:[Ll]|:)\s*(\d+)(?!\d)(?!\s*{_DASH}\s*\d)")
# 「88行」形式
_SINGLE_SUFFIX_RE = re.compile(r"(?<!\d)(\d+)\s*行")
# 項目全体が数字と区切りだけ（例: "42,43" / "142-145"）
_BARE_RE = re.compile(r"^[\d\s,、\-–〜~]+$")


def _add_range(lines: set[int], a: str, b: str) -> None:
    lo, hi = int(a), int(b)
    if lo <= hi and hi - lo < 10000:
        lines.update(range(lo, hi + 1))


def extract_lines(item: str) -> set[int]:
    """対象外項目のラベルから行番号を抽出する。

    受け付ける記法（誤検出を避けるため、行番号だとわかる目印を要求する）:
        L142-145 / L88 / lib/foo.dart:42 / 142-145行 / 88行
        項目全体が数字と区切りだけの場合は "42,43" や "142-145" も可
    """
    lines: set[int] = set()
    if not item:
        return lines

    text = item
    for a, b in _RANGE_PREFIX_RE.findall(text):
        _add_range(lines, a, b)
    for a, b in _RANGE_SUFFIX_RE.findall(text):
        _add_range(lines, a, b)
    for n in _SINGLE_PREFIX_RE.findall(text):
        lines.add(int(n))
    for n in _SINGLE_SUFFIX_RE.findall(text):
        lines.add(int(n))

    if not lines and _BARE_RE.match(text.strip()):
        for a, b in re.findall(rf"(\d+)\s*{_DASH}\s*(\d+)", text):
            _add_range(lines, a, b)
        for n in re.findall(r"\d+", text):
            lines.add(int(n))
    return lines


def reasoned_lines(target: str) -> tuple[set[int], bool, bool]:
    """項目書 MD の「## 対象外」から、理由が付いている行番号を集める。

    戻り値: (行番号の集合, 有効な理由が1件でもあるか, 判断保留が残っているか)
    """
    doc = doc_path_for(target)
    if not doc:
        return set(), False, False
    try:
        with open(doc, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return set(), False, False

    lines: set[int] = set()
    has_reason = False
    has_pending = False
    for item, reason in parse_offtargets(text):
        if PENDING_MARK in reason or PENDING_MARK in item:
            has_pending = True
            continue
        if not reason:
            continue
        has_reason = True
        lines |= extract_lines(item)
    return lines, has_reason, has_pending


# --------------------------------------------------------------------------- #
# 仕様書（詳細設計書）との突き合わせ
# --------------------------------------------------------------------------- #
# 仕様書の書き方は .claude/skills/spec-authoring/SKILL.md、テスト工程での使い方は
# .claude/skills/test-loop/SKILL.md「詳細設計書（仕様書）との関係」が正。
SPEC_DIR = os.path.join(REPO, "docs", "detailed_design")

# `SMP-V17〜V19` / `SMP-V17〜SMP-V19` / `[SMP-D01]` / `SMP-C04, SMP-C06` を拾う
_SPEC_ID_RE = re.compile(
    r"([A-Z]{3})-([A-Z])(\d{2,})(?:\s*[〜~～]\s*(?:[A-Z]{3}-)?([A-Z])?(\d{2,}))?"
)

# 対象ファイルの種類 → (担当する章, 2.2 の「守る層」の先頭語)
_SPEC_ROLES = [
    (lambda p: p.endswith("_page.dart"), 3, "画面"),
    (lambda p: p.endswith("_view_model.dart"), 4, "ViewModel"),
    (lambda p: "/repositories/" in p, 5, "Repository"),
    (lambda p: "/use_cases/" in p, 6, "UseCase"),
]


def expand_spec_ids(text: str) -> set[str]:
    """文字列中の仕様 ID を集める。`SMP-V17〜V19` のような範囲は展開する。"""
    out: set[str] = set()
    for m in _SPEC_ID_RE.finditer(text or ""):
        prefix, kind, start, kind2, end = m.groups()
        width = len(start)
        if end is None:
            out.add(f"{prefix}-{kind}{start}")
            continue
        if kind2 and kind2 != kind:
            # 種別をまたぐ範囲は両端だけ（範囲の意味が決まらないため）
            out.add(f"{prefix}-{kind}{start}")
            out.add(f"{prefix}-{kind2}{end}")
            continue
        for n in range(int(start), int(end) + 1):
            out.add(f"{prefix}-{kind}{n:0{width}d}")
    return out


def boundary_value_count(cell: str) -> int:
    """2.2 の「境界値」セルに並ぶ値の数（有効・無効の合計）。

    `有効: v1 ／ v2 無効: v3` のように「／」で区切って並べる書式を数える。
    2.2 の ID は境界値の数だけテストケースが必要（spec-authoring の規約）。
    """
    parts = re.split(r"(?:有効|無効)\s*[:：]", cell or "")
    segments = parts[1:] if len(parts) > 1 else parts
    return sum(
        len([v for v in seg.split("／") if v.strip()]) for seg in segments
    )


def _read_frontmatter(text: str) -> dict:
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    meta: dict = {"targets": []}
    key = None
    for line in m.group(1).splitlines():
        item = re.match(r"^\s+-\s+(.+?)\s*$", line)
        if item and key == "targets":
            meta["targets"].append(item.group(1))
            continue
        kv = re.match(r"^([A-Za-z_]+):\s*(.*?)\s*$", line)
        if kv:
            key = kv.group(1)
            if kv.group(2):
                meta[key] = kv.group(2)
    return meta


def parse_spec(path: str) -> dict | None:
    """仕様書から ID ごとの章・守る層・境界値の数・廃止かどうかを読む。

    ID として数えるのは 2〜6章の表の**先頭列**だけ（7章「対象外」と8章「要確認事項」は除く。
    4章の「対応する画面仕様」列のように他の ID を引用している列も除く）。
    """
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None
    meta = _read_frontmatter(text)
    prefix = meta.get("prefix", "")
    if not prefix:
        return None
    items: dict[str, dict] = {}
    chapter = 0
    row_re = re.compile(rf"^\|\s*({re.escape(prefix)}-[A-Z]\d{{2,}})\s*\|")
    for line in text.splitlines():
        h = re.match(r"^##\s+(\d+)\.", line)
        if h:
            chapter = int(h.group(1))
            continue
        if not 2 <= chapter <= 6:
            continue
        m = row_re.match(line)
        if not m:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        item = {
            "chapter": chapter,
            "abolished": cells[-1] == "廃止",
            "layer": "",
            "boundary": 0,
        }
        if chapter == 2 and len(cells) >= 4:
            item["layer"] = cells[2]
            item["boundary"] = boundary_value_count(cells[3])
        items[m.group(1)] = item
    return {
        "path": os.path.relpath(path, REPO).replace("\\", "/"),
        "prefix": prefix,
        "status": meta.get("status", ""),
        "targets": meta.get("targets", []),
        "items": items,
    }


def responsible_spec_ids(spec: dict, target: str) -> list[str]:
    """対象ファイルが担当する仕様 ID（廃止を除く）。章ごとの振り分けは test-loop の規約どおり。"""
    for match, chapter, layer in _SPEC_ROLES:
        if match(target):
            return sorted(
                i for i, it in spec["items"].items()
                if not it["abolished"] and (
                    it["chapter"] == chapter
                    or (it["chapter"] == 2 and it["layer"].startswith(layer))
                )
            )
    return []


def read_case_spec_ids(doc: str) -> tuple[str | None, list[dict]]:
    """項目書 MD の `| 仕様書 |` 行と、テストケース一覧の各ケースの仕様 ID を読む。"""
    try:
        with open(doc, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None, []
    spec = None
    m = re.search(r"^\|\s*仕様書\s*\|\s*(.+?)\s*\|\s*$", text, re.M)
    if m:
        spec = m.group(1).strip("` ")
    cases: list[dict] = []
    header = None
    for line in text.splitlines():
        if not line.strip().startswith("|"):
            header = None
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if "テスト名" in cells:
            header = cells
            continue
        if header is None or set(line.strip()) <= set("|-: "):
            continue
        row = dict(zip(header, cells))
        cases.append({"name": row.get("テスト名", ""),
                      "ids": expand_spec_ids(row.get("仕様ID", ""))})
    return spec, cases


def find_spec_for(target: str, doc_spec: str | None = None) -> dict | None:
    """対象ファイルの承認済み仕様書。項目書の `| 仕様書 |` 行を優先し、
    無ければ frontmatter の `targets` に対象（または対象を含むディレクトリ）が載る仕様書を探す。"""
    candidates = []
    if doc_spec:
        candidates.append(os.path.join(REPO, doc_spec))
    else:
        candidates = glob.glob(os.path.join(SPEC_DIR, "**", "*.md"), recursive=True)
    for path in candidates:
        spec = parse_spec(path)
        if not spec or spec["status"] != "approved":
            continue
        if doc_spec or any(
            target == t or (t.endswith("/") and target.startswith(t))
            for t in spec["targets"]
        ):
            return spec
    return None


def spec_coverage(target: str) -> dict | None:
    """対象ファイルの仕様 ID の網羅状況。仕様書が無い対象は None。

    - missing: 担当する仕様 ID のうち、どのテストケースからも引用されていないもの
    - boundary_short: 2.2 の ID で、引用するテストケースが境界値の数より少ないもの
    """
    doc = doc_path_for(target)
    doc_spec, cases = read_case_spec_ids(doc) if doc else (None, [])
    spec = find_spec_for(target, doc_spec)
    if not spec:
        return None
    required = responsible_spec_ids(spec, target)
    cited: dict[str, int] = {}
    for c in cases:
        for i in c["ids"]:
            cited[i] = cited.get(i, 0) + 1
    boundary_short = [
        {"id": i, "need": spec["items"][i]["boundary"], "have": cited.get(i, 0)}
        for i in required
        if spec["items"][i]["chapter"] == 2
        and 0 < cited.get(i, 0) < spec["items"][i]["boundary"]
    ]
    return {
        "target": target,
        "spec": spec["path"],
        "doc": os.path.relpath(doc, REPO).replace("\\", "/") if doc else None,
        "required": required,
        "cited": {i: cited.get(i, 0) for i in required},
        "missing": [i for i in required if not cited.get(i)],
        "boundary_short": boundary_short,
        "boundary_need": {
            i: spec["items"][i]["boundary"] for i in required
            if spec["items"][i]["chapter"] == 2
        },
    }


def format_spec_warning(sc: dict) -> str | None:
    """ループ判定の warnings に載せる1行（問題が無ければ None）。合否には使わない。"""
    parts = []
    if sc["missing"]:
        parts.append("テストの無い仕様 ID: " + ", ".join(sc["missing"]))
    if sc["boundary_short"]:
        parts.append("境界値のテストが足りない仕様 ID: " + ", ".join(
            f"{b['id']}（{b['have']}/{b['need']} 件）" for b in sc["boundary_short"]))
    return "仕様漏れ … " + " ／ ".join(parts) if parts else None


def known_bug_failures(failures: list[dict], state: dict) -> list[dict]:
    """記録済みのバグ（production_bugs）の仕様 ID だけで説明できる失敗。

    テスト名の `[SMP-D01]` が、記録済みのバグの症状に書かれた仕様 ID にすべて含まれる失敗は
    「仕様どおりの期待値で落ちた既知のバグ」なので、ループを回し続ける理由にならない。
    """
    bug_ids: set[str] = set()
    for bug in (state or {}).get("production_bugs", []):
        bug_ids |= expand_spec_ids(bug.get("symptom", ""))
    if not bug_ids:
        return []
    out = []
    for fl in failures:
        ids = expand_spec_ids(fl.get("name", ""))
        if ids and ids <= bug_ids:
            out.append(fl)
    return out


# --------------------------------------------------------------------------- #
# verdict
# --------------------------------------------------------------------------- #
def compute_verdict(report: dict, target: str | None, state: dict,
                    in_denominator: bool = True) -> dict:
    """ループを継続すべきか（continue / stop / n/a）を算出する。

    まず上限を無視して「失敗 → 達成 → 理由あり → それ以外」の順に判定し、
    結果が continue のときだけ上限（内部 → 外部）を当てはめて stop に変える。
    上限は暴走（continue が続くこと）を止めるためのものなので、目標に達した
    stop（記録済みのバグだけが残っている場合を含む）を「上限に到達」で上書きしない。
    こうしないと、エージェントが1起動内でハーネスを何度も回して内部カウンタを
    使い切ったとき、バグを記録しても「内部上限」としか出ず、外部ループを
    余分に1周させないと本当の判定が得られない。

    `in_denominator=False`（Widget テストの Page など限定分母外）のときは
    カバレッジを見ず、全テスト green かどうかだけで判定する。
    """
    loop = _goal_verdict(report, target, state, in_denominator)
    if loop["verdict"] != "continue":
        return loop

    # 上限: continue のままなら打ち切る（未達の理由は warnings に残す）
    if loop["inner"] >= INNER_MAX:
        limit = f"内部上限に到達（{loop['inner']}/{INNER_MAX} 回）"
    elif loop["outer"] >= OUTER_MAX:
        limit = f"外部上限に到達（{loop['outer']}/{OUTER_MAX} 回）"
    else:
        return loop
    loop["warnings"].append(f"未達のまま打ち切り: {loop['reason']}")
    loop["verdict"] = "stop"
    loop["reason"] = limit
    return loop


def _goal_verdict(report: dict, target: str | None, state: dict,
                  in_denominator: bool) -> dict:
    """上限を考えずに、目標（green・カバレッジ）に達しているかだけを判定する。"""
    inner = int((state.get("inner") or {}).get(target, 0)) if target else 0
    outer = int((state.get("outer") or {}).get(target, 0)) if target else 0
    loop = {
        "target": target,
        "verdict": "n/a",
        "reason": "",
        "inner": inner,
        "inner_max": INNER_MAX,
        "outer": outer,
        "outer_max": OUTER_MAX,
        "warnings": [],
    }

    if not target:
        loop["reason"] = (
            "対象ファイルを特定できない（全体実行、または複数パス指定）ため判定しない"
        )
        return loop

    cov = report.get("coverage", {}) or {}
    threshold = cov.get("threshold", 90.0)
    entry = next((f for f in cov.get("files", []) if f.get("path") == target), None)

    # 1. テスト失敗（対象のテストファイルに限る）
    stem = _stem(target)
    failures = [
        fl for fl in (report.get("tests", {}) or {}).get("failures", [])
        if not fl.get("file") or _stem(fl["file"]) == stem
    ]
    # 記録済みのバグによる失敗（仕様どおりの期待値で落ちたもの）はループを回す理由にしない
    known = known_bug_failures(failures, state)
    if known:
        loop["warnings"].append(
            f"記録済みのバグによる失敗 {len(known)} 件は判定から除外した"
            "（仕様どおりの期待値で落ちているため、テストを直さない）"
        )
        failures = [fl for fl in failures if fl not in known]
    if failures:
        loop["verdict"] = "continue"
        loop["reason"] = f"テスト失敗 {len(failures)} 件"
        return loop

    # 限定分母外（Widget テストの Page 等）は green 判定のみで完了とする
    if not in_denominator:
        loop["verdict"] = "stop"
        loop["reason"] = (
            "記録済みのバグによる失敗を除き全テスト green" if known else "全テスト green"
        ) + "（限定分母外のためカバレッジは判定に使わない）"
        return loop

    # カバレッジに現れない＝このテストが対象ファイルを読み込んでいない
    if entry is None:
        loop["verdict"] = "continue"
        loop["reason"] = f"{target} がカバレッジに現れていない（テストが対象を読み込んでいない）"
        return loop

    pct = entry.get("pct", 0.0)
    uncovered = set(entry.get("uncovered_lines", []) or [])

    # 2. 達成
    if pct >= threshold:
        loop["verdict"] = "stop"
        loop["reason"] = f"カバレッジ {pct}% が閾値 {threshold}% を満たしている"
        return loop

    # 3. 90% 未満だが、未カバー行に理由が付いている
    lines, has_reason, has_pending = reasoned_lines(target)
    if has_pending:
        loop["verdict"] = "continue"
        loop["reason"] = (
            f"カバレッジ {pct}%。項目書に「{PENDING_MARK}」が残っている"
            "（理由が確定していない）"
        )
        return loop

    if has_reason and not lines:
        # 段階移行: 行番号が書かれていない既存項目書は「理由あり」とみなす
        loop["warnings"].append(_NO_LINE_WARNING)
        loop["verdict"] = "stop"
        loop["reason"] = (
            f"カバレッジ {pct}% だが、項目書の「## 対象外」に理由がある"
            "（行番号なしのため照合は未実施）"
        )
        return loop

    missing = sorted(uncovered - lines)
    if has_reason and not missing:
        loop["verdict"] = "stop"
        loop["reason"] = (
            f"カバレッジ {pct}% だが、未カバー行 {len(uncovered)} 行すべてに"
            "「## 対象外」の理由がある"
        )
        return loop

    # 4. それ以外
    loop["verdict"] = "continue"
    if has_reason:
        preview = ", ".join(map(str, missing[:12]))
        more = " …" if len(missing) > 12 else ""
        loop["reason"] = (
            f"カバレッジ {pct}%。未カバー行 {len(uncovered)} 行のうち "
            f"{len(missing)} 行に理由がない（{preview}{more}）"
        )
    else:
        loop["reason"] = (
            f"カバレッジ {pct}% が閾値 {threshold}% 未満で、"
            "項目書に「## 対象外」の理由もない"
        )
    return loop


def test_paths_for(target: str) -> list[str]:
    """対象の lib ファイルに対応するテストファイルを探す（無ければ空リスト）。

    規約どおりのミラー構成（lib/x/y.dart → test/x/y_test.dart）を先に見て、
    無ければ test/ 全体から同じ stem のファイルを探す（Page は階層がずれるため）。
    """
    rel = target.replace("\\", "/")
    hits: list[str] = []
    if rel.startswith("lib/") and rel.endswith(".dart"):
        mirror = "test/" + rel[len("lib/"):-len(".dart")] + "_test.dart"
        if os.path.exists(os.path.join(REPO, mirror)):
            hits.append(mirror)
    if not hits:
        stem = _stem(rel)
        cwd = os.getcwd()
        try:
            os.chdir(REPO)
            hits = [
                p.replace("\\", "/")
                for p in glob.glob("test/**/*_test.dart", recursive=True)
                if _stem(p) == stem
            ]
        finally:
            os.chdir(cwd)
    return sorted(hits)


def _stale_inputs(target: str, report: dict) -> list[str]:
    """レポートより後に更新されたファイル（＝レポートが古いことの証拠）を返す。"""
    raw = report.get("generated_at") or ""
    try:
        gen = datetime.fromisoformat(raw).timestamp()
    except ValueError:
        return ["harness_report.json（生成時刻を読めない）"]
    watched = [target, *test_paths_for(target)]
    doc = doc_path_for(target)
    if doc:
        watched.append(doc)
    out = []
    for rel in watched:
        full = os.path.join(REPO, rel)
        if os.path.exists(full) and os.path.getmtime(full) > gen + 1:
            out.append(rel)
    return out


def can_skip_generation(target: str, report: dict, state: dict) -> dict:
    """既存のテストだけで基準を満たしているか（＝手順3〜6を飛ばしてよいか）。

    「2回目の実行で成果物が変わらない」ようにするための判定。
    次の3つをすべて満たすときだけ飛ばしてよい:

      1. loop.verdict が stop（green かつカバレッジ基準を満たす。
         上限到達による stop は除く＝目標に達していないため）
      2. 仕様書がある対象では、テストの無い仕様 ID が無い
      3. 同じく、境界値のテストが足りない仕様 ID が無い

    判定材料は「そのテストファイルでハーネスを回した直後のレポート」であること。
    """
    stale = _stale_inputs(target, report)
    if stale:
        return {
            "target": target,
            "can_skip": False,
            "reason": "レポートが古い（" + ", ".join(stale)
                      + " の方が新しい）。対象のテストでハーネスを回し直すこと",
            "loop": {},
            "spec_checked": False,
        }
    loop = compute_verdict(report, target, state,
                           in_denominator=target in (report.get("coverage", {})
                                                     .get("target_files", []) or [target]))
    reasons: list[str] = []
    if loop.get("verdict") != "stop":
        reasons.append(f"ループ判定が stop ではない（{loop.get('reason')}）")
    elif "上限に到達" in (loop.get("reason") or ""):
        reasons.append(f"上限による打ち切りで、目標に達していない（{loop.get('reason')}）")
    sc = report.get("spec") or spec_coverage(target)
    if sc:
        if sc.get("missing"):
            reasons.append("テストの無い仕様 ID: " + ", ".join(sc["missing"]))
        if sc.get("boundary_short"):
            reasons.append("境界値のテストが足りない仕様 ID: " + ", ".join(
                f"{b['id']}（{b['have']}/{b['need']} 件）" for b in sc["boundary_short"]))
    return {
        "target": target,
        "can_skip": not reasons,
        "reason": "既存のテストで基準を満たしている（生成を飛ばして手順7へ）"
                  if not reasons else " ／ ".join(reasons),
        "loop": loop,
        "spec_checked": bool(sc),
    }


def format_loop(loop: dict) -> str:
    """stdout 表示用の1〜2行。"""
    mark = {"stop": "■", "continue": "▶", "n/a": "－"}.get(loop["verdict"], "?")
    head = (
        f"  {mark} ループ判定: {loop['verdict']}"
        f"  (内部 {loop['inner']}/{loop['inner_max']}, "
        f"外部 {loop['outer']}/{loop['outer_max']})"
    )
    body = f"      理由: {loop['reason']}" if loop["reason"] else ""
    warn = "".join(f"\n      ⚠ {w}" for w in loop.get("warnings", []))
    return head + ("\n" + body if body else "") + warn


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _print_state(state: dict) -> None:
    print(json.dumps(state, ensure_ascii=False, indent=2))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("start-session", help="セッションを開始する（既にあれば継続）")
    p.add_argument("--scope", nargs="+", default=None,
                   help="このセッションで扱う対象を限定する（部分依頼のとき）。"
                        "未指定なら全対象。例: --scope lib/core/utils/a.dart lib/b.dart")

    p = sub.add_parser("scope", help="セッション途中で対象範囲を設定/解除する")
    p.add_argument("targets", nargs="*",
                   help="限定する lib パス。省略すると全対象に戻す")
    sub.add_parser("show", help="現在のステートを表示する")
    p = sub.add_parser("end-session", help="ステートを破棄する（Excel 生成後のみ）")
    p.add_argument("--force", action="store_true",
                   help="Excel 未生成でも破棄する（緊急脱出用。通常は使わない）")

    p = sub.add_parser("begin-attempt", help="外部ループを1周進める（内部は0にリセット）")
    p.add_argument("target")

    p = sub.add_parser("record-run", help="内部ループを1周進める（通常はハーネスが自動で呼ぶ）")
    p.add_argument("target")

    p = sub.add_parser("verdict", help="harness_report.json から継続判定を算出する")
    p.add_argument("target")
    p.add_argument("--report",
                   default=os.path.join(REPO, "coverage", "harness_report.json"))

    p = sub.add_parser(
        "can-skip",
        help="既存のテストだけで基準を満たしているか判定する（満たしていれば生成を飛ばす）")
    p.add_argument("target")
    p.add_argument("--report",
                   default=os.path.join(REPO, "coverage", "harness_report.json"))

    p = sub.add_parser("finish", help="対象を done / skipped として記録する")
    p.add_argument("target")
    p.add_argument("--status", choices=["done", "skipped"], required=True)
    p.add_argument("--reason", default="")

    p = sub.add_parser("bug", help="プロダクションコードのバグを記録する")
    p.add_argument("--path", required=True)
    p.add_argument("--line", type=int, default=0)
    p.add_argument("--symptom", required=True)
    p.add_argument("--evidence", default="")
    p.add_argument("--recommendation", default="")

    args = ap.parse_args()

    if args.cmd == "start-session":
        state = load_state()
        save_state(state)
        if args.scope:
            state = set_scope(args.scope)
        print(f"session_id: {state['session_id']}（created_at: {state['created_at']}）")
        scope = state.get("scope")
        print(f"  対象範囲: {'全対象' if not scope else f'{len(scope)} ファイル限定'}")
        for t in scope or []:
            print(f"    - {t}")
        return 0

    if args.cmd == "scope":
        state = set_scope(args.targets or None)
        scope = state.get("scope")
        print(f"対象範囲: {'全対象に戻しました' if not scope else f'{len(scope)} ファイルに限定'}")
        for t in scope or []:
            print(f"  - {t}")
        return 0

    if args.cmd == "show":
        if not os.path.exists(STATE_PATH) and not os.path.exists(LEGACY_STATE_PATH):
            print("セッションはまだありません（.test_loop/state.json が無い）")
            return 0
        _print_state(load_state(create=False))
        return 0

    if args.cmd == "end-session":
        if not os.path.exists(STATE_PATH) and not os.path.exists(LEGACY_STATE_PATH):
            print("破棄するセッションはありません")
            return 0

        state = load_state(create=False)
        completed = state.get("completed_at")

        # Excel 未生成のまま工程を畳むのを防ぐ関所。
        # Stop フックは「state.json が無ければ通す」分岐を持たざるを得ない
        # （テスト工程外で暴発させないため）ので、ここを塞がないと
        # 「end-session を打てば終われる」という近道が残ってしまう。
        if not completed and not args.force:
            print(
                "Excel 項目書がまだ生成されていないため、セッションを破棄できません。\n"
                "SKILL.md 手順11 を先に実行してください:\n"
                "  Agent ツールで test-doc-excel-generator を起動する\n"
                "  （直接なら python3 scripts/gen_test_excel.py）\n"
                "生成が成功すると completed_at が記録され、このコマンドが通るようになります。\n"
                "どうしても破棄が必要な場合のみ --force を付けてください。",
                file=sys.stderr,
            )
            return 1

        if args.force and not completed:
            print("⚠ Excel 未生成のまま --force で破棄します", file=sys.stderr)

        clear_state()
        print("セッションを破棄しました"
              + (f"（Excel: {state.get('excel_path')}）" if completed else "（--force）"))
        return 0

    if args.cmd == "begin-attempt":
        state = begin_attempt(args.target)
        print(f"{args.target}: 外部 {state['outer'][args.target]}/{OUTER_MAX} 周目"
              f"（内部カウンタをリセット）")
        return 0

    if args.cmd == "record-run":
        state = record_run(args.target)
        print(f"{args.target}: 内部 {state['inner'][args.target]}/{INNER_MAX} 周目")
        return 0

    if args.cmd == "verdict":
        try:
            with open(args.report, encoding="utf-8") as f:
                report = json.load(f)
        except (OSError, json.JSONDecodeError):
            print(f"{args.report} を読めません", file=sys.stderr)
            return 2
        loop = compute_verdict(report, args.target, load_state(create=False))
        print(json.dumps(loop, ensure_ascii=False, indent=2))
        return 0

    if args.cmd == "can-skip":
        try:
            with open(args.report, encoding="utf-8") as f:
                report = json.load(f)
        except (OSError, json.JSONDecodeError):
            print(f"{args.report} を読めません", file=sys.stderr)
            return 2
        if report.get("loop", {}).get("target") not in (None, args.target):
            print("⚠ レポートは別の対象のものです。対象のテストファイルで "
                  "test_harness.sh を実行してから判定してください", file=sys.stderr)
            return 2
        res = can_skip_generation(args.target, report, load_state(create=False))
        mark = "■ 生成を飛ばしてよい" if res["can_skip"] else "▶ 生成が必要"
        print(f"{mark}: {args.target}")
        print(f"      理由: {res['reason']}")
        if res["loop"] and not res["spec_checked"]:
            print("      ※ 承認済みの仕様書が見つからないため、仕様 ID の網羅は判定していない")
        return 0 if res["can_skip"] else 1

    if args.cmd == "finish":
        finish(args.target, args.status, args.reason)
        print(f"{args.target}: {args.status}"
              + (f"（{args.reason}）" if args.reason else ""))
        return 0

    if args.cmd == "bug":
        add_bug({
            "path": args.path, "line": args.line, "symptom": args.symptom,
            "evidence": args.evidence, "recommendation": args.recommendation,
        })
        print(f"production_bugs に追加しました: {args.path}:{args.line}")
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
