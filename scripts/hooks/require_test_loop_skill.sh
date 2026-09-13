#!/usr/bin/env bash
# PreToolUse(Agent|Task) hook.
#
# テスト自動生成のサブエージェント（test-unit-test-generator /
# test-widget-test-generator / test-doc-excel-generator）の起動を、
# `.claude/skills/test-loop/SKILL.md` を読み込んだ後にのみ許可する関所。
#
# 目的:
#   Skill は「description を見てモデルが呼ぶかどうか判断する」仕組みであり、
#   必ず読まれる保証がない。SKILL.md を読まないままテストエージェントを
#   起動すると、Tier順・進捗管理(.test_loop/state.json)・ハーネス差し戻し・
#   Excel生成までのやり切り・要確認一覧での問題報告まで一式が飛ぶ。
#   そこで「テストエージェントの起動」という入口をブロックし、
#   手順書の読み込みを物理的に強制する。
#
# 判定方法:
#   PreToolUse には transcript_path（このセッションのJSONL）が渡ってくる。
#   そこに test-loop スキルの読み込み痕跡があるかを grep する。
#   痕跡として認めるのは次のいずれか:
#     1. Skill ツール呼び出し   {"skill":"test-loop"}
#     2. スラッシュ起動         <command-name>...test-loop...
#     3. SKILL.md の直接読み込み .claude/skills/test-loop/SKILL.md
#
# フェイルオープン方針:
#   transcript_path が無い・読めない場合はブロックしない。
#   関所の誤作動で作業が完全に止まる方が、素通りより害が大きいため。
set -euo pipefail

input="$(cat)"

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
case "$tool_name" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

subagent="$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty')"
case "$subagent" in
  test-unit-test-generator|test-widget-test-generator|test-doc-excel-generator) ;;
  *) exit 0 ;;
esac

transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
# フェイルオープン: 判定材料が無ければ通す
[[ -n "$transcript" && -r "$transcript" ]] || exit 0

if grep -Eq '"skill"[[:space:]]*:[[:space:]]*"test-loop"|<command-name>[^<]*test-loop|\.claude/skills/test-loop/SKILL\.md' "$transcript"; then
  exit 0
fi

reason="テスト生成エージェント（${subagent}）の起動前に .claude/skills/test-loop/SKILL.md を読み込んでください。Skill ツールで test-loop を呼ぶ（または /test-loop）と、Tier順の消化・.test_loop/state.json での進捗管理・ハーネス結果の差し戻し（対象ファイル90%+ / green）・最後のExcel項目書生成（未解消の問題は要確認一覧に記載）までの手順が入ります。これを飛ばすと単発のテスト生成で終わり、カバレッジ確認と項目書が欠落します。"

jq -n --arg reason "$reason" '{
  decision: "block",
  reason: $reason,
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'

exit 0
