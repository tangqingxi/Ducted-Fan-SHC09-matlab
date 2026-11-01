"""绘制更激进八字及动态失配确认结果，保持真实资格、优先级触发和代价分别可见。"""

import argparse
import csv
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

import plot_figure8_lite as base


METRICS = base.METRICS + [
    ("actuator_estimate_rmse_deg", "舵角模型估计误差 RMS", "°"),
    ("prediction_rmse_deg", "实际 PWM 终点预测误差 RMS", "°"),
    ("lambda_scaled_percent", "主窗 λ 缩放（仅 PCA）", "%"),
]


def tracking(folder, figures, method, protocol, qualification):
    data = base.load_track(folder, method)
    fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
    for i, (ax, state, label, unit) in enumerate(zip(axes.flat, base.STATES, base.STATE_LABELS, base.UNITS)):
        ax.axvspan(6, 50, color="#e8edf2", alpha=0.45)
        ax.plot(data["time_s"], data["target_" + state], "--", color="#252d35", lw=1.2, label="几何目标 / 本次实际控制指令")
        ax.plot(data["time_s"], data["actual_" + state], color=base.COLORS[base.METHODS.index(method)], lw=1.1, label="物理真值（离线评价）")
        ax.plot(data["time_s"], data["estimate_" + state], color="#3e90a2", lw=0.7, alpha=0.7, label="lite / 控制反馈估计")
        ax.set_title(label, loc="left", fontsize=11)
        ax.set_ylabel(unit)
        ax.grid(alpha=0.2)
        ax.ticklabel_format(axis="y", useOffset=False)
        ax.spines[["top", "right"]].set_visible(False)
        if i >= 9:
            ax.set_xlabel("时间 / s")
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="outside lower center", ncol=3, frameon=False)
    fig.suptitle(f"{base.LABELS[base.METHODS.index(method)]} · {protocol['scenario_id']} · seed 1 · {qualification}\n"
                 "速度目标无前馈；姿态/角速度为实际控制指令；真实舵机24–40ms、模型30ms（未实测假设）", fontsize=13)
    base.save_figure(fig, figures, method + "_12states_seed1")


