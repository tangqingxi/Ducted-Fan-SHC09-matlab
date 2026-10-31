"""Writable temp directory handling for launching the Rerun viewer.

Rerun 0.41 needs a writable temp directory for its internal catalog.  On some
Windows hosts the OS temp is not writable for this process, so fall back to the
repository-local ``.tmp/`` (git-ignored) instead of failing to start a viewer.
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
FALLBACK_DIR = REPO_ROOT / ".tmp"


def _writable(path: Path) -> bool:
    """True only if a file can actually be created and removed in ``path``."""
    try:
        path.mkdir(parents=True, exist_ok=True)
        fd, probe = tempfile.mkstemp(prefix="shc09-viz-", dir=str(path))
        os.close(fd)
        os.unlink(probe)
        return True
    except OSError:
        return False


def temp_env(environ: dict | None = None, temp_dir: str | Path | None = None) -> dict:
    """Environment for the viewer: system TEMP if writable, else ``<repo>/.tmp``."""
    env = dict(os.environ if environ is None else environ)
    candidate = Path(temp_dir) if temp_dir is not None else Path(tempfile.gettempdir())
    if _writable(candidate):
        target = candidate
    else:
        FALLBACK_DIR.mkdir(parents=True, exist_ok=True)
        target = FALLBACK_DIR
    env["TEMP"] = str(target)
    env["TMP"] = str(target)
    return env
