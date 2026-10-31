"""Multi-method study discovery, condition checks and summary metrics (plan v0.2 §3).

Definitions are frozen in docs/viz_replay_plan_v0.2.md:

* ``saturation_percent`` mirrors analysis/ca_metrics.m (PWM events at the 40 deg
  limit, 1e-5 deg tolerance);
* ``pwm_total_variation_deg`` mirrors analysis/estimator_feedback_metrics_row.m;
* ``solve_time_p95_ms`` is the plan's own definition (linear percentile);
* window defaults to the ``task`` window from ``summary.csv`` ([6, 16] s).
"""

from __future__ import annotations

import csv
import hashlib
import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

METHODS = ("DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE")
DEFAULT_TASK_WINDOW = (6.0, 16.0)
SATURATION_TOL_DEG = 1e-5

LOG_NAME = re.compile(
    r"^(?P<case>[A-Za-z0-9]+)_(?P<mode>[a-z0-9_]+)_s(?P<seed>\d+)_"
    r"(?P<method>[A-Z][A-Z0-9_]*)_(?P<hash>[0-9a-f]{64})\.mat$"
)


class StudyError(ValueError):
    """Selection or metrics problem; always surfaced as a non-zero exit."""


class MixedConditionError(StudyError):
    """Requested case/mode/seed does not match what the study actually has."""


@dataclass
class StudySelection:
    study_dir: Path
    case: str
    mode: str
    seed: int
    logs: dict[str, Path] = field(default_factory=dict)
    missing_methods: list[str] = field(default_factory=list)


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_log_name(name: str) -> dict | None:
    m = LOG_NAME.match(name)
    if not m:
        return None
    d = m.groupdict()
    d["seed"] = int(d["seed"])
    return d


def _read_csv(path: Path) -> list[dict]:
    try:
        with path.open("r", encoding="utf-8", newline="") as fh:
            return list(csv.DictReader(fh))
    except FileNotFoundError:
        return []


def select_logs(study_dir: str | Path, case: str, mode: str, seed: int) -> StudySelection:
    """Pick exactly one log per method for one (case, mode, seed); never guess."""
    study = Path(study_dir)
    logs_dir = study / "logs"
    if not logs_dir.is_dir():
        raise StudyError(f"study has no logs/ directory: {study}")

    parsed = []
    for p in sorted(logs_dir.glob("*.mat")):
        d = parse_log_name(p.name)
        if d is not None and d["method"] in METHODS:
            parsed.append((p, d))
    if not parsed:
        raise StudyError(f"no <case>_<mode>_s<seed>_<METHOD>_<hash>.mat logs in {logs_dir}")

    cases = sorted({d["case"] for _, d in parsed})
    if case not in cases:
        raise MixedConditionError(f"case {case!r} not found; study cases={cases}")
    modes = sorted({d["mode"] for _, d in parsed if d["case"] == case})
    if mode not in modes:
        raise MixedConditionError(
            f"mode {mode!r} not found for case {case!r}; modes={modes} "
            "(mixed case/mode is rejected, not averaged)"
        )
    seeds = sorted({d["seed"] for _, d in parsed if d["case"] == case and d["mode"] == mode})
    if seed not in seeds:
        raise MixedConditionError(
            f"seed {seed} not found for {case}/{mode}; seeds={seeds} "
            "(mixed seed is rejected, not averaged)"
        )

    exact: dict[str, list[tuple[Path, dict]]] = {}
    for p, d in parsed:
        if d["case"] == case and d["mode"] == mode and d["seed"] == seed:
            exact.setdefault(d["method"], []).append((p, d))

    ambiguous = {m: v for m, v in exact.items() if len(v) > 1}
    if ambiguous:
        detail = "; ".join(f"{m}: {[str(p) for p, _ in v]}" for m, v in ambiguous.items())
        raise StudyError(f"ambiguous duplicate hash for method(s): {detail}")

    missing = [m for m in METHODS if m not in exact]
    if len(exact) < 2:
        raise StudyError(
            f"need at least 2 methods to replay side by side; found {sorted(exact)} "
            f"(missing {missing})"
        )

    return StudySelection(
        study_dir=study,
        case=case,
        mode=mode,
        seed=seed,
        logs={m: exact[m][0][0] for m in METHODS if m in exact},
        missing_methods=missing,
    )


