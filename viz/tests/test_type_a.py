"""Type A (comparison log) end-to-end contract and manifest provenance."""

import numpy as np

from conftest import comparison_path, write_comparison
from shc09_viz.layers import log_trajectories
from shc09_viz.manifest import build_manifest
from shc09_viz.mat_io import load_log


class FakeRec:
    def __init__(self):
        self.paths = []

    def log(self, path, archetype, static=False):
        self.paths.append(path)

    def set_time(self, name, duration=None):
        pass


def test_type_a_time_base(tmp_path, capsys):
    path = write_comparison(comparison_path(tmp_path), estimated=True)
    log = load_log(path)  # no --rate: must not warn
    assert log.kind == "comparison"
    assert log.time_base == "time_for_metrics"
    assert log.n == 1601
    assert log.duration_s == 2.0
    assert log.meta["estimator_mode"] == "lite"
    assert log.meta["estimator_mode_source"] == "c"
    assert "assuming" not in capsys.readouterr().err


def test_type_a_estimated_layer(tmp_path):
    lite = load_log(write_comparison(comparison_path(tmp_path, mode="lite"), estimated=True))
    rec = FakeRec()
    log_trajectories(rec, lite)
    assert "/traj/estimated" in rec.paths

    ideal = load_log(write_comparison(comparison_path(tmp_path, mode="ideal"), estimated=False))
    rec2 = FakeRec()
    log_trajectories(rec2, ideal)
    assert "/traj/estimated" not in rec2.paths


def test_manifest_not_null(tmp_path):
    path = write_comparison(comparison_path(tmp_path), estimated=True)
    log = load_log(path)

    class FakeRrd:
        name = "replay.rrd"

        def stat(self):
            class S:
                st_size = 1234

            return S()

    m = build_manifest(log, {"sha256": "0" * 64, "source": "ca_shc09_parameters"}, FakeRrd(), str(path))
    assert m["input"]["estimator_mode"] == "lite"
    assert m["input"]["estimator_mode_source"] == "c"
    assert m["input"]["plant_model"] == "shc09_6dof"
    assert m["input"]["plant_model_source"] == "c"


def test_manifest_estimator_from_filename(tmp_path):
    # No c.estimator_mode (real MATLAB string objects are opaque): use the name.
    path = write_comparison(comparison_path(tmp_path, mode="lite"), c_estimator=None)
    log = load_log(path)
    assert log.meta["estimator_mode"] == "lite"
    assert log.meta["estimator_mode_source"] == "filename"


def test_plant_model_from_output_tag(tmp_path):
    path = write_comparison(
        comparison_path(tmp_path),
        c_plant=None,
        c_output_tag="shc09_6dof_meng_pwm333",
    )
    log = load_log(path)
    assert log.meta["plant_model"] == "shc09_6dof"
    assert log.meta["plant_model_source"] == "output_tag"
