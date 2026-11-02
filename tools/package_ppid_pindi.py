"""打包新四环研究轻量证据，并独立检查哈希、输入一致性和旧F8保护。"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import platform
import subprocess
import zipfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write_text(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value.replace("\r\n", "\n").encode("utf-8"))


def write_json(path, value):
    write_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def verify(package):
    manifest = read_json(package / "manifest.json")
    expected = {row["path"]: row for row in manifest["files"]}
    actual = {p.relative_to(package).as_posix(): p for p in package.rglob("*") if p.is_file() and p.name != "manifest.json"}
    assert set(actual) == set(expected), "交付目录文件集合与manifest不一致"
    assert len({p.casefold() for p in actual}) == len(actual), "存在大小写文件名冲突"
    for relative, path in actual.items():
        assert path.stat().st_size == expected[relative]["bytes"] and digest(path) == expected[relative]["sha256"], relative
        assert path.suffix.lower() not in {".mat", ".pyc", ".exe", ".log"}, relative
        assert not any(part in {"results", "__pycache__", "geometry", "logs"} for part in path.relative_to(package).parts), relative
    assert len(list((package / "tracks_10hz").glob("*.csv"))) == 15
    assert len(read_csv(package / "summary.csv")) == 15 and len(read_csv(package / "state_metrics.csv")) == 720
    assert all(r["status"] == "completed" for r in read_csv(package / "status.csv"))
    assert read_json(package / "completion.json")["completed"] == 15
    for track in (package / "tracks_10hz").glob("*.csv"):
        rows = read_csv(track)
        assert len(rows) == 521 and float(rows[0]["time_s"]) == 0 and float(rows[-1]["time_s"]) == 52
    # 压缩包仅含本阶段源码和文档，不允许借压缩隐藏重型结果。
    with zipfile.ZipFile(package / "reproducibility" / "new_sources.zip") as archive:
        for name in archive.namelist():
            assert ".." not in Path(name).parts and not name.startswith(("/", "results/", "build/"))
            assert Path(name).suffix in {".m", ".py", ".md", ".json"}, name
    return {"files_including_manifest": len(actual) + 1, "bytes": sum(p.stat().st_size for p in package.rglob("*") if p.is_file()),
            "manifest_verified": True, "lightweight_only": True, "track_files": 15}


def build(root, folder, package, old_root):
    assert not package.exists(), "不覆盖已有交付包"
    protocol = read_json(folder / "protocol.json")
    rows = read_csv(folder / "status.csv")
    expected = {(method, str(seed)) for method in protocol["methods"] for seed in protocol["formal_seeds"]}
    assert len(rows) == 15 and {(r["method"], r["seed"]) for r in rows} == expected
    assert all(r["status"] == "completed" for r in rows), "正式实验尚未全部完成"
    checks = read_json(folder / "independent_checks.json")
    assert checks["logs_verified"] == 15 and checks["numerical_sources_verified"] and checks["simulations_rerun"] == 0
    priority = read_json(folder / "priority_checks.json")
    assert priority["runs_verified"] == 6 and priority["independent_lp_samples"] > 0 and priority["simulations_rerun"] == 0
    provenance = read_csv(folder / "provenance.csv")
    assert len(provenance) == 15 and {(r["method"], r["seed"]) for r in provenance} == expected
    assert all(r["truth_feedback_absent"].lower() in {"1", "true"} for r in provenance)
    for seed in protocol["formal_seeds"]:
        signatures = {r["input_signature"] for r in provenance if r["seed"] == str(seed)}
        assert len(signatures) == 1
    # 旧数据在独立原工作区，只读核对全部原始保护清单。
    guard = read_json(root / "results" / "ppid_pindi_work_20261101" / "original_f8_guard.json")
    for relative, sha in guard.items():
        assert digest(old_root / relative) == sha, f"旧F8证据变化：{relative}"
    assert len(guard) == 280
    lock = read_json(root / "research" / "ppid_pindi" / "formal_lock.json")
    sources = read_json(folder / "sources.json")
    assert lock["sources"] == sources
    for item in sources["files"]:
        assert digest(root / item["path"]) == item["sha256"], item["path"]
    assert digest(root / "build" / "px4_ecl" / "px4_ecl_bridge.exe") == sources["ekf_executable_sha256"]
    package.mkdir(parents=True)
    for name in ["protocol.json", "sources.json", "effective_configurations.json", "summary.csv", "aggregate_metrics.csv", "state_metrics.csv", "solver_timing.csv", "priority_summary.csv", "priority_checks.json", "status.csv", "provenance.csv", "completion.json", "independent_checks.json", "report.md"]:
        write_text(package / name, (folder / name).read_text(encoding="utf-8-sig"))
    write_text(package / "formal_lock.json", (root / "research" / "ppid_pindi" / "formal_lock.json").read_text(encoding="utf-8-sig"))
    for path in (folder / "figures").iterdir():
        assert path.suffix in {".png", ".pdf"}
        dest = package / "figures" / path.name; dest.parent.mkdir(exist_ok=True); dest.write_bytes(path.read_bytes())
    for path in sorted((folder / "tracks").glob("*.csv")):
        with path.open(encoding="utf-8-sig", newline="") as stream:
            reader = csv.reader(stream); header = next(reader); sampled = [row for i, row in enumerate(reader) if i % 10 == 0]
        output = io.StringIO(newline=""); writer = csv.writer(output, lineterminator="\n"); writer.writerow(header); writer.writerows(sampled)
        assert len(sampled) == 521
        write_text(package / "tracks_10hz" / path.name, output.getvalue())
    for label in ["20261101_cuav_dev1", "20261101_cuav_dev2_local_frame"]:
        pilot = root / "results" / ("ppid_pindi_pilot_" + label)
        for name in ["protocol.json", "sources.json", "summary.csv", "status.csv"]:
            write_text(package / "development" / label / name, (pilot / name).read_text(encoding="utf-8-sig"))
    for path in (root / "results" / "ppid_pindi_work_20261101").glob("*.json"):
        write_text(package / "development" / path.name, path.read_text(encoding="utf-8-sig"))
    for name in ["build/px4_ecl/build_manifest.json", "third_party/source_manifest.json"]:
        write_text(package / "reproducibility" / Path(name).name, (root / name).read_text(encoding="utf-8-sig"))
    source_paths = list((root / "research" / "ppid_pindi").glob("*"))
    source_paths += [root / name for name in ["AGENTS.md", "README.md", "HANDOFF.md", "run_ppid_pindi.m", "tests/test_ppid_pindi_results.m", "tests/audit_ppid_pindi_priority.m", "tools/plot_ppid_pindi.py", "tools/package_ppid_pindi.py"]]
    with zipfile.ZipFile(package / "reproducibility" / "new_sources.zip", "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source_paths):
            assert path.is_file() and path.suffix in {".m", ".py", ".md", ".json"}
            archive.writestr(path.relative_to(root).as_posix(), path.read_bytes())
    version = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    import matplotlib
    import numpy
    write_json(package / "reproducibility" / "environment.json", {
        "base_commit": version, "branch": "controller-ppid-p-indi", "python": platform.python_version(),
        "matplotlib": matplotlib.__version__, "numpy": numpy.__version__, "new_sources_uncommitted": True,
        "results_relative_path": folder.relative_to(root).as_posix(), "old_f8_files_sha256_verified": len(guard),
        "score_sample_hz": 800, "plot_sample_hz": 100, "package_track_sample_hz": 10,
        "relative_mission_frame": True, "post_flight_alignment": False})
    write_text(package / "README.md", """# 四环P–PID/P–INDI八字研究交付