def resolve_window(
    study_dir: str | Path,
    case: str,
    mode: str,
    window: str,
    duration_s: float,
) -> dict:
    """Return the frozen metric window; clamp only the end and record it."""
    if window == "whole":
        start, end, source = 0.0, float(duration_s), "whole"
    else:
        start, end = DEFAULT_TASK_WINDOW
        source = "default_task"
        rows = _read_csv(Path(study_dir) / "summary.csv")
        picked = [
            r
            for r in rows
            if r.get("case_id") == case
            and r.get("estimator_mode") == mode
            and r.get("window") == "task"
        ]
        if picked:
            starts = {float(r["window_start_s"]) for r in picked}
            ends = {float(r["window_end_s"]) for r in picked}
            if len(starts) == 1 and len(ends) == 1:
                start, end = starts.pop(), ends.pop()
                source = "summary.csv"
            else:
                raise StudyError(f"inconsistent task window in summary.csv: {starts} / {ends}")
    if start > duration_s:
        raise StudyError(f"window start {start:g}s is beyond log duration {duration_s:g}s")
    clamped = end > duration_s
    end = min(end, float(duration_s))
    return {
        "name": window,
        "start_s": float(start),
        "end_s": float(end),
        "source": source,
        "clamped": bool(clamped),
    }


def load_comparability(study_dir: str | Path, case: str, mode: str) -> dict:
    """Return the raw comparability status for (case, mode), never computed here."""
    path = Path(study_dir) / "comparability.csv"
    rows = _read_csv(path)
    match = [r for r in rows if r.get("case_id") == case and r.get("estimator_mode") == mode]
    if not rows:
        return {"status": "unknown", "source": {"path": None, "sha256": None}, "note": ""}
    status = match[0].get("comparability", "unknown") if match else "unknown"
    if status in ("", None):
        status = "unknown"
    return {
        "status": status,
        "source": {
            "path": str(path),
            "sha256": _sha256(path) if path.is_file() else None,
        },
        "note": "原样引用 comparability.csv，非本工具计算",
    }


def compute_metrics(log, window: dict, cm_deg: float = 40.0) -> dict:
    """Three frozen metrics for one log, evaluated on the resolved window."""
    start, end = window["start_s"], window["end_s"]
    t = np.asarray(log.time_s, dtype=float)
    q = (t >= start) & (t <= end)
    pwm_t = (
        np.asarray(log.pwm_update_time_s, dtype=float).ravel()
        if log.pwm_update_time_s is not None
        else np.array([])
    )
    e = (pwm_t >= start) & (pwm_t <= end)
    cmd_deg = np.rad2deg(np.asarray(log.pwm_command_rad, dtype=float)[e]) if log.pwm_command_rad is not None else np.empty((0, 6))

    if cmd_deg.shape[0] == 0:
        saturation = float("nan")
        tv = float("nan")
    else:
        saturated = np.any(np.abs(cmd_deg) >= cm_deg - SATURATION_TOL_DEG, axis=1)
        saturation = 100.0 * float(np.mean(saturated))
        changes = np.diff(cmd_deg, axis=0)
        tv = float(np.sum(np.abs(changes))) if changes.size else 0.0

    solve = np.asarray(log.solve_time_s, dtype=float).ravel()[q] if log.solve_time_s is not None else np.array([])
    p95 = float(np.percentile(solve, 95)) * 1000.0 if solve.size else float("nan")

    return {
        "saturation_percent": saturation,
        "pwm_total_variation_deg": tv,
        "solve_time_p95_ms": p95,
        "samples_in_window": int(np.count_nonzero(q)),
        "pwm_events_in_window": int(cmd_deg.shape[0]),
    }


METRIC_DEFINITIONS = {
    "saturation_percent": {
        "definition": "100*mean(any(|deg(pwm_command_rad[e,:])| >= cm-1e-5, axis=1)) over PWM events in window",
        "source": "analysis/ca_metrics.m (position_saturation_percent); analysis/ca_mismatch_metrics.m",
        "cm_deg": 40.0,
        "tolerance_deg": SATURATION_TOL_DEG,
    },
    "pwm_total_variation_deg": {
        "definition": "sum(|diff(deg(pwm_command_rad[e,:]), axis=0)|) over consecutive PWM events in window",
        "source": "analysis/estimator_feedback_metrics_row.m:17 (command_total_variation_deg)",
    },
    "solve_time_p95_ms": {
        "definition": "1000*percentile(solve_time_s[q], 95) with linear interpolation",
        "source": "docs/viz_replay_plan_v0.2.md §3 (v0.2 definition; project baseline uses mean/median)",
    },
}