def priority_figure(folder, figures, qualification):
    rows = base.read_csv(folder / "priority_trace.csv")
    activation = base.read_csv(folder / "priority_activation.csv")
    fig, axes = plt.subplots(3, 2, figsize=(14, 10), layout="constrained")
    for seed in [1, 2, 3]:
        for column, bounds in enumerate([(0, 52), (6, 50)]):
            ax = axes[seed-1, column]
            for method, color in [("PCA_STATIC", base.COLORS[3]), ("PCA_PREDICTIVE", base.COLORS[4])]:
                selected = [r for r in rows if r["method"] == method and int(r["seed"]) == seed]
                t = np.array([float(r["time_s"]) for r in selected])
                value = np.array([float(r["lambda"]) for r in selected])
                ax.step(t, value, where="post", lw=1, color=color, label=base.LABELS[base.METHODS.index(method)])
                active = (value < 1-1e-6) & (t >= bounds[0]) & (t <= bounds[1])
                ax.scatter(t[active], value[active], s=9, color=color, zorder=3)
            window = "whole" if column == 0 else "task"
            counts = [r for r in activation if int(r["seed"]) == seed and r["window"] == window]
            text = "；".join(("静态" if r["method"] == "PCA_STATIC" else "预测")+f"缩放{r['scaled_count']}点" for r in counts)
            ax.set_title(f"seed {seed} · {bounds[0]}–{bounds[1]} s · {text}", fontsize=10)
            ax.set(xlim=bounds, ylim=(-0.03, 1.06), xlabel="时间 / s", ylabel="λ（正常优先级缩放）")
            ax.grid(alpha=0.2)
            ax.spines[["top", "right"]].set_visible(False)
    axes[0, 0].legend(frameon=False)
    fig.suptitle(f"实际 λ 触发 · {qualification}\n800Hz统计全部样本；曲线保留所有缩放点及邻点，不把启动触发算成主窗机制", fontsize=14)
    base.save_figure(fig, figures, "priority_lambda")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scenario_dir", type=Path)
    args = parser.parse_args()
    folder = args.scenario_dir.resolve()
    status = base.read_csv(folder / "status.csv")
    assert len(status) == 15 and all(r["status"] == "completed" for r in status)
    assert (folder / "independent_checks.json").is_file(), "请先运行test_figure8_search_results"
    protocol = json.loads((folder / "protocol.json").read_text(encoding="utf-8-sig"))
    aiding = bool(protocol.get("lite_velocity_aiding_enabled", False))
    rows = base.read_csv(folder / "summary.csv")
    state_rows = base.read_csv(folder / "state_metrics.csv")
    descriptive = protocol.get("evaluation_policy") == "trajectory_descriptive_v2"
    gate_file = "legacy_hover_comparability.csv" if descriptive else "comparability.csv"
    gate = base.read_csv(folder / gate_file)[0]
    quality = "动态任务探索（悬停门禁仅历史对照）"
    figures = folder / "figures"
    assert not figures.exists(), "拒绝覆盖已有图表目录"
    figures.mkdir()
    plt.rcParams.update({"font.family": "sans-serif", "font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"], "axes.unicode_minus": False, "pdf.fonttype": 42})
    fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
    for ax, state, label, unit in zip(axes.flat, base.STATES, base.STATE_LABELS, base.UNITS):
        base.boxes(ax, [base.values(state_rows, m, "rmse", state) for m in base.METHODS], label+" RMSE", unit)
    fig.suptitle(f"十二状态跟踪 · {protocol['scenario_id']} · {quality}\n五方法×三种子，主窗[6,50]秒；每点为一次运行；GNSS速度辅助{'开' if aiding else '关'}", fontsize=14)
    base.save_figure(fig, figures, "boxplot_12states_rmse")
    fig, axes = plt.subplots(4, 3, figsize=(16, 13), layout="constrained")
    for ax, (metric, label, unit) in zip(axes.flat, METRICS):
        base.boxes(ax, [base.values(rows, m, metric) for m in base.METHODS], label, unit)
    fig.suptitle(f"跟踪、模型误差和分配代价 · {quality}\nM2b＋真实舵机24–40ms，舵角模型30ms；非PCA的λ保持缺失，不能填成0或1", fontsize=14)
    base.save_figure(fig, figures, "boxplot_tracking_and_mismatch")
    fig, axes = plt.subplots(2, 3, figsize=(16, 8), layout="constrained")
    for ax, (window, metric, label, unit) in zip(axes.flat, base.TRANSIENT_METRICS):
        base.boxes(ax, [base.values(rows, m, metric, window=window) for m in base.METHODS], label, unit)
    fig.suptitle(f"加载及全程表现 · {quality}\n启动、加载与八字主窗分别保留；不按悬停门禁排除动态轨迹", fontsize=14)
    base.save_figure(fig, figures, "boxplot_load_transients")
    for method in ["PCA_STATIC", "PCA_PREDICTIVE"]:
        tracking(folder, figures, method, protocol, quality)
    priority_figure(folder, figures, quality)
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), layout="constrained")
    ref = base.load_track(folder, "PCA_PREDICTIVE")
    axes[0].plot(ref["target_x"], ref["target_y"], "k--", label="共同几何目标", lw=1.6)
    for method, label, color in zip(base.METHODS, base.LABELS, base.COLORS):
        data = base.load_track(folder, method)
        axes[0].plot(data["actual_x"], data["actual_y"], color=color, lw=1, label=label)
        error = np.sqrt(sum((data["actual_"+s]-data["target_"+s])**2 for s in ["x","y","z"]))
        axes[1].plot(data["time_s"], error, color=color, lw=1)
    axes[0].set(xlabel="北向 x / m", ylabel="东向 y / m", title="seed1：曲线重合时后绘线会遮盖前线")
    axes[0].set_aspect("equal", adjustable="box");axes[0].legend(frameon=False, fontsize=9)
    axes[1].set(xlabel="时间 / s", ylabel="三维位置误差 / m", title="保持原时钟，不作相位对齐")
    for ax in axes:
        ax.grid(alpha=0.2);ax.spines[["top", "right"]].set_visible(False)
    fig.suptitle(f"五方法八字轨迹 · {protocol['scenario_id']} · {quality}", fontsize=14)
    base.save_figure(fig, figures, "figure8_five_methods_seed1")
    write_report(folder, protocol, gate, rows, state_rows)
    print(json.dumps(dict(completed=15, failed=0, figures=7, legacy_hover_comparability=gate["comparability"], hover_gates_define_task_qualification=False, servo_parameters_calibrated=False), ensure_ascii=False))
    print(folder / "report.md")


