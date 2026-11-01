# AGENTS.md — SHC09 MATLAB 项目接手手册（面向 AI 助手）

> **这份文件是干什么的**：让一个没有任何上下文的 AI 助手（chat 端或编码 agent）在读完之后，能准确理解 *这是什么项目、现在做到哪、什么不能说、下一步该干什么*。
> **怎么用**：先读第 0、1 章建立框架；要动手就跑第 3 章；要推进研究直接跳到第 5、6 章；每次行动前过一遍第 9 章的自检清单。
> **更新规则**：第 1–8、10 章是**稳定事实**，改动需谨慎；第 11 章是**易变快照**，每次交付前必须重新核对。不要在这份文件里写"自引用 SHA"，用 `git rev-parse` 现场取。

---

## 0. 三十秒速览

| 问题 | 答案 |
|---|---|
| 这是什么 | SHC09 六舵面涵道风扇的 **MATLAB 仿真试验台**，用同一套模型/控制器比较**五种控制分配器** |
| 不是什么 | 不是 PX4 固件、不是 SITL、不是数字孪生、没有实机验证 |
| 核心问题 | 换成"不完美的状态估计反馈"后，不同分配器到底还有没有差别 |
| 当前答案 | 估计误差约 1.3° 时，分配器对**跟踪**的影响被淹没；主要影响的是**分配代价**（残差更低但舵面活动更大） |
| 已发布版本 | v0.5.0，tag 指向 `3fc46c0`；`main` = `origin/main` = `9918d9d`（已验证基线） |
| 当前分支 | **`f8-research`**（2026-11-01 从 `main` 切出并推送），`main` 未推进，随时可回退 |
| 当前主线 | **F8 平滑八字研究**，已提交并推送到 `f8-research`，未合并到 `main`、未打 tag，暂停在"独立确认 1/15" |
| 下一步 | 把 F8 确认批补到 15/15 → 后处理 → 打包 → 写 `pipeline_complete.json` |
| 最大坑 | 断点续跑会撞上"冻结文件锁 + 不覆盖既有目录"两条断言，见 §6.6 |

---

## 1. 项目是什么

### 1.1 一句话与边界

SHC09 有 **6 个舵面**，但只需要产生 **3 轴力矩**，所以是**过驱动**的：同一组力矩可以由很多种舵面组合实现。**分配器**就是决定"用哪一组舵面"的模块。

平台的设计原则是**只换分配器插件**，物理、控制器、参考轨迹、传感器、PWM 时序全部固定。这样比较的是**分配算法本身**，而不是"谁的控制器调得好"。

**它不是**：PX4 固件、SITL、ULog 生成器、数字孪生、已验证的飞控。
**它是**：一个诚实的、带门禁的、可复现的离线比较实验台。

### 1.2 被控对象

| 项 | 值 | 来源 |
|---|---|---|
| 质量 | `m = 2.1 kg`，`g = 9.788`，重量 `20.5548 N` | `models/shc09/ca_shc09_parameters.m` |
| 惯量 | `diag([0.0438, 0.0436, 0.005006])` kg·m² | 同上 |
| 静态模型最大推力 | 41.70816 N（上界） | 力扫描 |
| 理想保高倾角 | 60.4736°；留 10% 余量 56.7987° | 解析 |
| 悬停实测 | 2100 gf @ 70% 遥控杆量 | 用户提供，**不是**归一化推力 |
| 真实最大推力 | **未知**，未实测 | — |
| 气动数据 | `models/shc09/reference/duct_raw.mat`、`wing_raw.mat`，冻结，域外只记 NaN 不外推 | — |

> **最常见的误读**：70% 是**遥控器杆量**，不能当推力百分比或转速百分比，也不能据此推断最大推力。

### 1.3 五种分配器

`allocators/registry.m` 是**唯一注册表**。`PCA` 指"优先级控制分配"，**不是主成分分析**。

| 编号 | 名称 | 一句话 | 关键文件 |
|---:|---|---|---|
| 1 | `DA_NS` | 直接分配 + 零空间 | `allocators/da_ns/ca_da_ns.m` |
| 2 | `WLS` | 加权最小二乘（带有效集） | `allocators/wls/ca_wls.m` |
| 3 | `DCA` | 动态控制分配，预测下一拍可达 | `allocators/dca/ca_dca.m` |
| 4 | `PCA_STATIC` | 静态优先级：先保关键方向，再最小范数恢复 | `allocators/pca_static/ca_dp_lpca.m` |
| 5 | `PCA_PREDICTIVE` | 在静态 PCA 上考虑舵机保持/等待，预测终点 | `allocators/pca_predictive/ca_priority_core.m` |
| — | `EXAMPLE_PINV` | 插件接口示例，不参与研究 | `allocators/example_pinv/` |

`main(n)` 的编号就是上表编号，`main(5)` = 预测 PCA。

### 1.4 反馈模式 `ideal` / `lite` / `px4_ecl`

**它们不是"物理理想 vs 简化物理"，而是"控制器拿到的状态反馈从哪来"。**

| 模式 | 控制器看到什么 | 定位 | 现状 |
|---|---|---|---|
| `ideal` | 真实姿态/位置直接透传 | 零估计误差的 **oracle**、冻结回归、隔离分配器差异 | **平台默认**；不是现实反馈 |
| `lite` | 陀螺/加计/磁计/气压/GNSS → Mahony/互补滤波级估计器 | 近似现实的估计反馈 | **experimental**；可比较，但偏置门禁仍失败 |
| `px4_ecl` | 官方 PX4 ECL 归档桥接 | 可选交叉验证 | 需 JVM + `build_px4_ecl_bridge.m`，非主路径 |

**`lite` 不是 EKF2**，只是简化估计器，不能当 PX4 导航质量的代表。
**`LitePhysicalBias` 门禁是 0.05 °/s，实测约 0.061 °/s，一直失败且没有放宽** —— 这是已知预期失败，不是待修 bug。

### 1.5 工况 `M0` / `M2b` / `M4`

