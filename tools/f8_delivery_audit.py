"""只读核对F8冻结来源和轻量交付包，不调用MATLAB或仿真入口。"""

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

METHODS = ["DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE"]


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def snapshot(root, folders):
    # 只枚举明确给出的冻结批次，包含原始日志、失败记录及已有派生证据。
    return {p.relative_to(root).as_posix(): sha256(p)
            for folder in folders for p in sorted(folder.rglob("*")) if p.is_file()}


def verify_sources(root, pipeline):
    work = root / "results/f8_work_20261101"
    lock = read_json(work / "numerical_sources_before_confirmation.json")
    assert len(lock["files"]) == 20
    for item in lock["files"]:
        assert sha256(root / item["path"]) == item["sha256"], item["path"]
    base = Path(pipeline["base_output"])
    confirmation = Path(pipeline["confirmation_output"]) / "F8PR-Y60-F075"
    datasets = [("F8-R", base / "F8-R"), ("F8-D", base / "F8-D"), ("F8PR-Y60-F075", confirmation)]
    logs = 0
    for name, folder in datasets:
        seeds = [201, 202, 203] if name.startswith("F8PR") else [101, 102, 103]
        expected = {(m, str(s)) for m in METHODS for s in seeds}
        for file in ["status.csv", "task_metrics.csv", "provenance.csv"]:
            rows = read_csv(folder / file)
            assert len(rows) == 15 and {(r["method"], r["seed"]) for r in rows} == expected, file
        assert all(r["status"] == "completed" for r in read_csv(folder / "status.csv"))
        assert len(read_csv(folder / "state_metrics.csv")) == 720
        provenance = read_csv(folder / "provenance.csv")
        for seed in seeds:
            same_seed = [r for r in provenance if r["seed"] == str(seed)]
            assert len({r["input_signature"] for r in same_seed}) == 1
        assert all(r["truth_topics_absent"] in ("1", "true") and r["smoke_test"] in ("0", "false") for r in provenance)
        checks = read_json(folder / "independent_checks.json")
        assert checks["formal_logs_verified"] == 15
        for item in checks["verified_log_files"]:
            assert sha256(folder / item["path"]) == item["sha256"], item["path"]
            logs += 1
        if name.startswith("F8PR"):
            for path in (folder / "tracks").glob("*.csv"):
                with path.open(encoding="utf-8-sig") as stream:
                    assert sum(1 for _ in stream) == 5202
            geometry = list(folder.glob("priority_geometry_*.csv"))
            assert len(geometry) == 6 and len(list((folder / "tracks").glob("*.csv"))) == 15
            for path in geometry:
                with path.open(encoding="utf-8-sig") as stream:
                    assert sum(1 for _ in stream) == 35202
    screen = Path(pipeline["pressure_output"])
    status = read_csv(screen / "status.csv")
    assert len(status) == 9 and sum(r["status"] == "completed" for r in status) == 6
    assert sum(r["status"] == "failed" for r in status) == 3
    for item in read_json(screen / "development_priority_checks.json")["verified_log_files"]:
        assert sha256(screen / item["path"]) == item["sha256"]
        logs += 1
    return datasets, dict(frozen_source_files_verified=20, raw_log_hashes_verified=logs,
                          original_matlab_checks_reexecuted=False, simulations_run=0)


def verify_bundle(folder):
    from PIL import Image
    manifest = read_json(folder / "artifact_manifest.json")
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()}
    expected = {r["path"] for r in manifest["artifacts"]} | {"artifact_manifest.json"}
    assert actual == expected, (actual - expected, expected - actual)
    for item in manifest["artifacts"]:
        assert sha256(folder / item["path"]) == item["sha256"], item["path"]
    for item in manifest["source_copies"]:
        assert sha256(folder / item["artifact"]) == item["source_sha256"], item["artifact"]
    images = 0
    for path in folder.rglob("*.png"):
        with Image.open(path) as img:
            assert img.width >= 1000 and img.height >= 600
            img.verify()
        assert path.with_suffix(".pdf").is_file()
        assert path.with_suffix(".pdf").read_bytes().startswith(b"%PDF")
        images += 1
    confirm = folder / "F8PR-Y60-F075"
    metrics = read_csv(confirm / "task_metrics.csv")
    aggregate = read_csv(confirm / "aggregate_metrics.csv")
    for row in aggregate:
        values = [float(r[row["metric"]]) for r in metrics if r["method"] == row["method"]]
        mean = sum(values) / 3
        std = math.sqrt(sum((v - mean) ** 2 for v in values) / 2)
        assert math.isclose(mean, float(row["mean"]), rel_tol=1e-12, abs_tol=1e-12)
        assert math.isclose(std, float(row["std"]), rel_tol=1e-12, abs_tol=1e-12)
        assert float(row["minimum"]) == min(values) and float(row["maximum"]) == max(values)
    for row in read_csv(confirm / "paired_pca_deltas.csv"):
        a = next(r for r in metrics if r["method"] == row["candidate"] and r["seed"] == row["seed"])
        b = next(r for r in metrics if r["method"] == row["baseline"] and r["seed"] == row["seed"])
        delta = float(a[row["metric"]]) - float(b[row["metric"]])
        assert math.isclose(delta, float(row["candidate_minus_baseline"]), rel_tol=1e-12, abs_tol=1e-12)
        if row["percent_change"]:
            assert math.isclose(100 * delta / float(b[row["metric"]]), float(row["percent_change"]), rel_tol=1e-12, abs_tol=1e-12)
    assert all(r["run_task_passed"] == "1" for r in metrics)
    for row in metrics:
        if row["method"].startswith("PCA"):
            assert float(row["lambda_min"]) == 1 and float(row["total_scaled_duration_s"]) == 0
    return dict(artifact_hashes_verified=len(manifest["artifacts"]), png_pdf_pairs_verified=images,
                aggregate_rows_recomputed=len(aggregate), paired_rows_recomputed=len(read_csv(confirm / "paired_pca_deltas.csv")),
                confirmation_runs=15, simulations_run=0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify_bundle(args.bundle.resolve()), ensure_ascii=False))
