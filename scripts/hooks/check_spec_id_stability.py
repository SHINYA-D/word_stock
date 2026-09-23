#!/usr/bin/env python3
"""PreToolUse(Edit|Write) hook — 詳細設計書の仕様 ID の振り直しを止める。

spec-authoring の規約:

    ID と「条件・期待される動作」の対応を変えない。
    行の並べ替え・章の再編は自由。追加は種別ごとの末尾の連番で行う。

この規約は SKILL.md に書かれていたが、書かれた次のコミットで破られた
（103 項目 → 170 項目の改訂で ID が振り直され、旧 SMP-D04「読み込み中の表示」が
新 SMP-D11 に移り、新 SMP-D04 は別の項目になった）。項目書とテストコードは
ID を文字列で引用しているだけなので、つなぎ替わったことに誰も気づけない。

**拒否するのは「振り直し」だけ**。すなわち、編集後に

    既存 ID の内容が、別の ID の内容として現れている

場合に止める。既存 ID の中身を更新するだけ（例: 半角20文字 → 30文字）は
spec-authoring が認めているので通す。そちらは test-loop 側の
内容照合ゲート（spec.drifted）が拾う。
"""
from __future__ import annotations

import json
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import loop_state  # noqa: E402

SPEC_DIR = "docs/detailed_design/"


def _deny(reason: str) -> int:
    print(json.dumps({
        "decision": "block",
        "reason": reason,
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        },
    }, ensure_ascii=False))
    return 0


def _after_text(tool: str, tool_input: dict, current: str) -> str | None:
    """この編集を適用した後の本文（作れなければ None）。"""
    if tool == "Write":
        return tool_input.get("content")
    old = tool_input.get("old_string")
    new = tool_input.get("new_string")
    if old is None or new is None:
        return None
    if tool_input.get("replace_all"):
        return current.replace(old, new)
    if current.count(old) != 1:
        return None  # 一意でない編集は判定できないので通す
    return current.replace(old, new, 1)


def _items(text: str) -> dict[str, str]:
    """本文から ID → 指紋を取る（loop_state.parse_spec と同じ数え方）。"""
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False,
                                     encoding="utf-8") as f:
        f.write(text)
        tmp = f.name
    try:
        spec = loop_state.parse_spec(tmp)
    finally:
        os.unlink(tmp)
    if not spec:
        return {}
    return {i: it["digest"] for i, it in spec["items"].items() if it["digest"]}


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool = payload.get("tool_name") or ""
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path or tool not in ("Edit", "Write"):
        return 0

    try:
        rel = os.path.relpath(os.path.abspath(file_path), loop_state.REPO)
    except ValueError:
        return 0
    rel = rel.replace("\\", "/")
    if not rel.startswith(SPEC_DIR) or not rel.endswith(".md"):
        return 0
    if not os.path.exists(file_path):
        return 0  # 新規作成は検査しない

    try:
        with open(file_path, encoding="utf-8") as f:
            current = f.read()
    except OSError:
        return 0

    after = _after_text(tool, tool_input, current)
    if after is None or after == current:
        return 0

    before_items = _items(current)
    after_items = _items(after)
    if not before_items or not after_items:
        return 0

    # 編集後の「指紋 → ID」。既存 ID の内容がここで別の ID に紐づいていたら振り直し。
    after_by_digest: dict[str, list[str]] = {}
    for i, d in after_items.items():
        after_by_digest.setdefault(d, []).append(i)

    renumbered = []
    for i, d in before_items.items():
        if after_items.get(i) == d:
            continue  # 変わっていない
        moved = [m for m in after_by_digest.get(d, []) if m != i]
        if moved:
            renumbered.append((i, moved[0]))

    if not renumbered:
        return 0

    lines = "\n".join(f"    {a} の内容が {b} に移っています" for a, b in renumbered[:12])
    more = f"\n    …ほか {len(renumbered) - 12} 件" if len(renumbered) > 12 else ""
    return _deny(
        "仕様 ID の振り直しになっています（spec-authoring の規約違反）。\n"
        f"{lines}{more}\n\n"
        "ID は項目書とテストコードが文字列で引用している識別子です。番号を付け替えると、"
        "テストが別の項目を指したまま「テスト済み」と判定され、未テストの項目にバグが隠れます。\n\n"
        "直し方:\n"
        "  - 既存 ID は動かさず、新しい項目は種別ごとの末尾の連番で足す（番号が飛んでよい）\n"
        "  - 表の行の並べ替え・章の再編は自由。ID と内容の対応だけ保つこと\n"
        "  - 項目を消すときは行を残し、確定度を「廃止」にして理由を書く\n"
        "  - 既存項目の中身を更新するだけなら ID を変えなくてよい（それは通ります）"
    )


if __name__ == "__main__":
    sys.exit(main())