**它们是舵效测试工况，不是飞行模式，不是难度等级。**

| 工况 | 舵增益 | 舵映射 | 用来回答什么 |
|---|---|---|---|
| `M0` | 全 1 | `linear` | 名义健康飞行器上，五方法差多少 |
| `M2b` | `[1.2, 1, 0.8, 1, 1.2, 1]` | `linear` | **行空间**舵效失配下还能不能稳住 |
| `M4` | 全 1 | `tanh`，拐点 28° | 大命令非线性饱和压力；lite 在 0.4/0.5/0.6 都未过门禁，**不进主比较** |

`M1/M2/M3` 是更早的失配阶梯，只在历史文档里（`ca_mismatch_protocol` 里仍有定义）。

> **高频误读（`README.md` 旧版曾如此表述，2026-11-01 已修订）**：`vane_saturation_deg = 28` **只在 `tanh` / `stall` 映射里被消费**（`models/shc09/ca_shc09_aerodynamics.m:52-59`），`linear` 映射下 `effective_delta = delta`、`slope = 1`，28° **完全不起作用**。所有工况真正的硬限是 `p.cm = deg2rad(40)`（同文件第 7 行），分配器命令边界 `model.command_upper = ±40°`。
> 因此 `M0/M2b/F8` 的真实舵角上限是 **40°**，不是 28°。M4 才是 28° 拐点的 tanh。

悬停协议固定：总时长 20 s，2 s 加载偏航扰动，16 s 卸载，**主窗 6–16 s**，`0.6` 负载 = 外部偏航扰动约为**名义偏航能力的 60%**（不是电机负载）。

---

## 2. 代码地图

### 2.1 目录职责

```text
根目录/            main.m、shc09_run.m、ca_setup.m、run_*_tests.m、CHANGELOG.md、HANDOFF.md、本文件
apps/              现行入口；experimental/ 实验入口；legacy/ 旧 main_* 研究入口
platform/          总线、调度、模块、仿真、日志 —— 平台骨架
models/            SHC09 物理、气动、参数；reference/ 是冻结原始气动表
allocators/        五种分配器 + 插件接口 + registry
configs/           参数、预设、比较选择、F8 机器协议（JSON 是唯一数值来源）
experiments/       固定研究协议（F8、失配、八字搜索等）
analysis/          指标、绘图、日志导出、完整性工具
tests/             测试、夹具、冻结基线
docs/              guides/ reference/ history/ releases/ validation/ evidence/
examples/          随仓库分发的**轻量**结果（可进 Git）
results/           本机重型结果与缓存 —— **不进 Git**，保留旧证据
archive/           本机历史副本与运行日志 —— 不参与当前构建
third_party/       归档上游源码及许可
.tmp_matlab/       MATLAB 临时工作区，可删
build/             桥接编译产物，可删
```

**`ca_setup()` 只把显式列出的源码路径加入 MATLAB path**，不把整个仓库加进去，也不会加入 `archive/`。这是刻意的：`archive/` 里有大量同名函数副本。

### 2.2 一次仿真是怎么跑起来的

```text
ca_setup()                      显式加路径 + 注册插件
  └─ 配置构造（如 ca_mismatch_protocol / ca_f8_protocol / ca_figure8_search_protocol）
       └─ ca_validate_config      私有真实参数不得进入名义分配模型
       └─ ca_model(cfg)           名义模型；effectiveness_for_model 派生分配用 B
       └─ ca_reference(cfg)       参考轨迹（位置/速度/加速度/姿态/偏航）
       └─ ca_prepare_experiment   预生成噪声/扰动序列（同种子跨方法完全一致）
       └─ allocation_comparison_hash({c,ref,experiment})   输入签名
  └─ ca_simulate(model,cfg,ref,method,experiment)
       └─ shc09_runtime → bus + scheduler
       └─ 每拍：传感器 → 估计器(ideal/lite) → position → attitude → rate
                → control_allocator（调用 registry 中的插件）→ actuator_output
                → ca_plant_step（真实物理，含舵机动态失配）
       └─ 返回 L：时间序列 + topic_log（真值 topic 必须缺席）
  └─ 评价：f8_evaluate_run / allocation_comparison_* / 各 app 的产品函数
```

**关键不变量**：
- 同一 `seed` 下，五种方法共用**完全相同的**参考、初态、噪声与扰动序列；
- 分配器只能看到 `state.delta_hat`（估计舵角），**不能看真值**；
- `L.topic_log` 里出现 `plant_truth` / `sensor_attitude` / `sensor_local_position` 即判 `ca:F8TruthAudit` 失败。

### 2.3 关键入口

| 入口 | 签名 | 用途 |
|---|---|---|
| `main.m` | `main(allocator_flag, overrides)` | 单方法，内部转 `main_comparison` |
| `shc09_run.m` | `shc09_run(overrides)` | 平台版单次运行 |
| `apps/main_comparison.m` | `main_comparison(o)` | 五方法同参考比较（常用） |
| `apps/allocation_comparison_app.m` | `allocation_comparison_app('Name',Value)` | **标准比较入口**，带门禁/效应量/Pareto |
| `experiments/run_f8_comparison.m` | 见文件头 | F8 基础两场景 × 五方法 × 三种子 |
| `experiments/run_f8_pressure_study.m` | `(stage, 'Name',Value)` | F8 压力筛选/确认，`stage` ∈ `"screen"`/`"confirm"` |
| `run_project_tests.m` | `run_project_tests(include_navigation, test_names)` | 旧 14 项 |
| `run_platform_tests.m` | `run_platform_tests()` | 平台 6 项 |

`allocation_comparison_app` 的可选参数：`cases`（`"auto"`/`M0`/`M2b`/`M4`）、`modes`（`ideal`/`lite`）、`seeds`、`methods`、`m4_load`、`use_cached`、`reuse_from`、`output_tag`、`smoke_test`、`fail_fast`。

### 2.4 分配器插件接口

