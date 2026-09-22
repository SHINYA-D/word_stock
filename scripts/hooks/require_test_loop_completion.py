#!/usr/bin/env python3
"""Stop hook. テスト工程を最後までやり切らせる関所。

## 目的

test-loop の二重ループ（内部3回 / 外部3回）は「回しすぎ」を止める上限であって、
「あと1回回せ」を強制する力を持たない。`loop.verdict` が `continue` でも、
ループを次の周に進める主体は LLM なので、途中でユーザーに制御を返してしまえば
そこで工程が終わる。SKILL.md「大原則: テスト工程は必ず最後（手順10 Excel 生成）
までやり切る」が自然言語のお願いのままになっているのはこのためである。

Stop hook は「LLM がターンを終えようとする瞬間」に割り込める唯一のタイミング。
ここで `loop_state.compute_verdict()` の判定を読み、まだ工程が残っていれば
終了を拒否して次のターンへ押し戻す。

判定ロジックは新規に書かない。既存の `loop_state.py` / `harness_report.py` を
そのまま呼ぶ。このフックが持つのは「いつ諦めるか」のガードだけ。

## 関所が立つ区間

    state.json が無い            → 通す（テスト工程ではない。暴発防止）
    completed_at が立っている    → 通す（工程完了）
    それ以外                     → 拒否

`completed_at` は `gen_test_excel.py` が Excel の保存に成功した直後に
`loop_state.mark_completed()` で記録する。成果物を作った本人が記録するので、
「Excel は無いが記録だけある」状態を作れない（`record_run()` と同じ思想）。

`end-session` も `completed_at` が無ければ拒否する（`loop_state.py` 側）。
このフックは「state.json が無ければ通す」分岐を持たざるを得ないため、
そこを塞がないと「end-session を打てば終われる」近道が残るため。

## 無限ループ対策

上限（内部/外部）に達すると `compute_verdict()` は continue を必ず stop に変えるため、
カウンタ経由の暴走は起きない。危ないのは別経路で、

    押し戻す → LLM がハーネスを回さず何か喋る → verdict は古いまま continue
    → カウンタが増えない → 永久に押し戻される

そこで「進捗フィンガープリント」を `.test_loop/stop_gate.json` に記録し、
前回と変化が無い押し戻しが NO_PROGRESS_MAX 回続いたら諦めて通す。
加えてセッション通算 TOTAL_MAX 回で打ち切る。

## フェイルオープン方針

例外・パース失敗・ステート破損はすべて「通す」に倒す。
関所の誤作動で作業が止まる方が、素通りより害が大きい（既存フックと同方針）。

## 環境変数

    TEST_LOOP_STOP_GATE        0 / false でこのフックを無効化
    TEST_LOOP_NO_PROGRESS_MAX  無進展のまま押し戻す上限（既定 3）
    TEST_LOOP_TOTAL_MAX        セッション通算の押し戻し上限（既定 60）
"""

from __future__ import annotations

import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPTS = os.path.join(REPO, "scripts")

GATE_PATH = os.path.join(REPO, ".test_loop", "stop_gate.json")
REPORT_PATH = os.path.join(REPO, "coverage", "harness_report.json")

NO_PROGRESS_MAX = int(os.environ.get("TEST_LOOP_NO_PROGRESS_MAX", "3"))
TOTAL_MAX = int(os.environ.get("TEST_LOOP_TOTAL_MAX", "60"))


def allow() -> int:
    """終了を許可する（何も出力しない）。"""
    return 0