def write_report(folder, protocol, gate, rows, state_rows):
    # 所有均值和波动都取三次完整运行；没有显著性或单一总分排名。
    lines = ["# 更激进八字与偏航：M2b＋舵机动态失配", "", "> 五方法×三种子，15/15全新仿真；参数是用户批准的未实测假设，不能冒充实机标定。", "", f"场景：{protocol['scenario_id']}；周期{protocol['period_s']}秒，N/E半幅{protocol['amplitude_ned_m'][:2]}米，共{protocol['cycles']}圈；航向为{protocol['yaw_fundamental_deg']}° sin(θ)+{protocol['yaw_third_harmonic_deg']}° sin(3θ)。", "", "全程52秒，运动主窗[6,50]，巡航[8,48]，初始悬停[0,6]；2秒加载、50秒卸载、原0.6负载。真实舵机时间常数[24,27,30,33,36,40]ms、舵角模型统一30ms；±40°及600°/s不变。M2b气动倍率单独保持，不改变M2b原定义。", "", "位置环没有速度/加速度前馈；速度目标为几何导数，姿态及机体角速度目标为本次控制器实际指令。十二状态不是十二个独立外部给定。", "", f"参考峰值速度{protocol['peak_horizontal_speed_m_s']:.7g}m/s、加速度{protocol['peak_horizontal_acceleration_m_s2']:.7g}m/s²、偏航角速度{protocol['peak_yaw_rate_deg_s']:.7g}°/s。", "", f"比较资格：**{gate['comparability']}**；原因：{gate['reason']}。主窗最坏姿态误差峰值{float(gate['max_attitude_error_deg']):.8g}°、饱和{float(gate['max_saturation_percent']):.8g}%、估计姿态RMS{float(gate['attitude_estimate_rmse_deg']):.8g}°、气动越界{gate['aero_extrapolated']}。", "", "## 主窗均值 ± 种子标准差", "", "|指标|DA-NS|WLS|DCA|静态PCA|预测PCA|", "|---|---:|---:|---:|---:|---:|"]
    lines[3:3] = ["", f"本批lite的GNSS速度辅助：{'启用' if protocol.get('lite_velocity_aiding_enabled',False) else '关闭'}。该辅助使用观测源时刻的估计速度历史和原始GNSS速度修正倾角，不读取真值；关闭时保留旧算法。旧结果不混入本批新引擎结果。", ""]
    lines = [line.replace("比较资格：**", "旧悬停门禁历史标签：**") for line in lines]
    lines[3:3] = ["", "更正：旧悬停标签不决定动态任务资格；本文件仅描述探索结果，不按5°或10%饱和占比排除八字。新F8协议另外预先声明参考、前馈、包线、跟踪要求与机制激励条件。", ""]
    for metric, label, unit in METRICS:
        groups = [base.values(rows, m, metric) for m in base.METHODS]
        cells = [f"{v.mean():.7g} ± {v.std(ddof=1):.3g}" if np.all(np.isfinite(v)) else "不适用" for v in groups]
        lines.append("|"+"|".join([f"{label} ({unit})"]+cells)+"|")
    lines += ["", "## 实际优先级触发", "", "mode0中的λ<1也属于缩放；mode1为高优先级补偿回退，mode2为工程兜底。非PCA没有该因子，缺失不填成1。", "", "|方法|主窗控制点数|主窗缩放点数|主窗实际PWM缩放次数|全程最小λ|主窗回退mode1/mode2|", "|---|---:|---:|---:|---:|---:|"]
    activation=base.read_csv(folder/'priority_activation.csv')
    for method in ["PCA_STATIC","PCA_PREDICTIVE"]:
        task=[r for r in activation if r['method']==method and r['window']=='task'];whole=[r for r in activation if r['method']==method and r['window']=='whole']
        minimum=min(float(r['lambda_min']) for r in whole)
        lines.append(f"|{method}|{sum(int(r['control_samples']) for r in task)}|{sum(int(r['scaled_count']) for r in task)}|{sum(int(r['pwm_scaled_count']) for r in task)}|{minimum:.8g}|{sum(int(r['mode1_count']) for r in task)}/{sum(int(r['mode2_count']) for r in task)}|")
    lines += ["", "名义冻结集合证书来自各方法自己的闭环输入，只说明名义可达几何，不能当成未知真实对象的可达性证明。λ没有持续缩放时，不能把预测模型或恢复策略带来的差异归因为优先级保护。", "", "## 十二状态RMSE", "", "|状态|DA-NS|WLS|DCA|静态PCA|预测PCA|", "|---|---:|---:|---:|---:|---:|"]
    for state,label,unit in zip(base.STATES,base.STATE_LABELS,base.UNITS):
        groups=[base.values(state_rows,m,'rmse',state) for m in base.METHODS]
        lines.append('|'+ '|'.join([f'{label} ({unit})']+[f'{v.mean():.7g} ± {v.std(ddof=1):.3g}' for v in groups])+'|')
    lines += ["", "箱线图每箱仅n=3，叠加全部原始点与同种子配对线，不作显著性声明。seed1跟踪示例预先固定。新轨迹与执行器模型同时变化，不能用它与旧轨迹的差异作单因素因果结论。名义预测残差接近零不代表实际力矩误差接近零。", "", "[十二状态箱线图](figures/boxplot_12states_rmse.png) · [跟踪与模型失配](figures/boxplot_tracking_and_mismatch.png) · [加载瞬态](figures/boxplot_load_transients.png) · [λ触发](figures/priority_lambda.png)", "", "[预测PCA十二状态](figures/PCA_PREDICTIVE_12states_seed1.png) · [静态PCA十二状态](figures/PCA_STATIC_12states_seed1.png) · [五方法轨迹](figures/figure8_five_methods_seed1.png)", "", "[完整指标](summary.csv) · [十二状态指标](state_metrics.csv) · [优先级统计](priority_activation.csv) · [事件](priority_events.csv) · [协议](protocol.json) · [可比性](comparability.csv) · [独立核验](independent_checks.json)", ""]
    if protocol.get("evaluation_policy") == "trajectory_descriptive_v2":
        lines = [line.replace("[可比性](comparability.csv)", "[旧悬停门禁对照](legacy_hover_comparability.csv)") for line in lines]
    (folder/'report.md').write_text('\n'.join(lines),encoding='utf-8')


if __name__ == "__main__":
    main()