```matlab
% registry 里的每一项
struct('name',"DA_NS", 'directory',"allocators/da_ns", ...
       'allocate',@da_ns_allocate, 'manifest',@da_ns_manifest)

% allocate 只接收统一上下文
[command, info] = da_ns_allocate(ctx)
%   ctx.demand.v_h, ctx.demand.v_c   —— 需求力矩
%   ctx.model.B                      —— 名义效能矩阵
%   ctx.state.delta_hat              —— 估计当前舵角
%   ctx.timing / ctx.config
%   info = allocator_info(info)      —— 统一信息结构
```

`*_manifest.m` 声明输入契约与是否使用执行器状态（`allocator_manifest(name, inputs, uses_actuator_state)`），**不读配置真值**。

### 2.5 新增一个分配器

1. 在 `allocators/<name>/` 下写 `*_allocate.m` + `*_manifest.m`；
2. 在 `allocators/registry.m` 的 `entries` 里加一行；
3. **不要**改 `ca_setup`（它按 registry 自动加路径）；
4. 加测试；如需进入正式比较，还要同步 `allocation_comparison_app` 的 `allowed` 白名单与 `apps/main_comparison.m` 的方法列表。

---

## 3. 运行与测试

### 3.1 环境

| 项 | 值 |
|---|---|
| MATLAB | R2025b，`E:\Matlab\R2025b\bin\matlab.exe`（`matlab` 已在 PATH） |
| 工具箱 | Optimization Toolbox（PCA/WLS 的 LP 需要） |
| 仓库 | `E:\Ducted-Fan-SHC09-matlab` |
| 规模 | 15770 个文件、约 16.2 GB；`results/` 15.1 GB、`archive/` 1.0 GB、`docs/` 19 MB；5545 个 `.m` |

> 仓库很大，**不要**盲目递归遍历；用 `glob`/`grep` 带目录限定。

### 3.2 最小验证（五分钟）

```matlab
ca_setup;
o = shc09_airframe("lite");
r = main(5,o);              % 预测 PCA，两秒
all = main_comparison(o);   % 五方法，相同参考与噪声
```

**默认不落盘**。要落盘必须同时设 `save_results=true` 和**新的** `output_tag`。

### 3.3 测试清单与预期

| 命令 | 预期 | 备注 |
|---|---|---|
| `run_project_tests(false)` | **14/14 通过** | 会写 `results/validation/project_tests.csv` |
| `run_platform_tests` | **6/6 通过** | 只打印，不落盘 |
| `test_platform_baseline` | 6 组冻结日志逐位一致 | 最大差应为 0 |
| `run_estimator_tests` | **预期在 `LitePhysicalBias` 失败** | 0.061 °/s > 0.05 门限，**不要修** |
| `test_allocation_comparability` / `test_allocation_comparison` | 通过 | 门禁与缓存逻辑 |
| `which main_mismatch_ladder` 等 | 解析到 `apps/legacy` | 旧名兼容 |
| `python tools/check_docs_links.py` | 0 断链 | 文档改动后必跑 |

> 最近一次记录（HANDOFF，2026-11-01 09:00 左右）：14/14、6/6、6 组基线一致。
> **本次接手未复跑**——写这份文件时只做了只读核对。动手前建议先复跑 `run_project_tests(false)` + `run_platform_tests`。

### 3.4 已知的"预期失败"

- `LitePhysicalBias`（约 0.061 °/s vs 0.05 门限）—— 门槛不放宽，`lite` 保持 experimental。
- 不要因为看到这个失败就"顺手修一下"。改了它就等于改了已发布协议。

---

## 4. 数值完整性：两道锁（**最容易踩坑的地方**）

这个项目用**两个不同机制**保护数值可复现性，覆盖范围**不一样**。

### 4.1 第一道锁：`allocation_comparison_engine(root)`

对以下目录的所有 `*.m` 求联合 SHA256：

```
platform/ allocators/ effectiveness/ models/ drivers/ lib/ configs/ modules/ compat/
+ experiments/ca_mismatch_protocol.m      ← 只此一个 experiment 文件
+ models/shc09/reference/duct_raw.mat、wing_raw.mat
```

当前记录指纹：`e8d0c32c3faee85b60dee14c6fc653f3e1155a10630b3b3a352ba933942603f8`

**⚠️ 它不覆盖 `experiments/` 的其它文件和整个 `analysis/`。**
所以改 `experiments/ca_f8_protocol.m`、`analysis/f8_evaluate_run.m` 之类**不会**让引擎指纹变化——缓存不会失效，但你的结果已经在数值上不可比了。

### 4.2 第二道锁：`numerical_sources_before_*.json`

`results/f8_work_20261101/` 下有一组显式锁文件，列出 **20 个文件**的 SHA256：

- `numerical_sources_before.json`（F8 正式批次前）
- `numerical_sources_before_pressure_v2.json`（压力 v2 前）
- `numerical_sources_before_confirmation.json`（**当前生效**，确认批前）

当前锁包含 20 项，其中 `experiments/run_f8_pressure_study.m` 锁在
`c5d77f38f73e43c9b6da525b8de890b482eda31e711adfb4434a2356623c59f4`。

**只读核对结果（本次接手已验证）：20/20 全部与磁盘一致。**

### 4.3 改代码的正确姿势

1. **先跑只读核对**：比对锁文件 SHA 与磁盘，确认起点一致；
2. 改之前先备份/记录 `old_sha256`；
3. 生成**精确 unified diff** 落盘成 JSON（参照 `results/f8_work_20261101/development_failure_guard_correction.json` 的格式）；
4. 明确声明"数值代码是否改变""门槛是否改变""选择规则是否改变"；
5. 更新锁文件里对应的 SHA，其它项**必须逐一断言未变**；
6. 如果改了"冻结期之后才允许改"的文件，必须同时写清**为什么这不是结果导向的放宽**。

> 已有一个先例：`development_failure_guard_correction.json` 记录了 `run_f8_pressure_study.m` 的单行修正（允许未选中候选保留 `failed`，但所选候选仍须 3 条完整、确认仍须 15/15）。这是**管理性例外**，不是数值改动。

