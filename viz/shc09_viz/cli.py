"""Command line entry point: one log -> replay.rrd, or a study -> multi-method replay."""

from __future__ import annotations

import argparse
import math
import shutil
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import rerun as rr

from . import layers, manifest, scene
from .geometry import GeometryError, load_geometry
from .mat_io import FlightLogError, load_log
from .study import (
    StudyError,
    compute_metrics,
    load_comparability,
    resolve_window,
    select_logs,
)
from .temp_env import temp_env


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="viz\\replay.py",
        description="Replay SHC09 .mat logs as Rerun recordings (post-processing only). "
        "Single log with --log, or side-by-side methods with --study.",
    )
    p.add_argument("--log", help="path to one .mat log (comparison or platform_run)")
    p.add_argument("--study", help="study directory containing logs/ and comparability.csv")
    p.add_argument("--case", help="case id for --study (e.g. M0)")
    p.add_argument("--mode", help="estimator mode for --study (e.g. lite)")
    p.add_argument("--seed", type=int, help="seed for --study")
    p.add_argument("--active", default="DCA", help="method whose body is visible by default")
    p.add_argument(
        "--window",
        choices=("task", "whole"),
        default="task",
        help="metric window: task (from summary.csv, default) or whole log",
    )
    p.add_argument("--out", required=True, help="output directory for replay.rrd + manifest.json")
    p.add_argument(
        "--rate",
        type=float,
        default=None,
        help="sample rate in Hz used only when the log has no time vector (default 800)",
    )
    p.add_argument("--viewer", action="store_true", help="open the finished .rrd in the Rerun viewer")
    p.add_argument("--no-blueprint", action="store_true", help="skip the viewer blueprint (layout only)")
    p.add_argument("--version", action="version", version="shc09-viz 0.2.0")
    return p


def _eye_controls(log) -> rr.blueprint.EyeControls3D:
    from . import frames

    target = np.median(frames.enu_positions(log.position_reference_ned_m), axis=0)
    eye = target + np.array([-1.0, 2.0, 0.9])
    return rr.blueprint.EyeControls3D(
        position=eye.tolist(),
        look_target=target.tolist(),
        eye_up=[0.0, 0.0, 1.0],
    )


