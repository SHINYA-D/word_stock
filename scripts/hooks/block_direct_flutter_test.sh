#!/usr/bin/env bash
# PreToolUse(Bash) hook.
#
# CLAUDE.md: 「テスト実行・カバレッジ計測は fvm flutter test の直叩きではなく
# scripts/test_harness.sh 経由で行う」。
# `fvm flutter test` / `flutter test` を直接呼び出そうとしたBashコマンドを検知してブロックし、
# scripts/test_harness.sh の利用を促す。
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

if printf '%s' "$cmd" | grep -Eq '\b(fvm[[:space:]]+)?flutter[[:space:]]+test\b'; then
  reason="fvm flutter test / flutter test の直叩きは禁止されています。CLAUDE.mdの方針により、テスト実行・カバレッジ計測は 'bash scripts/test_harness.sh [<path>]' 経由で行ってください。"
  jq -n \
    --arg reason "$reason" \
    '{
      decision: "block",
      reason: $reason,
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
fi

exit 0
