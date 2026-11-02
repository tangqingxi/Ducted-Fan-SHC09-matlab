"""绘制新四环研究的完整运行对比，不调用仿真或改写已有原始日志。"""
import argparse
import csv
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def read(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    args = parser.parse_args(); folder = args.folder.resolve()
    rows = read(folder / "summary.csv")
    assert rows and all(r["status"] == "completed" for r in read(folder / "status.csv"))
    figures = folder / "figures"; assert not figures.exists(); figures.mkdir()
    methods = list(dict.fromkeys(r["method"] for r in rows)); seeds = sorted({int(r["seed"]) for r in rows})
    colors = ["#3478b8", "#e79a38", "#299c83", "#8860ad", "#d54850"]
    plt.rcParams.update({"font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"], "axes.unicode_minus": False, "pdf.fonttype": 42})

    def save(fig, name):
        fig.savefig(figures / (name + ".png"), dpi=160, facecolor="white")
        fig.savefig(figures / (name + ".pdf"), facecolor="white"); plt.close(fig)

    metrics = [("horizontal_rmse_m", "水平位置RMS / m"), ("yaw_rmse_deg", "航向RMS / °"),
               ("altitude_rmse_m", "高度RMS / m"), ("actual_servo_rate_rms_deg_s", "实际舵速RMS / °/s"),
               ("actual_servo_travel_deg", "实际六通道行程 / °"), ("pwm_step_rms_deg", "全程PWM步变RMS / °")]
    fig, axes = plt.subplots(2, 3, figsize=(15, 9), layout="constrained")
    for ax, (key, label) in zip(axes.flat, metrics):
        for seed in seeds:
            paired = [float(next(r[key] for r in rows if r["method"] == method and int(r["seed"]) == seed)) for method in methods]
            ax.plot(range(len(methods)), paired, color="grey", alpha=.25, lw=.8)
        for i, method in enumerate(methods):
            values = [float(r[key]) for r in rows if r["method"] == method]
            ax.scatter(np.full(len(values), i), values, color=colors[i], s=35)
            ax.plot([i-.18, i+.18], [np.mean(values)]*2, color=colors[i], lw=2)
        ax.set_xticks(range(len(methods)), methods, rotation=18, fontsize=8); ax.set_ylabel(label); ax.grid(alpha=.2)
    fig.suptitle("共用四环控制器与CUAV误差测量链\n每点一条完整运行，灰线连接同种子，短横线为均值；不作显著性声明")
    save(fig, "tracking_actuation")
    names = ["x", "y", "z", "vx", "vy", "vz", "roll", "pitch", "yaw", "p", "q", "r"]
    labels = ["北向位置 / m", "东向位置 / m", "向下位置 / m", "北向速度 / m/s", "东向速度 / m/s", "向下速度 / m/s",
              "滚转 / °", "俯仰 / °", "航向 / °", "机体p / °/s", "机体q / °/s", "机体r / °/s"]
    for method in methods:
        data = read(folder / "tracks" / f"{method}_s{seeds[0]}.csv")
        time = np.array([float(r["time_s"]) for r in data])
        fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
        for ax, name, label in zip(axes.flat, names, labels):
            for prefix, label, style in [("target", "参考", "k--"), ("actual", "对象真值（评价）", "r-"), ("estimate", "测量/估计反馈", "c-")]:
                ax.plot(time, [float(r[prefix+"_"+name]) for r in data], style, lw=.7, label=label)
            ax.set_title(label); ax.grid(alpha=.2)
        axes[0, 0].legend(fontsize=8); fig.suptitle(f"{method} · seed{seeds[0]} · 十二状态；时序100Hz，评分800Hz")
        save(fig, method + "_12states")
    fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
    for i, method in enumerate(methods):
        data = read(folder / "tracks" / f"{method}_s{seeds[0]}.csv")
        time = np.array([float(r["time_s"]) for r in data])
        for ax, name, label in zip(axes.flat, names, labels):
            ax.plot(time, [float(r["actual_"+name]) for r in data], color=colors[i], lw=.65, label=method)
            ax.set_title(label); ax.grid(alpha=.2)
    for ax, name in zip(axes.flat, names):
        ax.plot(time, [float(r["target_"+name]) for r in data], "k--", lw=.8, label="共同参考")
        ax.axvspan(6, 50, color="grey", alpha=.05)
    axes[0, 0].legend(fontsize=7, ncol=2); fig.suptitle(f"共用控制器 · 十二状态对比 · 预定展示种子{seeds[0]}")
    save(fig, "five_methods_12states")
    fig, axes = plt.subplots(1, 2, figsize=(13, 5), layout="constrained")
    for i, method in enumerate(methods):
        data = read(folder / "tracks" / f"{method}_s{seeds[0]}.csv")
        x = np.array([float(r["actual_x"]) for r in data]); y = np.array([float(r["actual_y"]) for r in data])
        axes[0].plot(x, y, color=colors[i], label=method)
        if method.startswith("PCA_"):
            t = np.array([float(r["time_s"]) for r in data]); mode = np.array([int(r["mode"]) for r in data])
            scale = np.array([float(r["lambda"]) for r in data])
            axes[1].plot(t, np.where(mode == 0, scale, np.nan), color=colors[i], lw=.7, label=method+" 正常ρ")
            axes[1].scatter(t[mode == 1], scale[mode == 1], color=colors[i], marker="x", s=10, label=method+" 高优先级回退")
            axes[1].scatter(t[mode == 2], np.zeros(np.sum(mode == 2)), color=colors[i], marker="v", s=10, label=method+" 工程兜底")
    axes[0].plot([float(r["target_x"]) for r in data], [float(r["target_y"]) for r in data], "k--", label="共同参考")
    axes[0].set(xlabel="北向 / m", ylabel="东向 / m"); axes[0].set_aspect("equal", adjustable="box"); axes[0].legend(fontsize=8)
    axes[1].set(xlabel="时间 / s", ylabel="正常ρ；回退单独标记"); axes[1].legend(fontsize=6); save(fig, "trajectory_priority")
    if (folder / "diagnostics_100hz").is_dir():
        fig, axes = plt.subplots(3, 2, figsize=(15, 10), layout="constrained")
        for i, method in enumerate(methods):
            data = read(folder / "diagnostics_100hz" / f"{method}_s{seeds[0]}.csv")
            time = np.array([float(r["time_s"]) for r in data])
            for j, ax in enumerate(axes.flat, 1):
                ax.plot(time, [float(r[f"actual_servo_{j}"]) for r in data], color=colors[i], lw=.6, label=method)
                ax.set_title(f"实际舵面{j} / °"); ax.grid(alpha=.2)
        axes[0, 0].legend(fontsize=7, ncol=2); fig.suptitle(f"六舵面实际运动 · seed{seeds[0]} · 显示100Hz")
        save(fig, "actual_servos")
    aggregate = []
    for method in methods:
        record = {"method": method, "runs": len([r for r in rows if r["method"] == method])}
        for key, _ in metrics:
            values = np.array([float(r[key]) for r in rows if r["method"] == method])
            record.update({key+"_mean": float(values.mean()), key+"_min": float(values.min()), key+"_max": float(values.max())})
        aggregate.append(record)
    with (folder / "aggregate_metrics.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(aggregate[0]), lineterminator="\n"); writer.writeheader(); writer.writerows(aggregate)
    lines = ["# 新四环F8研究", "", "共用位置P、速度PID、姿态P、角速度比例P＋INDI；五种分配器以外设置相同。传感器为CUAV硬件类别误差假设，未完成实机标定。", "",
             "参考角加速度与角速度比例反馈合为nu_c；nu_h只含历史名义舵效减测量角加速度。真值只作对象、传感器生成和离线评价。", "",
             "|方法|种子|水平RMS m|航向RMS °|高度RMS m|实际舵速RMS °/s|任务通过|", "|---|---:|---:|---:|---:|---:|---|"]
    for r in rows:
        lines.append("|" + "|".join(r[k] for k in ["method", "seed", "horizontal_rmse_m", "yaw_rmse_deg", "altitude_rmse_m", "actual_servo_rate_rms_deg_s", "task_passed"]) + "|")
    lines += ["", "## 三种子均值", "", "|方法|水平RMS m|航向RMS °|高度RMS m|实际舵速RMS °/s|六通道行程 °|", "|---|---:|---:|---:|---:|---:|"]
    for r in aggregate:
        lines.append("|" + r["method"] + "|" + "|".join(f"{r[key+'_mean']:.6g}" for key in
                     ["horizontal_rmse_m", "yaw_rmse_deg", "altitude_rmse_m", "actual_servo_rate_rms_deg_s", "actual_servo_travel_deg"]) + "|")
    if (folder / "priority_summary.csv").exists():
        lines += ["", "## 名义可达集合独立审计", "", "|方法|种子|正常缩放 s|高优先级回退 s|工程兜底 s|严格非共线证书 s|正常最小ρ|", "|---|---:|---:|---:|---:|---:|---:|"]
        for r in read(folder / "priority_summary.csv"):
            lines.append("|" + "|".join(r[k] for k in ["method", "seed", "normal_scaled_s", "high_priority_fallback_s", "emergency_fallback_s", "strict_noncollinear_certificate_s", "normal_lambda_min"]) + "|")
        lines += ["", "支撑面几何核对全部主窗控制时刻，独立LP按预定模式分组抽样复核。只证明本批名义分配几何与求解一致；不等于实际对象优先级保护、稳定性或鲁棒性证明。"]
    lines += ["", "[跟踪与实际运动](figures/tracking_actuation.png) · [轨迹与优先级](figures/trajectory_priority.png)", "",
              "飞行前仅用EKF固定任务局部原点，原始导航误差另列；未进行飞行后相位、位置或真值对齐。开发伪逆结果与正式比较分开，失败记录保留。主窗口[6,50]s，800Hz评分；PWM步变为全程333Hz下发事件指标。",
              "", "solver_timing.csv是离线主机耗时；仿真未注入随求解耗时变化的计算延迟，400Hz逻辑更新不等于已经验证硬件实时期限。本批未记录完整EKF创新历史或在线数据年龄，不能声称完成了对应审计。",
              "", "不宣称统计显著性、实机优势或已验证优先级保护。", ""]
    (folder / "report.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"runs": len(rows), "methods": methods, "figure_pairs": len(list(figures.glob("*.png")))}))


if __name__ == "__main__":
    main()