---

## 5. 比较门禁与"能说什么"

### 5.1 悬停比较（M0/M2b/M4）的门禁

只有全部满足才叫 `rankable`：

- 五种方法 × 全部请求种子都完成；
- 主窗内每条轨迹舵面**饱和 ≤ 10%**；
- 主窗内每条轨迹**真实姿态峰值 ≤ 5°**；
- **气动表越界 = 0**；
- `lite` 还要**估计姿态 RMS ≤ 2°**。

**按每条轨迹、每个方法、每个种子的最坏值检查，不拿平均值放宽。**

| 标记 | 含义 |
|---|---|
| `rankable` | 有资格比较；**不等于**五方法两两可分，**不等于**统计显著 |
| `stress` | 未通过资格检查；数据保留但**不排名** |
| `invalid` | 气动越界、数据非有限、缓存/真值隔离审计失败；不参与比较 |

`60/60` = 2 工况 × 2 反馈 × 5 方法 × 3 种子。三种子**只描述本批差异和波动，不是 p 值/置信区间/显著性**。

### 5.2 效应量与 Pareto

- **效应量** = 方法间极差 ÷ 种子波动；≥ 1 才标 `distinguishable`，**不是**显著性检验；
- **Pareto** = PWM 活动 vs 跟踪误差等二维权衡；**没有单一总分**；
- `not_distinguishable` = 在这批数据里分不开，**不是**"证明完全一样"。

### 5.3 F8 的门禁（**全新的一套，不要和悬停混用**）

F8 明确**不复用**悬停的 5°/10% 门禁。它把四件事分开评价：

| 维度 | 判据 | 字段 |
|---|---|---|
| 数据有效 | 全状态有限 且 气动越界 = 0 | `valid_data` |
| 飞行包线 | 见下表 | `flight_envelope_passed` |
| 任务跟踪 | 见下表 | `tracking_requirements_passed` |
| 优先级激励 | 另需**独立几何审计** + ≥2 个种子 | `priority_*` |

**包线上限**（`configs/f8_protocol_v1.json` → `envelope`）：

| 项 | 上限 |
|---|---:|
| 真实合成倾角 | 45° |
| 命令舵角 | 40° |
| 真实舵角 | 40° |
| 真实舵速 | 600 °/s |
| 电机命令静态推力比 | 0.9 |

> **注意**：包线只是**研究上界**，不是实测飞行许可。其中 40° 舵角是真**唯一会生效**的物理硬限（`p.cm`），28° 只对 M4 的 `tanh` 有意义，详见 §1.5 注。F8-R 的 `command_limit_occupancy_percent` 实测为 0，说明命令并未普遍触限。

**任务跟踪要求**（`tracking_requirements`，逐条轨迹判，跑完不放宽）：

| 指标 | 上限 |
|---|---:|
| 水平位置 RMS | 0.5 m |
| 水平位置峰值 | 1.5 m |
| **高度 RMS** | **0.2 m** |
| 高度峰值 | 0.5 m |
| 速度 RMS | 0.5 m/s |
| 航向 RMS | 5° |
| 航向峰值 | 15° |
| 内环姿态跟踪 RMS | 5° |
| 内环姿态跟踪峰值 | 20° |
| 估计姿态 RMS | 2° |

**优先级证据门槛**（`priority_evidence`）：`λ` 容差 `1e-6`、累计缩放 ≥ `0.1 s`、单次最长 ≥ `0.02 s`、至少 `2` 个种子、高低优先级夹角 ≥ `15°`。

> **即使激励条件满足，也只允许讨论"当前场景下的优先级作用"，不证明 PCA 普遍更优。**

---

## 6. 当前主线：F8 平滑八字研究

### 6.1 协议链（三份，逐层叠加）

```text
F8-v1.0        configs/f8_protocol_v1.json          ← 基础：两场景 × 五方法 × 种子 101–103 = 30 条
  ├─ F8-P-v1.0 configs/f8_pressure_protocol_v1.json ← 未执行，已被 v2 取代（保留）
  └─ F8-P-v2.0 configs/f8_pressure_protocol_v2.json ← 有限偏航压力：开发 9 条 + 确认 15 条
```

协议哈希：`a53cfd39757a9bd52ecd8343e0174e6f8e4d66a2674b875c45546dc7a75228ce`（F8-v1，被 v2 引用为 `base_protocol_hash`）。

**F8 是"写定后跑"，不是"跑完追认"。** v2 是**公开披露的自适应设计**：因为 F8-D 出现公共高度瓶颈，才把压力试验的位置基线换成已 15/15 合格的 F8-R。这个变更发生在**任何压力轨迹仿真之前**，有 `status`/`reason` 字段和文档记录，**不追认为预注册**。

### 6.2 固定条件

| 项 | 值 |
|---|---|
| 仿真时长 | 52 s（主窗 `[6,50]`，巡航 `[10,46]`，相位斜坡 4 s） |
| 高度 | −10 m（NED 下为负） |
| 位置参考 | N/E 半幅 3 / 1.5 m，平滑运动时钟 |
| F8-R | 周期 20 s，偏航 20°·sin |
| F8-D | 周期 10 s，偏航 35°·sin + 8°·sin3 |
| 工况 | `M2b`，负载 0.6，线性舵映射（真实硬限 40°，见 §1.5 注） |
| **执行器失配** | 真实 τ = `[24,27,30,33,36,40]` ms，模型 τ = 30 ms —— **未实测的假设** |
| 估计器 | `lite`，**显式开启** GNSS 速度辅助 |
| 前馈 | 显式开启速度/加速度 + 名义几何角速度/角加速度前馈 |
| 反馈增益 | `pos [1.3,1.3,1]`、`vel [3.2,3.2,2.1]`、`att 8`、`rate 12` |
| 限幅 | 倾角 45°，静态推力比 0.9 |

