"""Render a PNG screenshot of a replay with the bundled Rerun viewer (headless).

Rerun needs a writable temp directory for its internal catalog; in this
workspace the OS temp is outside the sandbox, so we point TEMP at ./.tmp.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description="Screenshot a .rrd with the Rerun CLI")
    ap.add_argument("--rrd", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--window-size", default="1400x900")
    args = ap.parse_args()

    exe = shutil.which("rerun") or str(Path(sys.executable).with_name("rerun.exe"))
    if not Path(exe).exists() and shutil.which(exe) is None:
        print(f"screenshot: rerun CLI not found ({exe})", file=sys.stderr)
        return 1
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    tmp = Path.cwd() / ".tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    env["TEMP"] = str(tmp)
    env["TMP"] = str(tmp)
    cmd = [exe, str(Path(args.rrd).resolve()), "--screenshot-to", str(out.resolve()),
           "--window-size", args.window_size]
    print("screenshot:", " ".join(cmd))
    proc = subprocess.run(cmd, env=env)  # noqa: S603
    if proc.returncode != 0:
        print(f"screenshot: rerun exited with {proc.returncode}", file=sys.stderr)
        return proc.returncode
    print(f"screenshot: wrote {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
