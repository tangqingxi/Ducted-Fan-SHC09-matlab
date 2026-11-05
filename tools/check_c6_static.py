"""静态检查 C6/W5 范围、工具入口和文档工作流，不冒充 MATLAB 测试。"""
import argparse
import csv
import hashlib
import json
import subprocess
from pathlib import Path

MAPPING_SHA256 = "1022a7d78afe3831d448018466d1259b8ad717d6c956b8348f1e662a45a5656a"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check(root, mapping):
    assert sha(mapping) == MAPPING_SHA256, "C6 映射身份不匹配。"
    rows = list(csv.DictReader(mapping.open(encoding="utf-8", newline="")))
    assert len(rows) == 223
    counts = {k: sum(r["action"] == k for r in rows) for k in ("KEEP", "PATCH", "DEFER", "MOVE")}
    assert counts == {"KEEP": 215, "PATCH": 1, "DEFER": 7, "MOVE": 0}, counts
    assert all((root / r["old_path"]).is_file() for r in rows)
    assert (root / "tools" / "repo_inventory.py").read_text(encoding="utf-8").find("layouts = {") >= 0
    agents = (root / "AGENTS.md").read_text(encoding="utf-8")
    assert "当前唯一开发分支" not in agents
    assert "refactor/phase3-source" in agents and "稳定基线" in agents
    repo = (root / "docs" / "repository_map.md").read_text(encoding="utf-8")
    assert "C5/W4" in repo and "尚未落地" in repo
    assert not Path(r"D:/AeroGNC-Backup").exists() and not Path(r"D:/AeroGNC-Restore-Test").exists()
    tracked = set(subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"]).decode().split("\0"))
    assert "results" not in {p.split("/")[0] for p in tracked}
    return {"status": "PASS", "w5_rows": len(rows), "actions": counts,
            "mapping_sha256": MAPPING_SHA256, "patched": [r["old_path"] for r in rows if r["action"] == "PATCH"],
            "deferred": [r["old_path"] for r in rows if r["action"] == "DEFER"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--mapping", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = check(args.root, args.mapping)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(text + "\n", encoding="utf-8", newline="\n")
    print("PASS: C6 static scope and workflow checks")