**前馈全部来自已知计划轨迹的解析导数**，不做数值微分，不读对象真值，不读未来传感器。

> F8 的 `ref` 由 `experiments/ca_f8_reference.m` 生成：九次相位速度多项式保证位置到四阶导数连续，正弦导数用截断泰勒递推。`ca_f8_protocol` 里先调 `ca_figure8_search_protocol('F14_A2_Y20',seed,true)` **只借它的 cfg/model**，参考随后被整体覆盖。

### 6.3 三阶段状态（**交接时的断点**）

| 阶段 | 目录 | 状态 |
|---|---|---|
| 基础 F8-v1 | `results/f8_v1_formal_20261101_frozen_3seeds` | **30/30 完成，0 运行失败** |
| 开发筛选 F8-P-v2 | `results/f8_pressure_screen_20261101_Rbase_v2_bounded_yaw` | **9 次尝试全部落盘：6 完成、3 失败** |
| 独立确认 | `results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds` | **1/15**（仅 `DA_NS`/seed 201） |

**基础批次的实际通过率**（`task_metrics.csv` 实测）：

| 场景 | 运行 | 通过全部任务要求 | 说明 |
|---|---:|---:|---|
| F8-R | 15/15 | **15/15** | 但 `priority_excitation…` = **false**，缺优先级激励 |
| F8-D | 15/15 | **5/15** | 仅 seed 103 的 5 条通过；seed 101/102 全部高度 RMS 超标 |

**F8-D 失败根因**（离线力分解，`results/f8_work_20261101/F8D_DANS_s101_outer_diagnosis.json`）：

- 真实高度 RMS `0.2281 m` vs 门槛 `0.2`；
- 高度估计均值偏差仅 `−0.0154 m`（估计器基本无辜）；
- **来流气动相对静态推力映射的向下缺口 `0.2248 m/s²`** —— 这是**公共推力控制瓶颈**；
- 电机滞后仅 `−0.0008 m/s²`，姿态投影 `−0.0099 m/s²`；
- 力分解闭合误差 `1.7e−15`（分解自洽）；
- 该分解**不是闭环反事实**，不据此改控制器或门槛。

> **绝对不能**把 F8-D 的高度超差包装成"某个分配器更差"。

### 6.4 开发筛选的结论与边界

**3 次失败不是 bug**：`ca:AeroTableDomain`，迎角超出参考气动表（108.95° / 113.78° / 119.95°），失败 JSON 完整保留在各自 `failures/`。

**唯一入选候选 `F8PR-Y60-F075`**（60° / 0.75 Hz），开发种子 9002：

| 指标 | 值 | 含义 |
|---|---:|---|
| 航向 RMS 改善 | **−49.06%** | 降低 |
| 水平位置 RMS 改善 | **+1.77%** | **反而变差**，但在 5% 容差内 |
| 实际主窗舵速比 | ×1.026 | 代价合格（门槛 ×2） |
| 实际总行程比 | ×1.031 | 代价合格（门槛 ×2） |
| PWM 步变比 | **×6.88** | 只报告，**不等于机械损耗/能耗** |
| 参考峰值偏航角速度 | 282.74 °/s | 平局时按此最小者选 |
| 参考峰值偏航角加速度 | 1332.40 °/s² | 次级平局判据 |

另外两个候选 `F8PR-Y60-F100`、`F8PR-Y75-F100` 的 `promising = 0`，`NaN` 指标保留。

> **该组开发主窗 λ 全程为 1**，没有持续缩放，因此**不能宣称受限优先级保护**。
> **开发筛选有目标选择偏差**，不能当成独立确认或泛化证据。

### 6.5 确认批现状

`results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds/F8PR-Y60-F075/`：

- `status.csv`：15 行 = 1 `completed`（`DA_NS`/201）+ 14 `not_run`；
- 唯一完成的 `DA_NS`/201：水平 RMS `0.330156 m`、航向 RMS `1.18017°`、高度 RMS `0.110733 m`，`run_task_passed = 1`；
- **`WLS`/201 被用户"先暂停"打断，未产生任何文件**（日志停在 `F8_PRESSURE_RUN confirm F8PR-Y60-F075 seed201 WLS`，没有对应的 `F8_PRESSURE_DONE`）；
- 该中断**既不是模型运行失败，也不是完整轨迹**——不要写进 `failed`，也不要计入完成。

确认日志：`archive/logs/f8_confirmation_20261101.log`。
中断发生时**没有遗留 MATLAB 进程**（已核实）。

### 6.6 断点续跑的技术障碍（**动手前必读**）

**障碍**：`experiments/run_f8_pressure_study.m:14`

```matlab
out = fullfile(root,'results','f8_pressure_'+stage+'_'+string(o.output_tag));
assert(~isfolder(out),'不覆盖既有压力试验。');   % ← 目录已存在，直接断言失败
mkdir(out);
```

所以**直接重跑 `finish_f8_confirmation.m` 会立刻被拒绝**。

**更麻烦的是**：这个文件在 20 文件冻结锁里（`c5d77f38…`），而 `finish_f8_confirmation.m:13-17` 会在跑之前逐文件核对 SHA。改了它，锁就对不上。

**两个方案（需要用户拍板，不要自行选）**：

| 方案 | 做法 | 代价 |
|---|---|---|
| **A（改锁内文件）** | 加 `resume_from` / `allow_existing` 参数：目录存在时读回已有 `status.csv` / `task_metrics.csv` / `state_metrics.csv` / `provenance.csv`，只补 `not_run` | 需按 §4.3 出具**管理性例外**记录（exact diff + 更新锁 + 声明数值代码未变）；有 `development_failure_guard_correction.json` 先例 |
| **B（不动锁文件）** | 在 `results/f8_work_20261101/` 另写续跑驱动，复用 `ca_simulate` / `f8_evaluate_run` 等 | 不碰锁，但会复制一部分批处理逻辑，有**逻辑漂移风险**，且要自己保证与 A 完全等价 |

