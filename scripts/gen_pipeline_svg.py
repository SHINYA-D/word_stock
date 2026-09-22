#!/usr/bin/env python3
"""docs/images/test_pipeline_overview.svg を生成する。

テスト自動生成パイプライン（ユーザー入力 → Excel 項目書 → セッション破棄）の全体図。
Skill / サブエージェント / Hooks / スクリプト / ファイルの発火位置を 1 枚にまとめる。

    python3 scripts/gen_pipeline_svg.py [--out docs/images/test_pipeline_overview.svg]

定義の正は .claude/skills/test-loop/SKILL.md と .claude/settings.json。
図はそれを追いかけるので、手順やフックを変えたらこのスクリプトも更新して再生成する
（SVG を直接手で編集しない）。
"""

from __future__ import annotations

import argparse
import os

JP = "'Hiragino Sans','Yu Gothic','Noto Sans JP',sans-serif"
MONO = "'SF Mono','Menlo','Consolas',monospace"

W = 1580
MAIN_X, MAIN_W = 355, 500          # 主フロー（縦一列）
RIGHT_X, RIGHT_W = 885, 665        # フック注釈
LEFT_X, LEFT_W = 20, 300           # ファイル入出力

# 役割ごとの配色（凡例と一致させる）
STYLE = {
    "user":     ("#f3f4f6", "#4b5563", "#111827"),
    "main":     ("#dbeafe", "#1d4ed8", "#1e3a8a"),
    "skill":    ("#ede9fe", "#7c3aed", "#5b21b6"),
    "agent":    ("#d1fae5", "#059669", "#065f46"),
    "hook":     ("#fee2e2", "#dc2626", "#991b1b"),
    "stop":     ("#ffe4e6", "#be123c", "#9f1239"),
    "script":   ("#ffedd5", "#ea580c", "#9a3412"),
    "file":     ("#fef9c3", "#ca8a04", "#854d0e"),
    "decision": ("#fff7ed", "#b45309", "#7c2d12"),
    "bug":      ("#fecaca", "#b91c1c", "#7f1d1d"),
    "note":     ("#ffffff", "#9ca3af", "#4b5563"),
}

LEGEND = [
    ("user", "ユーザー"),
    ("main", "メインエージェント"),
    ("skill", "Skill（手順書）"),
    ("agent", "サブエージェント"),
    ("hook", "Hook（PreToolUse）"),
    ("stop", "Hook（Stop）・関所"),
    ("script", "スクリプト"),
    ("file", "ファイル"),
]

out: list[str] = []


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def text(x, y, s, size=11.5, fill="#111827", bold=False, mono=False, anchor=None):
    weight = ' font-weight="700"' if bold else ""
    anc = f' text-anchor="{anchor}"' if anchor else ""
    out.append(
        f'<text x="{x}" y="{y}" font-family="{MONO if mono else JP}" '
        f'font-size="{size}"{weight}{anc} fill="{fill}">{esc(s)}</text>'
    )


def box(x, y, w, kind, title, lines, dashed=False, mono_lines=False):
    """角丸ボックス1つ。戻り値は高さ。"""
    fill, stroke, fg = STYLE[kind]
    h = 30 + 17 * len(lines) + (6 if lines else 0)
    dash = ' stroke-dasharray="6 4"' if dashed else ""
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" '
               f'fill="{fill}" stroke="{stroke}" stroke-width="2"{dash}/>')
    text(x + 14, y + 22, title, 13.5, fg, bold=True)
    for i, ln in enumerate(lines):
        text(x + 14, y + 42 + 17 * i, ln, 11.5, fg, mono=mono_lines)
    return h


def arrow(x, y1, y2, color="#374151", label=None, label_color=None):
    out.append(f'<line x1="{x}" y1="{y1}" x2="{x}" y2="{y2}" stroke="{color}" '
               f'stroke-width="2" marker-end="url(#ah)"/>')
    if label:
        text(x + 10, (y1 + y2) / 2 + 4, label, 11, label_color or color, bold=True)


