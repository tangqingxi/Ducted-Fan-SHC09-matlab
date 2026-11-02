"""打包完整八字研究证据；原始MAT保留本地结果目录，不改写原数据。"""
import csv
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import platform

from f8_delivery_audit import read_json, sha256, snapshot, verify_sources, verify_bundle, write_json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
work = root / "results/f8_work_20261101"
pipeline = json.loads((work / "pipeline_complete.json").read_text(encoding="utf-8-sig"))
out = root / "examples/f8_comparison_20261101"
assert not out.exists(), "不覆盖既有证据"
assert subprocess.check_output(["git", "branch", "--show-current"], cwd=root, text=True).strip() == "f8-research"
main_before = subprocess.check_output(["git", "rev-parse", "main"], cwd=root, text=True).strip()
datasets_checked, source_checks = verify_sources(root, pipeline)
source_folders = [Path(pipeline[k]) for k in ["base_output", "pressure_output", "confirmation_output", "superseded_partial_output"]] + [work]
before = snapshot(root, source_folders)
# 所有前置来源检查通过后才创建临时交付目录；原始实验目录始终只读。
final_out = out
staging = Path(tempfile.mkdtemp(prefix="f8_delivery_build_", dir=root / "results"))
out = staging / "bundle"
out.mkdir()
confirmation_source = datasets_checked[-1][1]
subprocess.run([sys.executable, str(root / "tools/plot_f8_comparison.py"), str(confirmation_source),
                "--output-dir", str(out / "F8PR-Y60-F075")], cwd=root, check=True)


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


source_copies = []


