"""Layer tests: fixed palette, vane colouring, ghost geometry and entity names."""

import numpy as np

from conftest import synthetic_arrays, write_platform
from shc09_viz.geometry import load_geometry
from shc09_viz.layers import (
    METHOD_COLORS,
    SATURATION_RED,
    _ghost_sphere,
    log_events,
    log_signals,
    log_trajectories,
    method_color,
    vane_rgba,
)


class FakeRec:
    """Minimal recording sink: records entity paths, never touches Rerun."""

    def __init__(self):
        self.paths = []
        self.times = []
        self.logs = []

    def log(self, path, archetype, static=False):
        self.paths.append(path)
        self.logs.append(archetype)

    def set_time(self, name, duration=None):
        self.times.append((name, duration))


def test_method_palette_is_fixed():
    assert method_color("DCA") == METHOD_COLORS["DCA"]
    assert method_color("unknown") == (200, 200, 200)


def test_vane_colour_blue_to_red_and_saturation():
    limit = np.deg2rad(40)
    rgba = vane_rgba(np.array([[0.0, limit / 2, limit, 2 * limit]]), limit)
    assert tuple(rgba[0, 0, :3]) == (40, 90, 230)  # blue at zero
    assert tuple(rgba[0, 2, :3]) == SATURATION_RED  # saturated
    assert tuple(rgba[0, 3, :3]) == SATURATION_RED  # clipped too
    assert 0 < rgba[0, 1, 0] < SATURATION_RED[0]


def test_ghost_is_a_wire_sphere_of_radius_015():
    rings = _ghost_sphere(np.array([1.0, 2.0, 3.0]))
    assert len(rings) == 3
    for ring in rings:
        r = np.linalg.norm(ring - np.array([1.0, 2.0, 3.0]), axis=1)
        np.testing.assert_allclose(r, 0.15, atol=1e-12)


def test_trajectory_entities(tmp_path):
    log = _platform_log(tmp_path)
    rec = FakeRec()
    log_trajectories(rec, log)
    assert "/traj/actual" in rec.paths
    assert "/traj/reference" in rec.paths


def test_three_curve_groups_only(tmp_path):
    log = _platform_log(tmp_path)
    rec = FakeRec()
    log_signals(rec, log)
    paths = set(rec.paths)
    assert paths == {
        "/signals/attitude_error_deg",
        "/signals/position_error_m",
        *(f"/signals/vane/{i}" for i in range(1, 7)),
    }
    # no PWM / solver curves in v0.1
    assert not any("pwm" in p or "exitflag" in p for p in paths)
    assert len(rec.times) == log.n  # one time stamp per sample ...
    assert len(rec.paths) == 8 * log.n  # ... and 8 scalar series per sample


def test_saturation_events_are_logged(tmp_path):
    arrays = synthetic_arrays()
    cmd = arrays["command_rad"].copy()
    cmd[10:12] = np.deg2rad(40)  # exactly at the limit
    path = write_platform(tmp_path / "DCA" / "log.mat", arrays={"command_rad": cmd})
    log = _load(path)
    rec = FakeRec()
    summary = log_events(rec, log, load_geometry())
    assert summary["saturation_frames"] == 2
    assert rec.paths.count("/events/saturation") == 2


def _platform_log(tmp_path):
    return _load(write_platform(tmp_path / "DCA" / "log.mat"))


def _load(path):
    from shc09_viz.mat_io import load_log

    return load_log(path, rate=800)
