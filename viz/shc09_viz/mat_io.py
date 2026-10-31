"""Read SHC09 logs into a validated, renderer-friendly ``FlightLog``.

Two input shapes exist (plan §5.1):

* comparison log  ``results/<tag>/logs/<case>_<mode>_s<seed>_<METHOD>_<hash>.mat``
  with variables ``L``, ``c``, ``r`` (time comes from ``L.time_for_metrics``);
* platform log    ``results/<tag>/<METHOD>/log.mat`` with only ``log``
  (no time vector: seconds are assumed from ``--rate``).

Only whitelisted top-level variables are loaded; ``comparison.mat`` (which embeds
the whole repository source) is never read.  No resampling is ever performed.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import scipy.io as sio

WHITELIST = ("L", "c", "r", "log")
DEFAULT_RATE_HZ = 800.0
TIME_TOLERANCE = 0.01  # 1% on dt, per plan §5.4
METHOD_IN_NAME = re.compile(r"_s\d+_([A-Z][A-Z0-9_]*)_[0-9a-f]{64}$")


class FlightLogError(ValueError):
    """Raised when the file does not satisfy the data contract."""


@dataclass
class FlightLog:
    source: Path
    kind: str
    time_s: np.ndarray
    time_base: str
    rate_hz: float
    position_ned_m: np.ndarray
    position_reference_ned_m: np.ndarray
    euler_rad: np.ndarray
    command_rad: np.ndarray
    actual_delta_rad: np.ndarray
    velocity_ned_m_s: np.ndarray | None = None
    desired_euler_rad: np.ndarray | None = None
    measured_euler_rad: np.ndarray | None = None
    rotation_error_rad: np.ndarray | None = None
    pwm_command_rad: np.ndarray | None = None
    pwm_update_time_s: np.ndarray | None = None
    pwm_end_actual_delta_rad: np.ndarray | None = None
    pwm_end_prediction_error_rad: np.ndarray | None = None
    table_extrapolated: np.ndarray | None = None
    solver_exitflag: np.ndarray | None = None
    iterations: np.ndarray | None = None
    solve_time_s: np.ndarray | None = None
    motor_rad_s: np.ndarray | None = None
    exit_speed_m_s: np.ndarray | None = None
    duct_angle_rad: np.ndarray | None = None
    wing_angle_rad: np.ndarray | None = None
    estimated_position_ned_m: np.ndarray | None = None
    estimated_attitude_error_rad: np.ndarray | None = None
    meta: dict = field(default_factory=dict)

    @property
    def n(self) -> int:
        return int(self.time_s.size)

    @property
    def duration_s(self) -> float:
        return float(self.time_s[-1])


def _struct(value):
    """Unwrap a MATLAB 1x1 struct array into an attribute-accessible object."""
    if isinstance(value, np.ndarray) and value.dtype == object and value.size == 1:
        return value.reshape(-1)[0]
    return value


def _has(obj, name: str) -> bool:
    return obj is not None and hasattr(obj, name)


def _matrix(obj, name: str) -> np.ndarray:
    a = np.asarray(getattr(obj, name))
    if a.ndim == 1:
        a = a[:, None]
    if a.ndim != 2:
        raise FlightLogError(f"{name}: expected a 2-D array, got shape {a.shape}")
    return a


def _vector(obj, name: str) -> np.ndarray:
    a = np.asarray(getattr(obj, name)).ravel()
    return a


def _optional(obj, name: str) -> np.ndarray | None:
    if not _has(obj, name):
        return None
    a = np.asarray(getattr(obj, name))
    if a.ndim == 0:
        return a.reshape(1)
    return a


def _text(obj, name: str) -> str | None:
    """Best-effort text for char arrays; MATLAB ``string`` objects are opaque."""
    if not _has(obj, name):
        return None
    value = getattr(obj, name)
    if isinstance(value, sio.matlab.MatlabOpaque):
        return None
    a = np.asarray(value)
    if a.dtype.kind in "US":
        return str(a.ravel()[0])
    return None


def _log_n(ds, name: str) -> int:
    a = _matrix(ds, name)
    return int(a.shape[0])


def load_log(path: str | Path, rate: float | None = None) -> FlightLog:
    """Load and validate one .mat log.  Never interpolates or resamples."""
    path = Path(path)
    if not path.is_file():
        raise FlightLogError(f"log file not found: {path}")
    try:
        mat = sio.loadmat(
            path,
            variable_names=list(WHITELIST),
            squeeze_me=False,
            struct_as_record=False,
            chars_as_strings=True,
        )
    except Exception as exc:  # noqa: BLE001 - surfaced as a contract error
        raise FlightLogError(f"cannot read {path.name}: {exc}") from exc

    if "L" in mat:
        kind = "comparison"
        ds = _struct(mat["L"])
        c = _struct(mat["c"]) if "c" in mat else None
        r = _struct(mat["r"]) if "r" in mat else None
    elif "log" in mat:
        kind = "platform"
        ds = _struct(mat["log"])
        c = None
        r = None
    else:
        raise FlightLogError(
            f"{path.name}: neither 'L' nor 'log' found (keys: {sorted(k for k in mat if not k.startswith('__'))})"
        )

    for required in ("position_ned_m", "actual_delta_rad"):
        if not _has(ds, required):
            raise FlightLogError(f"{path.name}: missing required field {required}")
    n = _log_n(ds, "position_ned_m")
    if n < 2:
        raise FlightLogError(f"{path.name}: needs at least 2 samples, got {n}")

    assumed_rate = float(rate) if rate is not None else DEFAULT_RATE_HZ
    if assumed_rate <= 0:
        raise FlightLogError(f"--rate must be positive, got {assumed_rate}")

    sample_hz = _vector(c, "sample_hz")[0] if _has(c, "sample_hz") else None
    rate_hz = float(sample_hz) if sample_hz is not None else assumed_rate

    time_s, time_base = _time_vector(ds, r, n, assumed_rate)
    _validate_time(path, time_s, n, rate_hz)
    if time_base == "assumed_rate":
        print(
            f"replay: warning: {path.name} has no stored time vector; "
            f"assuming {assumed_rate:g} Hz (manifest records time_base=assumed_rate)",
            file=sys.stderr,
        )

    position = _matrix(ds, "position_ned_m")
    actual = _matrix(ds, "actual_delta_rad")
    _check_shape(path, "position_ned_m", position, n, 3)
    _check_shape(path, "actual_delta_rad", actual, n, 6)

    reference = _matrix(ds, "position_reference_ned_m") if _has(ds, "position_reference_ned_m") else None
    if reference is None:
        reference = np.zeros((n, 3))
        print(
            f"replay: warning: {path.name} has no position_reference_ned_m; using zeros",
            file=sys.stderr,
        )
    _check_shape(path, "position_reference_ned_m", reference, n, 3)

    euler = _matrix(ds, "euler_rad")
    _check_shape(path, "euler_rad", euler, n, 3)
    command = _matrix(ds, "command_rad") if _has(ds, "command_rad") else np.zeros((n, 6))
    _check_shape(path, "command_rad", command, n, 6)

    for name, arr in (
        ("position_ned_m", position),
        ("position_reference_ned_m", reference),
        ("euler_rad", euler),
        ("command_rad", command),
        ("actual_delta_rad", actual),
    ):
        if not np.all(np.isfinite(arr)):
            raise FlightLogError(f"{path.name}: {name} contains NaN/Inf")

    method = _text(ds, "name")
    if kind == "comparison":
        _check_method_against_filename(path, method)
    elif not method:
        method = path.parent.name

    pwm_command = _optional(ds, "pwm_command_rad")
    pwm_time = _optional(ds, "pwm_update_time_s")
    if pwm_command is not None and pwm_time is not None:
        if pwm_command.shape[0] != pwm_time.size:
            raise FlightLogError(
                f"{path.name}: pwm_command_rad has {pwm_command.shape[0]} rows but "
                f"pwm_update_time_s has {pwm_time.size}"
            )

    meta = {
        "method": method,
        "estimator_mode": _text(ds, "estimator_mode"),
        "plant_model": _text(ds, "plant_model"),
        "flight_mode": _text(ds, "flight_mode"),
        "output_tag": _text(c, "output_tag") if c is not None else None,
        "sample_hz": float(sample_hz) if sample_hz is not None else None,
        "duration_s": float(_vector(c, "duration_s")[0]) if _has(c, "duration_s") else None,
    }

    return FlightLog(
        source=path,
        kind=kind,
        time_s=time_s,
        time_base=time_base,
        rate_hz=rate_hz,
        position_ned_m=position,
        position_reference_ned_m=reference,
        euler_rad=euler,
        command_rad=command,
        actual_delta_rad=actual,
        velocity_ned_m_s=_optional(ds, "velocity_ned_m_s"),
        desired_euler_rad=_optional(ds, "desired_euler_rad"),
        measured_euler_rad=_optional(ds, "measured_euler_rad"),
        rotation_error_rad=_optional(ds, "rotation_error_rad"),
        pwm_command_rad=pwm_command,
        pwm_update_time_s=pwm_time,
        pwm_end_actual_delta_rad=_optional(ds, "pwm_end_actual_delta_rad"),
        pwm_end_prediction_error_rad=_optional(ds, "pwm_end_prediction_error_rad"),
        table_extrapolated=_bool(_optional(ds, "table_extrapolated")),
        solver_exitflag=_optional(ds, "solver_exitflag"),
        iterations=_optional(ds, "iterations"),
        solve_time_s=_optional(ds, "solve_time_s"),
        motor_rad_s=_optional(ds, "motor_rad_s"),
        exit_speed_m_s=_optional(ds, "exit_speed_m_s"),
        duct_angle_rad=_optional(ds, "duct_angle_rad"),
        wing_angle_rad=_optional(ds, "wing_angle_rad"),
        estimated_position_ned_m=_optional(ds, "estimated_position_ned_m"),
        estimated_attitude_error_rad=_optional(ds, "estimated_attitude_error_rad"),
        meta=meta,
    )


def _bool(a: np.ndarray | None) -> np.ndarray | None:
    if a is None:
        return None
    return np.asarray(a).ravel().astype(bool)


def _time_vector(ds, r, n: int, assumed_rate: float) -> tuple[np.ndarray, str]:
    """Plan §5.3: stored time first, never silently interpolate."""
    if _has(ds, "time_for_metrics"):
        t = _vector(ds, "time_for_metrics")
        if t.size != n:
            raise FlightLogError(f"time_for_metrics has {t.size} samples, expected {n}")
        return t, "time_for_metrics"
    if _has(r, "time_s"):
        t = _vector(r, "time_s")
        if t.size != n:
            raise FlightLogError(f"r.time_s has {t.size} samples, expected {n}")
        return t, "r.time_s"
    return np.arange(n, dtype=float) / assumed_rate, "assumed_rate"


def _validate_time(path: Path, t: np.ndarray, n: int, rate_hz: float) -> None:
    if t.size != n:
        raise FlightLogError(f"{path.name}: time has {t.size} samples, expected {n}")
    dt = np.diff(t)
    if not np.all(dt > 0.0):
        bad = int(np.argmin(dt))
        raise FlightLogError(f"{path.name}: time is not strictly increasing at index {bad}")
    if abs(float(t[0])) > 1e-6:
        raise FlightLogError(f"{path.name}: time starts at {t[0]:.6g}s, expected 0")
    nominal = 1.0 / rate_hz
    median_dt = float(np.median(dt))
    if abs(median_dt - nominal) / nominal > TIME_TOLERANCE:
        raise FlightLogError(
            f"{path.name}: dt={median_dt:.6g}s does not match {rate_hz:g} Hz (expected {nominal:.6g}s)"
        )


def _check_shape(path: Path, name: str, arr: np.ndarray, n: int, cols: int) -> None:
    if arr.shape != (n, cols):
        raise FlightLogError(f"{path.name}: {name} shape {arr.shape}, expected {(n, cols)}")


def _check_method_against_filename(path: Path, method: str | None) -> None:
    match = METHOD_IN_NAME.search(path.stem)
    if match is None:
        return
    expected = match.group(1)
    if method and method != expected:
        raise FlightLogError(
            f"{path.name}: file name says {expected} but L.name says {method} - refusing to mix logs"
        )
