"""绘制正式F8五方法的箱线图与十二状态跟踪，保留未通过门禁和不利结果。"""

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

import plot_figure8_lite as base

SEEDS = [101, 102, 103]
EXAMPLE_SEED = 101


METRICS = [
    ("horizontal_position_rmse_m", "水平位置向量 RMS", "m"),
    ("altitude_rmse_m", "高度 RMS", "m"),
    ("velocity_rmse_m_s", "三维速度向量 RMS", "m/s"),
    ("yaw_rmse_deg", "航向 RMS", "°"),
    ("inner_attitude_rmse_deg", "实际期望姿态跟踪 RMS", "°"),
    ("inner_attitude_peak_deg", "实际期望姿态跟踪峰值", "°"),
    ("estimator_attitude_rmse_deg", "lite 姿态估计 RMS", "°"),
    ("command_step_rms_deg", "全程 PWM 命令步变 RMS", "°"),
    ("actuator_estimate_rmse_deg", "全程舵角估计 RMS", "°"),
    ("pwm_prediction_rmse_deg", "全程实际 PWM 终点预测 RMS", "°"),
    ("max_actual_tilt_deg", "全程真实合成倾角峰值", "°"),
    ("command_limit_occupancy_percent", "主窗命令触及 ±40°", "%"),
]

MOTION_METRICS = [
    ("actual_servo_rate_rmse_deg_s", "主窗实际舵速 RMS", "°/s"),
    ("actual_servo_total_variation_deg", "主窗实际舵角总行程（六通道和）", "°"),
]


def comparison_figures(figures, rows, scenario):
    # 保留三个种子的配对关系；不把箱线图当成大样本分布或显著性证据。
    metrics = [METRICS[3], METRICS[0], METRICS[4], *MOTION_METRICS, METRICS[7]]
    fig, axes = plt.subplots(2, 3, figsize=(16, 9), layout="constrained")
    for ax, (metric, label, unit) in zip(axes.flat, metrics):
        base.boxes(ax, groups(rows, metric), label, unit)
    fig.suptitle(f"{scenario} · 五方法正式确认 · seeds {SEEDS}\n每点为一次完整运行；灰线连接同种子；跟踪/舵机为主窗，PWM为全程；n=3", fontsize=14)
    base.save_figure(fig, figures, "key_metrics_paired")
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), layout="constrained")
    markers = ["o", "s", "^"]
    yaw = groups(rows, "yaw_rmse_deg")
    for ax, (metric, label, unit) in zip(axes, MOTION_METRICS):
        motion = groups(rows, metric)
        for i, (method, color, name) in enumerate(zip(base.METHODS, base.COLORS, base.LABELS)):
            for j, seed in enumerate(SEEDS):
                ax.scatter(motion[i][j], yaw[i][j], marker=markers[j], color=color, s=45, alpha=0.6)
            ax.scatter(motion[i].mean(), yaw[i].mean(), marker="X", s=95, color=color, edgecolor="white", label=name)
        ax.set(xlabel=f"{label} / {unit}", ylabel="航向 RMS / °")
        ax.grid(alpha=0.2); ax.spines[["top", "right"]].set_visible(False)
    axes[0].legend(frameon=False, fontsize=9)
    fig.suptitle(f"{scenario} · 航向误差与执行器活动\n○ seed{SEEDS[0]}；□ seed{SEEDS[1]}；△ seed{SEEDS[2]}；X 三种子均值；越向左下越低\n预测PCA与DCA构成权衡；DA-NS/WLS曲线可能重叠；不作显著性或能耗声明", fontsize=13)
    base.save_figure(fig, figures, "yaw_actuation_tradeoff")


def number(row, key):
    return float(row[key])


def groups(rows, metric, state=None):
    result = []
    for method in base.METHODS:
        selected = [r for r in rows if r["method"] == method and (state is None or (r["state"] == state and r["window"] == "task"))]
        selected.sort(key=lambda r: int(r["seed"]))
        assert [int(r["seed"]) for r in selected] == SEEDS
        result.append(np.array([number(r, metric) for r in selected]))
    return result


