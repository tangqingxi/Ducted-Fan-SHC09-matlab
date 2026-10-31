# HANDOFF — SHC09 MATLAB 平台（v0.4 进行中）

**Last updated:** 2026-10-31 18:30（Asia/Shanghai）  
**当前分支：** `comparison-ready`  
**v0.4 WIP 提交：** `59cd376`（已 push）  
**分支基准：** `e662e7d`（v0.3.0）  
**main / 远端 main：** `e662e7d`（v0.3.0）  
**当前 HEAD / 远端 comparison-ready：** 以 `git log -1` / `git ls-remote` 为准；本 HANDOFF 更新提交在其后。  
**v0.4.0：** **未打 tag、未发布**  
**工作区：** 干净。

---

## 1. 一句话状态

v0.4“平台可用、能比较分配器”的 WIP 已提交并 push 到 `comparison-ready`（`59cd376`）。M4 可比负载扫描 **30/30** 完成，主比较 **35/60**（0 失败，25 未运行），已暂停；代码、结果和缓存都在，可断点补跑。**v0.4.0 不是发布态。**

---

## 2. 当前目标

v0.4.0 不是“再加算法”，而是让平台能可靠地比较分配器：

- 预定义可比性门禁：五方法/全部种子完成、主窗饱和 ≤10%、姿态峰值 ≤5°、气动越界 0、lite 估计姿态 RMS ≤2°；
- 通过 = `rankable`，否则 `stress`/`invalid`，**不排名**；
- 跨种子做效应量（方法间极差 / 种子波动），不做显著性；
- 输出 `summary / comparability / effect_sizes / pareto / report`；
- 发布 v0.4.0。

门禁定义在 [docs/allocation_comparison_guide.md](docs/allocation_comparison_guide.md) 和 `analysis/allocation_comparability.m`，**先定后看结果，禁止临时放宽**。

---

## 3. 已完成

### M4 负载扫描
- 输出：`results/m4_load_sweep_research_seed1/`
- 30/30 完成，0 失败，0 未运行。
- 结论：**M4 在当前 lite 下没有可比负载**，`selected_m4_load = null`。
  - 0.4/lite：饱和 0.78%，姿态峰值 **5.5376°**（>5° 门禁），估计 RMS 1.404°。
  - 0.5/lite：饱和 2.55%，姿态峰值 **5.6847°**（>5°），估计 RMS 1.408°。
  - 0.6/lite：饱和 96.13%，姿态峰值 59.32°，估计 RMS 6.665°，明显压力演示。
  - ideal 三个负载均 rankable，但扫描只评价资格，不排名。
- 版本化选择：`configs/comparison/m4_selection.json`（`default_cases = ["M0","M2b"]`）。
- 轻量证据：`examples/allocation_comparison/m4_load_sweep/`。

### 主比较（进行中）
- 输出：`results/allocation_comparison_research_3seeds/`
- 计划 60 次：M0/M2b × ideal/lite × 五方法 × seeds 1:3；M4 因无同比负载不进入主比较。
- **35/60 completed，0 failed，25 not_run。**
  - M0/ideal：15/15（3 seeds × 5 methods）完成。
  - M0/lite：15/15 完成。
  - M2b/ideal：5/15 完成（seed 1 完成，seeds 2–3 未运行）。
  - M2b/lite：0/15 未运行。
- 已有 `summary.csv`、`comparability.csv`、`provenance.csv`、`status.csv`；**尚无完整 report/Pareto/effect_sizes**。
- 缓存：`results/allocation_comparison_cache/`；可恢复补跑。

### 回归记录
- `docs/estimator_diagnosis/release_v040_project_tests.csv`：14/14 通过。
- `docs/estimator_diagnosis/release_v040_platform_tests.csv`：6/6 通过。
- `docs/estimator_diagnosis/release_v040_baseline.csv`：六组冻结基线 `maximum_difference=0`，PWM 逐位一致。
- `docs/estimator_diagnosis/release_v040_regression.json`：在 `shc09:LitePhysicalBias` 处停止，`project_passed=14`、`platform_passed=6`、`baseline_exact=true`。**这是预期失败，不是 v0.4 发布回归全部通过。**

### v0.3.0 基线
- 已发布：`v0.2.0`、`v0.3.0`；远端 main = `e662e7d`。
- PX4 式平台、五分配器插件、估计器诊断、E3、仓库治理均已归档。

