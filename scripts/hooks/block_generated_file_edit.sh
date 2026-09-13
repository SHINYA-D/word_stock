#!/usr/bin/env bash
# PreToolUse(Edit|Write) hook.
#
# CLAUDE.md: 「生成ファイル不可侵」— *.freezed.dart / *.g.dart / router.g.dart は
# build_runner が自動生成するため手で編集しない。
# 該当パスへの Edit/Write を検知してブロックする。
set -euo pipefail

input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
base="$(basename -- "$file_path" 2>/dev/null || true)"

is_generated=false
case "$file_path" in
  *.freezed.dart|*.g.dart) is_generated=true ;;
esac
if [[ "$base" == "router.g.dart" ]]; then
  is_generated=true
fi

if [[ "$is_generated" == true ]]; then
  reason="生成ファイル(build_runner出力)は手で編集できません。CLAUDE.mdの方針により *.freezed.dart / *.g.dart / router.g.dart は 'fvm dart run build_runner build --delete-conflicting-outputs' でのみ更新してください。"
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
