"""End-to-end smoke: one command -> replay.rrd + manifest.json, twice."

Uses a synthetic 2 s platform log (no MATLAB), so it covers the headless path,
the assumed-rate branch and manifest determinism.
"""

import json

import pytest

from conftest import write_platform
from shc09_viz.cli import main


@pytest.fixture(scope="module")
def replay(tmp_path_factory):
    tmp = tmp_path_factory.mktemp("replay")
    log = write_platform(tmp / "results" / "viz_fixture" / "DCA" / "log.mat")
    out = tmp / "out1"
    rc = main(["--log", str(log), "--out", str(out), "--rate", "800"])
    return tmp, log, out, rc


def test_replay_writes_rrd_and_manifest(replay):
    tmp, log, out, rc = replay
    assert rc == 0
    rrd = out / "replay.rrd"
    assert rrd.is_file() and rrd.stat().st_size > 1024
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["input"]["n"] == 1601
    assert manifest["input"]["time_base"] == "assumed_rate"
    assert manifest["input"]["rate_hz"] == 800.0
    assert manifest["geometry"]["sha256"]
    assert manifest["assumptions"]


def test_manifest_is_stable_except_created_at(replay):
    tmp, log, _, _ = replay
    out2 = tmp / "out2"
    assert main(["--log", str(log), "--out", str(out2), "--rate", "800"]) == 0
    a = json.loads((tmp / "out1" / "manifest.json").read_text(encoding="utf-8"))
    b = json.loads((out2 / "manifest.json").read_text(encoding="utf-8"))
    a.pop("created_at")
    b.pop("created_at")
    assert a == b


def test_missing_log_returns_error(tmp_path):
    assert main(["--log", str(tmp_path / "nope.mat"), "--out", str(tmp_path / "out")]) == 1