---

## 4. v0.4 文件（已提交到 WIP 分支）

提交 `59cd376` 已包含以下 v0.4 文件；它们**不在 main**，从 GitHub main 重新 clone 不会包含：

- `analysis/allocation_comparability.m`
- `analysis/allocation_comparison_empty_summary.m`
- `analysis/allocation_comparison_engine.m`
- `analysis/allocation_comparison_hash.m`
- `analysis/allocation_comparison_products.m`
- `analysis/allocation_comparison_run.m`
- `apps/allocation_comparison_app.m`
- `apps/m4_load_sweep_app.m`
- `configs/comparison/m4_selection.json`
- `docs/allocation_comparison_guide.md`
- `docs/estimator_diagnosis/release_v040_*`（4 个回归记录）
- `examples/allocation_comparison/m4_load_sweep/`
- `tests/test_allocation_comparability.m`
- `tests/test_allocation_comparison.m`
- `HANDOFF.md`（本文件）
- 修改：`README.md`、`docs/README.md`、`docs/repository_map.md`

**注意：** `comparison-ready` 是 WIP 分支，不是发布分支；不要把它直接合入 main。

---

## 5. 恢复步骤（按顺序）

```powershell
cd E:\Ducted-Fan-SHC09-matlab
git switch comparison-ready
git pull --ff-only
git status
```

1. 确认 HEAD 为 `59cd376` 或其后继 WIP；工作区干净。
2. **不要 clean、不要 reset、不要从 main 重新 clone 覆盖本地 WIP。**
3. 补跑主比较剩余 25 次（新 output_tag，可复用缓存/旧 logs）：
   ```matlab
   ca_setup;
   s = allocation_comparison_app( ...
       'cases',["M0","M2b"], ...
       'modes',["ideal","lite"], ...
       'seeds',1:3, ...
       'use_cached',true, ...
       'reuse_from','results/allocation_comparison_research_3seeds', ...
       'output_tag','allocation_comparison_research_resume');
   ```
   预期补齐：M2b/ideal seeds 2–3（10 次）+ M2b/lite seeds 1–3（15 次）。
4. 生成/检查 `comparability`、`effect_sizes`、`pareto`、`report`；确认 M2b 的 rankable/stress 状态。
5. 跑 v0.4 新测试与旧回归：
   ```matlab
   ca_setup;
   test_allocation_comparability;
   test_allocation_comparison;
   run_project_tests(false);
   run_platform_tests;
   test_platform_baseline;
   ```
   `run_estimator_tests` 仍应在 `LitePhysicalBias` 失败（预期，不要修门限）。
6. 更新 README/指南/release notes；v0.4.0 tag/push；远端 SHA 核验。
7. 更新本 `HANDOFF.md`，单独 commit `docs: update handoff`。

---

## 6. 关键结果/路径

| 内容 | 路径 |
|---|---|
| M4 扫描 | `results/m4_load_sweep_research_seed1/` |
| M4 轻量证据 | `examples/allocation_comparison/m4_load_sweep/` |
| 主比较（35/60） | `results/allocation_comparison_research_3seeds/` |
| 主比较缓存 | `results/allocation_comparison_cache/` |
| 版本化 M4 选择 | `configs/comparison/m4_selection.json` |
| v0.4 回归记录 | `docs/estimator_diagnosis/release_v040_*` |
| v0.3.0 收尾 | `docs/release_notes_v0.3.0.md` |
| E3 | `docs/e3_estimated_structural_mismatch.md` |
| 诊断 | `docs/estimator_diagnosis_report.md` |
| 平台重构 | `docs/platform_refactor_report.md` |

`results/`、`build/`、`archive/` 不进 Git；不要删除研究证据。

---

## 7. 已知失败 / 边界（必须保留）

