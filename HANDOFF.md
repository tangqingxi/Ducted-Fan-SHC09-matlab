# HANDOFF — SHC09 控制分配仿真项目交接

> **原交接时间**：2026-11-01 20:45；**本阶段修订**：2026-11-01（Asia/Shanghai）
> **本文记录项目状态，具体事实须以源码、Git和数据核对为准。** `AGENTS.md` 是常驻的架构与开发规范手册；两者冲突时**以本文为准**。
> **上一版 HANDOFF 描述的是"F8 暂停在 1/15"的旧状态，已全部作废**，被本文取代。历史报告只作档案，不反映当前状态。

---

## 0. 一分钟速览

| 问题 | 答案 |
|---|---|
| 项目是什么 | SHC09 六舵面涵道风扇的 MATLAB 控制分配仿真平台，固定控制器/被控对象，只比较五种分配器 |
| 当前分支 / HEAD | **`f8-research`**；当前HEAD以`git rev-parse HEAD`为准（原快照基底7c5c9ab，main仍是9918d9d） |
| F8 基础实验 | **30/30** 完成（F8-R 15/15 全通过；F8-D 5/15） |
| F8 压力开发筛选 | **9 次尝试：6 完成 / 3 气动域失败**，选出 `F8PR-Y60-F075` |
| F8 独立确认 | **15/15 完成，0 失败**（本次已跑完，不需要再跑） |
| 核心结论 | PCA_PREDICTIVE 航向 RMS 比 WLS 改善 **−56.5%**，代价仅 **+2.3%** 舵速；与DCA航向接近但略高，实际舵速/行程低5.5–6.0%，构成权衡 |
| **重要限定** | 任务主窗λ恒为1；seed202启动时有1点缩放，未达激励要求，**不是**优先级保护机制的验证 |
| 当前断点 | **F8交付已验收，2026-11-02用户批准提交**；后续PPID/hover开发单独交接（见 §9） |
| 下一步 | 验收 `examples/f8_comparison_20261101/`；当前打包入口为 `tools/package_f8_results.py` |

---

## 1. 项目总体定位

**项目名称**：SHC09 MATLAB 控制分配仿真项目（仓库 `E:\Ducted-Fan-SHC09-matlab`）

**研究对象**：六舵面涵道式无人机 SHC09。6 个舵面只产生 3 轴力矩，属**过驱动**系统，同一组力矩可由无穷多组舵面组合实现——这正是"控制分配"要解决的问题。

**研究目标**：在**相同控制器、相同被控对象、相同参考轨迹、相同随机种子、相同传感器与执行器**的条件下，比较不同控制分配算法。

**核心研究方向**：
- Hierarchical INDI（增量非线性动态逆）与速率环
- 控制分配（含执行器约束、优先级、方向保持）
- 预测式分配（考虑执行器动态与保持段）
- 估计反馈对分配差异的掩盖效应

**仿真平台**：MATLAB R2025b + Optimization Toolbox。

**研究方法学底线**：被控对象与控制律全程一致，**唯一变化因素是分配器插件**。唯一注入点见 `platform/sim/ca_simulate.m:255`（`shc09_allocator_module(bus,method,...)`）。

---

## 2. 当前代码架构

### 2.1 目录职责

| 目录 | 职责 |
|---|---|
| `models/` | SHC09 物理、气动、参数；`reference/` 为冻结原始气动表 |
| `platform/` | 平台骨架：总线、调度、模块、仿真、日志 |
| `allocators/` | 五种分配器插件 + 接口示例 + 唯一注册表 |
| `effectiveness/` | 名义效能矩阵派生（分配器使用的 B） |
| `experiments/` | 固定研究协议（F8、压力、八字搜索、失配） |
| `analysis/` | 指标、门禁评价、诊断、完整性工具 |
| `configs/` | 参数、机架、F8 协议（JSON 是唯一数值来源） |
| `results/` | 本机重型结果与缓存，**不进 Git** |
| `tools/` | 绘图（Python）、文档与仓库检查 |
| `drivers/` | 执行器与 PWM 时序模型 |
| `lib/` | 滤波与旋转数学 |
| `modules/` | 兼容桥接（分配器白名单、PX4 ECL） |
| `compat/` | 旧 API 兼容包装 |
| `tests/` | 测试、夹具、冻结基线 |
| `third_party/` | 归档上游源码与许可 |

### 2.2 关键文件在哪

| 需要什么 | 文件 |
|---|---|
| **控制器（速率环 / INDI）** | `platform/modules/rate_control/ca_indi_rate_control.m`（产生 `v_h`/`v_c`）、`shc09_rate_module.m` |
| 位置环（F8 前馈） | `platform/modules/position_control/ca_f8_position_control.m`、`shc09_position_module.m` |
| 姿态环 | `platform/modules/attitude_control/` |
| **控制分配器（五种）** | `allocators/`（见 §3） |
| 分配器注册表 | `allocators/registry.m` |
| 分配器**可见配置白名单** | `modules/control_allocator/ca_allocator_config.m`（13 项，无反馈增益、无真实 tau） |
| 分配派发与上下文 | `modules/control_allocator/ca_allocate.m`、`platform/modules/control_allocator/shc09_allocator_{context,dispatch,module}.m` |
| **SHC09 物理模型** | `models/shc09/ca_plant_step.m`、`ca_shc09_aerodynamics.m`、`ca_shc09_parameters.m`、`ca_model.m` |
| **效能矩阵** | `effectiveness/shc09_6vane/shc09_6vane_effectiveness.m`、`effectiveness/effectiveness_for_model.m`；名义 B 由 `ca_model.m` 的 `acceleration_matrix` 给出 |
| 执行器 / PWM 时序 | `drivers/actuators/ca_actuator_step.m`、`ca_pwm_timing.m`、`ca_true_actuator_tau.m` |
| **公共仿真调度器** | `platform/sim/ca_simulate.m` |
| 实验输入预生成 | `platform/sim/ca_prepare_experiment.m`（同种子跨方法一致） |
| **F8 实验入口** | `experiments/run_f8_comparison.m`、`experiments/run_f8_pressure_study.m` |
| **数据评价（门禁）** | `analysis/f8_evaluate_run.m` |
| 轨迹导出 | `analysis/f8_write_tracking.m` |
| 分配真值诊断 | `analysis/f8_allocation_diagnostics.m` |
| 优先级几何审计 | `analysis/ca_priority_polytope_audit.m` |
| **绘图** | `tools/plot_f8_comparison.py`、`plot_f8_pressure_development.py`、`plot_f8_protocol.py` |
| **打包** | `tools/package_f8_results.py` |