def build_products(folder, output, rows, states, protocol):
    aggregate = []
    for metric, label, unit in METRICS + MOTION_METRICS:
        for method, values in zip(base.METHODS, groups(rows, metric)):
            aggregate.append(dict(method=method, metric=metric, label=label, unit=unit, n=3,
                                  mean=float(values.mean()), std=float(values.std(ddof=1)),
                                  minimum=float(values.min()), maximum=float(values.max())))
    base.write_csv(output / "aggregate_metrics.csv", aggregate)
    pairs = []
    comparisons = [("PCA_STATIC", m) for m in base.METHODS[:3]] + [("PCA_PREDICTIVE", m) for m in base.METHODS[:4]]
    for candidate, baseline in comparisons:
        for metric, _, _ in METRICS + MOTION_METRICS:
            candidate_values = groups(rows, metric)[base.METHODS.index(candidate)]
            baseline_values = groups(rows, metric)[base.METHODS.index(baseline)]
            for seed, value, reference in zip(SEEDS, candidate_values, baseline_values):
                pairs.append(dict(candidate=candidate, baseline=baseline, seed=seed, metric=metric,
                                  candidate_value=float(value), baseline_value=float(reference),
                                  candidate_minus_baseline=float(value-reference),
                                  percent_change=float(100*(value-reference)/reference) if abs(reference)>1e-12 else ""))
    base.write_csv(output / "paired_pca_deltas.csv", pairs)
    failures = []
    for row in rows:
        for section in ["tracking_requirements", "envelope"]:
            for metric, threshold in protocol[section].items():
                if metric == "role":
                    continue
                value = number(row, metric)
                tolerance = 1e-7 if section == "envelope" else 0
                if value > threshold+tolerance:
                    failures.append(dict(method=row["method"], seed=row["seed"], section=section,
                                         metric=metric, value=value, maximum=threshold))
    if failures:
        base.write_csv(output / "task_requirement_failures.csv", failures)
    phase_rows = []
    for method in base.METHODS:
        for seed in SEEDS:
            data = base.load_track(folder, method, seed)
            q = (data["time_s"]>=10) & (data["time_s"]<=46)
            phase = 2*np.pi*(data["time_s"][q]-8)/protocol["scenario"]["period_s"]
            for axis, harmonic, amplitude in [("x", 1, protocol["scenario"]["north_amplitude_m"]), ("y", 2, protocol["scenario"]["east_amplitude_m"])]:
                design = np.column_stack([np.sin(harmonic*phase), np.cos(harmonic*phase), np.ones(q.sum())])
                coefficients = np.linalg.lstsq(design, data["actual_"+axis][q], rcond=None)[0]
                residual = data["actual_"+axis][q]-design@coefficients
                phase_rows.append(dict(method=method, seed=seed, axis=axis, gain=float(np.hypot(*coefficients[:2])/amplitude),
                                       lag_deg=float(-np.rad2deg(np.arctan2(coefficients[1], coefficients[0]))),
                                       fit_residual_rmse_m=float(np.sqrt(np.mean(residual**2))),
                                       interpretation="仅诊断相位，不对跟踪分数作相位对齐"))
    base.write_csv(output / "tracking_phase.csv", phase_rows)
    return aggregate, failures


