"""Launcher for the SHC09 log replay pipeline.

Usage (no install needed):  python viz\\replay.py --log <path> --out <dir>
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from shc09_viz.cli import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