`ca_setup()` 只把**显式列出的路径**加入 MATLAB path（不含 `archive/`）。运行任何脚本前必须先 `ca_setup`。

---

## 3. 控制分配算法

五种方法注册在 `allocators/registry.m`：

| 编号 | 名称 | 实现 | 定位 |
|---:|---|---|---|
| 1 | `DA_NS` | `allocators/da_ns/ca_da_ns.m` | 直接分配 + 零空间利用 |
| 2 | `WLS` | `allocators/wls/ca_wls.m` + `ca_wls_active_set.m` | 加权最小二乘（带有效集） |
| 3 | `DCA` | `allocators/dca/ca_dca.m` | 动态分配，按舵机模型预测下一拍可达位置 |
| 4 | `PCA_STATIC` | `allocators/pca_static/ca_dp_lpca.m` | 优先级分配（静态），有界单纯形 LP |
| 5 | `PCA_PREDICTIVE` | `allocators/pca_predictive/ca_priority_core.m` | 在 PCA_STATIC 上加入预测式终态分配 |

### 3.1 优先级 LP 的真实数学形式

`ca_dp_lpca.m`（源注释写明"来源：PCA/DP_LPCA_copy.m"）：

```matlab
A = [B -yd];  b = m_higher - B*uMin;  c = [zeros(m,1); -1];  h = [uMax-uMin; 1];
```

求解后 `lambda = xout(m+1)`，即：

```
B·u = y_higher + λ·y_lower ,   0 ≤ λ ≤ 1 ,   最大化 λ
```

**λ 缩放的是"低优先级"需求，不是高优先级。**
λ<1 表示：高优先级需求被满足，但低优先级需求只能按 λ 比例交付。
只有 `mode==1` 的回退分支才把高层本身缩放（此时 `info.beta=λ`、`info.lambda=NaN`）。

> ⚠️ 旧版 `AGENTS.md` 术语表曾把 λ<1 写成"高优先级受限"，**这是错误的**，本轮已修正。

### 3.2 高/低优先级从哪来

`platform/modules/rate_control/ca_indi_rate_control.m`：

```matlab
v_h = model.acceleration_matrix*feedback_delta - alpha + alpha_reference;   % INDI 反演/前馈项 → 高优先级
v_c = cfg.rate_gain(:).*(omega_reference - omega);                          % 速率误差 P 项 → 低优先级
```

经 `shc09_rate_module.m` 发布到 `vehicle_torque_setpoint`，分配器以 `ctx.demand.v_h / v_c` 取得。
**这与 PX4 `df-main` 的 `y_higher`/`y_lower` 分解同构**（详见 §4）。

### 3.3 PCA_STATIC 与 PCA_PREDICTIVE 的区别

`PCA_STATIC` 用当前时刻效能 `matrix = B`、`continued = 0`，直接求上述 LP，再做 `ca_restore`。

`PCA_PREDICTIVE`（`ca_priority_core.m`，`predictive=true`）在此之上加了**六件事**：

| # | 机制 | 实现 |
|---|---|---|
| 1 | **名义执行器时间常数模型** | `f = exp(-hold_s./tau)`，`g = 1-f`，`tau = cfg.tau_model_s`（名义 30 ms，非真实 24–40 ms） |
| 2 | **保持段预测** | `continued = B*(f.*at_delivery)`：保持段内舵面继续运动产生的力矩 |
| 3 | **动态效能矩阵** | `matrix = B*diag(g)`：保持段内"还能改变多少力矩"的有效增益 |
| 4 | **执行器变化率约束** | `lower = max(lower, at-τ·rate)`、`upper = min(upper, at+τ·rate)`，使仿射预测在整段保持内严格成立 |
| 5 | **终点预测** | `predicted_delta = ca_actuator_step(at_delivery, command, τ, hold_s, rate)`；`assert(norm(predicted_effect-allocated_effect,Inf)<1e-7)` |
| 6 | **minimum-change 恢复** | `predictive_restore_mode=="minimum_change"` 时用 `ca_restore_minimum_change`，否则 `ca_restore`；`assert(norm(matrix*command-before,Inf)<1e-5)` 保证**恢复不改变已分配力矩** |

分配器内部参数（`configs/params/ca_config.m`，全方法共享）：`predictive_horizon_fraction = 1`、`predictive_restore_mode = "minimum_change"`、`max_iterations = 200`、`constraint_tolerance = 1e-7`。

### 3.4 降级链（重要）

`ca_priority_core.m:29-56`：

| mode | 触发 | 行为 | λ |
|---|---|---|---|
| 0 | 正常 | `allocated = v_h + λ·v_c` | 正常值 |
| 1 | 射线不可达 | 只分配 `λ·v_h`，丢弃 v_c | 转为 `beta`，`lambda=NaN` |
| 2 | 两条射线都不可达 | 用 `linprog` 最小化高优先级残差 | NaN |

`mode` 与 fallback 计数被写入 `task_metrics.csv`（`pca_high_priority_fallback_count` / `pca_engineering_fallback_count`）。

