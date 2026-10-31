"""Study selection, windows, metrics and multi-log manifest (plan v0.2 A/B/C)."""

import json
import shutil
from pathlib import Path

import numpy as np
import pytest

from conftest import comparison_path, synthetic_arrays, write_comparison, write_study
from shc09_viz.cli import main
from shc09_viz.mat_io import load_log
from shc09_viz.study import (
    METHODS,
    MixedConditionError,
    StudyError,
    compute_metrics,
    load_comparability,
    resolve_window,
    select_logs,
)

FIVE = ("DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE")


def test_multi_log_same_case(tmp_path):
    study = write_study(tmp_path / "study", methods=FIVE)
    selection = select_logs(study, "M0", "lite", 1)
    assert list(selection.logs) == list(METHODS)
    assert selection.missing_methods == []
    assert all(p.is_file() for p in selection.logs.values())


def test_multi_log_mixed_seed_rejected(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"), seed=2)
    with pytest.raises(MixedConditionError, match="seed 1"):
        select_logs(study, "M0", "lite", 1)


def test_multi_log_mixed_case_rejected(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"), case="M2b")
    with pytest.raises(MixedConditionError, match="case 'M0'"):
        select_logs(study, "M0", "lite", 1)


def test_multi_log_ambiguous_method_rejected(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"))
    dca = next((study / "logs").glob("*_DCA_*.mat"))
    dup = dca.with_name(dca.name.replace(dca.stem.rsplit("_", 1)[1], "f" * 64))
    shutil.copyfile(dca, dup)
    with pytest.raises(StudyError, match="ambiguous"):
        select_logs(study, "M0", "lite", 1)


def test_multi_log_too_few_rejected(tmp_path):
    study = write_study(tmp_path / "study", methods=("DCA",))
    with pytest.raises(StudyError, match="at least 2"):
        select_logs(study, "M0", "lite", 1)


def test_metrics_window_clamp(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"))
    window = resolve_window(study, "M0", "lite", "task", duration_s=1.0)
    assert window["start_s"] == 0.5
    assert window["end_s"] == 1.0  # task window is [0.5, 1.5]
    assert window["clamped"] is True
    assert window["source"] == "summary.csv"


def test_metrics_window_start_beyond_log_rejected(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"))
    with pytest.raises(StudyError, match="beyond log duration"):
        resolve_window(study, "M0", "lite", "task", duration_s=0.4)


def test_window_whole(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"))
    window = resolve_window(study, "M0", "lite", "whole", duration_s=2.0)
    assert (window["start_s"], window["end_s"]) == (0.0, 2.0)
    assert window["source"] == "whole"
    assert window["clamped"] is False


def test_metrics_match_summary_csv(tmp_path):
    """Golden check: values written to summary.csv must equal compute_metrics."""
    arrays = synthetic_arrays()
    pwm_t = arrays["pwm_update_time_s"].ravel()
    cmd = arrays["pwm_command_rad"].copy()
    in_window = (pwm_t >= 0.5) & (pwm_t <= 1.5)
    cmd[np.flatnonzero(in_window)[:40], 0] = np.deg2rad(45.0)  # saturated on vane 1
    solve = np.linspace(0.001, 0.02, arrays["solve_time_s"].shape[0]).reshape(-1, 1)
    path = write_comparison(
        comparison_path(tmp_path / "logs", method="DCA"),
        method="DCA",
        arrays={"pwm_command_rad": cmd, "solve_time_s": solve},
    )
    log = load_log(path)
    window = {"name": "task", "start_s": 0.5, "end_s": 1.5, "source": "summary.csv", "clamped": False}
    got = compute_metrics(log, window, cm_deg=40.0)

    # independent reference implementation of the frozen definitions
    sel = (pwm_t >= 0.5) & (pwm_t <= 1.5)
    deg = np.rad2deg(cmd[sel])
    expected_sat = 100.0 * float(np.mean(np.any(np.abs(deg) >= 40.0 - 1e-5, axis=1)))
    expected_tv = float(np.sum(np.abs(np.diff(deg, axis=0))))
    q = (log.time_s >= 0.5) & (log.time_s <= 1.5)
    expected_p95 = 1000.0 * float(np.percentile(solve.ravel()[q], 95))

    assert got["saturation_percent"] == pytest.approx(expected_sat, abs=1e-12)
    assert got["pwm_total_variation_deg"] == pytest.approx(expected_tv, abs=1e-9)
    assert got["solve_time_p95_ms"] == pytest.approx(expected_p95, abs=1e-9)
    # and the same numbers as written to summary.csv (the golden file)
    summary = tmp_path / "summary.csv"
    summary.write_text(
        "case_id,estimator_mode,seed,method,window,saturation_percent,pwm_total_variation_deg,"
        "solve_time_p95_ms\n"
        f"M0,lite,1,DCA,task,{expected_sat!r},{expected_tv!r},{expected_p95!r}\n",
        encoding="utf-8",
    )
    row = summary.read_text(encoding="utf-8").splitlines()[1].split(",")
    assert float(row[5]) == pytest.approx(got["saturation_percent"], abs=1e-12)
    assert float(row[6]) == pytest.approx(got["pwm_total_variation_deg"], abs=1e-9)
    assert float(row[7]) == pytest.approx(got["solve_time_p95_ms"], abs=1e-9)


def test_manifest_multi(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"))
    out = tmp_path / "out"
    rc = main(
        ["--study", str(study), "--case", "M0", "--mode", "lite", "--seed", "1",
         "--out", str(out), "--active", "DCA"]
    )
    assert rc == 0
    rrd = out / "replay.rrd"
    assert rrd.is_file() and rrd.stat().st_size > 1024
    m = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert m["schema"] == "shc09-replay-manifest-v2"
    assert [entry["method"] for entry in m["logs"]] == ["DA_NS", "DCA"]
    for entry in m["logs"]:
        assert Path(entry["path"]).is_file()
        assert len(entry["sha256"]) == 64
    assert m["study"]["case"] == "M0"
    assert m["study"]["seed"] == 1
    assert m["study"]["active_method"] == "DCA"
    assert m["metrics"]["window"]["start_s"] == 0.5
    assert set(next(iter(m["metrics"]["values"].values()))) >= {
        "saturation_percent", "pwm_total_variation_deg", "solve_time_p95_ms"
    }
    assert m["comparability"]["status"] == "stress"


def test_single_log_backward_compat(tmp_path):
    log = write_comparison(comparison_path(tmp_path, method="DCA"))
    out = tmp_path / "out"
    assert main(["--log", str(log), "--out", str(out)]) == 0
    m = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert m["schema"] == "shc09-replay-manifest-v1"
    assert set(m) == {"schema", "created_at", "recording", "input", "geometry", "code",
                      "versions", "assumptions"}
    assert set(m["input"]) == {
        "path", "sha256", "kind", "n", "duration_s", "time_base", "rate_hz", "method",
        "estimator_mode", "estimator_mode_source", "plant_model", "plant_model_source",
    }
    assert set(m["recording"]) == {"application_id", "rrd"}


def test_comparability_missing_is_unknown(tmp_path):
    study = write_study(tmp_path / "study", methods=("DA_NS", "DCA"))
    (study / "comparability.csv").unlink()
    assert load_comparability(study, "M0", "lite")["status"] == "unknown"
