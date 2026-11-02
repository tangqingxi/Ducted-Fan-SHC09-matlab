"""打包悬停偏差预检轻量证据；不改任何原始日志、旧协议或锁。"""
import argparse
import csv
import hashlib
import json
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def data(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def text_copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.suffix.lower() in {".png", ".pdf"}:
        target.write_bytes(source.read_bytes())
    else:
        target.write_bytes(source.read_text(encoding="utf-8-sig").replace("\r\n", "\n").encode("utf-8"))


def verify(folder):
    manifest = data(folder / "manifest.json")
    actual = {p.relative_to(folder).as_posix(): p for p in folder.rglob("*") if p.is_file() and p.name != "manifest.json"}
    expected = {r["path"]: r for r in manifest["files"]}
    assert set(actual) == set(expected)
    assert len({name.casefold() for name in actual}) == len(actual)
    for name, path in actual.items():
        assert path.stat().st_size == expected[name]["bytes"] and digest(path) == expected[name]["sha256"], name
        assert path.suffix.lower() not in {".mat", ".exe", ".pyc", ".zip"}, name
        assert not any(part in {"results", "build", "logs", "__pycache__", "tracks"} for part in path.relative_to(folder).parts), name
    checks = data(folder / "audit" / "independent_checks.json")
    assert checks["logs_verified"] == 2 and checks["formal_gate_rejected_failed_prechecks"]
    return {"files_including_manifest": len(actual)+1, "bytes": sum(p.stat().st_size for p in folder.rglob("*") if p.is_file()),
            "manifest_verified": True, "formal_batch_started": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", type=Path)
    parser.add_argument("--output", type=Path, default=Path("examples/hover_distance_precheck_20261102"))
    args = parser.parse_args(); root = Path(__file__).resolve().parents[1]
    if args.verify:
        print(json.dumps(verify(args.verify.resolve()))); return
    output = args.output.resolve(); assert not output.exists()
    review = root / "results/hover_distance_review_20261102_r1"; audit = root / "results/hover_distance_audit_20261102_r2"
    assert data(audit / "independent_checks.json")["formal_gate_rejected_failed_prechecks"]
    assert not (root / "research/hover_distance/formal_lock.json").exists()
    protection = data(root / "results/hover_distance_work_20261102/protection_summary.json")
    assert not protection["changed_existing_files"] and not protection["changed_old_result_files"]
    output.mkdir(parents=True)
    for path in review.iterdir():
        assert path.is_file() and path.suffix in {".csv", ".json", ".png", ".pdf", ".md"}
        text_copy(path, output / path.name)
    for name in ["independent_checks.json", "independent_metric_checks.csv", "geometry_summary.csv", "lambda_diagnostics.csv"]:
        text_copy(audit / name, output / "audit" / name)
    for name in ["protocol_checks.json", "setup_check_correction.json", "additional_diagnostics.json", "protection_summary.json"]:
        text_copy(root / "results/hover_distance_work_20261102" / name, output / "audit" / name)
    signatures = []
    for suffix, method in [("pinv", "EXAMPLE_PINV"), ("pred", "PCA_PREDICTIVE")]:
        source = root / ("results/hover_distance_precheck_20261102_a1_L085_Y280_"+suffix)
        for name in ["request.json", "effective_spec_s501.json", "status.csv", "summary.csv", "completion.json", "provenance.csv"]:
            text_copy(source / name, output / "prechecks" / method / name)
        with (source / "provenance.csv").open(encoding="utf-8-sig", newline="") as stream:
            signatures.append(list(csv.DictReader(stream))[0]["input_signature"])
    assert len(set(signatures)) == 1
    source = root / "results/hover_distance_precheck_20261102_a1_L085_Y280_pred"
    for name in ["sources.json", "scenario_protocol.json", "parent_protocol.json"]:
        text_copy(source / name, output / name)
    fingerprints = {name: digest(root / name) for name in ["tests/test_hover_distance_protocol.m", "tests/audit_hover_distance_results.m",
                    "tools/plot_hover_distance.py", "tools/package_hover_distance.py"]}
    (output / "analysis_sources.json").write_bytes((json.dumps(fingerprints, indent=2)+"\n").encode("utf-8"))
    notice = """
## 预检停点

仅种子501的EXAMPLE_PINV和PCA_PREDICTIVE各一条40 s飞行，均完整、无气动越界。预测版λ占空比15.0%合格，但λ_min=0.00823089不满足0.3–0.6；未启动正式批，也没有更改门槛。伪逆干扰段偏航速率RMS149.57°/s未过运行前70°/s工程线。

滚转模型权限1.213133995 N·m，85%幅值1.031163896 N·m。旧F8偏航外扰已移除。全部调参只准501；本次未调整参数，因为没有触发λ全1、mode1>5%或发散分支。

五方法三种子主表、成对比较和消融尚未生成；不得用PINV代替DA_NS/WLS/DCA。完整MAT/100Hz时序在本机新results中，不包含在本轻量包。sources.json记录引擎及源码SHA，analysis_sources.json记录后处理源码SHA，manifest.json覆盖除自身外的包内文件。文本统一LF。
"""
    readme = (output / "README.md").read_text(encoding="utf-8")
    (output / "README.md").write_bytes((readme+notice).encode("utf-8"))
    files = [{"path": p.relative_to(output).as_posix(), "bytes": p.stat().st_size, "sha256": digest(p)}
             for p in sorted(output.rglob("*")) if p.is_file()]
    (output / "manifest.json").write_bytes((json.dumps({"files": files, "excludes": ["manifest.json"]}, ensure_ascii=False, indent=2)+"\n").encode("utf-8"))
    print(json.dumps(verify(output)))


if __name__ == "__main__":
    main()
