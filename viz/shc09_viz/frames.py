"""Coordinate frames for SHC09 replay.

Facts frozen by the plan (§6) and by unit tests:

* navigation frame is NED (x north, y east, z down); gravity is +z;
* body frame is x left, y forward, z down - so psi = 0 points EAST, not north;
* Euler angles are [roll, pitch, yaw] with ZYX convention, evaluated exactly like
  ``lib/math/ca_euler_rotation.m``;
* display frame is ENU (x east, y north, z up).  NED->ENU is a *proper* rotation
  (det = +1) so attitude quaternions can be transformed without mirroring.
"""

from __future__ import annotations

import numpy as np

# NED -> ENU: p_enu = A @ p_ned = [E, N, -D]; det(A) = +1.
NED_TO_ENU = np.array(
    [
        [0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.0, 0.0, -1.0],
    ]
)


class FrameError(ValueError):
    """Raised when a rotation matrix is not a proper rotation."""


def euler_to_matrix(euler: np.ndarray) -> np.ndarray:
    """[roll, pitch, yaw] (n,3) -> R_ned_body (n,3,3), ZYX, same as MATLAB."""
    e = np.atleast_2d(np.asarray(euler, dtype=float))
    if e.ndim != 2 or e.shape[1] != 3:
        raise FrameError(f"euler must be (n,3), got {e.shape}")
    phi, theta, psi = e[:, 0], e[:, 1], e[:, 2]
    cp, sp = np.cos(psi), np.sin(psi)
    ct, st = np.cos(theta), np.sin(theta)
    cf, sf = np.cos(phi), np.sin(phi)
    r = np.empty((e.shape[0], 3, 3))
    r[:, 0, 0] = cp * ct
    r[:, 0, 1] = cp * st * sf - sp * cf
    r[:, 0, 2] = cp * st * cf + sp * sf
    r[:, 1, 0] = sp * ct
    r[:, 1, 1] = sp * st * sf + cp * cf
    r[:, 1, 2] = sp * st * cf - cp * sf
    r[:, 2, 0] = -st
    r[:, 2, 1] = ct * sf
    r[:, 2, 2] = ct * cf
    return r


def enu_positions(position_ned_m: np.ndarray) -> np.ndarray:
    """(n,3) NED positions -> (n,3) ENU positions."""
    p = np.atleast_2d(np.asarray(position_ned_m, dtype=float))
    if p.ndim != 2 or p.shape[1] != 3:
        raise FrameError(f"position must be (n,3), got {p.shape}")
    return p @ NED_TO_ENU.T


def enu_rotation(r_ned_body: np.ndarray) -> np.ndarray:
    """(n,3,3) R_ned_body -> (n,3,3) R_enu_body = A @ R_ned_body."""
    r = np.asarray(r_ned_body, dtype=float)
    if r.ndim != 3 or r.shape[1:] != (3, 3):
        raise FrameError(f"rotation must be (n,3,3), got {r.shape}")
    return NED_TO_ENU @ r


def assert_proper_rotation(r: np.ndarray, tol: float = 1e-9) -> None:
    """Raise unless every matrix is orthonormal with det = +1 (never silently fix)."""
    r = np.asarray(r, dtype=float)
    if r.ndim == 2:
        r = r[None, ...]
    eye = np.eye(3)
    ortho = np.einsum("nji,njk->nik", r, r) - eye
    dets = np.linalg.det(r)
    if np.max(np.abs(ortho)) > tol or np.max(np.abs(dets - 1.0)) > tol:
        raise FrameError(
            "matrix is not a proper rotation "
            f"(max|R^T R - I|={np.max(np.abs(ortho)):.3e}, det range="
            f"[{dets.min():.6f}, {dets.max():.6f}])"
        )


def enu_quaternions_xyzw(r_enu_body: np.ndarray) -> np.ndarray:
    """Proper rotations -> sign-continuous quaternions (xyzw) for Rerun."""
    from scipy.spatial.transform import Rotation

    r = np.asarray(r_enu_body, dtype=float)
    assert_proper_rotation(r)
    if r.ndim == 2:
        r = r[None, ...]
    q = Rotation.from_matrix(r).as_quat().astype(float)
    for k in range(1, q.shape[0]):
        if float(np.dot(q[k], q[k - 1])) < 0.0:
            q[k] = -q[k]
    return q


def body_forward_ned(euler: np.ndarray) -> np.ndarray:
    """Body y (forward) expressed in NED; at zero attitude this is +y = east."""
    r = euler_to_matrix(euler)
    return r @ np.array([0.0, 1.0, 0.0])


def body_forward_enu(euler: np.ndarray) -> np.ndarray:
    """Body y (forward) expressed in ENU; at zero attitude this is +x = east."""
    r = enu_rotation(euler_to_matrix(euler))
    return r @ np.array([0.0, 1.0, 0.0])
