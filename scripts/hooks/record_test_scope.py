#!/usr/bin/env python3
"""PreToolUse(Edit|Write) hook — 依頼範囲の外のテスト関連ファイルへの書き込みを記録する。

test-loop を「サンプル画面だけ」で回していても、サブエージェントは Edit/Write に
パスの制限を持たないので、他の画面のテストや共有ヘルパーを書き換えられる。
`start-session --scope` で宣言した範囲は、そのままでは何も守っていない。

このフックは**拒否しない**（共有ヘルパーへの追加が実際に必要になることがある）。
代わりに `.test_loop/state.json` の `out_of_scope_writes` に記録し、
ハーネスの警告・最終報告・Excel で「依頼範囲の外を触った」と見えるようにする。

通す条件:
  - セッションが無い（テスト工程ではない）
  - scope が未設定（全対象の依頼なので範囲の概念がない）
  - 書き込み先が test/ 配下でない
  - scope の対象ファイルに対応するテスト・項目書である
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import loop_state  # noqa: E402


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    file_path = (payload.get("tool_input") or {}).get("file_path") or ""
    if not file_path:
        return 0

    # セッションが無ければテスト工程ではない
    if not loop_state.session_active():
        return 0
    state = loop_state.load_state(create=False)
    scope = state.get("scope")
    if not scope:
        return 0  # 全対象の依頼。範囲の概念がない

    try:
        rel = os.path.relpath(os.path.abspath(file_path), loop_state.REPO)
    except ValueError:
        return 0
    rel = rel.replace("\\", "/")
    if rel.startswith(".."):
        return 0
    if not (rel.startswith("test/") or rel.startswith("integration_test/")):
        return 0

    if rel in loop_state.allowed_test_paths(scope):
        return 0

    loop_state.record_out_of_scope_write(rel)
    note = (
        f"⚠ {rel} は今回の依頼範囲（scope）の外です。記録しました。\n"
        "   共有ヘルパー（test/helpers/**）の変更は他の画面のテストにも影響します。"
        "既存のフィールド・関数は壊さず追加だけにし、手順8の全体ハーネスで回帰を確認してください。\n"
        "   依頼範囲の外のテストを直す必要がある場合は、最終報告にその理由を書いてください。"
    )
    print(note, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