def block(reason: str) -> int:
    """終了を拒否し、reason を次のターンの指示として返す。"""
    json.dump({"decision": "block", "reason": reason},
              sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


# --------------------------------------------------------------------------- #
# 無進展ガード
# --------------------------------------------------------------------------- #
def load_gate() -> dict:
    try:
        with open(GATE_PATH, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return {"fingerprint": None, "no_progress": 0, "total": 0, "session_id": None}


def save_gate(gate: dict) -> None:
    try:
        os.makedirs(os.path.dirname(GATE_PATH), exist_ok=True)
        with open(GATE_PATH, "w", encoding="utf-8") as f:
            json.dump(gate, f, ensure_ascii=False, indent=2)
    except OSError:
        pass  # 記録できなくても判定は続行する（フェイルオープン）


def fingerprint(state: dict) -> str:
    """「前回の押し戻しから何か進んだか」を表す指紋。

    ハーネスを回した（inner/outer が増えた・レポートが更新された）か、
    対象を1つ片付けた（done/skipped が増えた）場合にだけ変化する。
    LLM が喋っただけでは変化しない。
    """
    try:
        report_mtime = os.path.getmtime(REPORT_PATH)
    except OSError:
        report_mtime = 0.0
    parts = [
        str(state.get("current")),
        json.dumps(state.get("inner") or {}, sort_keys=True),
        json.dumps(state.get("outer") or {}, sort_keys=True),
        str(len(state.get("done") or [])),
        str(len(state.get("skipped") or {})),
        f"{report_mtime:.0f}",
    ]
    return "|".join(parts)


# --------------------------------------------------------------------------- #
# 工程の残りを判定する
# --------------------------------------------------------------------------- #
def pending_targets(state: dict, harness_report) -> list[str]:
    """まだ done / skipped になっていない対象ファイル。

    対象一覧の正は harness_report.is_target()（SKILL.md「対象ファイルの正は
    harness_report.py」）。ただし state["scope"] が設定されていれば
    （＝ユーザーが一部のファイルだけを依頼したセッション）その範囲だけを見る。
    scope を無視すると、2ファイルだけの依頼でも「残り48件やれ」と
    押し戻してしまい、SKILL.md 手順10 の部分依頼の扱いと矛盾する。

    coverage_exclusions.txt の登録済みファイルは常に除く。
    """
    done = set(state.get("done") or [])
    skipped = set((state.get("skipped") or {}).keys())
    excluded = set(harness_report.load_exclusions().keys())
    scope = state.get("scope")
    universe = list(scope) if scope else harness_report.enumerate_target_files()
    return [p for p in universe
            if p not in done and p not in skipped and p not in excluded]


def current_verdict(state: dict, loop_state) -> dict | None:
    """進行中の対象についての `loop.verdict`。判定材料が無ければ None。"""
    target = state.get("current")
    if not target:
        return None
    if target in set(state.get("done") or []):
        return None
    if target in set((state.get("skipped") or {}).keys()):
        return None
    try:
        with open(REPORT_PATH, encoding="utf-8") as f:
            report = json.load(f)
    except (OSError, json.JSONDecodeError):
        # まだ一度もハーネスを回していない＝この対象は着手直後
        return {"verdict": "continue", "target": target,
                "reason": "ハーネスがまだ実行されていない"}
    return loop_state.compute_verdict(report, target, state)


def decide(state: dict, loop_state, harness_report) -> str | None:
    """終了を拒否する理由。通してよければ None。"""
    loop = current_verdict(state, loop_state)
    if loop is not None and loop.get("verdict") == "continue":
        target = loop.get("target")
        return (
            f"テスト工程が未完了です（対象: {target}）。"
            f"ループ判定は continue。理由: {loop.get('reason')}\n"
            "SKILL.md 手順2〜5 に従って差し戻し・再生成・ハーネス再実行を続けてください。"
            "上限に達した場合は compute_verdict が stop を返すので、"
            "回数は自分で数えないこと。"
        )

    if loop is not None:
        # stop なのに finish されていない＝手順6の記録が抜けている
        return (
            f"{loop.get('target')} のループ判定は stop（{loop.get('reason')}）ですが、"
            "まだ done / skipped として記録されていません。SKILL.md 手順6の "
            "`python3 scripts/loop_state.py finish <lib パス> --status done` "
            "（または --status skipped --reason ...）を実行してください。"
        )

    pending = pending_targets(state, harness_report)
    if pending:
        head = "\n".join(f"  - {p}" for p in pending[:10])
        more = f"\n  … 他 {len(pending) - 10} 件" if len(pending) > 10 else ""
        scope_note = (
            ""
            if state.get("scope")
            else "\nユーザーが一部のファイルだけを依頼したセッションなら、"
                 "`python3 scripts/loop_state.py scope <lib パス...>` で対象範囲を"
                 "宣言してください（宣言しないと全対象が要求されます）。"
        )
        return (
            f"未消化の対象が {len(pending)} 件残っています。"
            "SKILL.md 手順1に戻り、最上位 Tier の対象を1つ選んで "
            "`begin-attempt` → エージェント起動 → ハーネス実行を続けてください。\n"
            f"{head}{more}\n"
            "テストを書かないと決めたファイルは test/coverage_exclusions.txt に "
            "`<パス> | <理由>` で登録してください。"
            + scope_note
        )

    return (
        "全対象が done / skipped になりましたが、テスト工程はまだ終わっていません。"
        "state.json に completed_at が立っていません。\n"
        "SKILL.md 手順7〜11 をやり切ってください:\n"
        "  7. bash scripts/test_harness.sh（引数なし・1回だけ）\n"
        "  8. architecture-guard による規約レビュー\n"
        "  9. 網羅性・必要性の自己監査\n"
        " 10. test-doc-excel-generator で Excel 項目書を生成（問題が残っていても必ず実行）\n"
        "     直接なら python3 scripts/gen_test_excel.py\n"
        " 11. python3 scripts/loop_state.py end-session\n"
        "\n"
        "completed_at は gen_test_excel.py が Excel の保存に成功したときにのみ"
        "記録されます。つまりこの関所を解除するには手順10 を完走させるしかありません"
        "（state.json の手編集は block_generated_file_edit.sh が拒否します）。"
        "completed_at が無いまま end-session を打っても拒否されます。"
    )


# --------------------------------------------------------------------------- #
def main() -> int:
    if os.environ.get("TEST_LOOP_STOP_GATE", "").lower() in ("0", "false", "off"):
        return allow()

    try:
        raw = sys.stdin.read()
    except OSError:
        return allow()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}

    # Claude Code 組み込みの多重発火防止フラグ。判定材料として記録だけする。
    stop_hook_active = bool(payload.get("stop_hook_active"))

    os.chdir(REPO)  # enumerate_target_files() が lib/** を相対 glob するため
    if SCRIPTS not in sys.path:
        sys.path.insert(0, SCRIPTS)

    try:
        import loop_state
        import harness_report
    except ImportError:
        return allow()

    # ── セッション境界: state.json が無ければテスト工程ではない ──
    if not os.path.exists(loop_state.STATE_PATH):
        if os.path.exists(GATE_PATH):
            try:
                os.remove(GATE_PATH)  # end-session 済み。カウンタも捨てる
            except OSError:
                pass
        return allow()

    try:
        state = loop_state.load_state(create=False)
    except Exception:
        return allow()

    # ── 出口: Excel 生成済み（gen_test_excel.py が mark_completed を呼んだ）──
    if state.get("completed_at"):
        return allow()

    gate = load_gate()

    # セッションが変わっていたらカウンタをリセットする
    session_id = state.get("session_id")
    if gate.get("session_id") != session_id:
        gate = {"fingerprint": None, "no_progress": 0,
                "total": 0, "session_id": session_id}

    # ── 無進展ガード ──
    fp = fingerprint(state)
    if fp == gate.get("fingerprint"):
        gate["no_progress"] = int(gate.get("no_progress", 0)) + 1
    else:
        gate["fingerprint"] = fp
        gate["no_progress"] = 0

    if gate["no_progress"] >= NO_PROGRESS_MAX:
        gate["no_progress"] = 0
        gate["fingerprint"] = None
        save_gate(gate)
        print(
            f"[test-loop stop gate] 押し戻したが {NO_PROGRESS_MAX} 回連続で進捗が"
            "ありません（ハーネス未実行・カウンタ未増加）。関所を解除して制御を"
            "返します。必要なら状況を確認してから続きを指示してください。"
            + ("（stop_hook_active）" if stop_hook_active else ""),
            file=sys.stderr,
        )
        return allow()

    if int(gate.get("total", 0)) >= TOTAL_MAX:
        save_gate(gate)
        print(f"[test-loop stop gate] セッション通算の押し戻しが上限 {TOTAL_MAX} 回に"
              "達したため関所を解除します。", file=sys.stderr)
        return allow()

    # ── 本判定 ──
    try:
        reason = decide(state, loop_state, harness_report)
    except Exception as exc:  # 判定不能はフェイルオープン
        print(f"[test-loop stop gate] 判定に失敗したため通します: {exc}",
              file=sys.stderr)
        return allow()

    if reason is None:
        save_gate(gate)
        return allow()

    gate["total"] = int(gate.get("total", 0)) + 1
    save_gate(gate)
    return block(reason)


if __name__ == "__main__":
    sys.exit(main())