def connect(x1, y1, x2, y2, color="#ca8a04"):
    out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
               f'stroke-width="1.6" stroke-dasharray="4 3"/>')


def band(x, y, w, kind, title, lines):
    """枠いっぱいの注意書き（Stop フックの説明など）。"""
    return box(x, y, w, kind, title, lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "docs", "images", "test_pipeline_overview.svg"))
    args = ap.parse_args()

    cx = MAIN_X + MAIN_W / 2       # 主フローの中心線
    y = 96

    # ── ヘッダ ──
    text(30, 40, "WordStock テスト自動生成 全体図", 22, "#111827", bold=True)
    text(30, 64, "ユーザー入力から Excel 項目書の生成・セッション破棄まで ／ "
                 "Skill・サブエージェント・Hooks の発火位置つき", 12, "#6b7280")
    text(30, 82, "定義の正: .claude/skills/test-loop/SKILL.md ・ .claude/settings.json　｜　"
                 "解説: docs/development/test_loop_pipeline.md ・ docs/development/hooks.md　｜　"
                 "この図は scripts/gen_pipeline_svg.py で生成（直接編集しない）",
         11, "#9ca3af")

    # ── 凡例 ──
    lg_h = 22 + 16 * len(LEGEND)
    out.append(f'<rect x="{W - 262}" y="8" width="242" height="{lg_h}" rx="8" '
               f'fill="#fcfcfd" stroke="#e5e7eb"/>')
    for i, (kind, label) in enumerate(LEGEND):
        fill, stroke, _ = STYLE[kind]
        ly = 14 + 16 * i
        out.append(f'<rect x="{W - 250}" y="{ly}" width="20" height="11" rx="3" '
                   f'fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
        text(W - 222, ly + 9, label, 10.5, "#374151")

    # ══ 1. 入口 ══
    h = box(MAIN_X, y, MAIN_W, "user", "👤 ユーザー入力",
            ["「テストケースを作成して」とチャットに入力",
             "一部のファイルだけを依頼することもできる（→ 手順1 の範囲宣言）"])
    arrow(cx, y + h, y + h + 30); y += h + 30

    h = box(MAIN_X, y, MAIN_W, "note", "セッション開始時に完了していること",
            ["CLAUDE.md が自動でコンテキストに読み込まれる（Claude Code の標準動作）",
             "全 Skill の name + description 一覧も同時に読み込まれる（本体はまだ）",
             "settings.json の hooks が登録される（Stop フックもここで有効化）"],
            dashed=True)
    arrow(cx, y + h, y + h + 30); y += h + 30

    h = box(MAIN_X, y, MAIN_W, "main", "🤖 メインエージェント 思考",
            ["CLAUDE.md と Skill 一覧の description から使う Skill を判断する",
             "※ここにフックは介在しない（PreToolUse は「ツール実行の前」）"])
    arrow(cx, y + h, y + h + 30); y += h + 30

    hy = y
    h = box(MAIN_X, y, MAIN_W, "main", "ツール呼び出し: Skill(test-loop)",
            ['tool_name = "Skill"'])
    box(RIGHT_X, hy, RIGHT_W, "hook", "🪝 PreToolUse 関所（matcher 照合）",
        ["Bash? / Agent|Task? / Edit|Write? … いずれにも不一致 ⇒ 素通り",
         "※ここを塞ぐと「手順書を読むのに手順書が要る」循環になるため開放"])
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#dc2626")
    arrow(cx, y + h, y + h + 30); y += h + 30

    fy = y
    h = box(MAIN_X, y, MAIN_W, "skill", "📘 SKILL: test-loop",
            [".claude/skills/test-loop/SKILL.md の手順書がコンテキストに入る",
             "Tier 順の消化 / 進捗管理 / 差し戻し基準 / Excel 生成までの流れを規定"])
    fh = box(LEFT_X, fy, LEFT_W, "file", "読み込み", [".test_loop/state.json（あれば）"],
             mono_lines=True)
    connect(LEFT_X + LEFT_W, fy + fh / 2, MAIN_X, fy + 25)
    arrow(cx, y + h, y + h + 30); y += h + 30

    # ══ 2. 手順1: 範囲宣言 ══
    sy = y
    h = box(MAIN_X, y, MAIN_W, "main", "手順1: 範囲宣言（部分依頼のときだけ）",
            ["python3 scripts/loop_state.py start-session --scope <lib パス...>",
             "宣言しないと Stop フックが全対象（is_target 全件）の消化を要求する",
             "全体依頼なら不要。途中からは loop_state.py scope <パス...>"])
    fh = box(LEFT_X, sy, LEFT_W, "file", "生成", [".test_loop/state.json",
                                                  "  scope / done / inner / outer"],
             mono_lines=True)
    connect(LEFT_X + LEFT_W, sy + fh / 2, MAIN_X, sy + 25)
    arrow(cx, y + h, y + h + 56); y += h + 56

    # ══ 個別ループ枠 ══
    loop_top = y - 40
    h = box(MAIN_X, y + 52, MAIN_W, "main", "手順2: 計画",
            ["scope（無ければ全対象）のうち done に無い最上位 Tier を 1 つ選ぶ",
             "Tier1 sync/repositories → Tier2 view_model/use_cases →",
             "Tier3 entities/utils → Tier4 page（Widget テスト）",
             "承認済み仕様書（status: approved・targets に対象）を探し、",
             "章ごとの振り分けで担当する仕様 ID を決める（3章→Widget / 4章→ViewModel …）",
             "既存テストがあれば先にハーネスを回し、loop_state.py can-skip で判定する",
             "　→「飛ばしてよい」なら手順3〜6を飛ばして手順7へ（2回目の実行で成果物を変えないため）"])
    fh = box(LEFT_X, y + 52, LEFT_W, "file", "読み込み（あれば）",
             ["docs/detailed_design/**/*.md", "  （approved の仕様書のみ）"],
             mono_lines=True)
    connect(LEFT_X + LEFT_W, y + 52 + fh / 2, MAIN_X, y + 52 + 25)
    y += 52
    loop_entry = y          # 「次の対象へ」の戻り先
    arrow(cx, y + h, y + h + 30); y += h + 30

    step2_y = y             # continue 差し戻しの戻り先（手順3）
    hy = y
    h = box(MAIN_X, y, MAIN_W, "main", "手順3: エージェント起動（Agent ツール）",
            ["直前に loop_state.py begin-attempt <lib パス>（外部ループ +1 / 内部 0）",
             "Tier1〜3 → test-unit-test-generator / Tier4 → test-widget-test-generator",
             "プロンプトには対象ファイルパスを 1 つだけ渡す",
             "仕様書があれば、仕様書のパスと担当する仕様 ID も渡す",
             "「期待値は仕様書から作る。コードは呼び出し方を知るためだけに読む」"])
    box(RIGHT_X, hy, RIGHT_W, "hook", '🪝 PreToolUse  matcher="Agent|Task"',
        ["scripts/hooks/require_test_loop_skill.sh",
         "transcript の JSONL を grep → test-loop 読込済か判定",
         "  ✅ 痕跡あり → 素通り　／　🚫 痕跡なし → deny「先に SKILL.md を読め」",
         "※ transcript が読めなければフェイルオープン（通す）"])
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#dc2626")
    arrow(cx, y + h, y + h + 30); y += h + 30

    hy = y
    h = box(MAIN_X, y, MAIN_W, "agent",
            "手順4: テスト生成 🟩 SUBAGENT",
            ["test-unit-test-generator / test-widget-test-generator",
             "参照 Skill: 📘 unit-test-authoring / 📘 widget-test-authoring",
             "　　　　　  📘 excel-testdoc-authoring（項目書 MD のフォーマット規約）",
             "テストコードと項目書 MD を必ずペアで生成する",
             "項目書の「仕様ID」列に、各テストケースが引用する仕様 ID を書く"])
    rh = box(RIGHT_X, hy, RIGHT_W, "hook", '🪝 PreToolUse  matcher="Edit|Write"',
             ["scripts/hooks/block_generated_file_edit.sh",
              "*.freezed.dart / *.g.dart / router.g.dart への書込を deny",
              "★ .test_loop/ 配下への書込も deny（ステート捏造の封鎖）"])
    fh = box(LEFT_X, hy, LEFT_W, "file", "生成物",
             ["test/**/*_test.dart", "test/test_cases/**/*_test_cases.md"],
             mono_lines=True)
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#dc2626")
    connect(LEFT_X + LEFT_W, hy + fh / 2, MAIN_X, hy + 25)
    arrow(cx, y + h, y + h + 30); y += h + 30

    hy = y
    h = box(MAIN_X, y, MAIN_W, "agent", "手順5: 実行（サブエージェント自身がハーネスを回す）",
            ["bash scripts/test_harness.sh <生成したテストファイルパス>",
             "内部ループは harness_report.py が record_run() で自動カウント（回避不可）",
             "カウントは test-loop のセッション中だけ。セッションが無いとき",
             "（動作確認など）はステートを作らず、Stop フックも動かない"])
    box(RIGHT_X, hy, RIGHT_W, "hook", '🪝 PreToolUse  matcher="Bash"',
        ["scripts/hooks/block_direct_flutter_test.sh",
         "`fvm flutter test` / `flutter test` の直叩きを deny → ハーネス経由を強制"])
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#dc2626")
    arrow(cx, y + h, y + h + 30); y += h + 30

    hy = y
    h = box(MAIN_X, y, MAIN_W, "script", "⚙ scripts/test_harness.sh",
            ["fvm flutter test --coverage --machine  →  scripts/harness_report.py",
             "限定分母でフィルタ / テスト漏れ（untested_files）検出 / JSON レポート出力",
             "harness_report.py が loop_state.compute_verdict() を呼び判定を書き込む",
             "仕様書がある対象は、項目書の仕様ID列を仕様書と突き合わせる",
             "（テストの無い ID・境界値の不足 → 「仕様漏れ」の警告。判定には影響しない）"])
    fh = box(LEFT_X, hy, LEFT_W, "file", "出力",
             ["coverage/lcov.info", "coverage/lcov.filtered.info",
              "coverage/harness_report.json", "coverage/test_machine.jsonl"],
             mono_lines=True)
    connect(LEFT_X + LEFT_W, hy + fh / 2, MAIN_X, hy + 25)
    arrow(cx, y + h, y + h + 30); y += h + 30

    # ── 手順6: 判定 ──
    dy = y
    h = box(MAIN_X, y, MAIN_W, "decision",
            "手順6: 判定 ◆ harness_report.json の loop.verdict は？",
            ["stop  → 手順7 へ（カバレッジ達成 / 未カバー行に理由あり /",
             "　　　　 失敗が記録済みのバグだけ / 上限到達）",
             "continue → 差し戻して手順3〜5 を反復",
             "上限は内部3回・外部3回。まず目標に達したかを判定し、continue の",
             "ときだけ上限を当てはめて stop に変える（目標達成の stop は上書きしない）",
             "※ ループの継続/終了は LLM が判断しない。回数も数えない"],
            dashed=True)
    bh = box(LEFT_X, dy, LEFT_W, "bug", "🐞 プロダクションコードのバグ",
             ["仕様書どおりの期待値で落ちた",
              "→ 期待値もコードも直さない",
              "loop_state.py bug で記録",
              "（症状の先頭に仕様 ID を書く）",
              "→ 再実行すると、その ID の失敗は",
              "　 判定から除外されて stop",
              "→ skipped にして次の対象へ"])
    connect(LEFT_X + LEFT_W, dy + bh / 2, MAIN_X, dy + 25)
    # continue の差し戻し（手順3 のエージェント起動へ戻る）
    out.append(f'<polyline points="{MAIN_X},{dy + 25} {MAIN_X - 20},{dy + 25} '
               f'{MAIN_X - 20},{step2_y + 25} {MAIN_X},{step2_y + 25}" fill="none" '
               f'stroke="#b91c1c" stroke-width="2" stroke-dasharray="6 4" '
               f'marker-end="url(#ahr)"/>')
    text(MAIN_X - 26, (dy + step2_y) / 2 - 8, "continue →",
         11, "#b91c1c", bold=True, anchor="end")
    text(MAIN_X - 26, (dy + step2_y) / 2 + 8, "手順3〜5 を反復",
         11, "#b91c1c", bold=True, anchor="end")
    arrow(cx, y + h, y + h + 34, "#047857", "stop", "#047857"); y += h + 34

    # ── 手順7: 記録 ──
    ry = y
    h = box(MAIN_X, y, MAIN_W, "main", "手順7: 記録",
            ["python3 scripts/loop_state.py finish <lib パス> --status done",
             "（または --status skipped --reason ...）"])
    fh = box(LEFT_X, ry, LEFT_W, "file", "更新",
             [".test_loop/state.json（done / skipped）",
              "test/coverage_exclusions.txt"], mono_lines=True)
    connect(LEFT_X + LEFT_W, ry + fh / 2, MAIN_X, ry + 25)
    # 次の対象へ戻る
    out.append(f'<polyline points="{MAIN_X + MAIN_W},{ry + 25} {MAIN_X + MAIN_W + 18},{ry + 25} '
               f'{MAIN_X + MAIN_W + 18},{loop_entry - 18} {cx},{loop_entry - 18} '
               f'{cx},{loop_entry - 4}" fill="none" stroke="#1d4ed8" stroke-width="2" '
               f'stroke-dasharray="6 4" marker-end="url(#ahb)"/>')
    text(cx + 18, loop_entry - 24, "次の対象へ（scope の数だけ反復）", 11, "#1d4ed8", bold=True)
    y += h
    loop_bottom = y + 14

    # 個別ループ枠（背面に置くため後で先頭へ差し込む）
    loop_frame = (f'<rect x="{MAIN_X - 35}" y="{loop_top}" width="{MAIN_W + 70}" '
                  f'height="{loop_bottom - loop_top}" rx="14" fill="#f8fafc" '
                  f'stroke="#94a3b8" stroke-width="2.5" stroke-dasharray="10 6"/>'
                  f'<text x="{MAIN_X - 19}" y="{loop_top + 22}" font-family="{JP}" '
                  f'font-size="14" font-weight="700" fill="#475569">'
                  f'個別ループ（手順2〜7）</text>'
                  f'<text x="{MAIN_X - 19}" y="{loop_top + 40}" font-family="{JP}" '
                  f'font-size="11.5" fill="#64748b">'
                  f'対象ファイル1つあたり</text>')

    arrow(cx, loop_bottom, loop_bottom + 44, "#047857",
          "scope の全対象が done / skipped", "#047857")
    y = loop_bottom + 44

    # ══ 仕上げ工程 ══
    fin_top = y - 12
    y += 34

    hy = y
    h = box(MAIN_X, y, MAIN_W, "script", "手順8: 全体回帰",
            ["bash scripts/test_harness.sh（引数なし = test/ 全体）を 1 回だけ実行",
             "再実行・差し戻しはしない（非 0 でも次へ）。問題は Excel の要確認一覧へ",
             "全体カバレッジは ⚠ 表示のみ（合否に使わない）／ verdict は n/a",
             "例外: 手順9・10でテストコードを直したら、手順11の直前にもう 1 回だけ実行する"])
    box(RIGHT_X, hy, RIGHT_W, "hook", '🪝 PreToolUse  matcher="Bash"',
        ["block_direct_flutter_test.sh → ハーネス経由なので ✅通過"])
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#dc2626")
    arrow(cx, y + h, y + h + 30); y += h + 30

    hy = y
    h = box(MAIN_X, y, MAIN_W, "agent", "手順9: 🟩 SUBAGENT: architecture-guard",
            ["生成したテストコードの CLAUDE.md 規約違反をレビュー（読み取り専用）"])
    box(RIGHT_X, hy, RIGHT_W, "hook", '🪝 PreToolUse  matcher="Agent|Task"',
        ["require_test_loop_skill.sh は発火するが subagent_type が",
         "test-* 3兄弟でないため 2段目のふるいで即 exit 0（素通り）"])
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#dc2626")
    arrow(cx, y + h, y + h + 30); y += h + 30

    h = box(MAIN_X, y, MAIN_W, "main", "手順10: 網羅性・必要性の自己監査（メインが実施）",
            ["正常系/異常系/境界値の欠落・重複・無価値テスト・対象外理由の妥当性を点検",
             "仕様書がある対象: 引用した ID の条件と期待される動作をすべて確かめているか、",
             "期待値をコードの動作に寄せていないか、仕様書にない操作手段を使っていないか",
             "指摘は該当サブエージェントへ差し戻して修正"])
    arrow(cx, y + h, y + h + 30); y += h + 30

    hy = y
    h = box(MAIN_X, y, MAIN_W, "agent", "手順11: 🟩 SUBAGENT: test-doc-excel-generator",
            ["参照 Skill: 📘 excel-testdoc-authoring",
             "入力: test/test_cases/**/*.md + harness_report.json + .test_loop/state.json",
             "手順8〜10で問題が残っていても必ず実行する"])
    box(RIGHT_X, hy, RIGHT_W, "hook", '🪝 PreToolUse  matcher="Agent|Task"',
        ["require_test_loop_skill.sh → test-* 3兄弟に該当",
         "→ transcript 判定 → ✅通過"])
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#dc2626")
    arrow(cx, y + h, y + h + 30); y += h + 30

    ey = y
    h = box(MAIN_X, y, MAIN_W, "script", "⚙ scripts/gen_test_excel.py",
            ["対象限定は --only <対象ファイル>（scope 付きセッションでは必ず渡す）",
             "★ wb.save() 成功直後に loop_state.mark_completed() を呼ぶ",
             "　 → state.json に completed_at / excel_path を記録（工程完了の唯一の証拠）"])
    fh = box(LEFT_X, ey, LEFT_W, "file", "最終成果物",
             ["~/Desktop/",
              "WordStock_テスト項目書_YYYYMMDD.xlsx",
              "（要確認一覧: 理由なし未達 / バグ /",
              " テスト失敗 / テスト漏れ は赤字）",
              "（仕様との対応: 仕様 ID ごとの",
              " テスト件数と OK / NG）"], mono_lines=True)
    connect(LEFT_X + LEFT_W, ey + fh / 2, MAIN_X, ey + 25)
    arrow(cx, y + h, y + h + 30); y += h + 30

    hy = y
    h = box(MAIN_X, y, MAIN_W, "main", "手順12: セッション破棄",
            ["python3 scripts/loop_state.py end-session",
             "→ .test_loop/state.json を削除（後片付け）"])
    box(RIGHT_X, hy, RIGHT_W, "stop", "🚧 end-session 側の関所（loop_state.py）",
        ["completed_at なし → 非 0 で拒否（先に手順11 を実行させる）",
         "completed_at あり → 削除を許可",
         "--force で強制破棄（警告つき。緊急脱出用）",
         "※ Stop フックは「state.json が無い＝工程外」で通すため、ここを",
         "　 塞がないと『end-session を打てば終われる』近道が残る"])
    connect(MAIN_X + MAIN_W, hy + 25, RIGHT_X, hy + 25, "#be123c")
    arrow(cx, y + h, y + h + 30); y += h + 30
    fin_bottom = y - 16

    fin_frame = (f'<rect x="{MAIN_X - 35}" y="{fin_top}" width="{MAIN_W + 70}" '
                 f'height="{fin_bottom - fin_top}" rx="14" fill="#f0fdf4" '
                 f'stroke="#86efac" stroke-width="2.5" stroke-dasharray="10 6"/>'
                 f'<text x="{MAIN_X - 19}" y="{fin_top + 22}" font-family="{JP}" '
                 f'font-size="14" font-weight="700" fill="#15803d">'
                 f'仕上げ工程（手順8〜12）</text>'
                 f'<text x="{MAIN_X - 19}" y="{fin_top + 40}" font-family="{JP}" '
                 f'font-size="11.5" fill="#16a34a">'
                 f'全対象の消化後に1回だけ</text>')

    h = box(MAIN_X, y, MAIN_W, "user", "👤 最終報告",
            ["生成ファイル数 / 要確認（区分別の件数と対象）/ 対象外にしたファイル・行 /",
             "レビュー指摘と対応 / Excel パス / 全体カバレッジ（参考値）"])
    y += h + 40

    # ══ Stop フックの説明（全ターン共通なので独立したバンドで説明）══
    stop_y = y
    h = band(LEFT_X, stop_y, W - 40, "stop",
             "🚧 Stop フック: scripts/hooks/require_test_loop_completion.py"
             "（上図の“どの段階でも”、メインがターンを終えようとするたびに発火）",
             ["解除条件 …… ① .test_loop/state.json が無い（テスト工程外）　"
              "② state.json に completed_at が立っている（Excel 生成済み）",
              "　　　　　　 ※ セッション外で動作確認のためにハーネスを回しても state.json は作られない（① のまま通る）",
              "拒否する場合 … ・進行中の対象の verdict が continue → reason を次ターンの指示として返す",
              "　　　　　　　  ・verdict が stop なのに finish 未実行 → 手順7 を促す",
              "　　　　　　　  ・scope（未設定なら全対象）に未消化が残っている → 手順2 へ戻す",
              "　　　　　　　  ・全対象 done だが completed_at 無し → 手順8〜12 を促す",
              "無限ループ対策 … 進捗指紋（inner/outer・done 件数・harness_report.json の mtime）が"
              "3 回連続で変化しなければ解除して制御を返す",
              "　　　　　　　　 セッション通算 60 回でも解除。例外・ステート破損はすべてフェイルオープン（通す）",
              "狙い …… SKILL.md「大原則: テスト工程は必ず最後（Excel 生成）までやり切る」を"
              "自然言語のお願いから機構に変える"])
    y = stop_y + h + 24

    height = int(y)
    defs = (
        '<defs>'
        '<marker id="ah" markerWidth="10" markerHeight="8" refX="9" refY="4" '
        'orient="auto"><path d="M0,0 L10,4 L0,8 z" fill="#374151"/></marker>'
        '<marker id="ahr" markerWidth="10" markerHeight="8" refX="9" refY="4" '
        'orient="auto"><path d="M0,0 L10,4 L0,8 z" fill="#b91c1c"/></marker>'
        '<marker id="ahb" markerWidth="10" markerHeight="8" refX="9" refY="4" '
        'orient="auto"><path d="M0,0 L10,4 L0,8 z" fill="#1d4ed8"/></marker>'
        '</defs>'
    )
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{height}" '
           f'viewBox="0 0 {W} {height}">{defs}'
           f'<rect x="0" y="0" width="{W}" height="{height}" fill="#ffffff"/>'
           f'{loop_frame}{fin_frame}' + "".join(out) + '</svg>')

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(svg)
    print(f"✅ {args.out}  ({W}x{height}, {len(svg):,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
