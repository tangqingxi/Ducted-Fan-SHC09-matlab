"""绘制真实八字实验的箱线图、十二状态跟踪和逐种子比较；不修改仿真结果。"""

import argparse
import csv
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


METHODS = ["DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE"]
LABELS = ["DA-NS", "WLS", "DCA", "静态PCA", "预测PCA"]
COLORS = ["#3478b8", "#e79a38", "#299c83", "#8860ad", "#d54850"]
STATES = ["x", "y", "z", "vx", "vy", "vz", "roll", "pitch", "yaw", "p", "q", "r"]
STATE_LABELS = ["北向位置 x", "东向位置 y", "向下位置 z", "北向速度 vx", "东向速度 vy", "向下速度 vz", "滚转角 roll", "俯仰角 pitch", "偏航角 yaw", "机体角速度 p", "机体角速度 q", "机体角速度 r"]
UNITS = ["m"] * 3 + ["m/s"] * 3 + ["°"] * 3 + ["°/s"] * 3
METRICS = [
    ("position_rmse_m", "三维位置 RMSE", "m"),
    ("velocity_rmse_m_s", "三维速度 RMSE（几何目标）", "m/s"),
    ("attitude_rmse_deg", "姿态旋转误差 RMS", "°"),
    ("inner_rate_command_rmse_deg_s", "角速度指令跟踪 RMS", "°/s"),
    ("common_predicted_torque_error_rms_nm", "名义共同预测力矩残差", "Nm"),
    ("moment_model_error_rms_nm", "实际与名义舵效力矩差 RMS", "Nm"),
    ("command_step_rms_deg", "PWM 命令步变 RMS", "°"),
    ("saturation_percent", "命令触及 ±40° 的比例", "%"),
    ("estimated_attitude_rmse_deg", "lite 姿态估计误差 RMS", "°"),
]
TRANSIENT_METRICS = [
    ("transient", "attitude_peak_deg", "加载窗姿态误差峰值 [0,6] s", "°"),
    ("transient", "yaw_rmse_deg", "加载窗偏航 RMSE [0,6] s", "°"),
    ("transient", "inner_rate_command_rmse_deg_s", "加载窗角速度指令跟踪 RMS", "°/s"),
    ("whole", "attitude_peak_deg", "全程姿态误差峰值 [0,52] s", "°"),
    ("whole", "yaw_rmse_deg", "全程偏航 RMSE [0,52] s", "°"),
    ("whole", "command_step_rms_deg", "全程 PWM 步变 RMS", "°"),
]


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write_csv(path, rows):
    if not rows:
        return
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def values(rows, method, column, state=None, window="task"):
    selected = [r for r in rows if r["method"] == method and r["window"] == window and (state is None or r["state"] == state)]
    selected.sort(key=lambda r: int(r["seed"]))
    return np.array([float(r[column]) for r in selected])


def save_figure(fig, folder, name):
    fig.savefig(folder / f"{name}.png", dpi=180, facecolor="white")
    fig.savefig(folder / f"{name}.pdf", facecolor="white")
    plt.close(fig)


def boxes(ax, groups, title, unit):
    # 每个箱子只有三个独立运行指标；同一种子的配对关系用浅线保留。
    result = ax.boxplot(groups, patch_artist=True, widths=0.5, whis=1.5, showfliers=False,
                        medianprops={"color": "#222222", "linewidth": 1.6})
    for patch, color in zip(result["boxes"], COLORS):
        patch.set_facecolor(color)
        patch.set_alpha(0.28)
        patch.set_edgecolor(color)
    jitter = np.linspace(-0.09, 0.09, len(groups[0]))
    for k in range(len(groups[0])):
        ax.plot(np.arange(1, 6) + jitter[k], [g[k] for g in groups], color="#9a9a9a", alpha=0.36, lw=0.7, zorder=1)
    for i, (group, color) in enumerate(zip(groups, COLORS), 1):
        ax.scatter(i + jitter, group, s=25, c=color, edgecolors="white", linewidths=0.45, zorder=3)
    ax.set_xticks(range(1, 6), LABELS, fontsize=9)
    ax.set_title(title, loc="left", fontsize=11, fontweight="bold")
    ax.set_ylabel(unit)
    ax.grid(axis="y", alpha=0.22)
    ax.spines[["top", "right"]].set_visible(False)
    ax.ticklabel_format(axis="y", style="sci", scilimits=(-3, 4), useOffset=False)