**无论哪个方案，都必须**：
1. 先核对 20 文件 SHA + 引擎指纹；
2. 保留已有的 `DA_NS`/201 完整日志（`logs/DA_NS_s201.mat`，55.6 MB）与指标，**不重跑、不覆盖**；
3. 不删除确认目录、不伪造缓存、不改保留种子；
4. 新增输出必须走**新目录**或明确的"只补 not_run"路径。

### 6.7 剩余工作（精确链路）

```text
① 续跑确认批                       → 15/15 completed（约需 0.8 GB 磁盘）
② test_f8_comparison_results(dir)  → independent_checks.json + independent_run_checks.csv
   断言：15 条、15 行 status、720 行 state_metrics、15 行 provenance、finish 全 52 s/41601 点
③ f8_allocation_diagnostics(dir)   → allocation_truth_diagnostics.csv + independent_priority_lp.csv
                                      + allocation_diagnostics_checks.json
④ python tools/plot_f8_comparison.py <dir>
                                   → aggregate_metrics.csv、paired_pca_deltas.csv、
                                     tracking_phase.csv、task_requirement_failures.csv（有失败才写）、
                                     report.md、figures/（≥7 PNG）
⑤ 写 pipeline_complete.json        ← 目前**不存在**，`finish_f8_confirmation.m:25-33` 负责生成
⑥ python results/f8_work_20261101/package_results.py
                                   → examples/f8_comparison_20261101/  ← 目前**不存在**
```

`package_results.py` 会自检：每个数据集 `independent_checks.json` 的 `formal_logs_verified == 15`、`figures/` 至少 7 张 PNG、`allocation_truth_diagnostics.csv` 存在。缺任何一项就断言失败。

> `finish_f8_confirmation.m:19` 会再跑一次 `f8_pressure_development_diagnostics(screen)`。该函数**是幂等的**：只会确定性地覆盖 `development_priority_summary.csv`、`development_priority_trace.csv`、`development_priority_checks.json` 和那张 λ/β 图，不会误判。

---

## 7. 治理硬约束（**违反即返工**）

1. **不覆盖已有结果目录**。所有入口都要求新的 `output_tag`，并被正则限制为 `^[A-Za-z0-9_-]+$`。
2. **不改门槛、不按结果回头挑场景或种子**。参考或门槛要变，必须**另立协议版本**。
3. **不宣称统计显著性**。没有 p 值、置信区间、多重比较校正。三种子只描述本批波动。
4. **不把 `rankable` 说成"五方法两两可分"**，也不说"DCA 实机最好"。
5. **不把悬停 5°/10% 门禁套到 F8**。
6. **不删除 `results/`、`archive/` 里的旧证据**，不 `git clean` / `git reset`，不删分支。
7. **不把 PWM 步变当机械损耗或能耗**；它与真实舵速是**不同量**。
8. **不把 F8-D 高度超差说成分配器优劣**。
9. **不改 `LitePhysicalBias` 门限**，不宣称该问题已修复。
10. **不读外部目录** `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`（明确禁区）。
11. **`lite` 保持 experimental，默认仍是 `ideal`**。
12. 未提交工作**不打 tag、不 push**，除非用户明确要求。

---

## 8. 已知限制与"不可宣称"清单

### 8.1 限制

| 限制 | 具体 |
|---|---|
| 无实机标定 | 模型来自参考方程 + 气动表；源码一致 ≠ 实机标定 |
| 无 HIL | 没做过硬件在环 |
| 陀螺/计算附加延迟 | **0**，结果偏乐观 |
| `lite` 不是 EKF2 | Mahony/互补滤波级，偏置门禁未过 |
| 执行器参数未实测 | F8 的 24–40 ms vs 30 ms 是**假设**，不是标定值 |
| 气动域有限 | 45° 部分来流方向不在模型域；4544 组合扫描中 302 组合域外，只记 NaN |
| 最大推力未知 | 只有 2100 gf @ 70% 杆量这一条实测线索 |
| 三种子 | 只描述本批差异与波动 |

### 8.2 不能说的话

- ❌ "PCA 优于 WLS" / "DCA 最好" / "某方法显著更好"
- ❌ "F8 研究已全部完成"（确认批才 1/15）
- ❌ "PCA 优势已重复验证"（开发筛选有选择偏差）
- ❌ "受限优先级保护已被证明"（该组 λ 全程 = 1）
- ❌ "F8-D 表明某分配器更差"（是公共推力瓶颈）
- ❌ "`lite` 已可替代 `ideal`"
- ❌ "这是飞控实现 / 数字孪生 / 已验证的飞行包线"

### 8.3 文档修订记录（2026-11-01 已处理）

接手时发现两处文档与事实不符，**均已修订**，留此记录以免后人再次误读：

| 位置 | 原说法 | 实际情况 | 处理 |
|---|---|---|---|
| `README.md` §3 工况表 | 「M0/M2b 线性舵机，28° 饱和」 | `linear` 映射下 `vane_saturation_deg` **不生效**，真实硬限是 `p.cm = 40°` | 已改为「舵角硬限 40°」，`M4` 标注「tanh 拐点 28°」，并加一段说明区分两者。**未改任何代码** |
| `docs/validation/f8_protocol_v1/report.md`、`checks.json` | 「正式结果为 0/30」「`formal_runs_completed: 0`」 | 那是**跑前快照**；正式批次实际 30/30 完成（F8-R 15/15 通过、F8-D 5/15） | 已加顶部/字段级**范围声明**，指向真实结果与 `HANDOFF.md`。**原始数值与当时结论一字未改**，符合"不改写历史结论"的既有约定 |

> 附带核实：`docs/guides/figure8_lite_comparison.md`、`docs/guides/allocation_comparison_guide.md` 中关于 28° 的表述**本来就是正确的**，`README.md` 是唯一错处。
> 发现新的不一致时，**先核实代码、再修订文档并记入本表**，不要静默改动历史结论。

---

## 9. 常见陷阱

