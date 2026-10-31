"""temp_env(): use system TEMP when writable, fall back to <repo>/.tmp."""

from pathlib import Path

from shc09_viz.temp_env import FALLBACK_DIR, temp_env


def test_temp_env_fallback_when_temp_unwritable(tmp_path):
    blocker = tmp_path / "not_a_dir"
    blocker.write_text("x", encoding="utf-8")
    env = temp_env(environ={"TEMP": "ignored"}, temp_dir=blocker)
    assert Path(env["TEMP"]) == FALLBACK_DIR
    assert Path(env["TMP"]) == FALLBACK_DIR
    assert FALLBACK_DIR.is_dir()


def test_temp_env_uses_writable_dir(tmp_path):
    env = temp_env(environ={"TEMP": "ignored"}, temp_dir=tmp_path)
    assert Path(env["TEMP"]) == tmp_path
    assert Path(env["TMP"]) == tmp_path
