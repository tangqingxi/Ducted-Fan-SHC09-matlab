"""Command line entry point: one .mat log -> replay.rrd + manifest.json."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import rerun as rr
import numpy as np

from . import layers, manifest, scene
from .geometry import GeometryError, load_geometry
from .mat_io import FlightLogError, load_log


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="viz\\replay.py",
        description="Replay a saved SHC09 .mat flight log as a Rerun .rrd recording "
        "(post-processing only; never runs the simulation).",
    )
    p.add_argument("--log", required=True, help="path to a .mat log (comparison or platform_run)")
    p.add_argument("--out", required=True, help="output directory for replay.rrd + manifest.json")
    p.add_argument(
        "--rate",
        type=float,
        default=None,
        help="sample rate in Hz used only when the log has no time vector (default 800)",
    )
    p.add_argument("--viewer", action="store_true", help="open the finished .rrd in the Rerun viewer")
    p.add_argument("--no-blueprint", action="store_true", help="skip the viewer blueprint (layout only)")
    p.add_argument("--version", action="version", version="shc09-viz 0.1.0")
    return p


def _send_blueprint(rec: rr.RecordingStream, log) -> None:
    from . import frames

    target = np.median(frames.enu_positions(log.position_reference_ned_m), axis=0)
    eye = target + np.array([-1.0, 2.0, 0.9])
    bp = rr.blueprint.Blueprint(
        rr.blueprint.Horizontal(
            rr.blueprint.Spatial3DView(
                origin="/",
                name="vehicle / trajectory",
                eye_controls=rr.blueprint.EyeControls3D(
                    position=eye.tolist(),
                    look_target=target.tolist(),
                    eye_up=[0.0, 0.0, 1.0],
                ),
            ),
            rr.blueprint.Vertical(
                rr.blueprint.TimeSeriesView(
                    origin="/signals",
                    contents=["/signals/attitude_error_deg", "/signals/position_error_m"],
                    name="attitude (deg) / position (m)",
                ),
                rr.blueprint.TimeSeriesView(origin="/signals/vane", name="vane angle (deg)"),
                name="time series",
            ),
            name="SHC09 replay",
        ),
        rr.blueprint.TimePanel(timeline="time", state=rr.blueprint.PanelState.Expanded),
    )
    rec.send_blueprint(bp)


def _open_viewer(rrd: Path) -> None:
    exe = shutil.which("rerun") or str(Path(sys.executable).with_name("rerun.exe"))
    env = os.environ.copy()
    tmp = Path.cwd() / ".tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    env["TEMP"] = str(tmp)
    env["TMP"] = str(tmp)
    subprocess.Popen([exe, str(rrd)], env=env)  # noqa: S603 - user asked for a viewer


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    started = time.perf_counter()
    try:
        log = load_log(args.log, rate=args.rate)
        geometry = load_geometry()
    except (FlightLogError, GeometryError) as exc:
        print(f"replay: error: {exc}", file=sys.stderr)
        return 1

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    rrd_path = out / "replay.rrd"

    rec = rr.RecordingStream("shc09_viz")
    rec.save(str(rrd_path))
    try:
        # Replay uses its own seconds timeline; dropping log_time keeps the
        # viewer, scalar plots and screenshots on simulation time.
        try:
            rec.set_log_time_enabled(False)
        except Exception:  # noqa: BLE001 - older SDKs may not support it
            pass
        scene.log_world(rec)
        scene.log_vehicle_static(rec, geometry)
        layers.log_trajectories(rec, log)
        summary = layers.log_vehicle_animation(rec, log, geometry)
        layers.log_signals(rec, log)
        summary.update(layers.log_events(rec, log, geometry))
        if not args.no_blueprint:
            try:
                _send_blueprint(rec, log)
            except Exception as exc:  # noqa: BLE001 - viewer layout must never block the .rrd
                print(f"replay: warning: blueprint skipped ({exc})", file=sys.stderr)
    finally:
        rec.flush()

    payload = manifest.build_manifest(log, geometry, rrd_path, args.log)
    manifest_path = manifest.write_manifest(payload, out / "manifest.json")
    elapsed = time.perf_counter() - started

    print(
        f"replay: {log.kind} log, method={log.meta.get('method')}, n={log.n}, "
        f"t=[0, {log.duration_s:.3f}]s, time_base={log.time_base}"
    )
    print(
        f"replay: wrote {rrd_path} ({rrd_path.stat().st_size / 1e6:.2f} MB) and "
        f"{manifest_path.name} in {elapsed:.1f}s"
    )
    print(
        f"replay: saturation_frames={summary['saturation_frames']}, "
        f"aero_frames={summary['aero_frames']} "
        "(PWM/solver curves are CSV-only in v0.1)"
    )
    if args.viewer:
        _open_viewer(rrd_path)
    return 0
