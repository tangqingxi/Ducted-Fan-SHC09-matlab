"""绘制冻结F8的共同十二状态计划参考；图中不包含闭环试验结果。"""

import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

import plot_figure8_lite as base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence_dir", type=Path)
    args = parser.parse_args()
    folder = args.evidence_dir.resolve()
    figures = folder / "figures"
    assert not figures.exists(), "不覆盖已有协议参考图"
    figures.mkdir()
    plt.rcParams.update({"font.family": "sans-serif", "font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"], "axes.unicode_minus": False, "pdf.fonttype": 42})
    fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
    for scenario, label, color in [("F8-R", "F8-R：周期20秒", "#3478b8"), ("F8-D", "F8-D：周期10秒", "#d54850")]:
        data = np.genfromtxt(folder / f"{scenario}_planned_targets.csv", delimiter=",", names=True, encoding="utf-8-sig")
        for ax, state, title, unit in zip(axes.flat, base.STATES, base.STATE_LABELS, base.UNITS):
            ax.plot(data["time_s"], data["target_" + state], color=color, lw=1.1, label=label)
            ax.set(title=title, ylabel=unit)
            ax.grid(alpha=0.2)
            ax.spines[["top", "right"]].set_visible(False)
            ax.ticklabel_format(axis="y", useOffset=False)
    for ax in axes[-1]:
        ax.set_xlabel("时间 / s")
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="outside lower center", ncol=2, frameon=False)
    fig.suptitle("F8-v1.0 · 共同十二状态计划参考（不是闭环结果）\n位置/速度与名义几何姿态/机体角速度；九次相位速度平滑，解析前馈", fontsize=14)
    base.save_figure(fig, figures, "planned_12states")
    print(figures / "planned_12states.png")


if __name__ == "__main__":
    main()