def load_track(folder, method, seed=1):
    rows = read_csv(folder / "tracks" / f"{method}_s{seed}.csv")
    return {name: np.array([float(r[name]) for r in rows]) for name in rows[0]}


def plot_tracks(folder, figures, method):
    data = load_track(folder, method)
    qualification = ""
    if (folder / "comparability.csv").exists():
        qualification = " · 比较资格 " + read_csv(folder / "comparability.csv")[0]["comparability"]
    fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
    for i, (ax, state, label, unit) in enumerate(zip(axes.flat, STATES, STATE_LABELS, UNITS)):
        ax.axvspan(6, 50, color="#e8edf2", alpha=0.45)
        ax.plot(data["time_s"], data["target_" + state], "--", color="#252d35", lw=1.25, label="目标 / 实际控制指令")
        ax.plot(data["time_s"], data["actual_" + state], color=COLORS[METHODS.index(method)], lw=1.15, label="物理真值（离线评价）")
        ax.plot(data["time_s"], data["estimate_" + state], color="#3e90a2", lw=0.75, alpha=0.7, label="lite / 控制反馈估计")
        ax.set_title(label, loc="left", fontsize=11)
        ax.set_ylabel(unit)
        ax.grid(alpha=0.2)
        ax.spines[["top", "right"]].set_visible(False)
        ax.ticklabel_format(axis="y", useOffset=False)
        if i >= 9:
            ax.set_xlabel("时间 / s")
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="outside lower center", ncol=3, frameon=False)
    fig.suptitle(f"{LABELS[METHODS.index(method)]} · M2b / lite · seed 1（预先固定示例）{qualification}\n"
                 "位置：共同八字目标；速度：几何导数，无前馈；姿态/角速度：本次运行实际控制指令", fontsize=14)
    save_figure(fig, figures, method + "_12states_seed1")