def _send_blueprint(rec: rr.RecordingStream, log) -> None:
    bp = rr.blueprint.Blueprint(
        rr.blueprint.Horizontal(
            rr.blueprint.Spatial3DView(
                origin="/",
                name="vehicle / trajectory",
                eye_controls=_eye_controls(log),
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


def _send_multi_blueprint(rec: rr.RecordingStream, logs: dict, active: str) -> None:
    overrides = {
        f"/vehicles/{m}": rr.blueprint.EntityBehavior(visible=(m == active))
        for m in logs
        if m != active
    }
    bp = rr.blueprint.Blueprint(
        rr.blueprint.Horizontal(
            rr.blueprint.Spatial3DView(
                origin="/",
                name="methods / trajectories",
                eye_controls=_eye_controls(logs[active]),
                overrides=overrides,
            ),
            rr.blueprint.Vertical(
                rr.blueprint.TimeSeriesView(
                    origin="/metrics/saturation_percent", name="saturation (%)"
                ),
                rr.blueprint.TimeSeriesView(
                    origin="/metrics/pwm_total_variation_deg", name="PWM total variation (deg)"
                ),
                rr.blueprint.TimeSeriesView(
                    origin="/metrics/solve_time_p95_ms", name="solve time P95 (ms)"
                ),
                name="summary metrics (window aggregates)",
            ),
            name="SHC09 study",
        ),
        rr.blueprint.TimePanel(timeline="time", state=rr.blueprint.PanelState.Expanded),
    )
    rec.send_blueprint(bp)


def _open_viewer(rrd: Path) -> None:
    exe = shutil.which("rerun") or str(Path(sys.executable).with_name("rerun.exe"))
    subprocess.Popen([exe, str(rrd)], env=temp_env())  # noqa: S603 - user asked for a viewer


def _run_single(args) -> int:
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
    elapsed = time.perf_counter() - args._started
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


def _run_multi(args) -> int:
    started = time.perf_counter()
    if not (args.case and args.mode and args.seed is not None):
        print("replay: --study requires --case, --mode and --seed", file=sys.stderr)
        return 2
    try:
        selection = select_logs(args.study, args.case, args.mode, args.seed)
        geometry = load_geometry()
    except (StudyError, GeometryError) as exc:
        print(f"replay: error: {exc}", file=sys.stderr)
        return 2

    logs = {}
    try:
        for method, path in selection.logs.items():
            logs[method] = load_log(path)
    except FlightLogError as exc:
        print(f"replay: error: {exc}", file=sys.stderr)
        return 1

    base = next(iter(logs.values()))
    for method, log in logs.items():
        if log.n != base.n or not np.array_equal(log.time_s, base.time_s):
            print(
                f"replay: error: mixed time bases (method {method}: n={log.n}, "
                f"duration={log.duration_s:.6g}s; expected n={base.n})",
                file=sys.stderr,
            )
            return 2
        if log.meta.get("method") not in (None, method):
            print(
                f"replay: error: {log.source.name} says method {log.meta.get('method')}, "
                f"expected {method}",
                file=sys.stderr,
            )
            return 2
    if args.active not in logs:
        print(
            f"replay: error: --active {args.active!r} not in {sorted(logs)}",
            file=sys.stderr,
        )
        return 2

    try:
        window = resolve_window(selection.study_dir, selection.case, selection.mode, args.window, base.duration_s)
    except StudyError as exc:
        print(f"replay: error: {exc}", file=sys.stderr)
        return 2
    cm_deg = float(np.rad2deg(float(geometry["vehicle"]["vane_limit_rad"])))
    metrics = {m: compute_metrics(log, window, cm_deg) for m, log in logs.items()}
    comparability = load_comparability(selection.study_dir, selection.case, selection.mode)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    rrd_path = out / "replay.rrd"
    rec = rr.RecordingStream("shc09_viz")
    rec.save(str(rrd_path))
    try:
        try:
            rec.set_log_time_enabled(False)
        except Exception:  # noqa: BLE001
            pass
        scene.log_world(rec)
        strides = {}
        for method, log in logs.items():
            stride = 1 if method == args.active else 8
            strides[method] = stride
            scene.log_vehicle_static(rec, geometry, prefix=f"/vehicles/{method}")
            layers.log_vehicle_animation(
                rec,
                log,
                geometry,
                prefix=f"/vehicles/{method}",
                ghost=(method == args.active),
                stride=stride,
            )
        for method, log in logs.items():
            layers.log_trajectories(
                rec,
                log,
                method=method,
                reference=(method == args.active),
                estimated=(method == args.active),
            )
        end = float(window["end_s"])
        for method, values in metrics.items():
            rec.set_time("time", duration=end)
            for name in ("saturation_percent", "pwm_total_variation_deg", "solve_time_p95_ms"):
                value = values[name]
                if not math.isnan(value):
                    rec.log(f"/metrics/{name}/{method}", rr.Scalars(float(value)))
        status = comparability["status"]
        status_md = "\n".join(f"| {m} | {status} |" for m in logs)
        rec.log(
            "/status",
            rr.TextDocument(
                "## comparability（原样引用，非本工具计算）\n\n"
                "| method | status |\n|---|---|\n" + status_md + "\n",
                media_type="text/markdown",
            ),
            static=True,
        )
        if not args.no_blueprint:
            try:
                _send_multi_blueprint(rec, logs, args.active)
            except Exception as exc:  # noqa: BLE001
                print(f"replay: warning: blueprint skipped ({exc})", file=sys.stderr)
    finally:
        rec.flush()

    payload = manifest.build_multi_manifest(
        selection, logs, geometry, metrics, window, comparability, rrd_path
    )
    payload["study"]["active_method"] = args.active
    payload["study"]["body_stride"] = strides
    payload["study"]["body_stride_note"] = (
        "active method at full rate; other methods at every 8th sample (100 Hz) "
        "to stay inside the v0.2 cost gate; hidden by blueprint default"
    )
    manifest_path = manifest.write_manifest(payload, out / "manifest.json")
    elapsed = time.perf_counter() - started
    size_mb = rrd_path.stat().st_size / 1e6
    print(
        f"replay: study {selection.study_dir} case={selection.case} mode={selection.mode} "
        f"seed={selection.seed} methods={len(logs)} active={args.active}"
    )
    print(
        f"replay: window {window['name']} [{window['start_s']:g}, {window['end_s']:g}]s "
        f"({window['source']}{', clamped' if window['clamped'] else ''}), "
        f"comparability={comparability['status']}"
    )
    print(
        f"replay: wrote {rrd_path} ({size_mb:.2f} MB) and {manifest_path.name} "
        f"in {elapsed:.1f}s"
    )
    for method, values in metrics.items():
        print(
            f"replay: metrics {method:15s} sat={values['saturation_percent']:8.4f}% "
            f"tv={values['pwm_total_variation_deg']:12.4f}deg "
            f"p95={values['solve_time_p95_ms']:8.4f}ms"
        )
    if args.viewer:
        _open_viewer(rrd_path)
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    args._started = time.perf_counter()
    if bool(args.log) == bool(args.study):
        print("replay: pass exactly one of --log or --study", file=sys.stderr)
        return 2
    if args.log:
        return _run_single(args)
    return _run_multi(args)
