"""只读新悬停工况结果，输出预检或正式对比、成对差值和种子波动。"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import statistics

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def read(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write_csv(path, rows):
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folders", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(); output = args.output.resolve(); assert not output.exists(); output.mkdir(parents=True)
    combined = []; provenance = []; failures = []
    for folder in args.folders:
        folder = folder.resolve()
        for row in read(folder / "status.csv"):
            if row["status"] != "completed":
                failures.append({"folder": str(folder), **row})
        summary = folder / "summary.csv"
        if summary.stat().st_size > 3:
            for row in read(summary):
                spec = json.loads((folder / f"effective_spec_s{row['seed']}.json").read_text(encoding="utf-8"))
                combined.append({"folder": str(folder), "load_fraction": spec["roll_load_fraction"],
                                 "yaw_peak_deg_s": spec["yaw_rate_peak_deg_s"], **row})
        for path in [folder / "summary.csv", folder / "status.csv", folder / "sources.json", folder / "request.json"]:
            provenance.append({"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    write_csv(output / "per_run_metrics.csv", combined); write_csv(output / "failures.csv", failures)
    (output / "input_sources.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    keys = ["horizontal_rmse_m", "horizontal_peak_m", "roll_rmse_deg", "roll_peak_deg", "yaw_rate_rmse_deg_s",
            "true_horizontal_rmse_m", "true_roll_rmse_deg", "lambda_scaled_duty", "normal_lambda_min",
            "mode1_duration_s", "mode2_duration_s", "actual_servo_rate_rms_deg_s", "actual_servo_travel_deg", "pwm_step_rms_deg"]
    groups = list(dict.fromkeys((r["method"], r["load_fraction"], r["yaw_peak_deg_s"]) for r in combined)); aggregate = []
    for method, load, yaw in groups:
        group = [r for r in combined if (r["method"], r["load_fraction"], r["yaw_peak_deg_s"]) == (method, load, yaw)]
        row = {"method": method, "load_fraction": load, "yaw_peak_deg_s": yaw, "runs": len(group)}
        for key in keys:
            values = np.array([float(r[key]) for r in group]); good = values[np.isfinite(values)]
            row.update({key+"_mean": float(good.mean()) if good.size else float("nan"),
                        key+"_seed_std": float(good.std(ddof=1)) if good.size > 1 else float("nan")})
        aggregate.append(row)
    write_csv(output / "aggregate_metrics.csv", aggregate)
    paired = []
    for candidate, baseline in [("PCA_PREDICTIVE", "DA_NS"), ("PCA_PREDICTIVE", "WLS"), ("PCA_PREDICTIVE", "DCA"),
                                ("PCA_PREDICTIVE", "PCA_STATIC"), ("PCA_STATIC", "DA_NS"), ("PCA_STATIC", "WLS")]:
        for a in [r for r in combined if r["method"] == candidate]:
            matches = [r for r in combined if r["method"] == baseline and all(a[k] == r[k] for k in ["seed", "load_fraction", "yaw_peak_deg_s"])]
            if not matches:
                continue
            assert len(matches) == 1; b = matches[0]
            row = {"candidate": candidate, "baseline": baseline, "seed": a["seed"], "load_fraction": a["load_fraction"], "yaw_peak_deg_s": a["yaw_peak_deg_s"]}
            for key in keys:
                av, bv = float(a[key]), float(b[key]); row[key+"_difference"] = av-bv
                row[key+"_relative_percent"] = (av/bv-1)*100 if np.isfinite(bv) and bv else float("nan")
            paired.append(row)
    write_csv(output / "paired_differences.csv", paired)
    plt.rcParams.update({"font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"], "axes.unicode_minus": False, "pdf.fonttype": 42})
    colors = {"EXAMPLE_PINV": "#3478b8", "DA_NS": "#3478b8", "WLS": "#e79a38", "DCA": "#299c83", "PCA_STATIC": "#8860ad", "PCA_PREDICTIVE": "#d54850"}
    for load, peak in sorted({(r["load_fraction"], r["yaw_peak_deg_s"]) for r in combined}):
        selected = [r for r in combined if r["load_fraction"] == load and r["yaw_peak_deg_s"] == peak and r["seed"] == "501"]
        fig, axes = plt.subplots(2, 2, figsize=(14, 8.5), layout="constrained")
        for row in selected:
            track = read(Path(row["folder"]) / "tracks" / f"{row['method']}_s501.csv")
            t = np.array([float(r["time_s"]) for r in track]); data = lambda name: np.array([float(r[name]) for r in track])
            color = colors[row["method"]]; label = row["method"]
            for prefix, style, suffix in [("estimated", "-", "估计"), ("true", ":", "真值")]:
                distance = np.hypot(data(prefix+"_position_1"), data(prefix+"_position_2"))
                axes[0, 0].plot(t, distance, style, color=color, lw=.9, label=label+" "+suffix)
                axes[0, 1].plot(t, data(prefix+"_euler_1"), style, color=color, lw=.8, label=label+" "+suffix)
            axes[1, 0].plot(t, data("measured_rate_3"), color=color, lw=.8, label=label)
            if row["method"].startswith("PCA"):
                mode = data("mode"); scale = data("lambda")
                axes[1, 1].plot(t, np.where(mode == 0, scale, np.nan), color=color, lw=.7, label=label+" 正常λ")
                axes[1, 1].scatter(t[mode == 1], np.zeros(np.sum(mode == 1)), marker="x", color=color, s=8, label="mode1")
                axes[1, 1].scatter(t[mode == 2], np.zeros(np.sum(mode == 2)), marker="v", color=color, s=8, label="mode2")
        axes[1, 0].plot(t, data("reference_rate_3"), "k--", lw=.8, label="规划参考")
        titles = [("水平偏差距离", "m"), ("滚转偏差", "°"), ("偏航机体角速度", "°/s"), ("正常λ与回退", "λ")]
        for ax, (title, unit) in zip(axes.flat, titles):
            ax.set(xlabel="时间 / s", ylabel=unit, title=title); ax.grid(alpha=.2)
            ax.axvspan(10, 22, color="#d48a49", alpha=.12); ax.axvspan(22, 32, color="#399577", alpha=.08)
            if ax.get_legend_handles_labels()[0]:
                ax.legend(fontsize=7, ncol=2)
        fig.suptitle(f"hover_distance预检/展示 · seed501 · 滚转权限{load:.0%} · 偏航峰值{peak:.0f}°/s\n显示100Hz，主窗评分800Hz；分配事件400Hz，阴影为干扰窗与恢复窗")
        name = f"hover_L{int(round(load*100)):03d}_Y{int(peak)}"
        for ext in ["png", "pdf"]:
            fig.savefig(output / f"{name}.{ext}", dpi=160, bbox_inches="tight", facecolor="white")
        plt.close(fig)
    lines = ["# hover_distance结果", "", "主窗[10,22)s，恢复窗[22,32)s。主指标为估计反馈域，真实偏差并列；未作事后平移。不同负载的预检不作为同工况分配器比较。", "",
             "|方法|种子|负载|位置RMS m|滚转RMS °|偏航速率RMS °/s|λ占空比|λ最小|mode1占比|mode2占比|预检通过|", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"]
    for row in combined:
        fields = [row["method"], row["seed"], f"{row['load_fraction']:.0%}"]
        fields += [f"{float(row[k]):.6g}" for k in ["horizontal_rmse_m", "roll_rmse_deg", "yaw_rate_rmse_deg_s", "lambda_scaled_duty", "normal_lambda_min", "mode1_duty", "mode2_duty"]]
        lines.append("|"+"|".join(fields+[row["precheck_passed"]])+"|")
    lines += ["", "来源、有效性与全部逐条指标见CSV/JSON。单种子预检只用501，不是独立确认；没有统计显著性、实机优势或全局最优结论。", ""]
    (output / "README.md").write_bytes("\n".join(lines).encode("utf-8"))
    print(json.dumps({"output": str(output), "completed_rows": len(combined), "failed_rows": len(failures), "paired_rows": len(paired)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