def copy_file(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    source_copies.append(dict(source=source.relative_to(root).as_posix(), artifact=target.relative_to(out).as_posix(), source_sha256=sha256(source)))


base = Path(pipeline["base_output"])
datasets = [("F8-R", base / "F8-R"), ("F8-D", base / "F8-D")]
if pipeline["pressure_confirmation_ran"]:
    confirmation = Path(pipeline["confirmation_output"])
    candidates = [p for p in confirmation.iterdir() if p.is_dir() and (p / "task_metrics.csv").is_file()]
    assert len(candidates) == 1
    datasets.append((candidates[0].name, candidates[0]))

files = ["status.csv", "task_metrics.csv", "state_metrics.csv", "protocol.json", "provenance.csv", "task_evaluation.json",
         "aggregate_metrics.csv", "paired_pca_deltas.csv", "tracking_phase.csv", "independent_checks.json", "independent_run_checks.csv",
         "priority_activation.csv", "priority_events.csv", "priority_trace.csv", "allocation_truth_diagnostics.csv", "independent_priority_lp.csv",
         "allocation_diagnostics_checks.json", "task_requirement_failures.csv", "report.md"]
raw_logs = []
summary = []
for name, source in datasets:
    check = load_json(source / "independent_checks.json")
    assert check["formal_logs_verified"] == 15
    target = out / name
    target.mkdir(exist_ok=True)
    generated = name == "F8PR-Y60-F075"
    if not generated:
        assert len(list((source / "figures").glob("*.png"))) >= 7
    required = [f for f in files if f != "task_requirement_failures.csv" and not (generated and f in ["aggregate_metrics.csv", "paired_pca_deltas.csv", "tracking_phase.csv", "report.md"])]
    for file in required:
        assert (source / file).is_file(), str(source / file)
    for file in files:
        if (source / file).is_file():
            copy_file(source / file, out / name / file)
    if not generated:
        shutil.copytree(source / "figures", out / name / "figures")
    raw_logs.append(dict(dataset=name, repository_relative_directory=source.relative_to(root).as_posix(),
                         verified_logs=check["verified_log_files"]))
    evaluation = load_json(source / "task_evaluation.json")
    rows = read_csv(source / "task_metrics.csv")
    passed = sum(r["run_task_passed"] in ("1", "true", "True") for r in rows)
    summary.append((name, passed, evaluation))

if pipeline["pressure_development_ran"]:
    source = Path(pipeline["pressure_output"])
    for file in ["status.csv", "task_metrics.csv", "selection.json", "screen_candidates.csv", "frozen_protocol.json", "base_protocol.json"]:
        copy_file(source / file, out / "development_screen" / file)
    for file in ["development_priority_summary.csv", "development_priority_checks.json", "development_priority_lambda_beta.png", "development_priority_lambda_beta.pdf"]:
        if (source / file).is_file():
            copy_file(source / file, out / "development_screen" / file)
    development_check=load_json(source / "development_priority_checks.json")
    raw_logs.append(dict(dataset="development_screen",repository_relative_directory=source.relative_to(root).as_posix(),
                         verified_logs=development_check["verified_log_files"]))
    for child in source.iterdir():
        if child.is_dir() and (child / "task_metrics.csv").is_file():
            for file in ["task_metrics.csv", "status.csv", "protocol.json", "provenance.csv", "task_evaluation.json"]:
                copy_file(child / file, out / "development_screen" / child.name / file)
            if (child / "failures").is_dir():
                shutil.copytree(child / "failures",out / "development_screen" / child.name / "failures")

for file in ["pipeline_complete.json", "numerical_sources_before.json", "numerical_sources_before_pressure_v2.json",
             "numerical_sources_before_confirmation.json", "development_failure_guard_correction.json",
             "F8D_DANS_s101_outer_diagnosis.json", "F8D_DANS_s101_outer_diagnosis.csv", "F8R_DANS_s101_outer_diagnosis.json", "F8R_DANS_s101_outer_diagnosis.csv"]:
    if (work / file).is_file():
        copy_file(work / file, out / "audit" / file)
copy_file(base / "frozen_protocol.json", out / "audit/base_protocol.json")
copy_file(root / "configs/f8_pressure_protocol_v2.json", out / "audit/pressure_protocol_v2.json")

lines = ["# 平滑八字：五方法比较与有限偏航筛选", "", "> MATLAB仿真研究。图中的真实量指仿真对象真值，不是实飞测量；三种子用于描述，不作显著性声明。", "",
         "控制条件：M2b/lite、GNSS速度辅助、平移及名义几何前馈；反馈增益与五算法保持共同配置。对象舵机24–40ms、估计统一30ms为未实测假设。", "",
         "## 完整性与任务要求", "", "|场景|完整轨迹|通过全部任务要求|优先级激励与名义几何条件|", "|---|---:|---:|---|"]
for name, passed, evaluation in summary:
    lines.append(f"|[{name}]({name}/report.md)|15/15|{passed}/15|{evaluation['priority_excitation_and_nominal_geometry_requirements_met']}|")
lines += ["", "任务通过按每条轨迹判断；完整仿真不等于全部任务通过。F8-D的高度未通过记录完整保留，没有把悬停5°/10%门禁套到八字，也没有在结果出来后放宽F8门槛。", "",
          "## 方法表现", "", "以下为每个方法三种子的均值；实际舵速与总行程来自主窗对象舵角，PWM步变为全程命令指标。", "",
          "|场景|方法|水平位置RMS m|高度RMS m|航向RMS °|主窗真实舵速RMS °/s|全程PWM步变RMS °|", "|---|---|---:|---:|---:|---:|---:|"]
for name, source in datasets:
    rows = read_csv(source / "task_metrics.csv")
    physical = [r for r in read_csv(source / "allocation_truth_diagnostics.csv") if r["window"] == "task"]
    for method in ["DA_NS", "WLS", "DCA", "PCA_STATIC", "PCA_PREDICTIVE"]:
        selected = [r for r in rows if r["method"] == method]
        mean = lambda key: sum(float(r[key]) for r in selected)/3
        rate = sum(float(r["actual_servo_rate_rmse_deg_s"]) for r in physical if r["method"] == method)/3
        lines.append(f"|{name}|{method}|{mean('horizontal_position_rmse_m'):.7g}|{mean('altitude_rmse_m'):.7g}|{mean('yaw_rmse_deg'):.7g}|{rate:.7g}|{mean('command_step_rms_deg'):.7g}|")
lines += ["", "分配器的闭环需求由各次估计和内环产生，不能把不同方法各自的力矩残差当成共同外部力矩任务。共同几何轨迹误差是主要效果指标；真实舵机运动、PWM活动及预测误差分开呈现。", "",
          "## 预先写定与自适应部分", "", "[F8-v1协议](../../docs/reference/f8_protocol.md)先写定，再运行两个场景五方法×101–103共30条。F8-R合格但缺少优先级激励；F8-D的公共高度瓶颈由离线力分解另行记录。", "",
          "[F8-P-v2协议](../../docs/reference/f8_pressure_protocol_v2.md)公开说明自适应设计：选择合格的F8-R位置基线、加强偏航，实际运动代价与PWM代价分开；原未执行的v1压力预案保留。没有修改控制器、物理、五算法或原F8任务门槛。", ""]
if pipeline["pressure_development_ran"]:
    selected = load_json(Path(pipeline["pressure_output"]) / "selection.json")
    status=read_csv(Path(pipeline["pressure_output"]) / "status.csv")
    completed=sum(r["status"]=="completed" for r in status);failed=sum(r["status"]=="failed" for r in status)
    lines += [f"开发阶段固定种子9002、三个候选×WLS/静态PCA/预测PCA共9次尝试：{completed}次完成，{failed}次失败；[完整状态](development_screen/status.csv)、[完成轨迹指标](development_screen/task_metrics.csv)、失败JSON与[选择记录](development_screen/selection.json)均保留。失败候选不具备选择资格，不以开发点冒充独立确认。", "",
              f"开发选择：has_promising_candidate={selected['has_promising_candidate']}，selected_scenario={selected['selected_scenario'] or '无'}。", ""]
    if pipeline["pressure_confirmation_ran"]:
        lines += ["所选单一候选用五方法×未用于开发选择的201–203确认，共15条。全部种子、方法和未通过点均呈现，不按确认结果改选场景。", ""]
    else:
        lines += ["没有候选达到先验收益与代价条件，因此未进行独立确认，没有扩大搜索或伪造最好组。", ""]
lines += ["优先级激励与方向可行性另外判定；没有持续缩放时不宣称受限优先级保护。小样本差异、当前固定M2b倍率及未实测动态假设不能证明实机或全场景优势。", "",
          "## 证据与复现", "", "每个正式场景目录含十二状态箱线图、共同目标/真值/估计跟踪、λ及回退事件、同种子差值、独立日志核验与LP抽查。所有方法共用每种子的预生成输入，未作相位对齐评分。", "",
          "[公共推力控制诊断](audit/F8D_DANS_s101_outer_diagnosis.json) · [基础冻结协议](audit/base_protocol.json) · [压力冻结协议](audit/pressure_protocol_v2.json) · [运行汇总](audit/pipeline_complete.json)", "",
          "大体积原始MAT留在本地results，源目录与逐文件SHA见artifact_manifest.json。源码、配置和输入摘要保留；本轮不提交、不打tag、不push。旧14/14、平台6/6及6组冻结基线通过情况沿用既有验证记录，本次未重新运行MATLAB测试。LitePhysicalBias仍保留原0.05°/s已知预期失败，不宣称本轮修复。", ""]
(out / "README.md").write_text("\n".join(lines), encoding="utf-8")
# 可复现的后处理脚本随包保存；大体积原始日志和轨迹以来源哈希定位。
repro = out / "reproducibility"
for file in ["plot_f8_comparison.py", "plot_figure8_lite.py", "package_f8_results.py", "f8_delivery_audit.py", "requirements-f8-delivery.txt"]:
    copy_file(root / "tools" / file, repro / "tools" / file)
copy_file(root / "configs/f8_protocol_v1.json", repro / "configs/f8_protocol_v1.json")
copy_file(root / "configs/f8_pressure_protocol_v2.json", repro / "configs/f8_pressure_protocol_v2.json")
# 历史驱动只作档案，文件扩展名改为文本，避免交付包内误启动仿真。
copy_file(work / "finish_f8_confirmation_rerun.m", repro / "archive/finish_f8_confirmation_rerun.m.txt")
partial = Path(pipeline["superseded_partial_output"]) / "F8PR-Y60-F075"
for file in ["status.csv", "task_metrics.csv", "protocol.json", "provenance.csv", "state_metrics.csv"]:
    copy_file(partial / file, out / "partial_batch" / file)
write_json(out / "audit/source_files_before.json", before)
after = snapshot(root, source_folders)
assert before == after, "冻结结果目录发生变化"
assert main_before == subprocess.check_output(["git", "rev-parse", "main"], cwd=root, text=True).strip()
write_json(out / "audit/delivery_checks.json", dict(**source_checks, original_result_files_unchanged=len(before),
           main_unchanged=True, frozen_results_written=False, all_source_snapshot_hashes_match=True))
source_files = {}
for directory in ["platform", "allocators", "effectiveness", "models", "drivers", "lib", "configs", "modules", "compat", "experiments", "analysis"]:
    for path in sorted((root / directory).rglob("*")):
        if path.is_file() and path.suffix in (".m", ".json"):
            source_files[path.relative_to(root).as_posix()] = sha256(path)
for file in ["duct_raw.mat", "wing_raw.mat"]:
    path = root / "models/shc09/reference" / file
    source_files[path.relative_to(root).as_posix()] = sha256(path)
write_json(repro / "numerical_source_sha256.json", source_files)
status_text = subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True)
(repro / "git_status_at_packaging.txt").write_text(status_text, encoding="utf-8")
patch = subprocess.check_output(["git", "diff", "HEAD", "--", "tools/plot_f8_comparison.py"], cwd=root)
(repro / "plotting_changes.patch").write_bytes(patch)
readme = (out / "README.md").read_text(encoding="utf-8")
readme += """
## 本次交付与复现边界

确认批新生成13组PNG/PDF：五方法各自十二状态、十二状态误差箱线、跟踪代价、五方法轨迹、误差时序、λ、真实分配/舵机、关键指标配对、航向/舵机活动权衡。基础F8-R/F8-D各8组历史图表原样保留。

主窗为[6,50]秒；舵速和总行程取完整800Hz日志的既有指标，PWM步变为全程统计。图中的轨迹时序来自100Hz导出，评分不作相位对齐。每组只有3个独立种子点，灰线显示配对，不是大样本或显著性检验。

PCA_PREDICTIVE相对DCA：航向RMS略高约0.89%，主窗实际舵速低约5.55%、行程低约5.99%，构成权衡，不是Pareto支配。这里百分比为三种子均值之比；场景report中的配对变化是逐种子百分比的均值，二者不可混用。DA_NS/WLS数值极接近但非逐位相同。任务主窗λ恒为1；预测PCA seed202在t=0有1个采样点的启动缩放（λ≈0.966394，按800Hz计数1.25ms），未满足协议时长和种子要求，没有验证受限优先级保护；未做消融，不分离各预测机制贡献。

轻量包不含原始MAT、完整tracks或完整geometry。它支持阅读、指标复核和图表审阅；重新绘制时序图需恢复本地来源目录。原始文件的仓库相对路径、SHA256见[audit/source_files_before.json](audit/source_files_before.json)，45条正式日志及6条开发日志的既有审计哈希已重新检查。保留的1/15暂停批另列partial_batch，不参与确认统计。

后处理源码位于reproducibility/tools，依赖版本见requirements-f8-delivery.txt；MATLAB原实验环境为R2025b与Optimization Toolbox。本次只运行Python后处理，未重新运行MATLAB核验器或仿真。MATLAB原核验记录原样收录，其记录的引擎指纹由历史运行提供，本次20文件锁与原始日志哈希复核不冒充新鲜MATLAB执行。

在仓库根目录进行只读验收：

```powershell
python tools/f8_delivery_audit.py examples/f8_comparison_20261101
python tools/check_docs_links.py
```

只重绘已有确认数据，必须指定新的派生输出目录：

```powershell
python tools/plot_f8_comparison.py results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds_rerun1/F8PR-Y60-F075 --output-dir results/f8_delivery_replot_NEW
```

构建完整包使用python tools/package_f8_results.py；若最终目录已经存在会拒绝覆盖。构建在results下新建临时目录，前后核对全部原始批次文件哈希，验收后才将新包移入examples。原始results/f8_work_20261101/package_results.py保留作历史，不作为当前打包入口。

交付manifest的source_head是共同基底提交，source_uncommitted与git_status_at_packaging.txt记录打包时状态；修改后的绘图脚本和新增打包/验收源码随包保存，不能仅凭HEAD重建本次产物。数值源码哈希见reproducibility/numerical_source_sha256.json。PNG/PDF可受字体和库版本影响，不承诺跨环境逐字节相同；数值汇总和同种子差值可独立复算。
"""
(out / "README.md").write_text(readme, encoding="utf-8")
head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
manifest = dict(source_head=head, source_uncommitted=bool(status_text.strip()), raw_logs=raw_logs,
                python_version=platform.python_version(), original_results_unchanged=True, source_copies=source_copies,
                recorded_engine_fingerprint=read_json(confirmation_source / "independent_checks.json")["engine_fingerprint"],
                artifacts=[dict(path=p.relative_to(out).as_posix(), sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                           for p in sorted(out.rglob("*")) if p.is_file()])
(out / "artifact_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps(verify_bundle(out), ensure_ascii=False))
assert not final_out.exists() and out.parent.parent == root / "results"
out.rename(final_out)
print(final_out)