def aggregate(rows, state_rows):
    output = []
    for window in ["task", "cruise", "whole", "transient"]:
        for name, _, unit in METRICS + [("attitude_peak_deg", "姿态峰值", "°"), ("yaw_rmse_deg", "偏航RMSE", "°"), ("position_peak_m", "位置峰值", "m")]:
            for method in METHODS:
                v = values(rows, method, name, window=window)
                output.append(dict(window=window, metric=name, unit=unit, method=method, n=len(v), mean=float(v.mean()), std=float(v.std(ddof=1)), minimum=float(v.min()), maximum=float(v.max())))
        for state, unit in zip(STATES, UNITS):
            for method in METHODS:
                v = values(state_rows, method, "rmse", state=state, window=window)
                output.append(dict(window=window, metric=f"state_{state}_rmse", unit=unit, method=method, n=len(v), mean=float(v.mean()), std=float(v.std(ddof=1)), minimum=float(v.min()), maximum=float(v.max())))
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    folder = args.output_dir.resolve()
    status = read_csv(folder / "status.csv")
    protocol = json.loads((folder / "protocol.json").read_text(encoding="utf-8-sig"))
    assert len(status) == 15 and all(r["status"] == "completed" for r in status), "只有真实完成15次才生成完整比较产品"
    assert sorted({(r["method"], int(r["seed"])) for r in status}) == sorted((m, s) for m in METHODS for s in [1, 2, 3])
    assert (folder / "independent_checks.json").is_file(), "请先运行test_figure8_results，核验完整MAT与CSV一致"
    rows = read_csv(folder / "summary.csv")
    state_rows = read_csv(folder / "state_metrics.csv")
    gates = read_csv(folder / "comparability.csv")[0]
    qualification = "比较资格：" + gates["comparability"] + ("（压力诊断，不作正式排名）" if gates["comparability"] != "rankable" else "（资格不等于统计排名）")
    figures = folder / "figures"
    assert not figures.exists(), "绘图结果目录已存在，请显式选择新输出目录，避免覆盖"
    figures.mkdir()
    plt.rcParams.update({"font.family": "sans-serif", "font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"], "axes.unicode_minus": False, "font.size": 10, "pdf.fonttype": 42})
    fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
    for ax, state, label, unit in zip(axes.flat, STATES, STATE_LABELS, UNITS):
        boxes(ax, [values(state_rows, m, "rmse", state) for m in METHODS], label + " RMSE", unit)
    fig.suptitle("十二状态误差 · M2b / lite · 五方法 × 三种子\n主评价窗 [6,50] s；每个点是一种子的运行 RMSE，浅线连接相同种子\n" + qualification, fontsize=15)
    save_figure(fig, figures, "boxplot_12states_rmse")
    fig, axes = plt.subplots(3, 3, figsize=(16, 11), layout="constrained")
    for ax, (name, label, unit) in zip(axes.flat, METRICS):
        boxes(ax, [values(rows, m, name) for m in METHODS], label, unit)
    fig.suptitle("跟踪效果与分配代价 · M2b / lite · 三种子箱线图\n名义预测残差与实际跟踪分开评价；所有指标越低越好，不合成总分\n" + qualification, fontsize=15)
    save_figure(fig, figures, "boxplot_tracking_allocation")
    fig, axes = plt.subplots(2, 3, figsize=(16, 8), layout="constrained")
    for ax, (window, name, label, unit) in zip(axes.flat, TRANSIENT_METRICS):
        boxes(ax, [values(rows, m, name, window=window) for m in METHODS], label, unit)
    fig.suptitle("加载瞬态与全程表现 · 五方法 × 三种子\n与八字主窗分开报告，保留加载和卸载峰值，不据此更换主评价窗\n" + qualification, fontsize=15)
    save_figure(fig, figures, "boxplot_load_transients")
    for method in ["PCA_PREDICTIVE", "PCA_STATIC"]:
        plot_tracks(folder, figures, method)
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), layout="constrained")
    reference = load_track(folder, "PCA_PREDICTIVE")
    axes[0].plot(reference["target_x"], reference["target_y"], "--", color="#222222", lw=1.8, label="共同八字目标")
    for method, label, color in zip(METHODS, LABELS, COLORS):
        data = load_track(folder, method)
        axes[0].plot(data["actual_x"], data["actual_y"], color=color, lw=1.1, label=label)
        error = np.sqrt(sum((data["actual_" + a] - data["target_" + a]) ** 2 for a in ["x", "y", "z"]))
        axes[1].plot(data["time_s"], error, color=color, lw=1, label=label)
    axes[0].set(xlabel="北向 x / m", ylabel="东向 y / m", title="五方法八字轨迹 · seed 1")
    axes[0].set_aspect("equal", adjustable="box")
    axes[0].legend(frameon=False, fontsize=9)
    axes[1].axvspan(6, 50, color="#e8edf2", alpha=0.45)
    axes[1].set(xlabel="时间 / s", ylabel="三维位置误差 / m", title="同一时刻的跟踪误差（未作相位对齐）")
    for ax in axes:
        ax.grid(alpha=0.22)
        ax.spines[["top", "right"]].set_visible(False)
    fig.suptitle("M2b / lite · ±40° 硬限幅 · 无速度前馈 / 无控制链修改\n" + qualification, fontsize=14)
    save_figure(fig, figures, "figure8_five_methods_seed1")

    aggregates = aggregate(rows, state_rows)
    write_csv(folder / "aggregate_metrics.csv", aggregates)
    paired = []
    for window in ["task", "cruise", "transient", "whole"]:
        specs = [(name, unit, None) for name, _, unit in METRICS] + [("attitude_peak_deg", "°", None), ("yaw_rmse_deg", "°", None)] + [(f"state_{s}_rmse", u, s) for s, u in zip(STATES, UNITS)]
        for name, unit, state in specs:
            source = rows if state is None else state_rows
            column = name if state is None else "rmse"
            a = values(source, "PCA_STATIC", column, state, window)
            b = values(source, "PCA_PREDICTIVE", column, state, window)
            for k in range(3):
                paired.append(dict(window=window, metric=name, unit=unit, seed=k+1, static=float(a[k]), predictive=float(b[k]), predictive_minus_static=float(b[k]-a[k]), predictive_change_percent=float(100*(b[k]-a[k])/a[k]) if a[k] != 0 else ""))
    write_csv(folder / "paired_pca_deltas.csv", paired)
    fig, axes = plt.subplots(4, 3, figsize=(16, 11), layout="constrained")
    for ax, state, label, unit in zip(axes.flat, STATES, STATE_LABELS, UNITS):
        a = values(state_rows, "PCA_STATIC", "rmse", state)
        b = values(state_rows, "PCA_PREDICTIVE", "rmse", state)
        delta = b - a
        ax.axhline(0, color="#555555", lw=1)
        ax.bar([1, 2, 3], delta, color=["#299c83" if d < 0 else "#d54850" for d in delta], width=0.55, alpha=0.8)
        ax.set_xticks([1, 2, 3], ["seed 1", "seed 2", "seed 3"])
        ax.set_title(label, loc="left", fontsize=11)
        ax.set_ylabel(f"RMSE差 / {unit}")
        ax.ticklabel_format(axis="y", style="sci", scilimits=(-3, 4), useOffset=False)
        ax.grid(axis="y", alpha=0.2)
        ax.spines[["top", "right"]].set_visible(False)
    fig.suptitle("预测PCA − 静态PCA：十二状态的同种子配对差值\n负值表示预测PCA误差更低；不作显著性声明\n" + qualification, fontsize=15)
    save_figure(fig, figures, "paired_pca_12states")
    comparison = []
    for name, label, unit in METRICS:
        groups = [values(rows, m, name) for m in METHODS]
        means = np.array([g.mean() for g in groups])
        pooled = np.sqrt(np.mean([g.var(ddof=1) for g in groups]))
        # 仅列观测均值最小者；零方差或差异极小时不虚构统计区分。
        winners = [m for m, mean in zip(METHODS, means) if mean == means.min()]
        comparison.append(dict(metric=name, label=label, unit=unit, observed_lowest_mean=";".join(winners), method_mean_range=float(np.ptp(means)), pooled_seed_std=float(pooled), range_over_seed_std=float(np.ptp(means)/pooled) if pooled > 0 else "", qualification=gates["comparability"], interpretation="本批次描述性差异，无显著性推断"))
    write_csv(folder / "metric_comparison.csv", comparison)
    phase_rows = []
    for method in METHODS:
        for seed in [1, 2, 3]:
            data = load_track(folder, method, seed)
            q = (data["time_s"] >= 10) & (data["time_s"] <= 46)
            phase = 2*np.pi*(data["time_s"][q]-8)/20
            for axis, harmonic, amplitude in [("x", 1, 2), ("y", 2, 1)]:
                design = np.column_stack([np.sin(harmonic*phase), np.cos(harmonic*phase), np.ones(q.sum())])
                coefficients = np.linalg.lstsq(design, data["actual_"+axis][q], rcond=None)[0]
                gain = np.hypot(coefficients[0], coefficients[1])/amplitude
                lag = -np.degrees(np.arctan2(coefficients[1], coefficients[0]))
                residual = data["actual_"+axis][q]-design@coefficients
                phase_rows.append(dict(method=method, seed=seed, axis=axis, window="cruise", fundamental_gain=float(gain), lag_deg=float(lag), fit_residual_rmse_m=float(np.sqrt(np.mean(residual**2))), interpretation="仅拟合解释滞后，未对跟踪误差作相位对齐"))
    write_csv(folder / "tracking_phase.csv", phase_rows)

    lines = ["# 八字轨迹：M2b / lite 五方法比较", "", "> 本次是独立轨迹实验，不替代 v0.5 的20秒悬停协议；三种子只作描述，不宣称统计显著性。", "", "## 协议与十二状态目标", "", "- 五方法 × seeds 1:3：15/15 全新仿真；52秒、800Hz控制、333Hz PWM，硬限幅±40°。", "- M2b 线性舵效倍率 [1.2,1,0.8,1,1.2,1]；名义模型保持未知失配。保留0.6偏航负载，2秒加载、50秒卸载、0.5秒过渡。", "- 位置：x=2 sin(θ) m，y=sin(2θ) m，z=-10 m（NED）；巡航周期20秒、累计两圈。0–6秒悬停；6–10秒相位加速；10–46秒匀速；46–50秒相位减速；50–52秒保持。", "- 主评价窗[6,50]秒（含平滑起止），另报[10,46]巡航、全程和初始悬停；所有方法使用相同窗口。", "- 十二状态：x/y/z、vx/vy/vz、roll/pitch/yaw、p/q/r。位置/速度为NED，姿态和角速度沿用SHC09机体系，没有假称FRD。", "- 速度目标是解析轨迹导数，只供评价；现有位置控制器不消费速度/加速度前馈，因此可能产生共同相位滞后。", "- roll/pitch及p/q/r目标取各次运行实际记录的内环指令，由估计反馈决定；航向给定0°。它们不是五方法共用的12个独立外部指令。", "- 角速度指令误差使用omega−omega_reference，与旧rate_rmse列（相对零角速度前馈）的语义分开；欧拉角误差按±180°折返。", "- 真值仅用于离线评价，lite总线无plant_truth/sensor_attitude/sensor_local_position。物理、控制器、估计器、五算法、数值门禁均未修改。", "", "## 资格检查", "", f"- 原5°/10%/2°/气动越界0的门槛应用于本次八字主窗：**{gates['comparability']}**。", f"- 最坏姿态峰值 {float(gates['max_attitude_error_deg']):.9g}°；饱和 {float(gates['max_saturation_percent']):.9g}%；估计姿态RMS {float(gates['attitude_estimate_rmse_deg']):.9g}°；气动越界 {gates['aero_extrapolated']}。", f"- 判定原因：{gates['reason']}。压力或无效结果仅作诊断，不包装成排名。", "", "## 主窗逐方法均值 ± 种子标准差", "", "|指标|DA-NS|WLS|DCA|静态PCA|预测PCA|", "|---|---:|---:|---:|---:|---:|"]
    for name, label, unit in METRICS:
        cells = []
        for method in METHODS:
            v = values(rows, method, name)
            cells.append(f"{v.mean():.7g} ± {v.std(ddof=1):.3g}")
        lines.append("|" + "|".join([f"{label} ({unit})"] + cells) + "|")
    lines += ["", "## 预先定义的加载窗及全程峰值", "", "主窗资格只对应[6,50]秒，不代表全程姿态峰值也≤5°。以下保留加载、卸载及全程数据，不用主窗均值掩盖瞬态。", "", "|指标|DA-NS|WLS|DCA|静态PCA|预测PCA|", "|---|---:|---:|---:|---:|---:|"]
    for window, name, label, unit in TRANSIENT_METRICS:
        groups = [values(rows, m, name, window=window) for m in METHODS]
        cells = [f"{v.mean():.7g} ± {v.std(ddof=1):.3g}" for v in groups]
        lines.append("|"+"|".join([f"{label} ({unit})"]+cells)+"|")
    lines += ["", "## 预测PCA相对静态PCA：八字主窗", "", "|指标|预测减静态的均值|相对静态均值变化|逐种子是否同向下降|", "|---|---:|---:|---|"]
    for name, label, unit in METRICS:
        a, b = values(rows, "PCA_STATIC", name), values(rows, "PCA_PREDICTIVE", name)
        change = f"{100*(b.mean()-a.mean())/a.mean():+.6g}%" if a.mean() != 0 else "基准为0，不计算百分比"
        lines.append(f"|{label} ({unit})|{(b-a).mean():+.8g}|{change}|{'是' if np.all(b<a) else '否'}|")
    lines += ["", "加载窗及全程的配对变化（仍保留原窗口，不选最有利种子）：", "", "|指标|预测相对静态的均值变化|逐种子是否同向下降|", "|---|---:|---|"]
    for window, name, label, unit in TRANSIENT_METRICS:
        a = values(rows, "PCA_STATIC", name, window=window)
        b = values(rows, "PCA_PREDICTIVE", name, window=window)
        change = f"{100*(b.mean()-a.mean())/a.mean():+.6g}%" if a.mean() else "基准为0"
        lines.append(f"|{label}|{change}|{'是' if np.all(b<a) else '否'}|")
    lines += ["", "## 各指标观测均值最低的方法与种子波动", "", "|指标|本批次均值最低|五方法均值极差 / 池化种子标准差|", "|---|---|---:|"]
    for row in comparison:
        ratio = row["range_over_seed_std"]
        ratio_text = f"{ratio:.7g}" if ratio != "" else "零种子方差，不计算比值"
        lines.append(f"|{row['label']}|{row['observed_lowest_mean']}|{ratio_text}|")
    lines += ["", "均值最低只指本批次观测值；比值<1说明五方法均值极差小于种子内池化波动。该比值不是显著性检验，也不能推出所有方法对均可区分。", "", "## 十二状态RMSE：均值 ± 种子标准差", "", "|状态|DA-NS|WLS|DCA|静态PCA|预测PCA|", "|---|---:|---:|---:|---:|---:|"]
    for state, label, unit in zip(STATES, STATE_LABELS, UNITS):
        groups = [values(state_rows, m, "rmse", state) for m in METHODS]
        cells = [f"{v.mean():.7g} ± {v.std(ddof=1):.3g}" for v in groups]
        lines.append("|" + "|".join([f"{label} ({unit})"] + cells) + "|")
    lines += ["", "## 共同外环滞后的诊断", "", "在[10,46]巡航窗对x、y分别拟合目标基频的正弦/余弦和常数，得到振幅比与相位滞后；此拟合只用于解释，所有跟踪指标保持原时钟，没有作相位对齐。", "", "|方法|x振幅比|x滞后°|y振幅比|y滞后°|", "|---|---:|---:|---:|---:|"]
    for method in METHODS:
        xrows = [r for r in phase_rows if r["method"] == method and r["axis"] == "x"]
        yrows = [r for r in phase_rows if r["method"] == method and r["axis"] == "y"]
        vals = [np.mean([r[field] for r in group]) for group in [xrows,yrows] for field in ["fundamental_gain", "lag_deg"]]
        lines.append("|"+"|".join([method]+[f"{v:.6g}" for v in vals])+"|")
    lines += ["", "## 怎样判断哪一组更好", "", "- 先检查资格，再逐指标比较；本实验没有预设PCA胜出，没有选最有利种子或修改轨迹追逐胜负。", "- 箱线图每箱n=3，叠加全部点，浅线连接同一种子；箱体四分位数只用于描述。连续时间点没有作为独立样本。", "- seed1跟踪图是预先固定示例，不是三种子中挑选的最好结果。所有三种子的原始MAT和100Hz跟踪CSV均保留。", "- 名义共同预测力矩残差接近数值零，不能解释为实际力矩误差为零；需同时检查真实跟踪、舵效模型误差与PWM活动。", "- lite物理偏置0.05°/s测试的既有预期失败仍存在；本次未修偏置、未改门槛。", "", "## 输出", "", "[十二状态箱线图](figures/boxplot_12states_rmse.png) · [效果与代价箱线图](figures/boxplot_tracking_allocation.png) · [五方法八字轨迹](figures/figure8_five_methods_seed1.png)", "", "[预测PCA十二状态](figures/PCA_PREDICTIVE_12states_seed1.png) · [静态PCA十二状态](figures/PCA_STATIC_12states_seed1.png) · [PCA配对差值图](figures/paired_pca_12states.png)", "", "[逐运行指标](summary.csv) · [十二状态指标](state_metrics.csv) · [均值/标准差](aggregate_metrics.csv) · [配对差值](paired_pca_deltas.csv) · [相位诊断](tracking_phase.csv) · [协议](protocol.json) · [可比性](comparability.csv) · [状态](status.csv)", ""]
    lines += ["[加载及全程箱线图](figures/boxplot_load_transients.png) · [峰值定位](peak_diagnostics.csv) · [独立重算检查](independent_checks.json)", ""]
    (folder / "report.md").write_text("\n".join(lines), encoding="utf-8")
    checks = dict(completed=15, failed=0, independent_seed_count=3, boxplot_unit="per_seed_run_metric", primary_window_s=[6,50], plot_example_seed=1, control_chain_changed=False, engine_fingerprint=protocol["engine_fingerprint"], comparability=gates["comparability"], generated_figures=len(list(figures.glob("*.png"))))
    (folder / "plot_checks.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(checks, ensure_ascii=False))
    print(folder / "report.md")


if __name__ == "__main__":
    main()