### 3.5 当前已知表现（务必与 §6 数据对照）

- `DA_NS` 与 `WLS` 在当前确认场景数值极接近，但存在浮点差异，不能称为逐位相同。
- `PCA_STATIC` 在本次确认中没有表现出明确跟踪优势；常以更高舵速换取与 WLS 相同的效果。
- `PCA_PREDICTIVE` 与 `DCA` 都能大幅改善航向跟踪，但 PCA_PREDICTIVE的实际舵速和行程更低；不作统计显著性声明。

---

## 4. PX4 参考仓库

**地址**：<https://github.com/mengchaoheng/DuctedFanUAV-Autopilot>
**参考分支**：`df-main`（默认开发分支）

> 仓库内 `PX4_SIH_DuctedFan_Modeling.md` 属于 `df-mpc` 分支，**不要**用它作为当前实现依据。一切以 `df-main` 源码为准。

### 4.1 值得研读的源码

| 主题 | 文件 |
|---|---|
| **PCA 有界 LP 求解器** | `src/lib/control_allocation/control_allocation/pca/ControlAllocation.h`（`DP_LPCA` / `DPscaled_LPCA` / `DP_LPCA_prio` / `restoring` / `simplxuprevsol`） |
| **PCA 适配层** | `src/lib/control_allocation/control_allocation/ControlAllocationLPCA.cpp`（方法分派、前置条件、fallback、诊断） |
| **Rate INDI** | `src/modules/mc_rate_control/IndiControl/IndiControl.cpp`（`output.rate_error_torque` 与 `output.feedback_torque`） |
| **SHC09 效能矩阵** | `src/modules/control_allocator/VehicleActuatorEffectiveness/ActuatorEffectivenessDuctedFan.cpp`（电机与舵面用 `selected_matrix=0/1` 分离） |
| **SHC09 SIH 物理模型** | `src/modules/simulation/simulator_sih/`（`classic_models.hpp`、`classic_model_data.hpp`、`sih.cpp`） |
| 机架参数 | `ROMFS/px4fmu_common/init.d/airframes/22005_SHC09`、`ROMFS/px4fmu_common/init.d-posix/airframes/22019_sihsim_SHC09` |

### 4.2 与 MATLAB 实现的关系

- **同源**：`ca_dp_lpca.m` 是 `PCA/DP_LPCA_copy.m` 的独立副本；LP 形式、目标、λ 语义、上下界处理**逐项对应**。
- **同构**：高/低优先级分解（INDI 反演项 / P 项）在两边一致。
- **MATLAB 多出的**：保持段预测、动态效能、变化率收紧、终点预测（PX4 无）。
- **PX4 多出的**：气流效率 `inverse_effectiveness = 1/max(0.1, flow²)` 修正、`restoring` 的 null-space 投影、显式 `_control_sp_priority_valid` / `hasPcaAxes()` 门禁、失败时回退 **INV（伪逆）**。

### 4.3 PX4 LPCA 的关键实现事实（移植前必读）

> **未读到的文件（不要以为本文已覆盖）**：`ControlAllocation.hpp`、`ActuatorEffectivenessDuctedFan.hpp`、`msg/VehicleTorqueSetpoint.msg`、`ControlAllocator.cpp`、`MulticopterRateControl.cpp`、SIH 各文件。前两个因 CDN 返回 `application/octet-stream` 取不到，`.msg` 因被 CDN 判为 Outlook 格式取不到。因此 **PX4 六舵面效能矩阵的具体数值**与 **`VehicleTorqueSetpoint` 的字段表**仍为 UNKNOWN，需要时请自行读源码。

**优先级 LP 的形式**（`ControlAllocation.h::DP_LPCA_copy`）：

```cpp
DP_LPCA_problem.A[i][n-1] = -input_lower[i];      // A = [B | -y_lower]
DP_LPCA_problem.b[i] = input_higher[i] - BuMin;   // b = y_higher - B*u_min
rho = xout[EffectorSize];                          // rho 就是 λ
```

⇒ `B·u = y_higher + λ·y_lower`，`h[λ] = 1`（`upper_lam=1`），目标为最大化 λ。**与 MATLAB `ca_dp_lpca.m` 逐项对应**。

**求解器**：`simplxuprevsol` 为**有界修正单纯形**（bounded revised simplex），两阶段（人工变量 + `cleanup_zero_artificial_basis`），`tol = 1e-10`，枢轴规则 `min(rdt)` / Bland / `min(rat)`。

**错误码**：`0` 成功；`−1` solver error（无界）；`−2` 初始可行解未找到；`−3` 迭代上限；`+1` / `+3` 终解阶段同类错误。

**内部降级**（`DP_LPCA_prio`）：`err<0` 时以 `higher=0, lower=higher` 重新求解——即放弃低优先级、只保高层。

**适配层降级链**（`ControlAllocationLPCA.cpp::allocate`），依次判断，**全部回退 INV（伪逆）**：

| 条件 | `solver_status` | `solver_err` |
|---|---|---|
| `Method::Inv` | — | — |
| 非行满秩 | −1 | `1` |
| 行数非 3/4 | −1 | `2` |
| 执行器数非 4/6/8 | −1 | `3` |
| PCA 但无有效优先级拆分 | −1 | `5` |
| PCA 但缺 ROLL/PITCH/YAW 三轴 | −1 | `4` |
| LPCA 求解失败 | −2 | 求解器 err |
| 成功 | `1` | — |
| 零指令（不求解） | `0` | — |

**`hasPcaAxes()` 要求恰好 3 个有效行且顺序为 ROLL→PITCH→YAW。**

**`restoring`**：把 LP 解投影到 `null(B)`，沿该方向移动 `min(K_max, K_opt)`（`a_constant = −2`），在**保持力矩不变**的前提下降低执行器幅值。

