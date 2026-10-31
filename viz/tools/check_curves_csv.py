"""Cross-check the three v0.1 curves against a platform_run control.csv (M3).

CSV angles are in DEGREES, MAT angles in radians, and the CSV's per-axis
``attitude_error_deg_*`` is an **Euler difference**, while the replay curve is
the **geodesic rotation error** (``acos((trace(R_true'R_des)-1)/2)``).  The two
only coincide to second order, so the gate recomputes the geodesic from the MAT
euler/desired fields and reports the CSV Euler difference as a note.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from shc09_viz.frames import euler_to_matrix  # noqa: E402
from shc09_viz.mat_io import load_log  # noqa: E402

TOL = 1e-6


def _geodesic_deg(euler: np.ndarray, desired: np.ndarray) -> float:
    r_true = euler_to_matrix(euler)[0]
    r_des = euler_to_matrix(desired)[0]
    relative = r_true.T @ r_des
    return float(np.rad2deg(np.arccos(np.clip((np.trace(relative) - 1.0) / 2.0, -1.0, 1.0))))


def main() -> int:
    ap = argparse.ArgumentParser(description="Compare replay curves with control.csv")
    ap.add_argument("--log", required=True, help="platform log.mat (same run as --control)")
    ap.add_argument("--control", required=True, help="control.csv next to the log")
    args = ap.parse_args()

    log = load_log(args.log, rate=800)
    csv = np.genfromtxt(args.control, delimiter=",", names=True)
    if csv.shape[0] != log.n:
        print(f"mismatch: csv rows={csv.shape[0]} log n={log.n}", file=sys.stderr)
        return 1

    rows = []
    for k in (0, log.n // 2, log.n - 1):
        vane_mat = np.rad2deg(log.actual_delta_rad[k])
        vane_csv = np.array([csv[f"actual_deg_{i}"][k] for i in range(1, 7)])
        dv = float(np.max(np.abs(vane_mat - vane_csv)))

        d_mat = log.position_ned_m[k] - log.position_reference_ned_m[k]
        d_csv = np.array(
            [
                csv[f"position_ned_m_{i}"][k] - csv[f"position_reference_ned_m_{i}"][k]
                for i in range(1, 4)
            ]
        )
        dp = abs(float(np.linalg.norm(d_mat) - np.linalg.norm(d_csv)))

        att_curve = float(np.rad2deg(log.rotation_error_rad.ravel()[k]))
        att_geo = _geodesic_deg(log.euler_rad[k], log.desired_euler_rad[k])
        da = abs(att_curve - att_geo)

        att_csv = np.linalg.norm([csv[f"attitude_error_deg_{i}"][k] for i in range(1, 4)])
        note = abs(att_curve - float(att_csv))
        rows.append((k, log.time_s[k], dv, dp, da, note))

    print(
        f"{'index':>6} {'t_s':>8} {'vane_deg':>10} {'pos_err_m':>10} "
        f"{'att_geo_deg':>12} {'csv_euler_note':>14}"
    )
    ok = True
    for k, t, dv, dp, da, note in rows:
        print(f"{k:6d} {t:8.3f} {dv:10.2e} {dp:10.2e} {da:12.2e} {note:14.2e}")
        ok = ok and dv <= TOL and dp <= TOL and da <= TOL
    print(
        f"gate tolerance={TOL:g}: {'PASS' if ok else 'FAIL'} "
        "(csv_euler_note is the Euler-vs-geodesic definitional difference, not a gate)"
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
