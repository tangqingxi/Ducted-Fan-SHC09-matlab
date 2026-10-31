"""The committed geometry JSON must match its own payload hash and the parameters."""

import json
from pathlib import Path

import numpy as np
import pytest

from shc09_viz.geometry import (
    DEFAULT_PATH,
    GeometryError,
    geometry_sha256,
    load_geometry,
    payload_text,
    vane_axes,
    vane_positions,
)


@pytest.fixture(scope="module")
def geom():
    if not DEFAULT_PATH.is_file():
        pytest.skip("run viz/geometry/export_geometry.m first")
    return load_geometry()


def test_committed_geometry_hash_is_valid(geom):
    assert geom["source"] == "ca_shc09_parameters"
    assert geom["sha256"] == geometry_sha256(geom)


def test_geometry_constants_match_plan(geom):
    v = geom["vehicle"]
    assert v["l1_m"] == pytest.approx(0.267)
    assert v["l2_m"] == pytest.approx(0.066)
    assert v["vane_limit_rad"] == pytest.approx(np.deg2rad(40))
    assert v["disc_area_radius_m"] == pytest.approx(0.114)
    assert v["duct_outer_m"] == pytest.approx(0.30)
    assert geom["assumed"]


def test_tampered_payload_is_detected(geom):
    tampered = json.loads(json.dumps(geom))
    tampered["vehicle"]["l1_m"] += 1e-9
    assert geometry_sha256(tampered) != geom["sha256"]


def test_vane_positions_and_axes(geom):
    pos = vane_positions(geom)
    assert pos.shape == (6, 3)
    assert np.allclose(np.hypot(pos[:, 0], pos[:, 1]), 0.267)
    assert np.allclose(pos[:, 2], 0.066)
    axes = vane_axes(geom)
    assert np.allclose(np.linalg.norm(axes, axis=1), 1.0)
    # tangential: perpendicular to the radial direction and to z
    radial = np.column_stack([pos[:, 0], pos[:, 1], np.zeros(6)])
    assert np.allclose(np.sum(axes * radial, axis=1), 0.0)
    assert np.allclose(axes[:, 2], 0.0)


def test_missing_geometry_raises(tmp_path: Path):
    with pytest.raises(GeometryError, match="not found"):
        load_geometry(tmp_path / "missing.json")
