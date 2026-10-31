"""Provenance manifest written next to every replay.rrd (decision D4)."""

from __future__ import annotations

import hashlib
import json
import platform
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import rerun as rr
import scipy


REPO_ROOT = Path(__file__).resolve().parents[2]
GEOMETRY_REL = "viz/geometry/shc09_geometry.json"

ASSUMPTIONS = [
    "post-processing only: no numerical code, model, allocator or random sequence was touched",
    "display frame is ENU (x east, y north, z up), converted from NED with det=+1",
    "psi=0 means the body y axis points east; this is a body-forward convention, not a heading bug",
    "no resampling: every curve uses the log's own time vector; PWM events keep their own timestamps",
    "geometry is schematic; duct radii and body box are visual choices, not airframe dimensions",
    "signal curves are in degrees where they show angles; positions are metres",
    "PWM latch events, solver health and residual curves are out of v0.1 scope; read pwm.csv/control.csv instead",
    "one log per recording; multi-method overlays are out of scope for v0.1",
]


def sha256_file(path: str | Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _git(*args: str) -> str:
    try:
        out = subprocess.run(
            ["git", *args], cwd=REPO_ROOT, capture_output=True, text=True, check=True, timeout=10
        )
        return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def build_manifest(log, geometry: dict, rrd_path: Path, log_argument: str) -> dict:
    status = _git("status", "--porcelain")
    return {
        "schema": "shc09-replay-manifest-v1",
        "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
        "recording": {
            "application_id": "shc09_viz",
            "rrd": rrd_path.name,
        },
        "input": {
            "path": log_argument,
            "sha256": sha256_file(log.source),
            "kind": log.kind,
            "n": log.n,
            "duration_s": round(log.duration_s, 9),
            "time_base": log.time_base,
            "rate_hz": log.rate_hz,
            "method": log.meta.get("method"),
            "estimator_mode": log.meta.get("estimator_mode"),
            "plant_model": log.meta.get("plant_model"),
        },
        "geometry": {
            "path": GEOMETRY_REL,
            "sha256": geometry["sha256"],
            "source": geometry["source"],
        },
        "code": {
            "git_sha": _git("rev-parse", "HEAD"),
            "git_branch": _git("rev-parse", "--abbrev-ref", "HEAD"),
            "git_dirty": bool(status),
        },
        "versions": {
            "python": platform.python_version(),
            "numpy": np.__version__,
            "scipy": scipy.__version__,
            "rerun_sdk": rr.__version__,
        },
        "assumptions": ASSUMPTIONS,
    }


def write_manifest(manifest: dict, out_path: Path) -> Path:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write("\n")
    return out_path
