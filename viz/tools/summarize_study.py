"""Generate docs/evidence/viz_numbers.md from a study's CSV products (plan v0.2 §C).

Only copies values out of summary.csv / comparability.csv / status.csv; it never
recomputes or reorders methods as a ranking.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
METHODS = ("DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE")


def sha256(path: Path) -> str | None:
    if not path.is_file():
        return None
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def git_sha() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=REPO_ROOT, capture_output=True, text=True, check=True
        )
        return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def read_csv(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    with path.open("r", encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


def fmt(value: str | None, digits: int = 6) -> str:
    if value in (None, "", "NaN"):
        return "n/a"
    try:
        return f"{float(value):.{digits}g}"
    except ValueError:
        return str(value)


def build_section(
    study: Path, case: str, mode: str, seed: int, window: str, note: str | None
) -> str:
    summary = read_csv(study / "summary.csv")
    comparability = read_csv(study / "comparability.csv")
    status_rows = read_csv(study / "status.csv")

    rows = [
        r
        for r in summary
        if r.get("case_id") == case
        and r.get("estimator_mode") == mode
        and r.get("seed") == str(seed)
        and r.get("window") == window
    ]
    rows.sort(key=lambda r: (METHODS.index(r["method"]) if r.get("method") in METHODS else 99,
                             r.get("load_fraction", "")))

    comp = next(
        (r for r in comparability if r.get("case_id") == case and r.get("estimator_mode") == mode),
        None,
    )
    comp_status = comp.get("comparability", "unknown") if comp else "unknown"
    run_status = {
        r.get("method"): r.get("status", "unknown")
        for r in status_rows
        if r.get("case_id") == case and r.get("estimator_mode") == mode and r.get("seed") == str(seed)
    }

    found = [m for m in METHODS if m in {r.get("method") for r in rows}]
    missing = [m for m in METHODS if m not in found]
    loads = sorted({r.get("load_fraction", "") for r in rows})

    lines = [
        f"## {case} / {mode} / s{seed} — `{window}` window",
        "",
        f"- 方法覆盖：**{len(found)}/{len(METHODS)}**"
        + (f"（缺 {', '.join(missing)}）" if missing else "（5 个方法齐全）"),
        f"- comparability：`{comp_status}`（原样引用 comparability.csv，非本工具计算）",
        "- 窗口：`summary.csv` 的 `window` 列；本表不重采样、不排序、不打分。",
        "",
    ]
    if len(loads) > 1:
        lines.append("| method | load_fraction | saturation_percent | attitude_peak_deg | position_peak_m | "
                     "estimated_attitude_rmse_deg | estimated_position_rmse_m | run_status |")
        lines.append("|---|---|---|---|---|---|---|---|")
        for r in rows:
            lines.append(
                f"| {r['method']} | {fmt(r.get('load_fraction'), 3)} | "
                f"{fmt(r.get('saturation_percent'))} | {fmt(r.get('attitude_peak_deg'))} | "
                f"{fmt(r.get('position_peak_m'))} | {fmt(r.get('estimated_attitude_rmse_deg'))} | "
                f"{fmt(r.get('estimated_position_rmse_m'))} | {run_status.get(r['method'], 'unknown')} |"
            )
    else:
        lines.append("| method | saturation_percent | attitude_peak_deg | position_peak_m | "
                     "estimated_attitude_rmse_deg | estimated_position_rmse_m | run_status |")
        lines.append("|---|---|---|---|---|---|---|")
        for r in rows:
            lines.append(
                f"| {r['method']} | {fmt(r.get('saturation_percent'))} | "
                f"{fmt(r.get('attitude_peak_deg'))} | {fmt(r.get('position_peak_m'))} | "
                f"{fmt(r.get('estimated_attitude_rmse_deg'))} | "
                f"{fmt(r.get('estimated_position_rmse_m'))} | {run_status.get(r['method'], 'unknown')} |"
            )
    if note:
        lines += ["", note.strip()]
    lines += ["", "<details><summary>来源</summary>", ""]
    for name in ("summary.csv", "comparability.csv", "status.csv"):
        path = study / name
        lines.append(f"- `{path}` sha256=`{sha256(path) or 'missing'}`")
    lines.append(f"- viz repo git sha `{git_sha() or 'unknown'}`")
    lines.append(f"- generated_at `{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}`")
    lines += ["", "</details>", ""]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate docs/evidence/viz_numbers.md from study CSVs")
    ap.add_argument("--study", required=True)
    ap.add_argument("--case", required=True)
    ap.add_argument("--mode", required=True)
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--window", choices=("task", "whole"), default="task")
    ap.add_argument("--out", default=str(REPO_ROOT / "docs" / "evidence" / "viz_numbers.md"))
    ap.add_argument("--append", action="store_true", help="append a section instead of overwriting")
    ap.add_argument("--note", default=None, help="optional paragraph after the table")
    args = ap.parse_args()

    section = build_section(Path(args.study), args.case, args.mode, args.seed, args.window, args.note)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    if args.append and out.is_file():
        text = out.read_text(encoding="utf-8") + "\n" + section
    else:
        header = (
            "# VIZ 汇总数字（生成物）\n\n"
            "> 本文件由 `viz/tools/summarize_study.py` 生成，不要手改；数值来自各 study 的\n"
            "> `summary.csv` / `comparability.csv` / `status.csv`，状态字符串原样引用。\n"
        )
        text = header + "\n" + section
    out.write_text(text, encoding="utf-8", newline="\n")
    print(f"viz_numbers: wrote {out} ({len(text)} chars)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
