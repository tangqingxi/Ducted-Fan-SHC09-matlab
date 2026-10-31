"""Frame conventions frozen by the plan: psi=0 -> EAST, ENU is a proper rotation."""

import numpy as np
import pytest

from shc09_viz.frames import (
    NED_TO_ENU,
    FrameError,
    assert_proper_rotation,
    body_forward_enu,
    body_forward_ned,
    enu_positions,
    enu_quaternions_xyzw,
    enu_rotation,
    euler_to_matrix,
)


def test_identity_forward_is_east_not_north():
    # ca_euler_rotation([0 0 0]) * [0;1;0] = [0 1 0]: body forward is NED +y = east.
    np.testing.assert_allclose(body_forward_ned([[0.0, 0.0, 0.0]]), [[0.0, 1.0, 0.0]], atol=1e-15)
    np.testing.assert_allclose(body_forward_enu([[0.0, 0.0, 0.0]]), [[1.0, 0.0, 0.0]], atol=1e-15)


def test_yaw_90_forward_points_west():
    # ca_euler_rotation([0 0 pi/2]) * [0;1;0] = [-1 0 0].
    np.testing.assert_allclose(body_forward_ned([[0.0, 0.0, np.pi / 2]]), [[-1.0, 0.0, 0.0]], atol=1e-12)


def test_roll_90_thrust_points_east():
    # ca_euler_rotation([pi/2 0 0]) * [0;0;-1] = [0 1 0] (recorded from MATLAB).
    r = euler_to_matrix([[np.pi / 2, 0.0, 0.0]])[0]
    np.testing.assert_allclose(r @ np.array([0.0, 0.0, -1.0]), [0.0, 1.0, 0.0], atol=1e-12)


def test_enu_is_proper_rotation_and_hover_thrust_points_up():
    assert abs(np.linalg.det(NED_TO_ENU) - 1.0) < 1e-15
    r_enu = enu_rotation(euler_to_matrix([[0.0, 0.0, 0.0]]))[0]
    np.testing.assert_allclose(r_enu @ np.array([0.0, 0.0, -1.0]), [0.0, 0.0, 1.0], atol=1e-15)
    assert_proper_rotation(r_enu)


def test_enu_positions_flip_down_to_up():
    p = enu_positions([[0.0, 0.0, -10.0], [1.0, 2.0, -3.0]])
    np.testing.assert_allclose(p, [[0.0, 0.0, 10.0], [2.0, 1.0, 3.0]], atol=1e-15)


def test_quaternion_sign_is_continuous():
    yaw = np.linspace(-np.pi + 0.1, np.pi - 0.1, 400)
    euler = np.column_stack([np.zeros_like(yaw), np.zeros_like(yaw), yaw])
    q = enu_quaternions_xyzw(enu_rotation(euler_to_matrix(euler)))
    dots = np.sum(q[1:] * q[:-1], axis=1)
    assert np.all(dots >= 0.0)


def test_reflection_is_rejected():
    mirrored = euler_to_matrix([[0.0, 0.0, 0.0]])
    mirrored[0, 0, 2] = 1.0  # det becomes -1
    with pytest.raises(FrameError):
        assert_proper_rotation(mirrored)