| 陷阱 | 说明 |
|---|---|
| **引擎指纹不等于全仓指纹** | 只覆盖核心数值目录 + `ca_mismatch_protocol.m`。改 `experiments/` 其它文件或 `analysis/` **不会**让指纹变化，但会让结果不可比 |
| **`archive/` 里有同名函数副本** | `ca_setup` 不加 `archive/` 路径；但用绝对路径 `addpath` 会静默覆盖 |
| **CSV 是 UTF-8** | PowerShell 默认编码读中文会乱码，必须 `Get-Content -Encoding utf8` |
| **`run_project_tests` 会写文件** | 写 `results/validation/project_tests.csv`，不是纯只读 |
| **`results/` 不在 Git** | 16 GB 的重型结果全在本地，Git 只有代码与轻量证据 |
| **`.tmp_matlab/` 536 个文件** | MATLAB 临时工作区，可删但不要当源码 |
| **门禁按最坏值判** | 不要用均值/中位数去"证明通过" |
| **`ca_setup` 返回仓库根** | 很多脚本第一行 `root=ca_setup()`，它同时完成加路径 |
| **`assert` 被吞** | 批处理里 `try/catch` 会把断言变成 `failed` 记录，看 `error_id` 才知道是门槛还是崩溃 |

---

## 10. 文档分工与阅读顺序

| 文档 | 类型 | 用途 |
|---|---|---|
| `AGENTS.md`（本文件） | **当前** | AI 接手全貌 + 推进指导 |
| `README.md` | 当前 | 给人看：项目是什么、怎么跑、结果怎么读 |
| `HANDOFF.md` | **当前** | 断点状态与停止边界 —— **与本文 §6.3、§11 冲突时以 HANDOFF 的最新日期为准** |
| `docs/README.md` | 当前 | 按"我想做什么"导航 |
| `docs/repository_map.md` | 当前 | 目录地图 |
| `docs/reference/f8_protocol.md` | 当前 | F8-v1 协议正文 |
| `docs/reference/f8_pressure_protocol_v2.md` | 当前 | F8-P-v2 自适应设计与理由 |
| `docs/guides/allocation_comparison_guide.md` | 当前 | 门禁、效应量、Pareto 怎么读 |
| `docs/guides/lite/README.md` | 当前 | lite 阅读顺序 |
| `docs/validation/f8_protocol_v1/report.md` | **跑前快照** | 已加顶部范围声明：其中"正式结果 0/30"是**运行前**记录，30/30 见 `results/`；指针指向 `HANDOFF.md` |
| `CHANGELOG.md` | 历史 | 版本差异 |
| `docs/history/` | 历史 | 保留当时结论，不是当前依赖 |

---

## 11. 现状快照（**易变——行动前必须重新核对**）

> 记录时间：2026-11-01 17:5x（Asia/Shanghai）。以下每一项都在写本文时实测。

### 11.1 Git

| 项 | 值 | 核对命令 |
|---|---|---|
| 工作分支 | **`f8-research`**（当前，2026-11-01 从 `main` 切出并推送） | `git branch --show-current` |
| `main` / `origin/main` | `9918d9d` —— **刻意未推进**，作为可回退基线 | `git rev-parse main origin/main` |
| 发布 tag | `v0.5.0` → `3fc46c0247fea6e82c95e38721f56fa256bf3b72` | `git rev-parse 'refs/tags/v0.5.0^{}'` |
| 工作区 | 应为**干净** | `git status --short` |
| HEAD | 现场取，**本文不写死**（写了就会自相矛盾） | `git rev-parse HEAD` |

分支拓扑：`f8-research` = `main` + 承载全部 F8 工作的提交，已推到 `origin`。
回退方式：`git switch main` 即回到已验证的 `9918d9d`；**不要**用 force push 或 `git reset` 改 `main`。

该提交包含：
- 49 个新增的 F8 源码/协议/测试/工具/文档/示例；
- 8 个平台与配置文件改动（净增 87 行删 7 行），核心是**可选**的 F8 前馈与 lite GNSS 速度辅助，**默认全部关闭**，旧路径逐字保留；
- `README.md` 文档修订（增 6 删 2）；
- 新增 `AGENTS.md`。

> 关于换行：提交时 Git 对 10 个文件报 `CRLF will be replaced by LF`（`.gitattributes` 的 `eol=lf`），这是既有约定，不是内容改动。

### 11.2 只读核验结果（本次接手已做）

| 检查 | 结果 |
|---|---|
| 20 文件冻结锁 SHA vs 磁盘 | **0 处不符** |
| 确认/筛选目录内 `base_protocol.json`、`frozen_protocol.json` vs `configs/` | **逐字节相同** |
| MATLAB 进程 | **无残留** |
| 磁盘 | E: 余 **74.5 GB** / 212.9 GB |
| 单次确认运行体积 | ≈ **56.6 MB**（日志 55.6 + 轨迹 3.6 + 指标），15 条约 **0.8 GB** |
| 引擎指纹 | 记录值 `e8d0c32c…603f8`，**未复算** |
| 回归测试 | **本次未复跑** |

