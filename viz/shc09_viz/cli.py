"""Command line entry point for the replay pipeline."""

from __future__ import annotations

import argparse
import sys


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="viz\\replay.py",
        description="Replay a saved SHC09 .mat flight log as a Rerun .rrd recording.",
    )
    p.add_argument("--log", help="path to a .mat log (comparison or platform_run)")
    p.add_argument("--out", help="output directory for replay.rrd + manifest.json")
    p.add_argument(
        "--rate",
        type=float,
        default=None,
        help="sample rate in Hz, only used when the log has no time vector (default 800)",
    )
    p.add_argument(
        "--no-viewer",
        action="store_true",
        help="write the .rrd only; never try to open a viewer",
    )
    p.add_argument("--version", action="version", version="shc09-viz 0.1.0")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if not args.log or not args.out:
        build_parser().print_help(sys.stderr)
        print("replay: --log and --out are required", file=sys.stderr)
        return 2
    print(
        "replay: pipeline not wired yet (M0 skeleton); "
        f"log={args.log} out={args.out} rate={args.rate}",
        file=sys.stderr,
    )
    return 3
