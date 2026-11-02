"""只读正式批和独立审计，生成五方法三种子的两域指标、成对分析和图表。"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

METHODS = ["DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE"]
SEEDS = [501, 502, 503]
PAIRS = [("PCA_PREDICTIVE", x) for x in METHODS[:-1]] + [("PCA_STATIC", x) for x in METHODS[:2]]
COLORS = dict(zip(METHODS, ["#2874ad", "#e59026", "#199c82", "#8860ad", "#d54b50"]))
PRIMARY = ["horizontal_rmse_m", "horizontal_peak_m", "roll_rmse_deg", "roll_peak_deg", "yaw_rate_rmse_deg_s"]


def read(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write(path, rows):
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def stats(values):
    values = np.asarray(values, dtype=float)
    values = values[np.isfinite(values)]
    return {"n": len(values), "mean": float(values.mean()) if len(values) else np.nan,
            "seed_std": float(values.std(ddof=1)) if len(values) > 1 else np.nan,
            "minimum": float(values.min()) if len(values) else np.nan,
            "maximum": float(values.max()) if len(values) else np.nan}


def save(fig, folder, name):
    for ext in ["png", "pdf"]:
        fig.savefig(folder / f"{name}.{ext}", dpi=190, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def time_axis(ax):
    ax.axvspan(10, 22, color="#dcaa62", alpha=.14)
    ax.axvspan(22, 32, color="#389775", alpha=.09)
    ax.set(xlim=(0, 40), xlabel="时间 / s")
    ax.grid(alpha=.18)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    folder = args.folder.resolve()
    output = args.output_dir.resolve() if args.output_dir else folder / "analysis"
    assert not output.exists(), "不覆盖已有后处理目录。"
    output.mkdir()
    figures = output / "figures"
    figures.mkdir()
    rows = read(folder / "audit/audited_per_run_metrics.csv")
    assert len({(r["method"], int(r["seed"])) for r in rows}) == len(rows)
    by_run = {(r["method"], int(r["seed"])): r for r in rows}
    assert all((m, s) in by_run for m in METHODS for s in SEEDS), "缺少条目，不输出完整五方法结论。"
    write(output / "per_run_metrics.csv", rows)
    # 所有数值指标均保留逐种子统计，缺失恢复时间不填零。
    numeric = []
    for key in rows[0]:
        if key in ["method", "seed", "original_driver_status"]:
            continue
        try:
            [float(r[key]) for r in rows]
            numeric.append(key)
        except ValueError:
            pass
    aggregate = []
    for method in METHODS:
        for key in numeric:
            aggregate.append({"method": method, "metric": key, **stats([float(by_run[method, s][key]) for s in SEEDS])})
    write(output / "aggregate_metrics.csv", aggregate)
    lookup = {(r["method"], r["metric"]): r for r in aggregate}
    paired = []
    for candidate, baseline in PAIRS:
        for seed in SEEDS:
            for key in numeric:
                a, b = float(by_run[candidate, seed][key]), float(by_run[baseline, seed][key])
                paired.append({"candidate": candidate, "baseline": baseline, "seed": seed, "metric": key,
                               "candidate_value": a, "baseline_value": b, "difference": a-b,
                               "relative_percent": 100*(a/b-1) if np.isfinite(b) and b != 0 else np.nan})
    write(output / "paired_per_seed.csv", paired)
    pair_stats = []
    for candidate, baseline in PAIRS:
        for key in numeric:
            selected = [r for r in paired if (r["candidate"], r["baseline"], r["metric"]) == (candidate, baseline, key)]
            pair_stats.append({"candidate": candidate, "baseline": baseline, "metric": key,
                               **stats([r["difference"] for r in selected]),
                               "negative_difference_seeds": sum(r["difference"] < 0 for r in selected),
                               "positive_difference_seeds": sum(r["difference"] > 0 for r in selected),
                               "relative_percent_mean": stats([r["relative_percent"] for r in selected])["mean"]})
    write(output / "paired_summary.csv", pair_stats)
    plt.rcParams.update({"font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"],
                         "axes.unicode_minus": False, "pdf.fonttype": 42, "font.size": 9})
    tracks = {(m, s): read(folder / "visualization/tracks" / f"{m}_s{s}.csv") for m in METHODS for s in SEEDS}

    def col(track, name):
        return np.array([float(r[name]) for r in track])

    # 水平轨迹分开显示估计和真值，三种子全部展示，不挑选最好种子。
    fig, axes = plt.subplots(3, 2, figsize=(12, 12), layout="constrained")
    for row_index, seed in enumerate(SEEDS):
        for j, (prefix, label) in enumerate([("estimated", "估计反馈"), ("true", "真值评估")]):
            ax = axes[row_index, j]
            for method in METHODS:
                track = tracks[method, seed]
                t = col(track, "time_s")
                x, y = col(track, prefix+"_position_1"), col(track, prefix+"_position_2")
                main_q, recovery = (t >= 10) & (t < 22), (t >= 22) & (t < 32)
                ax.plot(x[main_q], y[main_q], color=COLORS[method], lw=.95, label=method)
                ax.plot(x[recovery], y[recovery], color=COLORS[method], lw=.75, ls="--", alpha=.7)
            ax.scatter([0], [0], marker="+", color="black", s=80, label="悬停参考")
            ax.set(title=f"seed{seed} · {label}", xlabel="北向 / m", ylabel="东向 / m", aspect="equal")
            ax.grid(alpha=.18)
            if row_index == 0:
                ax.legend(fontsize=7, ncol=2)
    fig.suptitle("85%滚转权限深度饱和：水平轨迹\n实线10–22 s，虚线22–32 s；不做真值平移或相位对齐")
    save(fig, figures, "01_horizontal_tracks")
    for field, title, unit, reference in [("euler_1", "滚转偏差", "°", False), ("rate_3", "偏航机体角速度", "°/s", True)]:
        fig, axes = plt.subplots(3, 2, figsize=(15, 10), sharex=True, layout="constrained")
        for i, seed in enumerate(SEEDS):
            for j, (prefix, label) in enumerate([("estimated", "估计反馈"), ("true", "真值评估")]):
                ax = axes[i, j]
                for method in METHODS:
                    track = tracks[method, seed]
                    key = "measured_rate_3" if reference and prefix == "estimated" else prefix+"_"+field
                    ax.plot(col(track, "time_s"), col(track, key), color=COLORS[method], lw=.75, label=method)
                if reference:
                    ax.plot(col(track, "time_s"), col(track, "reference_rate_3"), "k--", lw=.7, label="规划参考")
                else:
                    ax.axhline(0, color="black", lw=.6, ls="--")
                time_axis(ax)
                ax.set(title=f"seed{seed} · {label}", ylabel=unit)
                if i == 0:
                    ax.legend(fontsize=7, ncol=3)
        fig.suptitle(title+" · 显示100 Hz，评分800 Hz；橙色主窗，绿色恢复窗")
        save(fig, figures, "02_roll" if not reference else "03_yaw_rate")
    fig, axes = plt.subplots(3, 2, figsize=(15, 9), sharex=True, sharey=True, layout="constrained")
    for i, seed in enumerate(SEEDS):
        for j, method in enumerate(METHODS[3:]):
            ax = axes[i, j]
            track = read(folder / "visualization/allocation_tracks" / f"{method}_s{seed}.csv")
            t, values, mode = col(track, "time_s"), col(track, "lambda"), col(track, "mode")
            ax.plot(t, np.where(mode == 0, values, np.nan), lw=.6, color=COLORS[method], label="mode0正常λ")
            for value, marker, label in [(1, "x", "mode1高优先级回退"), (2, "v", "mode2工程回退")]:
                q = mode == value
                ax.scatter(t[q], np.full(q.sum(), -.045 if value == 1 else -.095), s=8, marker=marker, label=label)
            m = by_run[method, seed]
            time_axis(ax)
            ax.set(ylim=(-.14, 1.04), ylabel="λ", title=f"{method} s{seed} · 主窗占空比{float(m['lambda_scaled_duty']):.1%} · min {float(m['normal_lambda_min']):.4g}")
            if i == 0:
                ax.legend(fontsize=7)
    fig.suptitle("400 Hz分配判定：正常λ与回退分列；回退标记的负坐标仅用于排版，不是λ数值")
    save(fig, figures, "04_lambda")
    fig, axes = plt.subplots(2, 3, figsize=(14, 8), layout="constrained")
    for i, prefix in enumerate(["", "true_"]):
        for j, (key, title, unit) in enumerate([("horizontal_rmse_m", "水平位置RMS", "m"), ("roll_rmse_deg", "滚转RMS", "°"), ("yaw_rate_rmse_deg_s", "偏航速率RMS", "°/s")]):
            ax = axes[i, j]
            for k, method in enumerate(METHODS):
                values = [float(by_run[method, seed][prefix+key]) for seed in SEEDS]
                ax.bar(k, np.mean(values), color=COLORS[method], alpha=.75)
                ax.errorbar(k, np.mean(values), yerr=np.std(values, ddof=1), color="black", capsize=3)
                ax.scatter(np.full(3, k)+np.array([-.13, 0, .13]), values, s=12, color="black", zorder=3)
            ax.set(xticks=range(5), xticklabels=METHODS, ylabel=unit, title=("估计 · " if not prefix else "真值 · ")+title)
            ax.tick_params(axis="x", labelrotation=25, labelsize=7)
            ax.grid(axis="y", alpha=.15)
    fig.suptitle("10–22 s主指标与偏航代价 · 均值、三种子点和样本标准差；不代表置信区间")
    save(fig, figures, "05_tracking_summary")
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5), layout="constrained")
    for ax, key, unit in zip(axes, ["actual_servo_rate_rms_deg_s", "actual_servo_travel_deg", "pwm_step_rms_deg"], ["舵速RMS / °/s", "六舵面总行程 / °", "PWM步变RMS / °"]):
        means = [lookup[m, key]["mean"] for m in METHODS]
        std = [lookup[m, key]["seed_std"] for m in METHODS]
        ax.bar(range(5), means, color=[COLORS[m] for m in METHODS], alpha=.8)
        ax.errorbar(range(5), means, yerr=std, fmt="none", color="black", capsize=3)
        ax.set(xticks=range(5), xticklabels=METHODS, ylabel=unit)
        ax.tick_params(axis="x", labelrotation=25, labelsize=7)
        ax.grid(axis="y", alpha=.15)
    fig.suptitle("10–22 s执行器活动 · PWM步变不等同于机械损耗或能耗")
    save(fig, figures, "06_actuator_activity")

    def f(value):
        return f"{value:.6g}" if np.isfinite(value) else "未达到/不适用"

    def ms(method, key):
        st = lookup[method, key]
        if st["n"] == 0:
            return "未达到/不适用"
        return f"{f(st['mean'])} ± {f(st['seed_std'])}"

    checks = json.loads((folder / "audit/independent_checks.json").read_text(encoding="utf-8-sig"))
    lock = json.loads((folder / "formal_lock.json").read_text(encoding="utf-8-sig"))
    lines = ["# hover_distance正式批：85%滚转权限深度饱和压力工况", "",
             f"15条各运行一次，完整40秒日志{checks['full_40s_logs']}/15；原驱动completed={checks['original_driver_completed']}、failed={checks['original_driver_failed']}。独立审计按原有配置容差核验有效性，具体见下述审计说明。未调参、未重跑，原失败记录保留。", "",
             "## 工况、来源与评价口径", "",
             "滚转权限1.213133995 N·m，85%幅值1.031163896 N·m，0.5 Hz；10 s加载、22 s开始卸载，0.5 s平滑，22.5 s完全卸载。偏航±280°/s、0.75 Hz，0–2/38–40 s平滑。定点NED[0,0,-10]m，总40 s，M2b、舵机τ失配、ECL、控制器、传感器与时序沿用预检。主窗[10,22)，恢复窗[22,32)。λ_min仅报告，无门槛。", "",
             "五方法共享同一需求公式、控制参数、参考、初态和同种子噪声，以及名义B、舵角估计规则、限幅和时钟。闭环作用导致ν_h/ν_c及舵角估计分叉，不是参考不一致，也不强制重放另一方法的状态。PCA在mode0保trim、缩tracking；mode1/2单列，不能声称回退阶段仍严格保trim。501是已用开发种子，不是独立留出确认。", "",
             "位置为飞前绑定的相对任务坐标。真值单独评分，不用作反馈，不做事后平移。滚转误差相对规划0°，偏航速率相对规划机体z轴速率，不混用内环omega_sp。统计使用800Hz状态；缩放/回退使用400Hz更新点；图中状态展示100Hz、λ展示400Hz。", "",
             "引擎：`"+lock["sources"]["parent"]["engine"]+"`。SHA详见sources.json及formal_lock.json；每种子输入在inputs/固定，五方法签名一致。", ""]
    for domain, prefix in [("估计反馈域", ""), ("真值评估域", "true_")]:
        lines += ["## "+domain+"：三种子均值 ± 样本标准差", "", "|方法|水平RMS m|水平峰值 m|滚转RMS °|滚转峰值 °|偏航速率RMS °/s|", "|---|---:|---:|---:|---:|---:|"]
        for method in METHODS:
            lines.append("|"+method+"|"+"|".join(ms(method, prefix+k) for k in PRIMARY)+"|")
    lines += ["", "## 逐种子主表", "", "|方法|种子|估计水平RMS m|估计滚转RMS °|估计偏航速率RMS °/s|真值水平RMS m|真值滚转RMS °|真值偏航速率RMS °/s|", "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for method in METHODS:
        for seed in SEEDS:
            r = by_run[method, seed]
            keys = ["horizontal_rmse_m", "roll_rmse_deg", "yaw_rate_rmse_deg_s", "true_horizontal_rmse_m", "true_roll_rmse_deg", "true_yaw_rate_rmse_deg_s"]
            lines.append(f"|{method}|{seed}|"+"|".join(f(float(r[k])) for k in keys)+"|")
    lines += ["", "## 预注册成对比较与消融", "", "差值=前者−后者；误差负值表示前者更低。逐种子差值、均值、样本标准差与范围全部保留；偏航代价与位置/滚转同时报告。没有显著性结论。", "", "|比较|域|水平RMS差 m|滚转RMS差 °|偏航速率RMS差 °/s|", "|---|---|---:|---:|---:|"]
    ps = {(r["candidate"], r["baseline"], r["metric"]): r for r in pair_stats}
    for a, b in PAIRS:
        for label, prefix in [("估计", ""), ("真值", "true_")]:
            cells = []
            for key in ["horizontal_rmse_m", "roll_rmse_deg", "yaw_rate_rmse_deg_s"]:
                s = ps[a, b, prefix+key]
                cells.append(f"{f(s['mean'])} ± {f(s['seed_std'])} [{f(s['minimum'])}, {f(s['maximum'])}]")
            lines.append(f"|{a} − {b}|{label}|"+"|".join(cells)+"|")
    lines += ["", "预测贡献以PCA_PREDICTIVE−PCA_STATIC评价；优先级贡献以PCA_STATIC−DA_NS/WLS评价。表中正负方向由数据决定，不能把预测或优先级贡献预设为正。DCA排序不预设；其动态可达集合与约束方向不同，不能据单一偏航指标宣布总排名。", "",
              "## 缩放与回退：逐种子", "", "λ仅针对mode0；mode1高优先级回退和mode2工程回退不伪装为正常λ。表中min和时刻均限于主窗；全40秒min另见per_run_metrics.csv。", "", "|方法|种子|λ<1占空比|累计/最长 s|正常λ_min|出现时刻 s|mode1占比/时长 s|mode2时长 s|PWM缩放事件|", "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for method in METHODS[3:]:
        for seed in SEEDS:
            r = by_run[method, seed]
            lines.append(f"|{method}|{seed}|{float(r['lambda_scaled_duty']):.3%}|{float(r['lambda_scaled_duration_s']):.5g} / {float(r['lambda_longest_episode_s']):.5g}|{float(r['normal_lambda_min']):.7g}|{float(r['normal_lambda_min_time_s']):.5g}|{float(r['mode1_duty']):.3%} / {float(r['mode1_duration_s']):.5g}|{float(r['mode2_duration_s']):.5g}|{r['pwm_scaled_events']}|")
    lines += ["", "DA_NS/WLS/DCA无同义的PCA λ，相关字段为不适用；其mode含义不能直接解释为PCA优先级回退。", "", "## 执行器代价：主窗均值 ± 种子标准差", "", "|方法|实际舵速RMS °/s|六舵面总行程 °|PWM步变RMS °|PWM步变总量 °|", "|---|---:|---:|---:|---:|"]
    for method in METHODS:
        lines.append("|"+method+"|"+"|".join(ms(method, k) for k in ["actual_servo_rate_rms_deg_s", "actual_servo_travel_deg", "pwm_step_rms_deg", "pwm_step_total_deg"])+"|")
    lines += ["", "PWM活动不等于机械损耗或能耗。实际舵速由800Hz真实舵角差分；总行程为六舵面绝对变化之和；PWM步变按333Hz真实下发事件计算。", "", "## 恢复：22–32 s", "", "进入时间相对22 s；同时满足水平距离≤0.2m、水平速度≤0.2m/s、|滚转|≤2°持续0.5s，确认时间=进入时间+0.5s。22–22.5s仍含平滑卸载，恢复时钟按预注册从22s开始。未达到保留缺失，不能填0或强制截断为10s。", "", "|方法|域|达到次数/3|进入时间 s|恢复窗水平峰值 m|位置反向超调 m|滚转反向超调 °|", "|---|---|---:|---:|---:|---:|---:|"]
    for method in METHODS:
        for label, prefix in [("估计", ""), ("真值", "true_")]:
            n = lookup[method, prefix+"recovery_entry_s"]["n"]
            lines.append(f"|{method}|{label}|{n}/3|"+"|".join(ms(method, prefix+k) for k in ["recovery_entry_s", "recovery_horizontal_peak_m", "recovery_opposite_position_overshoot_m", "recovery_opposite_roll_overshoot_deg"])+"|")
    lines += ["", "## 有效性、旧审计单位问题与解释边界", "",
              f"完整日志{checks['full_40s_logs']}/15；气动越界总数={sum(int(float(r['aero_domain_failures'])) for r in rows)}；独立审计有效且未发散={checks['valid_under_original_configured_tolerance']}。控制公式、同种子输入、PWM映射与真值隔离均核验；重建trim最大误差{checks['maximum_trim_error']:.4g}，PCA几何λ最大误差{checks['maximum_geometry_lambda_error']:.4g}，等式残差{checks['maximum_equality_error']:.4g}。501预测PCA与旧预检最大状态差{checks['seed501_precheck_max_state_difference']:.4g}。", "",
              f"原hd_check_log命令边界检查使用1e-7度，而分配器运行前即固定constraint_tolerance=1e-7弧度，造成{checks['legacy_command_tolerance_unit_mismatches']}条容差内命令越界被旧检查拒绝。未修改旧检查、原协议、原锁、原status或failures；独立审计另用原配置的弧度容差检查命令，并保持真实舵角、真实舵速和其余契约检查。详情见audit/audited_per_run_metrics.csv的command_excess_rad和legacy_log_check_passed。原驱动失败不能隐去或改写为原检查通过。", "",
              "DA_NS与WLS的闭环最大状态差及DA_NS的伪逆解触界比例见audit/DA_NS_WLS_comparison.csv。可行且未受约束时两者趋于相同最小范数解；本实现WLS含有限正则（gamma=1e8），不应无条件称为严格数学恒等。深度饱和时DA_NS沿总需求缩放，WLS按加权残差折中，数值和排序可以不同。", "",
              "三种子仅描述本批均值和波动；不宣称统计显著、实机优势或全局最优。估计域改善不能自动解释为绝对真值位置精度改善；传感器/ECL未实机标定。", "",
              "## 图表和复现", "", "图1水平轨迹，图2滚转，图3偏航角速度，图4λ及回退，图5主指标与偏航代价，图6执行器活动；每图PNG/PDF，三种子全部展示。表格保留逐种子、方法聚合、逐种子成对差值和成对聚合。", "",
              "运行前固定formal_protocol.json、formal_lock.json、sources.json和inputs/；MAT为本地原始证据，不加入Git。先用export_hover_distance_formal从MAT导出全部15条至新visualization目录；再用python tools/plot_hover_distance_formal.py <本批目录> --output-dir <全新目录>绘图，不覆盖。manifest.json覆盖本后处理目录，source_evidence.json记录输入来源。首次绘图因原驱动在旧审计失败后未导出DA_NS时序而停止，原analysis目录保留，补充只读导出后在analysis_v2交付，未重飞或改参数。", ""]
    (output / "report.md").write_text("\n".join(lines), encoding="utf-8")
    evidence = []
    for path in [folder / "status.csv", folder / "summary.csv", folder / "formal_lock.json", folder / "sources.json", folder / "audit/independent_checks.json", folder / "audit/audited_per_run_metrics.csv", Path(__file__).resolve(), Path(__file__).resolve().parents[1] / "tests/audit_hover_distance_formal.m", Path(__file__).resolve().parents[1] / "tools/export_hover_distance_formal.m"]:
        evidence.append({"path": str(path), "sha256": sha(path)})
    (output / "source_evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    files = [{"path": p.relative_to(output).as_posix(), "bytes": p.stat().st_size, "sha256": sha(p)} for p in sorted(output.rglob("*")) if p.is_file()]
    (output / "manifest.json").write_text(json.dumps({"files": files, "excludes": ["manifest.json"]}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "runs": len(rows), "paired_rows": len(paired), "figures": 6}, ensure_ascii=False))


if __name__ == "__main__":
    main()
