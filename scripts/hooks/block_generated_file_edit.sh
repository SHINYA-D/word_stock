#!/usr/bin/env bash
# PreToolUse(Edit|Write) hook.
#
# CLAUDE.md: 「生成ファイル不可侵」— *.freezed.dart / *.g.dart / router.g.dart は
# build_runner が自動生成するため手で編集しない。
# 該当パスへの Edit/Write を検知してブロックする。
#
# .test_loop/ 配下も同じ扱いにする。state.json はスクリプト（loop_state.py /
# harness_report.py / gen_test_excel.py）だけが書き込むべきファイルで、
# completed_at や inner/outer を手で書き換えられると、Stop フック
# （require_test_loop_completion.py）の解除条件とループ上限が両方とも無効化される。
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

is_loop_state=false
case "$file_path" in
  */.test_loop/*|.test_loop/*) is_loop_state=true ;;
  */coverage/test_loop_state.json|coverage/test_loop_state.json) is_loop_state=true ;;
esac

if [[ "$is_loop_state" == true ]]; then
  reason="test-loop のステート(.test_loop/ 配下)は手で編集できません。ループ回数・進捗・completed_at は scripts/loop_state.py 経由でのみ更新してください（begin-attempt / finish / bug / end-session）。Excel 生成の完了記録(completed_at)は python3 scripts/gen_test_excel.py が保存に成功したときにのみ自動で記録されます。"
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
  exit 0
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