def track_figure(folder, figures, method, scenario):
    data = base.load_track(folder, method, EXAMPLE_SEED)
    fig, axes = plt.subplots(4, 3, figsize=(16, 12), layout="constrained")
    for i, (ax, state, label, unit) in enumerate(zip(axes.flat, base.STATES, base.STATE_LABELS, base.UNITS)):
        ax.axvspan(6, 50, color="#e8edf2", alpha=0.4)
        ax.plot(data["time_s"], data["target_"+state], "--", color="#252d35", lw=1.2, label="共同几何目标")
        ax.plot(data["time_s"], data["actual_"+state], color=base.COLORS[base.METHODS.index(method)], lw=1, label="物理真值（评价）")
        ax.plot(data["time_s"], data["estimate_"+state], color="#3e90a2", lw=0.7, alpha=0.65, label="lite / 反馈估计")
        command = ["command_roll_deg", "command_pitch_deg", "command_yaw_deg"]
        if 6<=i<=8:
            ax.plot(data["time_s"], data[command[i-6]], color="#a58c63", lw=0.7, alpha=0.7, label="反馈修正后的姿态指令")
        if i>=9:
            ax.plot(data["time_s"], data[f"command_rate{i-8}_deg_s"], color="#a58c63", lw=0.7, alpha=0.7, label="实际角速度指令")
        ax.set(title=label, ylabel=unit)
        ax.grid(alpha=0.2);ax.spines[["top", "right"]].set_visible(False)
        ax.ticklabel_format(axis="y", useOffset=False)
        if i>=9:
            ax.set_xlabel("时间 / s")
    handles, labels = axes[0, 0].get_legend_handles_labels()
    handles2, labels2 = axes[2, 0].get_legend_handles_labels()
    handles3, labels3 = axes[3, 0].get_legend_handles_labels()
    fig.legend(handles+handles2[3:]+handles3[3:], labels+labels2[3:]+labels3[3:], loc="outside lower center", ncol=3, frameon=False)
    fig.suptitle(f"{scenario} · {base.LABELS[base.METHODS.index(method)]} · 预定示例 seed{EXAMPLE_SEED}\n共同几何参考与反馈指令分开；开启速度/加速度及名义几何 ω/α 前馈", fontsize=14)
    base.save_figure(fig, figures, method+f"_12states_seed{EXAMPLE_SEED}")


def priority_figure(folder, figures, scenario):
    rows = base.read_csv(folder / "priority_trace.csv")
    activation = base.read_csv(folder / "priority_activation.csv")
    fig, axes = plt.subplots(3, 2, figsize=(14, 10), layout="constrained")
    for seed, pair in zip(SEEDS, axes):
        for ax, bounds, window in zip(pair, [(0, 52), (6, 50)], ["whole", "task"]):
            for method in ["PCA_STATIC", "PCA_PREDICTIVE"]:
                r = [x for x in rows if x["method"]==method and int(x["seed"])==seed]
                t = np.array([number(x,"time_s") for x in r]);value = np.array([number(x,"lambda") for x in r])
                color = base.COLORS[base.METHODS.index(method)]
                ax.step(t, value, where="post", color=color, lw=1, label=base.LABELS[base.METHODS.index(method)])
                q = (value<1-1e-6)&(t>=bounds[0])&(t<=bounds[1]);ax.scatter(t[q], value[q], color=color, s=8)
            a = [x for x in activation if int(x["seed"])==seed and x["window"]==window]
            note = "；".join(("静态" if x["method"]=="PCA_STATIC" else "预测")+f"缩放{x['scaled_count']}点" for x in a)
            ax.set(title=f"seed{seed} · {bounds[0]}–{bounds[1]}s · {note}", xlim=bounds, ylim=(-0.03,1.06), xlabel="时间 / s", ylabel="λ")
            ax.grid(alpha=0.2);ax.spines[["top", "right"]].set_visible(False)
    axes[0,0].legend(frameon=False)
    fig.suptitle(f"{scenario} · 实际优先级缩放\n完整800Hz计数，曲线保留全部非1事件；启动触发与运动窗分别统计", fontsize=14)
    base.save_figure(fig, figures, "priority_lambda")


def error_figure(folder, figures, scenario):
    # 同一预定示例种子比较误差，避免大幅参考曲线掩盖小幅跟踪差异。
    fig,axes=plt.subplots(3,1,figsize=(14,10),layout="constrained",sharex=True)
    for method,label,color in zip(base.METHODS,base.LABELS,base.COLORS):
        data=base.load_track(folder,method,EXAMPLE_SEED);t=data["time_s"]
        yaw=data["actual_yaw"]-data["target_yaw"];yaw=np.rad2deg(np.arctan2(np.sin(np.deg2rad(yaw)),np.cos(np.deg2rad(yaw))))
        position=np.hypot(data["actual_x"]-data["target_x"],data["actual_y"]-data["target_y"])
        rate=data["actual_r"]-data["target_r"]
        for ax,value in zip(axes,[yaw,position,rate]):
            ax.plot(t,value,color=color,lw=1,label=label)
    for ax,label in zip(axes,["航向跟踪误差 / °","水平位置误差 / m","机体r相对几何参考误差 / °/s"]):
        ax.set(xlim=(6,50),ylabel=label);ax.grid(alpha=0.2);ax.spines[["top","right"]].set_visible(False)
    axes[0].legend(frameon=False,ncol=5);axes[-1].set_xlabel("时间 / s")
    fig.suptitle(f"{scenario} · 共同目标下的跟踪误差 · seed{EXAMPLE_SEED}\n100Hz示例；统计仍使用完整800Hz日志；重叠曲线可能遮挡",fontsize=14)
    base.save_figure(fig,figures,f"tracking_errors_seed{EXAMPLE_SEED}")


