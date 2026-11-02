"""绘制估计位置与规划八字的跟踪对比；只读原轨迹，使用完整日志导出的RMS。"""
import argparse
import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def read(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_folder", type=Path)
    parser.add_argument("output_folder", type=Path)
    parser.add_argument("--replace-figures", action="store_true", help="只重绘本次分析图，不改原日志和RMS表")
    args = parser.parse_args(); source = args.input_folder.resolve(); output = args.output_folder.resolve()
    assert output != source and not output.is_relative_to(source), "新分析图须放在原批次目录之外"
    rows = read(output / "estimated_tracking_metrics.csv")
    note = json.loads((output / "measurement_domain_analysis.json").read_text(encoding="utf-8"))
    assert note["score_hz"] == 800 and note["simulations_rerun"] == 0 and len(rows) == 15
    methods = ["DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE"]
    seeds = [401, 402, 403]; colors = ["#3478b8", "#e79a38", "#299c83", "#8860ad", "#d54850"]
    assert {(r["method"], int(r["seed"])) for r in rows} == {(m, s) for m in methods for s in seeds}
    plt.rcParams.update({"font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"], "axes.unicode_minus": False, "pdf.fonttype": 42})
    traces = {}
    for seed in seeds:
        for method in methods:
            data = read(source / "tracks" / f"{method}_s{seed}.csv")
            t = np.array([float(r["time_s"]) for r in data]); q = (t >= 6) & (t <= 50)
            values = {name: np.array([float(r[name]) for r in data])[q] for name in
                      ["target_x", "target_y", "estimate_x", "estimate_y"]}
            assert len(t) == 5201 and q.sum() == 4401
            # 显示序列与800Hz评分只差采样率，独立核查量级和数据通道。
            display_rms = np.sqrt(np.mean((values["estimate_x"]-values["target_x"])**2 +
                                          (values["estimate_y"]-values["target_y"])**2))
            full_rms = float(next(r["estimated_horizontal_rmse_m"] for r in rows if r["method"] == method and int(r["seed"]) == seed))
            assert abs(display_rms-full_rms) < 0.001
            traces[method, seed] = values

    def trajectory(ax, seed):
        for i, method in enumerate(methods):
            d = traces[method, seed]
            ax.plot(d["estimate_x"], d["estimate_y"], color=colors[i], lw=1.15, alpha=.85, label=method)
        ax.plot(d["target_x"], d["target_y"], "k--", lw=1.6, label="规划参考")
        ax.set(xlabel="北向 / m", ylabel="东向 / m", title=f"八字跟踪 · seed {seed}")
        ax.set_aspect("equal", adjustable="box"); ax.grid(alpha=.2)
        ax.set_xlim(-3.55, 3.55); ax.set_ylim(-2.05, 2.05)

    def save(fig, name):
        for extension in ["png", "pdf"]:
            path = output / f"{name}.{extension}"; assert not path.exists() or args.replace_figures, "不覆盖既有图件"
            fig.savefig(path, dpi=170, facecolor="white", bbox_inches="tight", pad_inches=.15)
        plt.close(fig)

    fig, axes = plt.subplots(1, 2, figsize=(13.5, 5.8), width_ratios=[1.2, 1], layout="constrained")
    trajectory(axes[0], 401); axes[0].legend(fontsize=8, ncol=3, loc="upper center", bbox_to_anchor=(.5, -.17))
    matrix = np.array([[float(next(r["estimated_horizontal_rmse_m"] for r in rows if r["method"] == method and int(r["seed"]) == seed))
                        for seed in seeds] for method in methods])
    means = matrix.mean(axis=1)
    axes[1].bar(range(5), means, color=colors, alpha=.65, width=.62)
    for j, seed in enumerate(seeds):
        axes[1].plot(np.arange(5)+(j-1)*.13, matrix[:, j], color="0.5", marker=["o", "s", "^"][j], ms=4, lw=.65, alpha=.8, label=f"seed {seed}")
    for i, mean in enumerate(means):
        axes[1].text(i, mean*.5, f"{mean:.5f}", ha="center", va="center", fontsize=10)
    axes[1].set_xticks(range(5), methods, rotation=20, fontsize=8)
    axes[1].set(ylabel="水平位置 RMS / m", title="五种分配器 · 柱为三种子均值", ylim=(0, max(.20, matrix.max()*1.28)))
    axes[1].grid(axis="y", alpha=.2); axes[1].legend(fontsize=8)
    fig.suptitle("EKF估计位置相对规划参考：五方法共用控制器\n主窗6–50 s；800 Hz完整日志评分，100 Hz显示；轨迹接近重合", fontsize=13)
    save(fig, "estimated_f8_tracking_and_rms")

    fig, axes = plt.subplots(1, 3, figsize=(16, 5.1), layout="constrained")
    for ax, seed in zip(axes, seeds):
        trajectory(ax, seed)
    axes[0].legend(fontsize=7, ncol=2, loc="upper center", bbox_to_anchor=(.5, -.17))
    fig.suptitle("三个正式种子的估计位置八字跟踪 · 五方法叠图", fontsize=13)
    save(fig, "estimated_f8_three_seeds")

    lines = ["# 估计反馈域的八字跟踪", "", "比较EKF估计位置与规划参考。水平RMS为sqrt(mean(e_N²+e_E²))；评分为完整800Hz日志主窗[6,50]s，无事后平移或相位对齐。原真值评分保持原样。", "",
             "|方法|seed401 / m|seed402 / m|seed403 / m|三种子均值 / m|", "|---|---:|---:|---:|---:|"]
    for method, values, mean in zip(methods, matrix, means):
        lines.append("|"+method+"|"+"|".join(f"{v:.6f}" for v in [*values, mean])+"|")
    lines += ["", "![八字与水平RMS](estimated_f8_tracking_and_rms.png)", "", "![三个种子](estimated_f8_three_seeds.png)", "",
              "该图说明控制器获得的估计状态跟踪效果，不等同于真实空间轨迹精度。位置域结果几乎相同，不能由此排出分配器优劣；航向及执行器活动另看原正式指标。", ""]
    (output / "README.md").write_bytes("\n".join(lines).encode("utf-8"))
    print(json.dumps({"output": str(output), "means_m": dict(zip(methods, means.tolist())), "score_hz": 800, "simulations_rerun": 0}, ensure_ascii=False))


if __name__ == "__main__":
    main()
