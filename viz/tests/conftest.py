"""Pytest bootstrap and synthetic logs (no MATLAB, no large files)."""

import csv
import sys
from pathlib import Path

import numpy as np
from scipy.io import savemat

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

N = 1601
DT = 1.0 / 800.0
HOVER_NED = np.array([0.0, 0.0, -10.0])


def synthetic_arrays(n: int = N, with_time: bool = True) -> dict:
    """Hover at 10 m, yaw = 0, 1601 samples at 800 Hz (matches the 2 s fixture)."""
    t = np.arange(n) * DT
    position = np.tile(HOVER_NED, (n, 1))
    euler = np.zeros((n, 3))
    actual = np.zeros((n, 6))
    command = np.zeros((n, 6))
    data = {
        "position_ned_m": position,
        "position_reference_ned_m": position.copy(),
        "velocity_ned_m_s": np.zeros((n, 3)),
        "euler_rad": euler,
        "desired_euler_rad": euler.copy(),
        "measured_euler_rad": euler.copy(),
        "rotation_error_rad": np.zeros((n, 1)),
        "command_rad": command,
        "actual_delta_rad": actual,
        "table_extrapolated": np.zeros((n, 1), dtype=np.uint8),
        "solver_exitflag": np.ones((n, 1), dtype=np.uint8),
        "iterations": np.ones((n, 1), dtype=np.uint8),
        "solve_time_s": np.zeros((n, 1)),
        "motor_rad_s": np.full((n, 1), 842.0),
        "exit_speed_m_s": np.full((n, 1), 24.0),
        "duct_angle_rad": np.zeros((n, 1)),
        "wing_angle_rad": np.zeros((n, 1)),
        "name": np.array(["DCA"]),
    }
    if with_time:
        data["time_for_metrics"] = t.reshape(-1, 1)
    e = 667
    pwm_t = (np.arange(e) * (n - 1) / (e - 1)) * DT
    pwm_cmd = np.zeros((e, 6))
    pwm_end = np.zeros((e, 6))
    pwm_end[-2:] = np.nan  # truncated at pwm_count: trailing NaN is allowed
    data.update(
        {
            "pwm_update_time_s": pwm_t.reshape(-1, 1),
            "pwm_command_rad": pwm_cmd,
            "pwm_end_actual_delta_rad": pwm_end,
            "pwm_end_prediction_error_rad": pwm_end.copy(),
        }
    )
    return data


def write_comparison(
    path: Path,
    method: str = "DCA",
    with_time: bool = True,
    arrays: dict | None = None,
    sample_hz: int = 800,
    estimated: bool = False,
    c_estimator: str | None = "lite",
    c_plant: str | None = "shc09_6dof",
    c_output_tag: str = "synthetic",
) -> Path:
    """Write a type-A comparison log (L + c + r) to ``path``.

    ``estimated=True`` adds the lite estimation fields; ``c_estimator`` /
    ``c_plant`` are char arrays so the loader can read them without MATLAB.
    """
    data = synthetic_arrays(with_time=with_time)
    data["name"] = np.array([method])
    if estimated:
        data["estimated_position_ned_m"] = data["position_ned_m"] + np.array([0.02, -0.01, 0.0])
        data["estimated_attitude_error_rad"] = np.full((N, 1), 0.01)
    if arrays:
        data.update(arrays)
    t = np.arange(N) * DT
    c = {
        "sample_hz": np.array([[sample_hz]], dtype=np.uint16),
        "duration_s": np.array([[2]], dtype=np.uint8),
        "output_tag": np.array([c_output_tag]),
    }
    if c_estimator is not None:
        c["estimator_mode"] = np.array([c_estimator])
    if c_plant is not None:
        c["plant_model"] = np.array([c_plant])
    payload = {
        "L": data,
        "c": c,
        "r": {
            "time_s": t.reshape(-1, 1),
            "position_ned_m": np.tile(HOVER_NED, (N, 1)),
            "euler_rad": np.zeros((N, 3)),
        },
    }
    if arrays and "name" in arrays:
        payload["L"]["name"] = arrays["name"]
    path.parent.mkdir(parents=True, exist_ok=True)
    savemat(path, payload)
    return path


def write_platform(path: Path, arrays: dict | None = None) -> Path:
    """Write a type-B platform log (single ``log`` variable, no time vector)."""
    data = synthetic_arrays(with_time=False)
    if arrays:
        data.update(arrays)
    path.parent.mkdir(parents=True, exist_ok=True)
    savemat(path, {"log": data})
    return path


def write_study_metadata(
    study: Path,
    methods,
    case: str = "M0",
    mode: str = "lite",
    seed: int = 1,
    window: tuple[float, float] = (0.5, 1.5),
    status: str = "stress",
    run_status: str = "completed",
) -> Path:
    """Minimal summary/comparability/status CSVs for a synthetic study."""
    study.mkdir(parents=True, exist_ok=True)
    with (study / "summary.csv").open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=[
                "case_id", "estimator_mode", "seed", "method", "window",
                "window_start_s", "window_end_s",
            ],
        )
        w.writeheader()
        for m in methods:
            w.writerow(
                {
                    "case_id": case, "estimator_mode": mode, "seed": seed, "method": m,
                    "window": "task", "window_start_s": window[0], "window_end_s": window[1],
                }
            )
    with (study / "comparability.csv").open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["case_id", "estimator_mode", "comparability"])
        w.writeheader()
        w.writerow({"case_id": case, "estimator_mode": mode, "comparability": status})
    with (study / "status.csv").open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["case_id", "estimator_mode", "seed", "method", "status"])
        w.writeheader()
        for m in methods:
            w.writerow({"case_id": case, "estimator_mode": mode, "seed": seed,
                        "method": m, "status": run_status})
    return study


def write_study(
    study: Path,
    methods=("DA_NS", "DCA"),
    case: str = "M0",
    mode: str = "lite",
    seed: int = 1,
    **meta,
) -> Path:
    """Synthetic study: logs/<case>_<mode>_s<seed>_<METHOD>_<hash>.mat + CSVs."""
    logs = study / "logs"
    for m in methods:
        write_comparison(comparison_path(study, method=m, case=case, mode=mode, seed=seed), method=m)
    write_study_metadata(study, methods, case=case, mode=mode, seed=seed, **meta)
    return study


def comparison_path(tmp_path: Path, method: str = "DCA", case: str = "M0", mode: str = "ideal", seed: int = 1) -> Path:
    digest = "0" * 64
    return tmp_path / "logs" / f"{case}_{mode}_s{seed}_{method}_{digest}.mat"
