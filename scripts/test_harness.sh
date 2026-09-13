#!/usr/bin/env bash
#
# WordStock テストハーネス
#
#   scripts/test_harness.sh [<test path> ...]
#
# 引数なし  : test/ 全体を実行し、テスト漏れゲートを適用（全体カバレッジ 90% 未満は ⚠ 表示のみ）
# 引数あり  : 指定パスのみ実行（カバレッジは計測・表示するがゲートは適用しない）
#
# 出力:
#   coverage/lcov.info           … flutter 生成の生 lcov
#   coverage/lcov.filtered.info  … 限定分母でフィルタした lcov
#   coverage/harness_report.json … 機械可読レポート（ループ / Excel エージェントが読む）
#
# 終了コード: テスト失敗 or （全体実行時に）テスト漏れあり で非 0
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATHS=("$@")
mkdir -p coverage
MACHINE_LOG="coverage/test_machine.jsonl"

if [ "${#PATHS[@]}" -eq 0 ]; then
  echo "▶ fvm flutter test --coverage （test/ 全体）"
else
  echo "▶ fvm flutter test --coverage ${PATHS[*]}"
fi

fvm flutter test --coverage --machine ${PATHS[@]+"${PATHS[@]}"} > "$MACHINE_LOG"
# flutter test の終了コードは無視し、判定は harness_report.py に委ねる
# （--machine の JSON からより詳細な失敗内訳を出すため）

PY="python3"
if [ -x "scripts/.venv/bin/python3" ]; then
  PY="scripts/.venv/bin/python3"
fi

"$PY" scripts/harness_report.py "$MACHINE_LOG" coverage/lcov.info ${PATHS[@]+"${PATHS[@]}"}
exit $?