先读 [结果报告](report.md) 和 [正式协议](protocol.json)。五分配器共用控制、EKF和含偏置的CUAV类别误差模型。

`summary.csv`为15条完整飞行的800 Hz离线评分；`state_metrics.csv`为四窗口×十二状态指标。`tracks_10hz/`仅为展示抽取，每条521行，不能替代完整日志评分。`figures/`为PNG/PDF。

`development/`保留第一次伪逆未达标和第二次通过的证据、局部任务原点更改说明及旧F8哈希保护清单。起飞前只用EKF固定局部原点，原始全球坐标误差仍单独报告；不作飞行后真值对齐。

`formal_lock.json`与`sources.json`固定本批数值来源；`reproducibility/new_sources.zip`保存未提交的新研究源码。在基础提交上展开源码、按原工具构建ECL后可研究复现；ECL编译产物哈希不同会触发严格锁，需要另立复现输出和来源记录，不能伪装成本批同一二进制。不得覆盖现有正式锁或原实验结果。

完整MAT和100 Hz轨迹仅在本机results。压缩包不含原始实验数据、第三方完整源码、可执行文件或缓存。`manifest.json`覆盖除自身外的所有交付文件，文本统一LF。可运行 `python tools/package_ppid_pindi.py --verify examples/ppid_pindi_f8_20261101` 校验。

三个种子只描述本批差异，不宣称统计显著性、实机性能或已经验证优先级保护。此批未进行任何旧F8仿真重跑。
""")
    files = [{"path": p.relative_to(package).as_posix(), "bytes": p.stat().st_size, "sha256": digest(p)}
             for p in sorted(package.rglob("*")) if p.is_file()]
    write_json(package / "manifest.json", {"schema": 1, "files": files, "excludes": ["manifest.json"]})
    return verify(package)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", nargs="?", type=Path)
    parser.add_argument("--output", type=Path, default=Path("examples/ppid_pindi_f8_20261101"))
    parser.add_argument("--old-root", type=Path, default=Path("E:/Ducted-Fan-SHC09-matlab"))
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args(); root = Path(__file__).resolve().parents[1]
    if args.verify:
        result = verify(args.verify.resolve())
    else:
        assert args.folder is not None
        result = build(root, args.folder.resolve(), args.output.resolve(), args.old_root.resolve())
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
