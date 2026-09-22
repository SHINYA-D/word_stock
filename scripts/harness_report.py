#!/usr/bin/env python3
"""テストハーネスのレポート生成 + カバレッジフィルタ。

`scripts/test_harness.sh` から呼ばれる。以下を行う:

1. `fvm flutter test --machine` の JSON イベント列を解析し、pass/fail/skip を集計
2. `coverage/lcov.info` を「限定分母」（下記 is_target）でフィルタし
   `coverage/lcov.filtered.info` を書き出す
3. ファイル別カバレッジ表と全体カバレッジを stdout に出力
4. `is_target()` の全対象ファイル（ディスク上）と lcov を突き合わせ、
   テストも対象外登録も無いファイル（= テスト漏れ）を検出
5. パス指定実行（= 1対象のループ中）なら `loop_state` でハーネス実行を内部試行として
   記録し、ループ継続判定（continue / stop）を算出する
6. `coverage/harness_report.json` に機械可読なレポートを書き出す
   （ループ Skill / test-doc-excel-generator が読む）

終了コード:
- テスト失敗が 1 件でもあれば非 0
- パス引数なし（= test/ 全体実行）かつテスト漏れ（untested_files）が 1 件以上で非 0
- 限定分母の全体カバレッジが閾値未満（HARNESS_COVERAGE_MIN、デフォルト 90.0）は
  ⚠ 表示のみで終了コードには影響しない。未カバー行の正当な理由は項目書 MD の
  「## 対象外」に記録される運用で、このスクリプトはそれを計算に反映できないため
  （90% 未満のファイルと理由の有無は Excel の「要確認一覧」シートで確認する）
- テスト対象外登録は test/coverage_exclusions.txt（HARNESS_EXCLUSIONS で変更可）
- `loop.verdict` は「次に何をするか」の指示であって合否ではない。終了コードには影響しない
  （カバレッジをハードゲート化すると水増しテストを誘発するため）
"""

from __future__ import annotations

import glob
import json
import os
import sys
from datetime import datetime, timezone

import loop_state

COVERAGE_MIN = float(os.environ.get("HARNESS_COVERAGE_MIN", "90.0"))

# 単体テスト対象（is_target=True）なのにテストを書かないと決めたファイルの登録簿。
# 形式は 1 行 1 ファイルで  "<lib/ からのパス> | <理由>"。
# ここに無く、かつどのテストからも読み込まれないファイルがあると
# 全体実行時にゲート失敗（テスト漏れ）とする。
EXCLUSIONS_PATH = os.environ.get(
    "HARNESS_EXCLUSIONS", "test/coverage_exclusions.txt"
)


def is_target(path: str) -> bool:
    """限定分母（カバレッジ計測対象）かどうか。

    プラン「決定事項 > カバレッジ」に対応。生成ファイル・UI・Mock は除外。
    """
    p = path.replace("\\", "/")
    if not p.startswith("lib/"):
        return False
    if p.endswith(".freezed.dart") or p.endswith(".g.dart"):
        return False
    if "/mock/" in p:
        return False
    if p == "lib/main.dart" or p.endswith("firebase_options.dart"):
        return False

    if p.startswith("lib/presentation/"):
        # Presentation 層はロジックを持つ ViewModel のみが対象。
        return p.endswith("_view_model.dart")
    return (
        p.startswith("lib/domain/entities/")
        or p.startswith("lib/application/use_cases/")
        or p.startswith("lib/infrastructure/repositories/")
        or p.startswith("lib/infrastructure/sync/")
        or p.startswith("lib/infrastructure/data_sources/local/")
        or p.startswith("lib/core/utils/")
    )


def enumerate_target_files() -> list[str]:
    """`is_target()` が True になる lib/ 配下の .dart ファイル一覧。

    lcov.info（= 実行されたファイル）ではなくディスク上の実ファイルを見る。
    「単体テストがあるべきファイル」の正式リストであり、これと lcov を
    突き合わせて『テストが 1 つも無いファイル』を炙り出す。
    """
    return sorted(
        p.replace("\\", "/")
        for p in glob.glob("lib/**/*.dart", recursive=True)
        if is_target(p.replace("\\", "/"))
    )


def load_exclusions(path: str = EXCLUSIONS_PATH) -> dict[str, str]:
    """テスト対象外として登録されたファイル {パス: 理由}。"""
    out: dict[str, str] = {}
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            p, _, reason = line.partition("|")
            out[p.strip().replace("\\", "/")] = reason.strip()
    return out


# --------------------------------------------------------------------------- #
# テスト結果（--machine JSON）
# --------------------------------------------------------------------------- #
def test_file_rel(path: str) -> str:
    """絶対パスのテストファイルを `test/...` 形式にそろえる。"""
    p = (path or "").replace("\\", "/")
    i = p.find("test/")
    return p[i:] if i != -1 else p