def write_report(folder, output, rows, protocol, evaluation, aggregate, failures):
    scenario = protocol["scenario"]["id"]
    lines = [f"# {scenario}：{protocol['protocol_id']} 正式五方法比较", "", f"> 15/15完整仿真，五方法×保留种子{'、'.join(str(s) for s in SEEDS)}；每箱n=3，不宣称显著性。", "",
             f"平滑八字半幅N/E={protocol['scenario']['north_amplitude_m']}/{protocol['scenario']['east_amplitude_m']}m，周期{protocol['scenario']['period_s']}s，高度10m；主窗[6,50]s，巡航[10,46]s，全程52s。", "",
             "M2b/lite，原0.6负载；真实舵机24–40ms、估计统一30ms是未实测假设。显式开启GNSS速度辅助及轨迹前馈；五方法共享相同反馈增益。未修改五算法、物理、气动表或已声明门禁。", "",
             f"完整性：{evaluation['all_five_methods_three_seeds_completed']}；全部方法满足任务要求：**{evaluation['all_five_methods_meet_task_requirements']}**；优先级激励与名义几何条件：**{evaluation['priority_excitation_and_nominal_geometry_requirements_met']}**。三项分别解释，不生成悬停rankable标签。", "",
             "## 主窗表现及全程分配代价", "", "|指标|DA-NS|WLS|DCA|静态PCA|预测PCA|", "|---|---:|---:|---:|---:|---:|"]
    if "yaw_clock_frequency_hz" in protocol["scenario"]:
        lines[4:4]=[f"偏航为{protocol['scenario']['yaw_amplitude_deg']}° sin(2π×{protocol['scenario']['yaw_clock_frequency_hz']}×平滑运动时钟)。这是开发筛选后保留种子的独立确认，不将开发点混入箱线图。", ""]
    for metric, label, unit in METRICS:
        values = groups(rows, metric)
        lines.append("|"+"|".join([f"{label} ({unit})"]+[f"{v.mean():.7g} ± {v.std(ddof=1):.3g}" for v in values])+"|")
    lines += ["", "角度误差先处理环绕。合成倾角是机体竖轴相对NED竖轴的夹角，与航向和姿态跟踪误差分开。已标明的舵角/PWM代价为全程统计，其余跟踪指标为主窗。", "", "## 逐次任务未通过项", ""]
    if (folder/"allocation_truth_diagnostics.csv").is_file():
        physical=base.read_csv(folder/"allocation_truth_diagnostics.csv")
        insert=["", "### 真实执行器与名义残差分开评价", "", "|主窗指标|DA-NS|WLS|DCA|静态PCA|预测PCA|", "|---|---:|---:|---:|---:|---:|"]
        for metric,label,unit in [("actual_instantaneous_vane_demand_residual_rms_nm","真实当前舵效相对当前需求的残差RMS","Nm"),
                                  ("actual_nominal_vane_torque_difference_rms_nm","真实与名义舵效力矩差RMS","Nm"),
                                  ("actual_servo_rate_rmse_deg_s","真实舵速RMS","°/s"),
                                  ("actual_servo_total_variation_deg","真实舵角总行程（六通道和）","°")]:
            selected=[r for r in physical if r["window"]=="task"]
            values=groups(selected,metric)
            insert.append("|"+"|".join([f"{label} ({unit})"]+[f"{v.mean():.7g} ± {v.std(ddof=1):.3g}" for v in values])+"|")
        insert += ["", "当前时刻的真实舵效残差与名义PWM终点约束具有不同的时间含义；前者不应被预测模型等式冒充为零。各次闭环的分配需求也由各自估计和控制器产生，并非跨方法相同的外部力矩目标，因此这些残差仅作诊断，不替代共同轨迹误差。PWM命令步变也不是实际舵角运动量，更不是已标定的磨损或能耗。", ""]
        location=lines.index("## 逐次任务未通过项")-1;lines[location:location]=insert
    if failures:
        lines += ["|方法|种子|类别|指标|数值|最大允许值|", "|---|---:|---|---|---:|---:|"]
        for r in failures:
            lines.append(f"|{r['method']}|{r['seed']}|{r['section']}|{r['metric']}|{r['value']:.9g}|{r['maximum']}|")
    else:
        lines.append("全部15条均通过已冻结的包线与任务跟踪要求。")
    lines += ["", "## PCA的同种子差值", "", "下面为候选减基线的百分比变化；负值表示该项更低，区间为三个种子最小值至最大值。不是显著性检验，不合成总分。", "", "|候选 / 基线|水平位置RMS|速度RMS|航向RMS|全程PWM步变RMS|", "|---|---:|---:|---:|---:|"]
    for candidate, baseline in [("PCA_STATIC","WLS"),("PCA_PREDICTIVE","WLS"),("PCA_PREDICTIVE","DCA"),("PCA_PREDICTIVE","PCA_STATIC")]:
        cells=[]
        for metric in ["horizontal_position_rmse_m","velocity_rmse_m_s","yaw_rmse_deg","command_step_rms_deg"]:
            a=groups(rows,metric)[base.METHODS.index(candidate)];b=groups(rows,metric)[base.METHODS.index(baseline)];change=100*(a-b)/b
            cells.append(f"{change.mean():+.4g}% [{change.min():+.4g}, {change.max():+.4g}]")
        lines.append("|"+"|".join([f"{candidate} / {baseline}"]+cells)+"|")
    lines += ["", "## 优先级证据与解释范围", "", "|方法|主窗mode0缩放累计秒（三种子合计）|单次最长连续缩放秒|主窗PWM缩放次数|全程最小λ|主窗mode1 / mode2点数|", "|---|---:|---:|---:|---:|---:|"]
    active=base.read_csv(folder/"priority_activation.csv")
    for method in ["PCA_STATIC","PCA_PREDICTIVE"]:
        task=[r for r in active if r["method"]==method and r["window"]=="task"];whole=[r for r in active if r["method"]==method and r["window"]=="whole"]
        lines.append(f"|{method}|{sum(number(r,'scaled_duration_s') for r in task):.8g}|{max(number(r,'longest_episode_s') for r in task):.8g}|{sum(int(r['pwm_scaled_count']) for r in task)}|{min(number(r,'lambda_min') for r in whole):.8g}|{sum(int(r['high_priority_fallback_count']) for r in task)} / {sum(int(r['engineering_fallback_count']) for r in task)}|")
    startup = [r for r in active if r["window"] == "initial_hover" and int(r["scaled_count"]) > 0]
    for r in startup:
        lines += ["", f"启动窗事件：{r['method']} seed{r['seed']}，{r['scaled_count']}个控制采样点，累计{r['scaled_duration_s']}s，最小λ={r['lambda_min']}。精确时间见priority_events.csv；启动缩放不能冒充任务主窗机制证据。"]
    lines += ["",
              "mode1是高优先级补偿回退（另看β），mode2是工程兜底，不能把缺失λ当成1。主窗没有持续缩放，不能据此宣称验证受限优先级保护。名义预测残差接近零不是实测力矩为零；全程真实PWM终点预测误差单独报告。通过激励条件也只是允许讨论当前场景的优先级作用，不证明PCA普遍更优。", "",
              "相位拟合单独保存，所有跟踪分数保持原时钟。共同几何姿态/角速度参考用于十二状态误差；反馈修正后的姿态和角速度指令另画，不能把每个方法自己的控制目标当成共同目标。", "",
              f"[十二状态箱线图](figures/boxplot_12states_rmse.png) · [跟踪与代价](figures/boxplot_tracking_costs.png) · [五方法轨迹](figures/figure8_five_methods_seed{EXAMPLE_SEED}.png) · [实际λ](figures/priority_lambda.png)", "",
              f"[静态PCA十二状态](figures/PCA_STATIC_12states_seed{EXAMPLE_SEED}.png) · [预测PCA十二状态](figures/PCA_PREDICTIVE_12states_seed{EXAMPLE_SEED}.png)", "",
              f"[共同目标下的五方法误差时序](figures/tracking_errors_seed{EXAMPLE_SEED}.png)", "",
              "[逐次指标](task_metrics.csv) · [十二状态指标](state_metrics.csv) · [均值和波动](aggregate_metrics.csv) · [配对差值](paired_pca_deltas.csv) · [相位诊断](tracking_phase.csv) · [独立核验](independent_checks.json) · [协议](protocol.json)", ""]
    lines += ["## 跟踪与执行器活动权衡", "",
              "[五方法关键指标与逐种子配对](figures/key_metrics_paired.png) · [航向与实际舵机活动权衡](figures/yaw_actuation_tradeoff.png)", "",
              "预测PCA的航向RMS略高于DCA、实际舵速和行程更低，是当前场景的权衡，不能称为Pareto支配。DA_NS与WLS数值极接近但并非逐位相同。未做消融实验，不能分离预测、等待段处理及最小变化恢复的各自贡献。", ""]
    for method in base.METHODS:
        lines.append(f"[{method} 十二状态](figures/{method}_12states_seed{EXAMPLE_SEED}.png)")
    (output/"report.md").write_text("\n".join(lines),encoding="utf-8")


