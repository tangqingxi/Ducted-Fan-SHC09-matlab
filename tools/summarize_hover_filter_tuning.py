"""按预先写定的滚转残差中性选型；只输出调参证据，不启动正式批。"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

METHODS = ["PCA_PREDICTIVE", "DCA"]
ORDER = [(8, 8), (10, 10), (12, 12), (15, 15), (12, 8), (8, 12)]
KEYS = ["residual_roll_ratio", "residual_vector_ratio", "horizontal_rmse_m", "roll_rmse_deg", "yaw_rate_rmse_deg_s",
        "true_horizontal_rmse_m", "true_roll_rmse_deg", "true_yaw_rate_rmse_deg_s", "command_hf_rms_deg",
        "actual_servo_rate_rms_deg_s", "actual_servo_travel_deg", "pwm_step_rms_deg", "pwm_step_total_deg"]


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


def stats(values):
    values = np.array(values, dtype=float)
    values = values[np.isfinite(values)]
    return {"n": len(values), "mean": float(values.mean()) if values.size else np.nan,
            "std": float(values.std(ddof=1)) if values.size > 1 else np.nan,
            "min": float(values.min()) if values.size else np.nan, "max": float(values.max()) if values.size else np.nan}


def group(rows, configurations, seeds):
    result = []
    for h1, h2 in configurations:
        selected = [r for r in rows if (int(r["h1_hz"]), int(r["h2_hz"])) == (h1, h2) and int(r["seed"]) in seeds]
        unique = {(r["method"], int(r["seed"])) for r in selected}
        complete = unique == {(m, s) for m in METHODS for s in seeds} and len(selected) == 2*len(seeds)
        row = {"h1_hz": h1, "h2_hz": h2, "runs": len(selected), "complete": complete}
        for key in KEYS:
            for suffix, value in stats([r[key] for r in selected]).items():
                row[key+"_"+suffix] = value
        # 先等权合并两方法，再按种子计算配置分数的波动，避免把6条当6个独立种子。
        seed_scores = [np.mean([float(r["residual_roll_ratio"]) for r in selected if int(r["seed"]) == s])
                       for s in seeds if any(int(r["seed"]) == s for r in selected)]
        row["pooled_method_seed_score_std"] = stats(seed_scores)["std"]
        for method in METHODS:
            row[method+"_residual_mean"] = stats([r["residual_roll_ratio"] for r in selected if r["method"] == method])["mean"]
        result.append(row)
    return result


def choose(candidates):
    valid = [r for r in candidates if r["complete"] and np.isfinite(r["residual_roll_ratio_mean"])]
    assert valid, "无完整且有效的候选，不能选型。"
    minimum = min(r["residual_roll_ratio_mean"] for r in valid)
    close = [r for r in valid if r["residual_roll_ratio_mean"] <= minimum+.001]
    return min(close, key=lambda r: (r["actual_servo_rate_rms_deg_s_mean"], r["pwm_step_rms_deg_mean"],
                                     r["actual_servo_travel_deg_mean"], ORDER.index((r["h1_hz"], r["h2_hz"]))))


def manifest(output, sources):
    def sha(path):
        with path.open("rb") as stream:
            return hashlib.file_digest(stream, "sha256").hexdigest()
    (output / "analysis_sources.json").write_text(json.dumps([{"path": str(p.resolve()), "sha256": sha(p)} for p in sources],
                                                              ensure_ascii=False, indent=2), encoding="utf-8")
    files = [{"path": p.relative_to(output).as_posix(), "sha256": sha(p), "bytes": p.stat().st_size}
             for p in sorted(output.rglob("*")) if p.is_file()]
    (output / "manifest.json").write_text(json.dumps({"files": files, "excludes": ["manifest.json"]}, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["select", "report"])
    parser.add_argument("--coarse", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--review", type=Path)
    parser.add_argument("--nominal", type=Path)
    args = parser.parse_args()
    coarse = args.coarse.resolve()
    assert (coarse / "completion.json").is_file()
    rows = [{"stage": "coarse", **r} for r in read(coarse / "tuning.csv")]
    coarse_summary = group(rows, ORDER, [501])
    output = args.output.resolve()
    assert not output.exists(), "不覆盖已有分析目录。"
    output.mkdir()
    write(output / "coarse_summary.csv", coarse_summary)
    if args.stage == "select":
        eligible = [r for r in coarse_summary if r["complete"]]
        first = choose(eligible)
        second = choose([r for r in eligible if r is not first])
        (output / "shortlist.json").write_text(json.dumps({"configurations": [[r["h1_hz"], r["h2_hz"]] for r in [first, second]],
            "primary": "roll_0p5Hz_residual_ratio", "methods_equal_weight": METHODS,
            "close_absolute_ratio": .001, "tracking_not_used_for_selection": True, "formal_15_runs_authorized": False}, indent=2), encoding="utf-8")
        manifest(output, [Path(__file__), coarse / "tuning.csv", coarse / "sources.json"])
        print((output / "shortlist.json").read_text(encoding="utf-8"))
        return
    assert args.review and args.nominal
    review = args.review.resolve()
    assert (review / "completion.json").is_file()
    review_rows = [{"stage": "review", **r} for r in read(review / "tuning.csv")]
    rows.extend(review_rows)
    configurations = list(dict.fromkeys((int(r["h1_hz"]), int(r["h2_hz"])) for r in review_rows))
    assert len(configurations) == 2
    finalists = group(rows, configurations, [501, 502, 503])
    winner = choose(finalists)
    write(output / "tuning.csv", rows)
    write(output / "finalist_summary.csv", finalists)
    best = (winner["h1_hz"], winner["h2_hz"])
    tuned = [r for r in rows if (int(r["h1_hz"]), int(r["h2_hz"])) == best]
    assert len(tuned) == 6
    nominal = read(args.nominal)
    baseline = {(r["method"], r["seed"]): r for r in nominal}
    deltas = []
    for row in tuned:
        original = baseline[row["method"], row["seed"]]
        for key in KEYS:
            a, b = float(row[key]), float(original[key])
            deltas.append({"method": row["method"], "seed": row["seed"], "metric": key,
                           "nominal_8_8": b, "recommended_filter": a, "difference": a-b})
    write(output / "nominal_vs_recommended.csv", deltas)
    method_rows = []
    for label, data in [("nominal_8_8", nominal), ("recommended_filter", tuned)]:
        for method in METHODS:
            for key in KEYS:
                method_rows.append({"configuration": label, "method": method, "metric": key,
                                    **stats([r[key] for r in data if r["method"] == method])})
    write(output / "method_summary.csv", method_rows)
    recommendation = {"h1_hz": best[0], "h2_hz": best[1], "mean_roll_residual_ratio": winner["residual_roll_ratio_mean"],
        "mean_vector_residual_ratio": winner["residual_vector_ratio_mean"],
        "seed_std_of_method_mean": winner["pooled_method_seed_score_std"],
        "target_below_5_percent": winner["residual_roll_ratio_mean"] < .05,
        "formal_batch_launched": False, "formal_batch_requires_user_decision": True,
        "configuration_frozen_for_formal": False, "phase_lead_used": False, "configs_tested": 6}
    (output / "recommendation.json").write_text(json.dumps(recommendation, indent=2), encoding="utf-8")
    plt.rcParams.update({"font.sans-serif": ["Microsoft YaHei", "SimHei", "DejaVu Sans"], "axes.unicode_minus": False, "pdf.fonttype": 42})
    figures = output / "figures"
    figures.mkdir()
    fig, axes = plt.subplots(1, 2, figsize=(13, 4.7), layout="constrained")
    for j, (key, title) in enumerate([("residual_roll_ratio", "滚转0.5Hz残差（主指标）"), ("residual_vector_ratio", "三轴幅值范数（并列报告）")]):
        ax = axes[j]
        for k, method in enumerate(METHODS):
            values = []
            for pair in ORDER:
                match = [r for r in rows if r["stage"] == "coarse" and r["method"] == method and (int(r["h1_hz"]), int(r["h2_hz"])) == pair]
                values.append(100*float(match[0][key]) if match else np.nan)
            ax.bar(np.arange(6)+(k-.5)*.34, values, width=.34, label=method)
        if j == 0:
            ax.axhline(5, color="black", ls="--", lw=.8, label="5%目标")
        ax.set(xticks=range(6), xticklabels=[f"{a}/{b}" for a, b in ORDER], xlabel="H1/H2 / Hz", ylabel="残差 / %", title=title)
        ax.grid(axis="y", alpha=.2)
        ax.legend(fontsize=8)
    fig.suptitle("seed501六组粗扫：两方法等权，未按PCA排名选择")
    for ext in ["png", "pdf"]:
        fig.savefig(figures / ("01_coarse_residual."+ext), dpi=180, bbox_inches="tight")
    plt.close(fig)
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), layout="constrained")
    for ax, pair in zip(axes, configurations):
        for method in METHODS:
            selected = sorted([r for r in rows if r["method"] == method and (int(r["h1_hz"]), int(r["h2_hz"])) == pair], key=lambda r: int(r["seed"]))
            ax.plot([int(r["seed"]) for r in selected], [100*float(r["residual_roll_ratio"]) for r in selected], "o-", label=method)
        ax.axhline(5, ls="--", color="black", lw=.8)
        ax.set(xticks=[501, 502, 503], xlabel="种子", ylabel="滚转0.5Hz残差 / %", title=f"H1/H2={pair[0]}/{pair[1]} Hz")
        ax.legend(fontsize=8)
        ax.grid(alpha=.2)
    fig.suptitle("两组复核：501为粗扫种子，502/503用于工程调参，不是独立确认")
    for ext in ["png", "pdf"]:
        fig.savefig(figures / ("02_finalists."+ext), dpi=180, bbox_inches="tight")
    plt.close(fig)
    lines = ["# hover_distance滤波工程调参报告", "", "本轮仅六组501粗扫与两组502/503复核；没有启动新的五方法15条正式批。所有旧标称批、旧协议、旧锁和旧结果保持原样。", "",
             f"共享参数建议：H1={best[0]}Hz、H2={best[1]}Hz；三种子、两方法等权平均滚转残差为{100*winner['residual_roll_ratio_mean']:.6g}%，三轴范数为{100*winner['residual_vector_ratio_mean']:.6g}%。5%目标{'达到' if recommendation['target_below_5_percent'] else '未达到，按停止条件不扩网格'}。这只是调参建议，未生成正式运行锁，待用户决定下一步。", "",
             "## 口径与选型规则", "", "400Hz控制点，[10,22)共4800点。r=nu_h+J^-1*M_dist，取实际平滑扰动的0.5Hz傅里叶幅值归一化；滚转分量为主，三轴范数并列。两方法等权，不看PCA排名，不用位置/滚转跟踪误差选型。残差相差≤0.1个百分点时优先实际舵速RMS，再按PWM步变、行程及固定顺序。", "",
             "## 六组粗扫（seed501）", "", "|H1/H2 Hz|预测PCA滚转残差 %|DCA滚转残差 %|等权平均 %|三轴等权 %|", "|---|---:|---:|---:|---:|"]
    for r in coarse_summary:
        lines.append(f"|{r['h1_hz']}/{r['h2_hz']}|{100*r['PCA_PREDICTIVE_residual_mean']:.6g}|{100*r['DCA_residual_mean']:.6g}|{100*r['residual_roll_ratio_mean']:.6g}|{100*r['residual_vector_ratio_mean']:.6g}|")
    lines += ["", "## 两组复核：三种子与两方法等权", "", "|H1/H2 Hz|滚转残差均值 %|种子标准差 %|三轴残差均值 %|舵速RMS °/s|PWM步变RMS °|", "|---|---:|---:|---:|---:|---:|"]
    for r in finalists:
        lines.append(f"|{r['h1_hz']}/{r['h2_hz']}|{100*r['residual_roll_ratio_mean']:.6g}|{100*r['pooled_method_seed_score_std']:.6g}|{100*r['residual_vector_ratio_mean']:.6g}|{r['actual_servo_rate_rms_deg_s_mean']:.6g}|{r['pwm_step_rms_deg_mean']:.6g}|")
    lines += ["", "## 全部逐条调参数据", "", "|阶段|H1/H2 Hz|种子|方法|滚转残差 %|三轴残差 %|位置RMS m|滚转RMS °|指令高频RMS °|舵速RMS °/s|PWM步变RMS °|", "|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|"]
    for r in rows:
        lines.append(f"|{r['stage']}|{r['h1_hz']}/{r['h2_hz']}|{r['seed']}|{r['method']}|{100*float(r['residual_roll_ratio']):.6g}|{100*float(r['residual_vector_ratio']):.6g}|"+"|".join(f"{float(r[k]):.6g}" for k in ["horizontal_rmse_m", "roll_rmse_deg", "command_hf_rms_deg", "actual_servo_rate_rms_deg_s", "pwm_step_rms_deg"])+"|")
    lines += ["", "## 标称8/8与建议配置：相同501–503", "", "逐种子对照及所有差值见nominal_vs_recommended.csv；正值表示建议配置指标更高。以下为三种子均值±样本标准差，位置/滚转仅记录，没有用于选型。", "", "|方法|配置|滚转残差 %|位置RMS m|滚转RMS °|偏航速率RMS °/s|舵速RMS °/s|行程 °|PWM步变RMS °|", "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    lookup = {(r["configuration"], r["method"], r["metric"]): r for r in method_rows}
    for method in METHODS:
        for label in ["nominal_8_8", "recommended_filter"]:
            cells = []
            for key in ["residual_roll_ratio", "horizontal_rmse_m", "roll_rmse_deg", "yaw_rate_rmse_deg_s", "actual_servo_rate_rms_deg_s", "actual_servo_travel_deg", "pwm_step_rms_deg"]:
                r = lookup[label, method, key]
                factor = 100 if key == "residual_roll_ratio" else 1
                cells.append(f"{factor*r['mean']:.6g} ± {factor*r['std']:.6g}")
            lines.append("|"+method+"|"+label+"|"+"|".join(cells)+"|")
    lines += ["", "## 解释边界与下一步", "", "这是工程调参配置下的比较，不是泛化确认。三轴残差包含其他非线性/耦合补偿项，不能把全部残差都称作滤波误差。指令>=20Hz高频RMS是活动代理，不是已分离的传感器噪声；PWM步变不等于能耗或机械损耗。", "",
              "只覆盖plan.controller的indi_output_filter_hz和indi_input_filter_hz；没有改控制器增益、对象、参考、干扰、分配器、传感器或估计器。没有加入角加速度相位超前，也不自动评估或试飞新的超前结构。", "",
              "两方法在调参期间的跟踪差异只作记录。滚转误差反馈仍位于nu_c，PCA缩放该跟踪项是源码中的结构事实；若后续共享滤波正式对比仍有差异，应结合该结构、约束几何和代价分析，不能仅凭本轮调参断定唯一因果。", "",
              "原标称批的12 completed/3个DA_NS旧单位审计失败保留原样。本轮未运行DA_NS，也未运行新的五方法正式批，因而不伪造新的15条结果或DA_NS审计。", "",
              "数据：tuning.csv全部20条、coarse_summary.csv、finalist_summary.csv、nominal_vs_recommended.csv、method_summary.csv、recommendation.json。每阶段sources.json和source_lock.json在首条运行前写定，输入记录包含plan；旧数值输入签名不变。", ""]
    (output / "report.md").write_text("\n".join(lines), encoding="utf-8")
    manifest(output, [Path(__file__), coarse / "tuning.csv", review / "tuning.csv", args.nominal])
    print(json.dumps(recommendation, ensure_ascii=False))


if __name__ == "__main__":
    main()
