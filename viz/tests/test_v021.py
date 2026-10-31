"""v0.2.1: multi-method signal layer, summary table and blueprint smoke."""

import numpy as np

from conftest import comparison_path, write_comparison
from shc09_viz import layers
from shc09_viz.cli import _send_multi_blueprint, _signal_strides, _summary_markdown
from shc09_viz.study import compute_metrics
from shc09_viz.mat_io import load_log

WINDOW = {"name": "task", "start_s": 0.5, "end_s": 1.5, "source": "summary.csv", "clamped": False}


class FakeRec:
    def __init__(self):
        self.paths = []
        self.times = []
        self.logs = []
        self.blueprint = None

    def log(self, path, archetype, static=False):
        self.paths.append(path)
        self.logs.append(archetype)

    def set_time(self, name, duration=None):
        self.times.append((name, duration))

    def send_blueprint(self, bp, **kwargs):
        self.blueprint = bp


def _log(tmp_path, method="DCA"):
    path = write_comparison(comparison_path(tmp_path, method=method), method=method)
    return load_log(path)


def test_multi_logs_signal_series(tmp_path):
    rec = FakeRec()
    for method in ("DA_NS", "WLS", "DCA"):
        layers.log_signals(rec, _log(tmp_path, method), method=method, include_vane=(method == "DCA"))
    for method in ("DA_NS", "WLS", "DCA"):
        assert f"/signals/{method}/attitude_error_deg" in rec.paths
        assert f"/signals/{method}/position_error_m" in rec.paths
    # one static SeriesLines per method series (att + pos)
    assert sum(type(a).__name__ == "SeriesLines" for a in rec.logs) >= 6


def test_single_paths_unchanged(tmp_path):
    rec = FakeRec()
    layers.log_signals(rec, _log(tmp_path))
    paths = set(rec.paths)
    assert "/signals/attitude_error_deg" in paths
    assert "/signals/position_error_m" in paths
    assert {f"/signals/vane/{i}" for i in range(1, 7)} <= paths
    assert not any(p.startswith("/signals/DA_NS") for p in paths)


def test_vane_series_active_only(tmp_path):
    rec = FakeRec()
    active = _log(tmp_path, "DCA")
    other = _log(tmp_path, "DA_NS")
    layers.log_signals(rec, active, method="DCA", include_vane=True)
    layers.log_signals(rec, other, method="DA_NS", include_vane=False)
    assert {f"/signals/DCA/vane/{i}" for i in range(1, 7)} <= set(rec.paths)
    assert not any(p.startswith("/signals/DA_NS/vane/") for p in rec.paths)


def test_metric_table_markdown(tmp_path):
    metrics = {
        "DA_NS": {"saturation_percent": 0.0, "pwm_total_variation_deg": 1746.1, "solve_time_p95_ms": 2.15},
        "DCA": {"saturation_percent": 1.92134, "pwm_total_variation_deg": 18191.99, "solve_time_p95_ms": 1.49},
        "PCA_PREDICTIVE": {"saturation_percent": 2.19153, "pwm_total_variation_deg": 17319.59,
                           "solve_time_p95_ms": float("nan")},
    }
    table = _summary_markdown(metrics, {"status": "stress"})
    rows = [ln for ln in table.splitlines() if ln.startswith("| ") and "method" not in ln]
    assert len(rows) == 3
    assert "| method | saturation % | PWM total variation (deg) | solve time P95 (ms) | status |" in table
    assert "非本工具计算" in table
    assert "n/a" in table  # NaN metric rendered explicitly
    assert "stress" in table


def test_blueprint_smoke(tmp_path):
    logs = {m: _log(tmp_path, m) for m in ("DA_NS", "DCA")}
    rec = FakeRec()
    _send_multi_blueprint(rec, logs, "DCA", WINDOW)
    assert rec.blueprint is not None


def test_events_split_by_method(tmp_path):
    from shc09_viz.geometry import load_geometry

    cmd = np.zeros((1601, 6))
    cmd[10, 0] = np.deg2rad(40.0)  # one saturated frame
    path = write_comparison(
        comparison_path(tmp_path / "s", method="DCA"), method="DCA", arrays={"command_rad": cmd}
    )
    log = load_log(path)
    rec = FakeRec()
    layers.log_events(rec, log, load_geometry(), method="DCA")
    assert "/events/DCA/saturation" in rec.paths
    assert "/events/DCA/aero_extrapolation" in rec.paths
    rec_single = FakeRec()
    layers.log_events(rec_single, log, load_geometry())
    assert "/events/saturation" in rec_single.paths


def test_signal_stride_estimate():
    class L:
        n = 16001

    logs = {m: L() for m in ("DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE")}
    strides, extra_mb, chosen = _signal_strides(logs, "DCA")
    assert strides["DCA"] == 1
    assert chosen >= 2  # 5x(2)+6 series would exceed the 1.5x budget at full rate
    assert strides["DA_NS"] == chosen
    assert extra_mb < 0.5 * 19.86 * 1.5

    class Small:
        n = 800

    small = {m: Small() for m in ("DA_NS", "DCA")}
    s2, _, chosen2 = _signal_strides(small, "DCA")
    assert chosen2 == 1 and s2 == {"DA_NS": 1, "DCA": 1}
