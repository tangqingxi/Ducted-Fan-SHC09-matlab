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
    p.add_argument(
        "--metric-lines",
        action="store_true",
        help="multi only: also log window metrics at the window start/end as constant reference lines",
    )
    p.add_argument("--no-blueprint", action="store_true", help="skip the viewer blueprint (layout only)")
    p.add_argument("--version", action="version", version="shc09-viz 0.2.1")
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


SIGNAL_BASELINE_MB = 19.86  # recorded v0.2.0 multi-method .rrd size
SIGNAL_BYTES_PER_SCALAR = 40.0
METRIC_NAMES = ("saturation_percent", "pwm_total_variation_deg", "solve_time_p95_ms")


def _signal_strides(logs: dict, active: str) -> tuple[dict, float, int]:
    """Estimate the signal layer cost before logging; decimate non-active methods."""
    n = next(iter(logs.values())).n
    budget_mb = 1.5 * SIGNAL_BASELINE_MB

    def extra_mb(stride: int) -> float:
        points = 0
        for method in logs:
            step = 1 if method == active else stride
            points += 2 * ((n + step - 1) // step)
            if method == active:
                points += 6 * n  # only the active method keeps vane curves
        return points * SIGNAL_BYTES_PER_SCALAR / 1e6

    chosen = 8
    for stride in (1, 2, 4, 8):
        chosen = stride
        if SIGNAL_BASELINE_MB + extra_mb(stride) <= budget_mb:
            break
    return {m: (1 if m == active else chosen) for m in logs}, extra_mb(chosen), chosen


def _fmt_metric(value: float) -> str:
    return "n/a" if value is None or math.isnan(float(value)) else f"{float(value):.6g}"


def _summary_markdown(metrics: dict, comparability: dict) -> str:
    lines = [
        "## Window summary metrics",
        "",
        "`status` 原样引用 comparability.csv，**非本工具计算**；本表不排名、不打分。",
        "",
        "| method | saturation % | PWM total variation (deg) | solve time P95 (ms) | status |",
        "|---|---|---|---|---|",
    ]
    status = comparability["status"]
    for method, values in metrics.items():
        lines.append(
            f"| {method} | {_fmt_metric(values['saturation_percent'])} | "
            f"{_fmt_metric(values['pwm_total_variation_deg'])} | "
            f"{_fmt_metric(values['solve_time_p95_ms'])} | {status} |"
        )
    return "\n".join(lines) + "\n"


def _window_time_range(window: dict) -> list:
    return [
        rr.blueprint.VisibleTimeRange(
            timeline="time",
            range=rr.blueprint.TimeRange(
                start=rr.blueprint.TimeRangeBoundary.absolute(seconds=float(window["start_s"])),
                end=rr.blueprint.TimeRangeBoundary.absolute(seconds=float(window["end_s"])),
            ),
        )
    ]


def _send_multi_blueprint(
    rec: rr.RecordingStream, logs: dict, active: str, window: dict
) -> None:
    overrides = {
        f"/vehicles/{m}": rr.blueprint.EntityBehavior(visible=(m == active))
        for m in logs
        if m != active
    }
    contents = []
    for method in logs:
        contents.append(f"/signals/{method}/attitude_error_deg")
        contents.append(f"/signals/{method}/position_error_m")
    time_ranges = _window_time_range(window)
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
                    origin="/signals",
                    contents=contents,
                    name="attitude (deg) / position (m)",
                    time_ranges=time_ranges,
                ),
                rr.blueprint.TimeSeriesView(
                    origin=f"/signals/{active}/vane",
                    name=f"{active} vane angle (deg)",
                    time_ranges=time_ranges,
                ),
                rr.blueprint.TimeSeriesView(
                    origin="/events",
                    name="saturation / aero events",
                    time_ranges=time_ranges,
                ),
                rr.blueprint.TextDocumentView(origin="/summary", name="window summary"),
                name="signals / summary",
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
    signal_strides, signal_extra_mb, signal_stride = _signal_strides(logs, args.active)

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
        for method, log in logs.items():
            layers.log_signals(
                rec,
                log,
                method=method,
                include_vane=(method == args.active),
                stride=signal_strides[method],
            )
            layers.log_events(rec, log, geometry, method=method)
        start_t, end_t = float(window["start_s"]), float(window["end_s"])
        for method, values in metrics.items():
            for name in METRIC_NAMES:
                value = values[name]
                if math.isnan(float(value)):
                    continue
                times = (start_t, end_t) if args.metric_lines else (end_t,)
                for stamp in times:
                    rec.set_time("time", duration=stamp)
                    rec.log(f"/metrics/{name}/{method}", rr.Scalars(float(value)))
        rec.log(
            "/summary",
            rr.TextDocument(_summary_markdown(metrics, comparability), media_type="text/markdown"),
            static=True,
        )
        if not args.no_blueprint:
            try:
                _send_multi_blueprint(rec, logs, args.active, window)
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
    payload["study"]["signal_stride"] = signal_strides
    payload["study"]["signal_stride_note"] = (
        f"estimated signal layer +{signal_extra_mb:.2f} MB on top of the "
        f"{SIGNAL_BASELINE_MB:.2f} MB v0.2 baseline (threshold 1.5x); "
        f"non-active methods stride={signal_stride}, active method/vane curves full rate"
    )
    payload["study"]["metric_lines"] = bool(args.metric_lines)
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