> **环境备注（非仓库内容）**：本会话修复过两次 Windows 文件权限 —— 一次在 `E:\Ducted-Fan-SHC09-matlab`，一次在 `E:\Ducted-Fan-SHC09-matlab\.git`，都是"目录缺少当前用户的权限项、导致 DSH 沙箱无法写入"。只改了文件权限，**没有**改文件内容、所有者或仓库对象。
> 备份与回滚脚本在 `C:\Users\32450\dsh-acl-recovery\`（每次修复各一对 `acl-backup-*.json` / `.json.ps1`）。
> 注意：沙箱的执行进程是受限令牌，**只能匹配按 SID 授予的权限项**，所以按组（`Authenticated Users` 等）继承的权限对它无效 —— 这就是 `.git` 表现为"看起来 Everyone 可写、实际写不进"的原因。

### 11.3 缺失产物

- `results/f8_work_20261101/pipeline_complete.json` —— **不存在**
- `examples/f8_comparison_20261101/` —— **不存在**

两者都是"研究尚未收尾"的直接证据。**不得**在它们存在之前宣称 F8 研究完成。

---

## 12. 决策点（需要用户拍板）

| # | 决策 | 选项 | 影响 |
|---|---|---|---|
| 1 | 确认批断点续跑怎么实现 | **A** 改 `run_f8_pressure_study.m` + 管理性例外记录 / **B** 另写续跑驱动 | A 更稳但动锁；B 不动锁但有漂移风险 |
| 2 | 是否先复跑回归（14/14、6/6、引擎指纹） | 是 / 直接续跑 | 复跑约数分钟，能提前发现环境漂移 |
| 3 | F8-D 高度瓶颈是否另立新研究 | 现在不做 / 另立协议 | 改门槛需**新协议版本**，不能就地放宽 |

> **已结项**：原第 2 项「`docs/validation/f8_protocol_v1/` 的 `0/30` 怎么处理」已于 2026-11-01 按"标注为跑前快照"完成，见 §8.3。

---

## 13. AI 助手自检清单（每次回答前过一遍）

1. 这个数字是**实测**的，还是我从文档里复述的？两者要分开说。
2. 我引用的路径**真实存在**吗？（不确定就先 `glob`/`read`/`Test-Path`）
3. 我的结论有没有把 `rankable` 说成"可分"、把开发筛选说成"确认"？
4. 我有没有宣称显著性、实机优势、全局最优？
5. 我要跑的东西会不会覆盖已有结果目录？`output_tag` 是新的吗？
6. 我改的文件在冻结锁里吗？改了要不要出 diff 记录 + 更新 SHA？
7. 我是不是把"公共瓶颈"（F8-D 高度、lite 偏置）包装成了"分配器差异"？
8. 我有没有动 `results/`、`archive/` 里的旧证据？
9. 我是**只读核对**还是**已经修改**？两者必须在回答里说清楚。
10. 如果状态不确定，我是不是应该先核对再回答，而不是猜？

---

## 附录 A：关键路径索引

```text
配置 / 协议
  configs/f8_protocol_v1.json                       F8-v1 机器协议（唯一数值来源）
  configs/f8_pressure_protocol_v1.json              未执行的旧压力预案（保留）
  configs/f8_pressure_protocol_v2.json              F8-P-v2 机器协议
  configs/comparison/m4_selection.json              M4 可比负载选择证据

F8 代码
  experiments/ca_f8_protocol.m                      构造 F8 cfg/model/ref/protocol
  experiments/ca_f8_reference.m                     平滑八字 + 解析前馈参考
  experiments/ca_f8_attitude_reference.m            几何姿态/角速度/角加速度前馈
  experiments/ca_f8_position_control.m              F8 位置环（消费前馈）
  experiments/ca_f8_pressure_protocol.m             压力候选参考
  experiments/run_f8_comparison.m                   基础批次运行器
  experiments/run_f8_pressure_study.m               压力筛选/确认运行器（★含不覆盖断言）
  analysis/f8_evaluate_run.m                        四维门禁评价
  analysis/f8_write_tracking.m                      轨迹导出
  analysis/f8_allocation_diagnostics.m              分配真值诊断 + LP 抽查
  analysis/ca_priority_polytope_audit.m             λ/优先级几何审计
  analysis/f8_pressure_development_diagnostics.m    开发批后处理（幂等）
  analysis/f8_outer_loop_diagnostics.m              高度力分解诊断
  analysis/audit_f8_thrust_envelope.m               推力/倾角包线审计
  tests/test_f8_protocol.m                          协议与前馈单元测试
  tests/test_f8_comparison_results.m                结果独立核验（★生成 independent_checks.json）
  tests/test_f8_pressure_protocol.m                 压力协议单元测试

F8 工具 / 编排
  tools/plot_f8_comparison.py                       出图 + report.md + aggregate/paired/phase
  tools/plot_f8_pressure_development.py             开发批 λ/β 图
  tools/plot_f8_protocol.py                         协议参考图
  results/f8_work_20261101/finish_f8_study.m        基础批次收尾
  results/f8_work_20261101/finish_f8_confirmation.m 确认批收尾（★被不覆盖断言卡住）
  results/f8_work_20261101/prepare_confirmation.py  生成管理性例外记录 + 更新锁
  results/f8_work_20261101/package_results.py       打包到 examples/

平台
  platform/sim/ca_simulate.m                        公共仿真调度器（21 KB）
  platform/sim/ca_prepare_experiment.m              预生成噪声/扰动（同种子一致）
  platform/modules/control_allocator/               分配器模块与派发
  allocators/registry.m                             唯一注册表
  analysis/allocation_comparison_engine.m           引擎指纹（第一道锁）
  analysis/allocation_comparison_hash.m             SHA256 工具
```

## 附录 B：术语表

| 术语 | 含义 |
|---|---|
| `rankable` | 有资格参与比较（≠ 方法可分） |
| `stress` | 未过资格检查，数据保留不排名 |
| `invalid` | 数据/审计失败，不参与比较 |
| `distinguishable` | 效应量 ≥ 1，本批内可分开（≠ 显著） |
| `λ`（lambda） | PCA 的优先级缩放系数；1 = 未缩放，<1 = 高优先级受限 |
| `mode` | 0 正常 / 1 高优先级补偿回退 / 2 工程兜底；**缺 λ 不等于 λ=1** |
| `M0/M2b/M4` | 舵效测试工况，**不是飞行模式** |
| `ideal` / `lite` | 反馈来源（oracle / 估计器），**不是物理精度** |
| 主窗 | 悬停 `6–16 s`；F8 `6–50 s` |
| `output_tag` | 结果目录后缀，必须新且 `[A-Za-z0-9_-]` |
| 冻结锁 | `numerical_sources_before_*.json`，20 个文件的 SHA256 |
| 引擎指纹 | `allocation_comparison_engine()`，覆盖核心数值目录 |
| 管理性例外 | 对冻结文件的有记录、有 diff、不改数值的修正 |