**`DPscaled_LPCA` 的 `rho` 与 λ 不是同一个量**：它是方向保持比例 `ydtᵀBu / (ydtᵀydt)`，且 `rho>1` 时整体除以 `rho`。不要混用。

**INDI 输出**（`IndiControl.cpp::update`）分成两个独立分量：`rate_error_torque = I·Kp·e`（P 项）与 `feedback_torque = (G·u_prev − I·ω̇)·s⁻¹`（反演项，`s` 为气流效率）。

### 4.4 硬性禁止

- **禁止**未经验证就复制 PX4 代码到本仓库。
- **禁止**用 PX4 参数覆盖本地物理模型（推力系数、质量、时延等）。已知差异：PX4 `k_T=2.937612e-5` / 最大推力 42.30 N，本地 `k_T0=2.8964e-5` / 41.708 N。
- **禁止**把 PX4 的 SIH/SITL 结果当作本地验证结果。

---

## 5. 当前实验完成情况

### 5.1 三阶段总览

| 实验 | 状态 | 路径 |
|---|---|---|
| **F8 基础正式** | **30/30 完成，0 运行失败** | `results/f8_v1_formal_20261101_frozen_3seeds/` |
| **F8 压力开发筛选** | **9 次尝试：6 完成 / 3 失败**（失败均为 `ca:AeroTableDomain`） | `results/f8_pressure_screen_20261101_Rbase_v2_bounded_yaw/` |
| **F8 独立确认** | **15/15 完成，0 失败** | `results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds_rerun1/` |
| 原暂停确认批 | 1/15，**保留作证据，不得删除或合并** | `results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds/` |

基础批次通过率：F8-R **15/15 通过**全部任务要求；F8-D **5/15**（seed 101/102 高度 RMS 0.2197–0.2281 m 超 0.20 m 门槛，属公共推力控制瓶颈，不是分配器差异）。

### 5.2 独立确认实验（当前主线）

**路径**：`results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds_rerun1/F8PR-Y60-F075/`

| 项 | 值 |
|---|---|
| Scenario | `F8PR-Y60-F075` |
| 协议 | `F8-P-v2.0`（`configs/f8_pressure_protocol_v2.json`），`protocol_version=2` |
| 位置基线 | F8-R：N/E 半幅 3 / 1.5 m，周期 20 s，高度 −10 m |
| 偏航参考 | 60°·sin(15φ)，φ为20s位置相位；等价于60°·sin(2π×0.75×平滑运动时钟) |
| 仿真时长 | 52 s（主窗 [6,50]、巡航 [10,46]、相位斜坡 4 s） |
| 随机种子 | **201、202、203**（holdout，未参与开发筛选） |
| 算法 | DA_NS、WLS、DCA、PCA_STATIC、PCA_PREDICTIVE |
| 工况 | M2b，负载 0.6，线性舵映射，真实舵角硬限 40° |
| 执行器 | 真实 τ = [24,27,30,33,36,40] ms，模型 τ = 30 ms（未实测假设） |
| 估计器 | `lite`，显式开启 GNSS 速度辅助 |
| 前馈 | 速度/加速度 + 名义几何角速度/角加速度 |

### 5.3 数据规模与产物

候选目录 **50 个文件 / 872.7 MB**（整个新目录树 56 个文件，含顶层协议副本与汇总）：

| 文件 | 数量 / 行数 |
|---|---|
| `status.csv` | 15 行，全 `completed` |
| `task_metrics.csv` | 15 行 × 40 列 |
| `state_metrics.csv` | **720 行**（15 × 4 窗口 × 12 状态） |
| `provenance.csv` | 15 行 |
| `logs/*.mat` | **15 份**（807.7 MB，每份含 `L,c,m,ref,protocol,signature`） |
| `tracks/*.csv` | **15 份，每份 5201 行** |
| `priority_geometry_*.csv` | **6 份，每份 35201 行**（12 列） |
| `protocol.json` / `task_evaluation.json` | 各 1 份 |

> **重要更正**：`priority_geometry_*.csv` 每份是 **35201 行**（主窗 44 s × 800 Hz），**不是** 4401 行。早期汇报（`2.md`）写错了，以此处为准。

### 5.4 后处理测试状态

| 测试 | 结果 |
|---|---|
| `test_f8_comparison_results(folder)` | **通过**。`formal_logs_verified=15`、`state_metric_rows_verified=720`、`maximum_csv_error=5.12e-13`（阈值 1e-10）、`maximum_metric_error=4.55e-12`（阈值 1e-9）、`all_methods_meet_task_requirements=true` |
| `f8_allocation_diagnostics(folder)` | **通过**。`formal_logs_read=15`、`independent_lp_snapshots=18`、`maximum_lp_lambda_error=0` |

产物：`independent_checks.json`、`independent_run_checks.csv`、`priority_{activation,trace,events}.csv`、`allocation_truth_diagnostics.csv`、`independent_priority_lp.csv`、`allocation_diagnostics_checks.json`。

### 5.5 pipeline 记录

**位置**：`results/f8_work_20261101/pipeline_complete.json`

```json
"pressure_confirmation_ran": true,
"confirmation_output": "...\\f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds_rerun1",
"confirmation_completed": 15,
"superseded_partial_output": "...\\f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds",
"superseded_partial_completed_runs": 1,
"partial_batch_preserved_unmodified": true,
"thresholds_changed": false,
"all_unfavorable_outcomes_retained": true,
"significance_claims": false
```

---

## 6. 当前最重要的实验结论

### 6.1 三种子均值（`task_metrics.csv` 直接计算）

