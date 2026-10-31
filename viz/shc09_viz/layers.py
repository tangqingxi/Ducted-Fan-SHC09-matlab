"""Dynamic replay layers: trajectories, vehicle animation, signals and events.

Every layer has its own Rerun entity prefix so the viewer can toggle it (D2).
All angles logged under ``/signals`` are in **degrees** (the .mat stores radians);
positions are ENU metres.
"""

from __future__ import annotations

import numpy as np
import rerun as rr
from scipy.spatial.transform import Rotation

from . import frames
from . import geometry as geo

# --- fixed palette (plan §8) -------------------------------------------------
METHOD_COLORS = {
    "DA_NS": (31, 119, 180),
    "WLS": (44, 160, 44),
    "DCA": (255, 127, 14),
    "PCA_STATIC": (148, 103, 189),
    "PCA_PREDICTIVE": (214, 39, 40),
    "EXAMPLE_PINV": (140, 86, 75),
}
REFERENCE_GRAY = (150, 150, 150)
GRID_GRAY = (70, 70, 70)
DARK_GRAY = (60, 60, 60)
BODY_GRAY = (120, 120, 120)
FAN_TEAL = (0, 110, 110)
ESTIMATED_CYAN = (0, 200, 200)
GHOST_WHITE = (220, 220, 220, 150)
CMD_PANEL = (170, 190, 255, 64)
SATURATION_RED = (220, 30, 30)
VANE_BLUE = (40, 90, 230)
VANE_HALF_EXTENTS = np.array([0.045, 0.045, 0.006])


def method_color(method: str | None) -> tuple[int, int, int]:
    return METHOD_COLORS.get(str(method), (200, 200, 200))


