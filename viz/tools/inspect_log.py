"""Print the validated shape of one log (M1 acceptance helper)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from shc09_viz.mat_io import load_log  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="Inspect and validate an SHC09 .mat log")
    ap.add_argument("--log", required=True)
    ap.add_argument("--rate", type=float, default=None)
    args = ap.parse_args()
    log = load_log(args.log, rate=args.rate)
    dt = (log.time_s[-1] - log.time_s[0]) / max(log.n - 1, 1)
    print(f"kind      {log.kind}")
    print(f"method    {log.meta.get('method')}")
    print(f"n         {log.n}")
    print(f"time      t in [{log.time_s[0]:.6g}, {log.time_s[-1]:.6g}] s, dt={dt:.8g} s")
    print(f"time_base {log.time_base} (rate {log.rate_hz:g} Hz)")
    print(f"pwm       {0 if log.pwm_update_time_s is None else log.pwm_update_time_s.size} events")
    print(f"source    {log.source}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
