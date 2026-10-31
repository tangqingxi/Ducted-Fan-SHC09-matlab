"""SHC09 geometry loaded from the MATLAB-exported JSON (decision D1).

The JSON is written by ``viz/geometry/export_geometry.m`` and carries a SHA-256
over a canonical ASCII payload.  Python never hard-codes l1/l2/P_cs; if the
MATLAB parameters change and the JSON is not re-exported, ``load_geometry``
raises.  Geometry is *schematic*: see the ``assumed`` field (§6.6).
"""

from __future__ import annotations

import hashlib
import json
from functools import lru_cache
from pathlib import Path

import numpy as np

DEFAULT_PATH = Path(__file__).resolve().parents[1] / "geometry" / "shc09_geometry.json"


class GeometryError(ValueError):
    """Raised when the geometry JSON is missing, stale or malformed."""


def _fmt(x) -> str:
    return format(float(x), ".17g")


def payload_text(g: dict) -> str:
    """Rebuild the canonical payload that export_geometry.m hashes."""
    v = g["vehicle"]
    lines = [
        "shc09-geometry-v1",
        f"l1_m {_fmt(v['l1_m'])}",
        f"l2_m {_fmt(v['l2_m'])}",
        f"vane_limit_rad {_fmt(v['vane_limit_rad'])}",
        f"disc_area_m2 {_fmt(v['disc_area_m2'])}",
        f"disc_area_radius_m {_fmt(v['disc_area_radius_m'])}",
        f"duct_outer_m {_fmt(v['duct_outer_m'])}",
        f"duct_inner_m {_fmt(v['duct_inner_m'])}",
        f"body_x_m {_fmt(v['body_box_m'][0])}",
        f"body_y_m {_fmt(v['body_box_m'][1])}",
        f"body_z_m {_fmt(v['body_box_m'][2])}",
        f"mass_kg {_fmt(v['mass_kg'])}",
        f"inertia_xx {_fmt(v['inertia_kg_m2'][0])}",
        f"inertia_yy {_fmt(v['inertia_kg_m2'][1])}",
        f"inertia_zz {_fmt(v['inertia_kg_m2'][2])}",
    ]
    verts = v["vane_vertices"]
    for i in range(3):
        for j in range(6):
            lines.append(f"vane_vertex_{i + 1}_{j + 1} {_fmt(verts[i][j])}")
    return "\n".join(lines)


def geometry_sha256(g: dict) -> str:
    return hashlib.sha256(payload_text(g).encode("utf-8")).hexdigest()


@lru_cache(maxsize=4)
def _load(path_str: str, mtime: float) -> dict:
    path = Path(path_str)
    with path.open("r", encoding="utf-8") as fh:
        g = json.load(fh)
    for key in ("source", "generated_by", "sha256", "vehicle", "assumed"):
        if key not in g:
            raise GeometryError(f"{path.name}: missing key {key}")
    expected = geometry_sha256(g)
    if expected != g["sha256"]:
        raise GeometryError(
            f"{path.name}: sha256 mismatch (file says {g['sha256']}, payload hashes to "
            f"{expected}). Re-run viz/geometry/export_geometry.m - parameters drifted."
        )
    v = g["vehicle"]
    verts = np.asarray(v["vane_vertices"], dtype=float)
    if verts.shape != (3, 6):
        raise GeometryError(f"{path.name}: vane_vertices shape {verts.shape}, expected (3, 6)")
    if not np.allclose(np.hypot(verts[0], verts[1]), 1.0, atol=1e-12):
        raise GeometryError(f"{path.name}: vane vertices are not unit hexagon vertices")
    return g


def load_geometry(path: str | Path | None = None) -> dict:
    p = Path(path) if path is not None else DEFAULT_PATH
    if not p.is_file():
        raise GeometryError(f"geometry file not found: {p} (run export_geometry.m)")
    return _load(str(p.resolve()), p.stat().st_mtime)


def vane_positions(g: dict) -> np.ndarray:
    """Six vane hinge points in the body frame: [l1*P1, l1*P2, l2]."""
    v = g["vehicle"]
    verts = np.asarray(v["vane_vertices"], dtype=float)
    l1, l2 = float(v["l1_m"]), float(v["l2_m"])
    return np.column_stack([l1 * verts[0], l1 * verts[1], np.full(6, l2)])


def vane_axes(g: dict) -> np.ndarray:
    """Tangential rotation axes (-P2, P1, 0), unit length (display choice)."""
    verts = np.asarray(g["vehicle"]["vane_vertices"], dtype=float)
    axes = np.column_stack([-verts[1], verts[0], np.zeros(6)])
    return axes / np.linalg.norm(axes, axis=1, keepdims=True)