- **`LitePhysicalBias` 仍失败**：物理闭环偏置约 0.061°/s > 0.05°/s；lite 仍是 **experimental**，默认仍是 **ideal**。不要调 kp/ki、不要放宽门限、不要真值兜底。
- **M4 在 lite 下没有可比负载**：0.4/0.5 姿态峰值 5.54/5.68° 略超 5°，0.6 是压力演示。**不要改 tanh/门禁/负载来强行制造 M4 排名**；主比较只用 M0/M2b，M4 只作 stress。
- **tau/rate 仍 matched**：真实与名义 tau 均 30 ms，速率限制只有一份 600°/s；比较结果不代表执行器失配鲁棒性。
- **gyro/compute delay 为 0**：`gyro_transport_delay_s=0`，求解耗时只记录不注入命令延迟。
- **无 ECL E3**：本轮 E3 未跑 ECL；ECL 是旧版归档核心。
- **单/三种子**：只做效应量，不做显著性、实机优势或全局排名。
- **v0.4 新测试未在发布回归中记录**：`release_v040_*` 只覆盖 14/6/基线；恢复后必须补跑 `test_allocation_comparability` / `test_allocation_comparison`。
- **WIP 已提交但未发布**：`comparison-ready` 是 WIP 分支；v0.4.0 还没有 tag。

---

## 8. 不要做

1. 不要改物理、控制器、五种分配算法、旧协议、估计器增益/偏置门禁。
2. 不要 `git clean` / `git reset --hard` / 从 main 重新 clone 覆盖本地 WIP。
3. 不要把 `comparison-ready` 的 WIP 直接合入 main 或 push main；先完成 v0.4.0 发布流程。
4. 不要删除 `results/`、`archive/`、`examples/`、`docs/` 中的证据。
5. 不要读/写 `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`。
6. 不要跑完整 30 次失配阶梯或 E1/E2 全量重跑；当前只补主比较剩余 25 次。
7. 不要把 M4/lite 的 stress 结果包装成方法排名。
8. 不要在 `comparison-ready` 上直接开 Viz 分支；Viz 用独立 worktree 从 main 开。

---

## 9. 先读

1. 本文件
2. `README.md`
3. `docs/allocation_comparison_guide.md`
4. `docs/e3_estimated_structural_mismatch.md`
5. `docs/estimator_diagnosis_report.md`
6. `docs/release_notes_v0.3.0.md`
7. `docs/repository_map.md`
8. `configs/comparison/m4_selection.json`

---

## 10. 后续候选（未排期）：MAT → Rerun 3D 回放（v0.5）

**当前不启动。** v0.4.0 的验收不含可视化；以下只是交接计划，避免下一轮重复讨论。

- 目标：仿真结束后读 `.mat`（`comparison.mat` / `log.mat`），生成可拖时间轴的 3D 回放 + 曲线；不是实时 3D，不嵌入仿真循环，不改变任何数值结果。
- 方案首选：Python + Rerun（`scipy` 读 MAT，`rerun-sdk` 写 `.rrd`）；MATLAB `flight_view_app` 作为无 Python 备选。**不转 ULog、不依赖 Hawkeye/PX4。**
- 本地 Python：`D:\app\python_manager\3.13.0\python.exe`（3.13.14）；`scipy`/`rerun-sdk` 尚未安装；建 `.venv-viz`，`.gitignore` 忽略 `.venv-viz/`、`*.rrd`、`__pycache__/`。
- 分支建议：**独立 worktree** `E:\Ducted-Fan-SHC09-viz`，分支 `viz-replay`，从 `main` 开；不要从 `comparison-ready` 开，避免带入 v0.4 WIP。viz worktree 目前**尚未创建**。
- 场景：SHC09 简化模型（涵道环 + 机体 + 六舵）、实际/参考轨迹、目标 ghost、姿态/位置误差、PWM/饱和曲线、事件 marker；六舵默认显示 `actual_delta_rad`，command 另注。
- 坐标：NED → Rerun `[north, east, up=-down]`；机体 y 前向、z 轴向；六舵几何/铰链写成可复用模块。
- 输出：`results/viz/<tag>/*.rrd`（不入 Git）；一条命令生成；headless 测试只验证 `.rrd` 非空，viewer 目视为可选。
- 验收：不改 MATLAB 数值；旧 14/6/基线不变；新增 `docs/flight_replay.md`；先打 `viz-preview`，v0.4.0 发布后再合并发 v0.5.0；更新 HANDOFF。

---

## 11. 更新协议（以后每个长任务）

每次长任务结束（包括暂停/失败）都要更新本文件：

- `Last updated`、当前分支、最新 commit、tag、远端 SHA、工作区状态；
- 本次完成了什么、失败了什么、哪些未运行；
- 结果/缓存/证据路径；
- 下一步的具体命令；
- 已知失败/边界、禁止事项；
- 单独 commit `docs: update handoff`，随发布一起 push（如果未发布则留在分支）。

**不要让 HANDOFF 与仓库实际状态不一致。**
