"""Static world and vehicle geometry for the Rerun replay (plan §8)."""

from __future__ import annotations

import numpy as np
import rerun as rr

from . import geometry as geo
from .layers import BODY_GRAY, CMD_PANEL, DARK_GRAY, FAN_TEAL, GRID_GRAY, VANE_HALF_EXTENTS


def _circle(radius: float, z: float = 0.0, n: int = 96) -> np.ndarray:
    a = np.linspace(0.0, 2.0 * np.pi, n)
    return np.column_stack([radius * np.cos(a), radius * np.sin(a), np.full(n, z)])


def log_world(rec: rr.RecordingStream, half_extent_m: float = 5.0) -> None:
    """1 m ground grid (z = 0) plus N/E origin arrows.  ENU frame."""
    lines = []
    vals = np.arange(-half_extent_m, half_extent_m + 1e-9, 1.0)
    for v in vals:
        lines.append([[v, -half_extent_m, 0.0], [v, half_extent_m, 0.0]])
        lines.append([[-half_extent_m, v, 0.0], [half_extent_m, v, 0.0]])
    rec.log("/world/grid", rr.LineStrips3D(lines, colors=[GRID_GRAY], radii=0.004), static=True)
    rec.log(
        "/world/axes",
        rr.Arrows3D(
            origins=[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
            vectors=[[0.0, 1.0, 0.0], [1.0, 0.0, 0.0]],  # north, east (ENU)
            colors=[[255, 255, 255], [160, 160, 160]],
            labels=["N", "E"],
            radii=0.012,
        ),
        static=True,
    )


def log_vehicle_static(rec: rr.RecordingStream, g: dict) -> None:
    """Duct ring, fan disc, body box, body axes and command-panel ghosts."""
    v = g["vehicle"]
    outer = _circle(v["duct_outer_m"])
    inner = _circle(v["duct_inner_m"])
    rec.log("/vehicle/duct", rr.LineStrips3D([outer, inner], colors=[DARK_GRAY, DARK_GRAY], radii=0.003), static=True)
    fan = _circle(v["disc_area_radius_m"], z=-0.004)
    rec.log("/vehicle/fan", rr.LineStrips3D([fan], colors=[FAN_TEAL], radii=0.002), static=True)

    half = np.asarray(v["body_box_m"], dtype=float) / 2.0
    rec.log("/vehicle/body", rr.Boxes3D(centers=[[0, 0, 0]], half_sizes=[half], colors=[BODY_GRAY]), static=True)
    rec.log(
        "/vehicle/body/axes",
        rr.Arrows3D(
            origins=np.zeros((3, 3)),
            vectors=np.eye(3) * 0.18,
            colors=[[255, 0, 0], [0, 255, 0], [0, 0, 255]],
            labels=["x", "y", "z"],
            radii=0.004,
        ),
        static=True,
    )
    # Command ghosts are a fixed translucent colour: they must not be confused
    # with the true vane deflection (plan §6.5).
    for i in range(6):
        rec.log(
            f"/vehicle/vane_cmd/{i + 1}/panel",
            rr.Boxes3D(centers=[[0, 0, 0]], half_sizes=[VANE_HALF_EXTENTS], colors=[CMD_PANEL]),
            static=True,
        )


def vehicle_hinges(g: dict) -> np.ndarray:
    return geo.vane_positions(g)


def vehicle_axes(g: dict) -> np.ndarray:
    return geo.vane_axes(g)