def parse_test_events(jsonl_path: str) -> dict:
    tests: dict[int, dict] = {}
    suites: dict[int, str] = {}  # suiteID → テストファイルパス（失敗の所在を示すため）
    if not os.path.exists(jsonl_path):
        return {"total": 0, "passed": 0, "failed": 0, "skipped": 0, "failures": []}

    with open(jsonl_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or not line.startswith("{"):
                continue
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            t = ev.get("type")
            if t == "suite":
                suite = ev.get("suite", {})
                suites[suite.get("id")] = suite.get("path") or ""
            elif t == "testStart":
                info = ev["test"]
                # group / loading 系の隠しテストは除外
                if info.get("name", "").startswith("loading /"):
                    continue
                tests[info["id"]] = {"name": info.get("name", "?"), "result": None,
                                     "message": "",
                                     "file": suites.get(info.get("suiteID"), "")}
            elif t == "testDone":
                tid = ev.get("testID")
                if tid in tests:
                    if ev.get("hidden"):
                        tests.pop(tid, None)
                        continue
                    tests[tid]["result"] = (
                        "skipped" if ev.get("skipped") else ev.get("result", "error")
                    )
            elif t == "error":
                tid = ev.get("testID")
                if tid in tests:
                    tests[tid]["message"] = (ev.get("error", "") or "")[:500]

    passed = failed = skipped = 0
    failures = []
    for info in tests.values():
        r = info["result"]
        if r == "success":
            passed += 1
        elif r == "skipped":
            skipped += 1
        else:
            failed += 1
            failures.append({"name": info["name"], "message": info["message"],
                             "file": test_file_rel(info["file"])})
    return {
        "total": passed + failed + skipped,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "failures": failures,
    }


# --------------------------------------------------------------------------- #
# カバレッジ（lcov.info）
# --------------------------------------------------------------------------- #
def parse_lcov(lcov_path: str):
    """SF レコードごとに {path, da: {line: hits}} を返す。"""
    records = []
    if not os.path.exists(lcov_path):
        return records
    cur = None
    with open(lcov_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:"):
                cur = {"path": line[3:].replace("\\", "/"), "da": {}}
            elif line.startswith("DA:") and cur is not None:
                ln, hits = line[3:].split(",")[:2]
                cur["da"][int(ln)] = cur["da"].get(int(ln), 0) + int(hits)
            elif line == "end_of_record" and cur is not None:
                records.append(cur)
                cur = None
    return records


def normalize(path: str) -> str:
    p = path.replace("\\", "/")
    i = p.find("lib/")
    return p[i:] if i != -1 else p


def build_coverage(lcov_path: str, filtered_out_path: str):
    records = parse_lcov(lcov_path)
    files = []
    total_found = total_hit = 0
    lines_out = []
    for rec in records:
        rel = normalize(rec["path"])
        if not is_target(rel):
            continue
        found = len(rec["da"])
        hit = sum(1 for h in rec["da"].values() if h > 0)
        uncovered = sorted(ln for ln, h in rec["da"].items() if h == 0)
        total_found += found
        total_hit += hit
        pct = round(100.0 * hit / found, 1) if found else 100.0
        files.append({
            "path": rel, "pct": pct, "found": found, "hit": hit,
            "uncovered_lines": uncovered,
        })
        lines_out.append(f"SF:{rel}")
        for ln in sorted(rec["da"]):
            lines_out.append(f"DA:{ln},{rec['da'][ln]}")
        lines_out.append(f"LF:{found}")
        lines_out.append(f"LH:{hit}")
        lines_out.append("end_of_record")

    os.makedirs(os.path.dirname(filtered_out_path), exist_ok=True)
    with open(filtered_out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines_out) + ("\n" if lines_out else ""))

    files.sort(key=lambda x: (x["pct"], x["path"]))
    overall = round(100.0 * total_hit / total_found, 1) if total_found else 0.0
    return {
        "overall_pct": overall,
        "lines_found": total_found,
        "lines_hit": total_hit,
        "threshold": COVERAGE_MIN,
        "files": files,
    }


# --------------------------------------------------------------------------- #
def main() -> int:
    jsonl_path = sys.argv[1] if len(sys.argv) > 1 else "coverage/test_machine.jsonl"
    lcov_path = sys.argv[2] if len(sys.argv) > 2 else "coverage/lcov.info"
    test_paths = sys.argv[3:]
    gate_overall = len(test_paths) == 0

    tests = parse_test_events(jsonl_path)
    coverage = build_coverage(lcov_path, "coverage/lcov.filtered.info")
    coverage["gate_applied"] = gate_overall

    # ---- テスト漏れ検出 ------------------------------------------------- #
    # 「あるべき対象ファイル」（ディスク上）と「テストが読み込んだ対象ファイル」
    # （lcov.info）と「対象外登録」を突き合わせ、どこにも属さないファイル＝
    # テストも除外理由も無いファイルを漏れとして扱う。
    target_files = enumerate_target_files()
    tested_files = {f["path"] for f in coverage["files"]}
    exclusions = load_exclusions()
    untested = [
        p for p in target_files
        if p not in tested_files and p not in exclusions
    ]
    stale_exclusions = sorted(
        p for p in exclusions
        if p in tested_files or p not in target_files or not os.path.exists(p)
    )
    coverage["target_file_count"] = len(target_files)
    coverage["untested_files"] = untested
    coverage["exclusions"] = [
        {"path": p, "reason": exclusions[p]} for p in sorted(exclusions)
    ]
    coverage["stale_exclusions"] = stale_exclusions

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "paths": test_paths,
        "tests": tests,
        "coverage": coverage,
    }

    # ---- ループ継続判定 --------------------------------------------------- #
    # パス指定実行（= 1対象のループ中）のときだけ、この実行を内部試行として数え、
    # continue / stop を算出する。全体実行では n/a（何も判断しない）。
    loop_target = (
        loop_state.resolve_target(test_paths, target_files) if test_paths else None
    )
    if loop_target:
        state = loop_state.record_run(loop_target)
    else:
        state = loop_state.load_state(create=False)
    report["loop"] = loop_state.compute_verdict(
        report, loop_target, state,
        in_denominator=bool(loop_target) and loop_target in target_files,
    )

    # ---- 仕様書との突き合わせ（警告のみ。合否・verdict には使わない） ------- #
    if loop_target:
        sc = loop_state.spec_coverage(loop_target)
        report["spec"] = sc
        warning = loop_state.format_spec_warning(sc) if sc else None
        if warning:
            report["loop"]["warnings"].append(warning)

    with open("coverage/harness_report.json", "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    # ---- stdout レポート -------------------------------------------------- #
    print()
    print("=" * 70)
    print(f"  テスト: {tests['passed']} passed / {tests['failed']} failed / "
          f"{tests['skipped']} skipped  (計 {tests['total']})")
    for fl in tests["failures"]:
        print(f"    ✗ {fl['name']}")
        if fl["message"]:
            first = fl["message"].splitlines()[0]
            print(f"        {first}")
    print("-" * 70)
    print(f"  限定分母カバレッジ: {coverage['overall_pct']}%  "
          f"({coverage['lines_hit']}/{coverage['lines_found']} 行, 閾値 {COVERAGE_MIN}%)")
    for fl in coverage["files"]:
        flag = "  " if fl["pct"] >= COVERAGE_MIN else "⚠ "
        unc = ""
        if fl["uncovered_lines"]:
            preview = ", ".join(map(str, fl["uncovered_lines"][:12]))
            more = " …" if len(fl["uncovered_lines"]) > 12 else ""
            unc = f"  未カバー行: {preview}{more}"
        print(f"    {flag}{fl['pct']:5.1f}%  {fl['path']}{unc}")
    print("-" * 70)
    print(f"  単体テスト対象: {coverage['target_file_count']} 件 / "
          f"テスト到達 {len(tested_files)} 件 / 対象外登録 {len(exclusions)} 件")
    if untested:
        print(f"  ❌ テスト漏れ（対象なのにテストも対象外登録も無い）: {len(untested)} 件")
        for p in untested:
            print(f"       - {p}")
        print("     → テストを書くか test/coverage_exclusions.txt に")
        print("       「<パス> | <理由>」を追記してください")
    if stale_exclusions:
        print(f"  ⚠ 不要な対象外登録（テスト追加済み or ファイル消滅）: "
              f"{len(stale_exclusions)} 件")
        for p in stale_exclusions:
            print(f"       - {p}")
        print("     → test/coverage_exclusions.txt から削除してください")
    if report["loop"]["verdict"] != "n/a":
        print("-" * 70)
        print(loop_state.format_loop(report["loop"]))
    print("=" * 70)
    print("  → coverage/harness_report.json / coverage/lcov.filtered.info")
    print()

    # ---- 終了コード ---------------------------------------------------- #
    failed = tests["failed"] > 0
    cov_low = gate_overall and coverage["overall_pct"] < COVERAGE_MIN
    leak_fail = gate_overall and len(untested) > 0
    if cov_low:
        print(f"⚠ 全体カバレッジが閾値 {COVERAGE_MIN}% 未満（合否には影響しない。"
              "90% 未満のファイルは項目書の「## 対象外」の理由を確認すること）")
    if failed:
        print("結果: ❌ テスト失敗あり")
    elif leak_fail:
        print("結果: ❌ テスト漏れあり")
    else:
        print("結果: ✅ PASS")
    return 1 if (failed or leak_fail) else 0


if __name__ == "__main__":
    sys.exit(main())