def main():
    global SEEDS, EXAMPLE_SEED
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("scenario_dir",type=Path)
    parser.add_argument("--output-dir",type=Path,required=True,help="新的派生输出目录；不写入原始实验目录")
    args=parser.parse_args()
    folder=args.scenario_dir.resolve();status=base.read_csv(folder/"status.csv")
    assert len(status)==15 and all(r["status"]=="completed" for r in status)
    independent=json.loads((folder/"independent_checks.json").read_text(encoding="utf-8-sig"));assert independent["formal_logs_verified"]==15
    protocol=json.loads((folder/"protocol.json").read_text(encoding="utf-8-sig"));assert not protocol["smoke_test"]
    assert not protocol.get("development_screen", False), "开发结果不能作正式三种子箱线图"
    SEEDS=sorted(int(s) for s in protocol["seeds"]);assert len(SEEDS)==3
    EXAMPLE_SEED=int(protocol["analysis"]["example_seed"])
    evaluation=json.loads((folder/"task_evaluation.json").read_text(encoding="utf-8-sig"));scenario=protocol["scenario"]["id"]
    rows=base.read_csv(folder/"task_metrics.csv");states=base.read_csv(folder/"state_metrics.csv")
    assert len(rows)==15 and len(states)==720
    output=args.output_dir.resolve()
    assert not output.exists(),"不覆盖已有派生输出"
    assert not output.is_relative_to(folder) and not folder.is_relative_to(output),"输入与派生输出必须分离"
    output.mkdir(parents=True);figures=output/"figures";figures.mkdir()
    plt.rcParams.update({"font.family":"sans-serif","font.sans-serif":["Microsoft YaHei","SimHei","DejaVu Sans"],"axes.unicode_minus":False,"pdf.fonttype":42})
    aggregate,failures=build_products(folder,output,rows,states,protocol)
    fig,axes=plt.subplots(4,3,figsize=(16,12),layout="constrained")
    for ax,state,label,unit in zip(axes.flat,base.STATES,base.STATE_LABELS,base.UNITS):
        base.boxes(ax,groups(states,"rmse",state),label+" RMSE",unit)
    fig.suptitle(f"{scenario} · 十二状态跟踪误差\n五方法×三种子；每点是一条完整轨迹；保留全部任务未通过点",fontsize=14)
    base.save_figure(fig,figures,"boxplot_12states_rmse")
    fig,axes=plt.subplots(4,3,figsize=(16,13),layout="constrained")
    for ax,(metric,label,unit) in zip(axes.flat,METRICS):
        base.boxes(ax,groups(rows,metric),label,unit)
        threshold=protocol["tracking_requirements"].get(metric)
        if threshold is not None:
            ax.axhline(threshold,color="#a85050",ls=":",lw=1)
    fig.suptitle(f"{scenario} · 跟踪、估计与分配代价\n虚线为冻结任务门槛；n=3，不作显著性声明",fontsize=14)
    base.save_figure(fig,figures,"boxplot_tracking_costs")
    for method in base.METHODS:
        track_figure(folder,figures,method,scenario)
    priority_figure(folder,figures,scenario)
    error_figure(folder,figures,scenario)
    fig,axes=plt.subplots(1,2,figsize=(14,6),layout="constrained");r=base.load_track(folder,"PCA_PREDICTIVE",EXAMPLE_SEED)
    axes[0].plot(r["target_x"],r["target_y"],"k--",lw=1.6,label="共同几何参考")
    for method,label,color in zip(base.METHODS,base.LABELS,base.COLORS):
        data=base.load_track(folder,method,EXAMPLE_SEED);axes[0].plot(data["actual_x"],data["actual_y"],lw=1,color=color,label=label)
        error=np.sqrt(sum((data["actual_"+s]-data["target_"+s])**2 for s in ["x","y","z"]))
        axes[1].plot(data["time_s"],error,lw=1,color=color)
    axes[0].set(xlabel="北向 x / m",ylabel="东向 y / m",title=f"seed{EXAMPLE_SEED}；曲线重叠时后绘线可能遮盖前线");axes[0].set_aspect("equal",adjustable="box");axes[0].legend(frameon=False,fontsize=9)
    axes[1].set(xlabel="时间 / s",ylabel="三维位置误差 / m",title="保持原时钟，不作相位对齐")
    for ax in axes:
        ax.grid(alpha=0.2);ax.spines[["top","right"]].set_visible(False)
    fig.suptitle(f"{scenario} · 五方法平滑八字跟踪",fontsize=14);base.save_figure(fig,figures,f"figure8_five_methods_seed{EXAMPLE_SEED}")
    figure_count=10
    if (folder/"allocation_truth_diagnostics.csv").is_file():
        physical=[r for r in base.read_csv(folder/"allocation_truth_diagnostics.csv") if r["window"]=="task"]
        fig,axes=plt.subplots(2,3,figsize=(16,8),layout="constrained")
        metrics=[("actual_instantaneous_vane_demand_residual_rms_nm","真实当前舵效/当前需求残差RMS","Nm"),
                 ("actual_nominal_vane_torque_difference_rms_nm","真实与名义舵效力矩差RMS","Nm"),
                 ("actual_pwm_forecast_rmse_deg","真实PWM终点预测误差RMS","°"),
                 ("actual_servo_rate_rmse_deg_s","真实舵速RMS","°/s"),
                 ("actual_servo_total_variation_deg","真实舵角总行程（六通道和）","°"),
                 ("pwm_command_step_rms_deg","主窗PWM命令步变RMS","°")]
        for ax,(metric,label,unit) in zip(axes.flat,metrics):
            base.boxes(ax,groups(physical,metric),label,unit)
        fig.suptitle(f"{scenario} · 真实对象的分配残差与实际舵机运动\n主窗[6,50]秒；真值仅离线评价，当前时刻残差不等于名义PWM终点约束",fontsize=14)
        base.save_figure(fig,figures,"boxplot_actual_allocation_and_actuation");figure_count+=1
    comparison_figures(figures,rows,scenario)
    figure_count+=2
    write_report(folder,output,rows,protocol,evaluation,aggregate,failures)
    print(json.dumps(dict(scenario=scenario,formal_completed=15,figures=figure_count,task_failures=len(failures),all_methods_meet_task_requirements=evaluation["all_five_methods_meet_task_requirements"]),ensure_ascii=False))


if __name__=="__main__":
    main()