| 方法 | 水平 RMS (m) | 水平峰值 (m) | 高度 RMS (m) | 速度 RMS (m/s) | 航向 RMS (°) | 航向峰值 (°) | 内环姿态 RMS (°) | 估计姿态 RMS (°) | 主窗舵速 (°/s) | 主窗行程 (°) | PWM 步变 (°) | λ_min | 缩放时长 (s) | fallback |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| DA_NS | 0.339752 | 0.6325 | 0.106178 | 0.173478 | 1.19430 | 2.5732 | 2.55239 | 1.14477 | 32.2032 | 6864.81 | 0.104508 | — | — | — |
| WLS | 0.339752 | 0.6325 | 0.106178 | 0.173478 | 1.19430 | 2.5732 | 2.55239 | 1.14477 | 32.2032 | 6864.81 | 0.104508 | — | — | — |
| DCA | 0.347702 | 0.6435 | 0.105654 | 0.173893 | **0.51501** | **1.1225** | 2.31040 | 1.13437 | 34.8794 | 7505.92 | 0.731486 | — | — | — |
| PCA_STATIC | 0.339697 | 0.6324 | 0.106176 | 0.173482 | 1.19251 | 2.5734 | 2.55190 | 1.14478 | 35.8449 | 7142.31 | 0.267222 | **1.0** | **0** | **0** |
| PCA_PREDICTIVE | 0.347640 | 0.6434 | 0.105667 | 0.173897 | **0.51958** | **1.1518** | 2.31193 | 1.13457 | **32.9440** | **7056.69** | 0.710812 | **1.0** | **0** | **0** |

### 6.2 相对WLS的变化（三种子均值之比）

本表使用100×(候选均值−基线均值)/基线均值；逐种子百分比的均值另见交付report，二者通常略有不同。

| 方法 | 航向 RMS | 水平 RMS | 主窗舵速 | 主窗行程 | PWM 步变 |
|---|---:|---:|---:|---:|---:|
| DCA | −56.88% | +2.34% | +8.31% | +9.34% | ×7.00 |
| **PCA_PREDICTIVE** | **−56.50%** | **+2.32%** | **+2.30%** | **+2.80%** | **×6.80** |
| PCA_STATIC | −0.15% | −0.02% | +11.31% | +4.04% | ×2.56 |

逐种子（PCA_PREDICTIVE 相对同种子 WLS 的航向）：seed201 **−56.61%**、seed202 **−51.98%**、seed203 **−61.02%**。三种子方向一致。

### 6.3 必须记住的六条

1. **DA_NS与WLS在本场景数值极接近，非逐位相同**。逐种子航向RMS最大差约7.02e-10°、总行程最大差约1.22e-5°；不能把显示精度相同当成原值相等。
2. **DCA 与 PCA_PREDICTIVE 都取得明显航向跟踪改善**（约 −57%），且三种子一致。
3. **PCA_PREDICTIVE 相比 DCA**：航向 RMS 仅差 **+0.89%**（略差），但主窗舵速 **−5.55%**、行程 **−5.99%**。这是本场景的跟踪与实际运动量权衡，**不是对DCA的Pareto支配**。
4. **PCA_PREDICTIVE 相比 WLS**：航向 RMS 改善 **−56.50%**，代价仅舵速 **+2.30%**、行程 **+2.80%**；但水平位置差 **+2.32%**。
5. **PCA_STATIC 没有表现出明确的跟踪优势**：航向仅 −0.15%，舵速却 +11.31%。不能据此概括所有历史实验或未来场景。
6. **PCA_PREDICTIVE 的 PWM 步变明显增加**（×6.80），虽不等于机械损耗或能耗，但需要后续关注。

### 6.4 严禁的表述

**本次结果不能表述为"优先级保护机制已得到验证"。**

- 两种 PCA 的 `lambda_min = 1.0`、主窗缩放时长 **0 s**、高优先级 fallback **0 次**，这些字段仅针对任务主窗。全程中预测PCA seed202在t=0有1个控制采样点及1个PWM事件缩放，λ=0.966394388996382，计数时长0.00125s；不足协议要求，不构成优先级保护验证。
- `task_evaluation.json` 明确记录：`priority_excitation_and_nominal_geometry_requirements_met = false`、`priority_effect_or_method_superiority_proven = false`。
- 本批任务主窗没有λ缩放，因此不能据主窗收益宣称验证受限优先级钳位；收益与预测分配整体配置有关，但未做消融，不能分离终点预测、等待/保持及最小变化恢复的各自贡献。

也不能宣称：统计显著性、实机优势、方法全局最优、`lite` 可替代 `ideal`。

---

## 7. 数值保护与实验治理

### 7.1 两道锁

| 机制 | 覆盖 | 当前值 |
|---|---|---|
| **引擎指纹** `allocation_comparison_engine()` | `platform/ allocators/ effectiveness/ models/ drivers/ lib/ configs/ modules/ compat/` 全部 `.m` + `experiments/ca_mismatch_protocol.m` + `duct_raw.mat`/`wing_raw.mat` | **`e8d0c32c3faee85b60dee14c6fc653f3e1155a10630b3b3a352ba933942603f8`** |
| **20 文件冻结锁** | 见下 | `results/f8_work_20261101/numerical_sources_before_confirmation.json`，其自身 SHA256 = `4f6c4e6e1ae179f4f9485332642c84adfbc0b30eb0b33de463316dde0d49395b` |

> ⚠️ 引擎指纹**不覆盖** `experiments/` 的其它文件与整个 `analysis/`。改这些文件不会让指纹变化，却会让结果不可比——因此才有第二道锁。

### 7.2 20 个冻结文件

