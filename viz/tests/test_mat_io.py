"""Data-contract tests for both log shapes and the three time-base branches."""

import numpy as np
import pytest

from conftest import DT, N, comparison_path, synthetic_arrays, write_comparison, write_platform
from shc09_viz.mat_io import FlightLogError, load_log


def test_time_base_time_for_metrics(tmp_path):
    path = write_comparison(comparison_path(tmp_path))
    log = load_log(path)
    assert log.kind == "comparison"
    assert log.time_base == "time_for_metrics"
    assert log.n == N
    assert log.time_s[1] - log.time_s[0] == pytest.approx(DT)
    assert log.meta["method"] == "DCA"
    assert log.meta["sample_hz"] == 800


def test_time_base_falls_back_to_r_time_s(tmp_path):
    path = write_comparison(comparison_path(tmp_path), with_time=False)
    log = load_log(path)
    assert log.time_base == "r.time_s"
    assert log.n == N


def test_time_base_assumed_rate_warns(tmp_path, capsys):
    path = write_platform(tmp_path / "results" / "viz_fixture" / "DCA" / "log.mat")
    log = load_log(path, rate=800)
    assert log.kind == "platform"
    assert log.time_base == "assumed_rate"
    assert log.rate_hz == 800
    assert log.duration_s == pytest.approx(2.0)
    assert "assuming 800 Hz" in capsys.readouterr().err


def test_pwm_trailing_nan_is_allowed(tmp_path):
    log = load_log(write_comparison(comparison_path(tmp_path)))
    assert log.pwm_end_actual_delta_rad is not None
    assert np.isnan(log.pwm_end_actual_delta_rad[-1]).any()


def test_non_monotonic_time_is_rejected(tmp_path):
    arrays = synthetic_arrays()
    t = arrays["time_for_metrics"].copy()
    t[10, 0] = t[9, 0]
    path = write_comparison(comparison_path(tmp_path), arrays={"time_for_metrics": t})
    with pytest.raises(FlightLogError, match="strictly increasing"):
        load_log(path)


def test_wrong_position_shape_is_rejected(tmp_path):
    arrays = synthetic_arrays()
    path = write_comparison(comparison_path(tmp_path), arrays={"position_ned_m": arrays["position_ned_m"][:, :2]})
    with pytest.raises(FlightLogError, match="position_ned_m shape"):
        load_log(path)


def test_method_mismatch_is_rejected(tmp_path):
    path = write_comparison(comparison_path(tmp_path, method="DCA"), arrays={"name": np.array(["WLS"])})
    with pytest.raises(FlightLogError, match="refusing to mix logs"):
        load_log(path)


def test_nan_is_rejected(tmp_path):
    arrays = synthetic_arrays()
    p = arrays["position_ned_m"].copy()
    p[5, 1] = np.nan
    path = write_comparison(comparison_path(tmp_path), arrays={"position_ned_m": p})
    with pytest.raises(FlightLogError, match="NaN/Inf"):
        load_log(path)


def test_missing_file_is_rejected(tmp_path):
    with pytest.raises(FlightLogError, match="not found"):
        load_log(tmp_path / "nope.mat")


def test_rate_mismatch_is_rejected(tmp_path):
    # Stored samples are 800 Hz but c.sample_hz claims 400 Hz: contract violation.
    path = write_comparison(comparison_path(tmp_path), sample_hz=400)
    with pytest.raises(FlightLogError, match="does not match 400 Hz"):
        load_log(path)
