"""M0 API smoke: probe the local rerun-sdk 0.41 API, write 10 points to .rrd."""

import os
import sys

import rerun as rr


def main() -> int:
    print("rerun", rr.__version__)
    print("has Scalar:", hasattr(rr, "Scalar"), "has Scalars:", hasattr(rr, "Scalars"))
    print("has RecordingStream.save:", hasattr(rr.RecordingStream, "save"))
    print("has rr.save:", hasattr(rr, "save"))
    print("has set_time:", hasattr(rr, "set_time"), "has set_time_sequence:", hasattr(rr, "set_time_sequence"))

    out = os.path.join("results", "viz", "smoke")
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "smoke.rrd")

    rec = rr.RecordingStream("shc09_viz_smoke")
    rec.save(path)
    for i in range(10):
        if hasattr(rr, "set_time"):
            rr.set_time("t", duration=i / 10.0)
        else:
            rr.set_time_sequence("t", i)
        rec.log("world/points", rr.Points3D([[i / 10.0, 0.0, 0.0]], radii=0.02))
        if hasattr(rr, "Scalars"):
            rec.log("signals/value", rr.Scalars(float(i)))
        else:
            rec.log("signals/value", rr.Scalar(float(i)))
    rec.flush()
    print("wrote", path, os.path.getsize(path), "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