```
configs/f8_protocol_v1.json                              839dec7b1199dee603aa13119ad7988db1fc9e25a1ff5b34e87c222da1d67b5d
configs/f8_pressure_protocol_v1.json                     1940d8436f07c8f17036b08280c5496f826831c62f03f59732830e501ff639d1
configs/f8_pressure_protocol_v2.json                     9afcc18f6966265f6db8961a969eaa58ddc9fbb444ff790231b8c6119ca561de
configs/params/ca_realism_defaults.m                     a766092f247c7c592eae5b026e6bcb4faf872b82d96a7e51ce52dd249feea4b2
experiments/ca_f8_protocol.m                             efcf0b0af99f8d2bdc09173aa377cdd598e963759cc6232b22668fa66509d06b
experiments/ca_f8_reference.m                            fb95caf5c157f83236d9ded894ff2249c2a0bbc613e7ec666a0eadefc36f46e9
experiments/ca_f8_attitude_reference.m                   ee053cffeb803b28da6aa6330716c170c971d86b00b9adb592c4fda58b359cbd
experiments/ca_f8_pressure_protocol.m                    ad1b714541fbc401b5a02af4b79914c08ca3fc69c3cdfa4ab3dfa3c336634333
experiments/run_f8_comparison.m                          c2cca02131424aaa83063c6537f83f7af357bd90f37553c7e5c908daac1d2b44
experiments/run_f8_pressure_study.m                      c5d77f38f73e43c9b6da525b8de890b482eda31e711adfb4434a2356623c59f4
platform/modules/position_control/ca_f8_position_control.m 5f8726bbcf742382625bd809d8e85782a275e9be4f19782ff4cdb0789804e083
platform/modules/position_control/shc09_position_module.m cef84f2cdb92efc5203dde9cf43ed3811b1d66fa32add46abc28abee08ce30bc
platform/params/shc09_module_params.m                    4b8775c5605638e6eb2cac8cc34850b72877e269c29a0b4103228c72be8377fc
platform/sim/ca_simulate.m                               a9d25f02819b8ef0fb78dfd500ee56dfeee7e49e98a1b9ffc7da50fa0f4fdb5e
platform/modules/estimator/shc09_estimator_lite_module.m 75eb405d9a3c8a381086115a82308a65d023d1f9eda45e18418ee16db8d3121f
platform/modules/estimator/shc09_lite_velocity_aiding.m  3cf0eb809e1aa9315ad668e8bf6ab2c2e07895b407e1e93f6c2ce12bcf30a103
platform/modules/estimator/shc09_lite_params.m           aaec588fd89f6be9b397c5df07bf3a3020981639c5235a00de87a372f7ff58e6
analysis/f8_evaluate_run.m                               6b706760383e59c3c61be926d39b5c2841bbd8fcbf2a5d444af4595243e5895f
analysis/ca_priority_polytope_audit.m                    3d7f8c4116d5b7778dc5f69b7d95f0a9ce7e8000638738900a00cd59c55ddb97
analysis/f8_write_tracking.m                             bdfbc1ce56439a133db453c511a62b9321766252f4469fff7e0aca6718d26ab0
```

### 7.3 其他关键指纹

| 项 | 值 |
|---|---|
| F8-v1 协议内容哈希 | `a53cfd39757a9bd52ecd8343e0174e6f8e4d66a2674b875c45546dc7a75228ce` |
| F8-P-v2 冻结协议哈希 | `54993f7e7b1a39d871776616fdaa254e4baacb99540c1fc981b7f2b4c876bf7e` |
| 原暂停批 `logs/DA_NS_s201.mat` | `3bbde74a8da33535ed0848e27b15abab31277d1a85093dcdb13099b0d6e94fcb` |
| 原暂停批 `tracks/DA_NS_s201.csv` | `a93de1e7801279c11c6b8b98e2da918f892ebda58f9c1b89272d10e0aaf656ed` |
| 原暂停批 `status.csv` | `42ec044e74f010135a7106b290043cf882a2d99879d7bcf0c1c145c79b5f2bd9` |
| 原暂停批 `protocol.json` | `122ac4ece1bc43d3a987455c89bd2fe4752b688f276d8c307dc71408e5350c96` |
| 开发批 `development_priority_checks.json` | `63c73eeb33ebd63169ba8a83afd4e9e98d0365b2bcf0a8e6999f0d373f8ee8c2` |
| 开发批 `selection.json` | `2185e2abffda95fde30a2cc4d43dfe32d37a293a5ecfdb2a3ace69469babeb88` |

### 7.4 Git 状态

| 项 | 值 |
|---|---|
| 分支 | **`f8-research`**（工作分支） |
| HEAD | **`7c5c9ab91fdb310c33d5bf08209e0302e540008f`** |
| 上游 | `origin/f8-research`（已同步） |
| `main` / `origin/main` | `9918d9d`（**未推进**，可回退基线） |
| 发布 tag | `v0.5.0` → `3fc46c0247fea6e82c95e38721f56fa256bf3b72`（未动） |

回退方式：`git switch main` 即回到已验证的 `9918d9d`。**不要** force push、**不要** `git reset` 改 `main`、不要删分支。

### 7.5 治理规则（违反即返工）

1. **不覆盖已有结果目录**。所有实验入口都要求新 `output_tag`（`^[A-Za-z0-9_-]+$`）。
2. **不改门槛、不按结果回头挑场景或种子**。要改必须另立协议版本。
3. **原暂停确认批必须保留**（1/15），不得删除、覆盖、合并。
4. **开发筛选数据与独立确认数据不能混用**。前者用于选场景，后者用于验证；开发批有选择偏差。
5. **不允许未经批准删除结果目录或原始日志**（`results/`、`archive/`）。
6. **不宣称统计显著性、实机优势、全局最优**（只有 3 个种子）。
7. **不把 PWM 步变当机械损耗或能耗**。
8. **不改 `LitePhysicalBias` 门槛**（0.061 > 0.05 °/s 是已知预期失败，`lite` 仍 experimental）。
9. **不把 F8-D 高度超差说成分配器优劣**（公共推力瓶颈）。
10. 未提交工作**不打 tag、不 push**，除非明确要求。