def vane_rgba(values: np.ndarray, limit_rad: float) -> np.ndarray:
    """|delta|/limit -> blue..red; saturated values are forced to pure red."""
    s = np.clip(np.abs(np.asarray(values, dtype=float)) / float(limit_rad), 0.0, 1.0)
    rgb = (1.0 - s)[..., None] * np.asarray(VANE_BLUE) + s[..., None] * np.asarray(SATURATION_RED)
    rgba = np.empty(s.shape + (4,), dtype=np.uint8)
    rgba[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    rgba[..., 3] = 255
    rgba[s >= 1.0 - 1e-6] = (*SATURATION_RED, 255)
    return rgba


def log_trajectories(rec: rr.RecordingStream, log) -> None:
    """Whole flown paths as static polylines (plan §8)."""
    pos = frames.enu_positions(log.position_ned_m)
    ref = frames.enu_positions(log.position_reference_ned_m)
    rec.log(
        "/traj/actual",
        rr.LineStrips3D([pos], colors=[method_color(log.meta.get("method"))], radii=0.02),
        static=True,
    )
    rec.log("/traj/reference", rr.LineStrips3D([ref], colors=[REFERENCE_GRAY], radii=0.012), static=True)
    est = log.estimated_position_ned_m
    if est is not None and est.shape == log.position_ned_m.shape:
        rec.log(
            "/traj/estimated",
            rr.LineStrips3D([frames.enu_positions(est)], colors=[ESTIMATED_CYAN], radii=0.006),
            static=True,
        )


def _vane_quaternions(axes: np.ndarray, delta: np.ndarray) -> np.ndarray:
    out = np.empty((delta.shape[0], 6, 4))
    for i in range(6):
        rotvec = axes[i][None, :] * delta[:, i][:, None]
        out[:, i] = Rotation.from_rotvec(rotvec).as_quat()
    return out


def _ghost_sphere(center: np.ndarray, radius: float = 0.15, n: int = 48) -> list[np.ndarray]:
    """Three great circles: Rerun 0.41 renders point spheres opaque, not ghostly."""
    a = np.linspace(0.0, 2.0 * np.pi, n)
    rings = []
    for axis in (0, 1, 2):
        pts = np.zeros((n, 3))
        i, j = [k for k in range(3) if k != axis]
        pts[:, i] = radius * np.cos(a)
        pts[:, j] = radius * np.sin(a)
        rings.append(pts + center)
    return rings


def log_vehicle_animation(rec: rr.RecordingStream, log, g: dict) -> dict:
    """Per-sample body pose, six vane deflections and the target ghost."""
    v = g["vehicle"]
    limit = float(v["vane_limit_rad"])
    hinge = geo.vane_positions(g)
    axes = geo.vane_axes(g)
    t = log.time_s
    pos = frames.enu_positions(log.position_ned_m)
    ref = frames.enu_positions(log.position_reference_ned_m)
    quat = frames.enu_quaternions_xyzw(frames.enu_rotation(frames.euler_to_matrix(log.euler_rad)))
    delta = log.actual_delta_rad
    cmd = log.command_rad
    q_delta = _vane_quaternions(axes, delta)
    q_cmd = _vane_quaternions(axes, cmd)
    rgba = vane_rgba(delta, limit)

    log_fn = rec.log
    for k in range(t.size):
        rec.set_time("time", duration=float(t[k]))
        log_fn("/vehicle", rr.Transform3D(translation=pos[k], rotation=rr.Quaternion(xyzw=quat[k])))
        log_fn(
            "/target/ghost",
            rr.LineStrips3D(_ghost_sphere(ref[k]), colors=[GHOST_WHITE], radii=0.003),
        )
        for i in range(6):
            log_fn(
                f"/vehicle/vane/{i + 1}",
                rr.Transform3D(translation=hinge[i], rotation=rr.Quaternion(xyzw=q_delta[k, i])),
            )
            log_fn(
                f"/vehicle/vane/{i + 1}/panel",
                rr.Boxes3D(centers=[[0, 0, 0]], half_sizes=[VANE_HALF_EXTENTS], colors=[rgba[k, i]]),
            )
            log_fn(
                f"/vehicle/vane_cmd/{i + 1}",
                rr.Transform3D(translation=hinge[i], rotation=rr.Quaternion(xyzw=q_cmd[k, i])),
            )
    saturated = int(np.count_nonzero(np.any(np.abs(cmd) >= limit - 1e-6, axis=1)))
    return {"saturated_frames": saturated, "limit_rad": limit}


def log_signals(rec: rr.RecordingStream, log) -> None:
    """v0.1 scalar curves: attitude error, position error and six vane angles.

    PWM and solver-health curves are deliberately left to pwm.csv /
    control.csv (plan §8: v0.2 items), so they are not logged here.
    """
    t = log.time_s
    pos = log.position_ned_m
    err = np.linalg.norm(pos - log.position_reference_ned_m, axis=1)
    att = log.rotation_error_rad if log.rotation_error_rad is not None else np.zeros(t.size)
    att = np.asarray(att).ravel()
    delta_deg = np.rad2deg(log.actual_delta_rad)

    log_fn = rec.log
    for k in range(t.size):
        rec.set_time("time", duration=float(t[k]))
        log_fn("/signals/attitude_error_deg", rr.Scalars(float(np.rad2deg(att[k]))))
        log_fn("/signals/position_error_m", rr.Scalars(float(err[k])))
        for i in range(6):
            log_fn(f"/signals/vane/{i + 1}", rr.Scalars(float(delta_deg[k, i])))


def log_events(rec: rr.RecordingStream, log, g: dict) -> dict:
    """Saturation and aero-table extrapolation markers (PWM events are v0.2)."""
    limit = float(g["vehicle"]["vane_limit_rad"])
    summary = {"saturation_frames": 0, "aero_frames": 0}

    cmd_rad = log.command_rad
    sat = np.abs(cmd_rad) >= limit - 1e-6
    sat_rows = np.flatnonzero(np.any(sat, axis=1))
    for k in sat_rows:
        rec.set_time("time", duration=float(log.time_s[k]))
        rec.log("/events/saturation", rr.Scalars(float(np.count_nonzero(sat[k]))))
    summary["saturation_frames"] = int(sat_rows.size)

    if log.table_extrapolated is not None:
        rows = np.flatnonzero(np.asarray(log.table_extrapolated).ravel())
        for k in rows:
            rec.set_time("time", duration=float(log.time_s[k]))
            rec.log("/events/aero_extrapolation", rr.Scalars(1.0))
        summary["aero_frames"] = int(rows.size)
    return summary