---

## 8. 仿真确定性验证

独立确认批（新目录）与已暂停批（旧目录）的 `DA_NS / seed 201` 跨批次比较：

| 比较项 | 结果 |
|---|---|
| `task_metrics.csv` 整行（**40 列**） | **differing = 0**（逐字段完全相同） |
| 水平位置 RMS | 0.330156 = 0.330156 ✅ |
| 航向 RMS | 1.18017 = 1.18017 ✅ |
| `tracks/DA_NS_s201.csv` SHA256 | `a93de1e7…656ed` —— **两批次逐字节相同** ✅ |
| `logs/DA_NS_s201.mat` SHA256 | **不同**（新 `fcd4fed8…` / 旧 `3bbde74a…`） |
| `protocol.json` SHA256 | **不同**（新 `863cdd72…` / 旧 `122ac4ec…`） |

### 8.1 差异来源（已定位，非物理非确定性）

**MAT 文件**：在 MATLAB 内逐变量比对——

```
signature 相同；c、m、ref、protocol 全部 isequaln 相等
L 共 90 个字段，仅 2 个不同：solve_time_s（分配器 toc 计时）、elapsed_s（墙钟时间）
其余 88 个物理状态 / 估计 / 分配决策 / λ / mode / 预测字段逐位一致
MAT 文件头仅创建时间不同（17:20:15 vs 19:25:57）
```

字节级差异（约 14.6 MB）源于压缩流被这两条计时向量扰动后整体位移，不是内容变化。

**protocol.json**：文本 diff 只有一行——`"seed": 201` vs `"seed": 203`。该文件在每个种子开始时覆写一次（`run_f8_pressure_study.m:44`）：旧批次停在 seed 201，故保留 201；新批次跑完三种子，最后一次写入是 203。**属预期行为。**

### 8.2 结论

本次DA_NS/201跨批检查支持该配置下参考、状态与分配决策的数值复现；已有MATLAB逐变量记录仅发现计时差异。不能据单个方法/种子推断全部配置的全链条确定性，本轮未重跑仿真扩大验证。

比较同一配置的物理结果时，应排除计时和批次元数据；MAT文件SHA适合证明文件未被改动，不适合独自判定两次仿真的物理数值一致性。现有DA_NS/201指标及轨迹CSV一致证据保留。

---

## 9. 当前真正的工作断点

### 9.1 已完成（**不要重跑**）

- F8 基础正式 30/30。
- 压力开发筛选 9 次尝试。
- **独立确认 15/15**（新目录，已通过两项后处理测试）。
- `pipeline_complete.json` 已生成。

### 9.2 本阶段已交付，等待批准

- `examples/f8_comparison_20261101/` 已生成：确认批13组PNG/PDF，基础F8-R/F8-D各8组历史PNG/PDF；报告、逐次指标、配对差值、协议、失败记录、复现脚本和哈希清单一并交付。
- 当前打包入口：`python tools/package_f8_results.py`。先预检来源，再在新临时目录构建并验收，最终写入新交付目录；已有目标目录会拒绝覆盖。
- 只读验收：`python tools/f8_delivery_audit.py examples/f8_comparison_20261101`。
- 绘图入口要求 `--output-dir <新目录>`；原始确认批、开发批、暂停批和基础批均不写回。
- 两项MATLAB后处理核验沿用既有记录，本轮未调用MATLAB或重跑正式仿真。
- 完整变更、验收和待提交清单见 `codex-repo-2.md`；本阶段尚未暂存、提交或push，`main`未变。

### 9.3 不建议现在做的事

- **不要重跑任何已完成的仿真**（30 + 9 + 15 条已全部落盘）。
- **不要为了"更漂亮的结论"改门槛**。
- **不要用本次主窗λ≡1、仅有单点启动缩放的结果去论证优先级保护机制**。若要做该研究，必须**另立协议**，设计真正能激励 λ<1 且仍通过任务门槛的工况（开发筛选中出现任务主窗λ<1的两个候选 `F8PR-Y60-F100`、`F8PR-Y75-F100` 均任务失败，且 WLS 直接撞气动域）。

---

## 10. 下一位 Agent 的工作原则

1. **接手先做只读核对。** 文档快照不代替实际Git、冻结锁和数据；不要为了核对而重跑正式仿真。
2. **先读 `HANDOFF.md`（本文）再读 `AGENTS.md`。** 前者是当前状态，后者是架构与规范。
3. **以实际 Git 状态为准**：`git branch --show-current`、`git rev-parse HEAD`、`git status`。文档里的 SHA 会过期，命令不会。
4. **优先复用已有数据。** 30 + 9 + 15 条结果、15 份 MAT、全部 CSV 都在本地 `results/`。
5. **不重复运行已完成的实验。**
6. **每次开发前明确三件事**：目标、要改的文件、验收标准。改动涉及冻结文件时，必须先出精确 diff 与例外记录（参考 `results/f8_work_20261101/development_failure_guard_correction.json` 的格式）。
7. **每轮完成后详细汇报**，并说明：改了哪些文件、跑了什么、有没有动历史数据。
8. **技术决策必须有源码与实验数据依据**，不能只凭方法名称推断（例如"都叫 INDI 所以结构相同"是错的）。
9. **运行 MATLAB 需要 danger-full-access 文件策略**：workspace-write 下 MATLAB 无法启动（`Fatal Startup Error: System file inconsistency`，因为它要写工作区外的偏好与临时目录）。
10. **不要自行 push / 打 tag / 删结果目录。**

---

## 附录 A：关键路径索引

```text
协议与配置
  configs/f8_protocol_v1.json                         F8-v1 机器协议（唯一数值来源）
  configs/f8_pressure_protocol_v2.json                F8-P-v2 机器协议（本次确认所用）
  configs/params/ca_config.m                          总线默认配置（含 predictive_* 参数）
  configs/params/ca_realism_defaults.m                噪声/时延等真实化默认值

实验入口
  experiments/run_f8_comparison.m                     基础批（30 条）
  experiments/run_f8_pressure_study.m                 压力筛选 / 确认（含不覆盖断言）
  experiments/ca_f8_protocol.m                        构造 F8 cfg/model/ref
  experiments/ca_f8_reference.m                       平滑八字参考 + 解析前馈
  experiments/ca_f8_attitude_reference.m              几何姿态/角速度/角加速度前馈
  experiments/ca_f8_pressure_protocol.m               压力候选参考

分配器
  allocators/registry.m                               唯一注册表
  allocators/da_ns/ca_da_ns.m                         DA_NS
  allocators/wls/ca_wls.m                             WLS
  allocators/dca/ca_dca.m                             DCA
  allocators/pca_static/ca_dp_lpca.m                  PCA_STATIC 的 LP（有界单纯形）
  allocators/pca_predictive/ca_priority_core.m        PCA_PREDICTIVE 主逻辑
  allocators/pca_predictive/ca_restore_minimum_change.m  minimum-change 恢复

平台与仿真
  platform/sim/ca_simulate.m                          公共调度器（method 唯一注入点 :255）
  platform/sim/ca_prepare_experiment.m                同种子跨方法一致的输入预生成
  platform/modules/rate_control/ca_indi_rate_control.m  产生 v_h / v_c
  platform/modules/control_allocator/                 派发与上下文
  modules/control_allocator/ca_allocator_config.m     分配器可见白名单（13 项）

评价与诊断
  analysis/f8_evaluate_run.m                          四维门禁
  analysis/f8_write_tracking.m                        轨迹表（5201 行）
  analysis/f8_allocation_diagnostics.m                分配真值诊断 + LP 抽查
  analysis/ca_priority_polytope_audit.m               优先级几何审计（35201 行）
  analysis/allocation_comparison_engine.m             引擎指纹
  analysis/allocation_comparison_hash.m               SHA256 工具（内部用 getByteStreamFromArray）

测试
  tests/test_f8_comparison_results.m                  独立核验（15 日志 / 720 行 / 1e-10、1e-9）
  tests/test_f8_protocol.m                            协议与前馈单元测试
  tests/test_f8_pressure_protocol.m                   压力协议单元测试

工具与驱动
  tools/plot_f8_comparison.py                         只读来源，--output-dir写新派生图表
  tools/package_f8_results.py                        当前打包入口；原results脚本保留历史
  results/f8_work_20261101/finish_f8_confirmation_rerun.m  本次运行的驱动
  results/f8_work_20261101/pipeline_complete.json     流水线完成记录
  results/f8_work_20261101/numerical_sources_before_confirmation.json  20 文件冻结锁
```

## 附录 B：禁忌清单（速查）

- ❌ 重跑已完成实验（30 / 9 / 15 条）
- ❌ 改门槛、改协议、改冻结锁而不留 diff 记录
- ❌ 删除或合并原暂停确认批
- ❌ 混用开发筛选与独立确认数据
- ❌ 用本次结果论证优先级保护
- ❌ 宣称统计显著性 / 实机优势 / 全局最优
- ❌ 把 PWM 步变当机械损耗
- ❌ 改 `LitePhysicalBias` 门槛
- ❌ 把 F8-D 高度超差归因于分配器
- ❌ 未经验证复制 PX4 代码或参数
- ❌ force push、`git reset` 改 `main`、删分支、打 tag

## 附录 C：术语

| 术语 | 含义 |
|---|---|
| `rankable` | 有资格参与比较（≠ 方法两两可分） |
| `stress` | 未过资格检查，数据保留不排名 |
| `invalid` | 数据/审计失败，不参与比较 |
| `λ`（lambda） | 低优先级需求的缩放系数，`Bu = y_higher + λ·y_lower`，`0≤λ≤1`；**λ<1 表示低优先级被缩放，不是高优先级受限** |
| `beta` | `mode==1` 回退时对高优先级需求的缩放系数（此时 `lambda=NaN`） |
| `mode` | 0 正常 / 1 高优先级回退 / 2 工程兜底 |
| `M0/M2b/M4` | 舵效测试工况，**不是飞行模式** |
| `ideal` / `lite` | 反馈来源（真值 oracle / 简化估计器），**不是物理精度** |
| 主窗 | 悬停 6–16 s；F8 6–50 s |
| 引擎指纹 | `allocation_comparison_engine()` 的 SHA256，覆盖核心数值目录 |
| 冻结锁 | `numerical_sources_before_*.json`，20 个文件的 SHA256 |
| 管理性例外 | 对冻结文件的有记录、有 diff、不改数值的修正 |

## 附录 D：2026-11-01 Codex交付修订

当前工作区有未提交的文档、后处理代码与轻量交付文件，不是干净工作区。两条开发线为祖先关系：main=9918d9d，f8-research=7c5c9ab，差异0/2；用户已决定暂不合并。

本阶段纠正λ收益归因、Pareto表述、DA_NS/WLS逐位相同、偏航相位公式、40列指标和确定性外推。冻结引擎指纹为既有MATLAB记录，本轮以20文件锁和原始结果前后SHA256证明未改动，没有重新计算MATLAB引擎指纹。旧锁和历史证据均不改写。完整核验范围见交付包audit/delivery_checks.json。

## 2026-11-02提交核验补记

用户批准提交F8交付。仅新增包范围的-text与归档补丁-whitespace属性，保留172个交付文件原字节。20个冻结来源、51份原始日志、280个历史文件均核对通过；未重跑仿真。原交接中的“未提交、等待批准”是此前快照，当前Git状态应现场查询。main不合并，后续未提交的PPID/hover代码不包含在本F8交付中。
