# Phase3 C4/W3 Airframe / Dynamics 架构设计修订

日期：2026-11-05（Asia/Shanghai）。执行者：DeepSeek Harness / deepseek-flash；dual-repo-agent-handoff 0.2.2。

状态：**C4/W3 设计修订完成；C4 源码迁移未执行；执行准备结论 READY_WITH_CONDITIONS**。本报告只做架构审查、映射和兼容性设计，不移动或修改任何 MATLAB 源码。

## 0. 结论摘要

- 原 C4/W3“`models/shc09/*` 全部搬到 `airframes/shc09/*`”**不采纳**。它把动力学、气动、参考坐标适配和冻结参考数据混进 Airframe，职责不正确。
- 推荐把 8 个活动 `.m` 分为 **2 个 Airframe、5 个 Dynamics、1 个 Adapter**；8 个冻结参考文件 **KEEP 原位**；`configs/airframes/shc09_airframe.m` 是 Scenario 预设，**KEEP + DEFER 改名**，不是 Airframe。
- `ca_model_hover.m` 是 SHC09 的**简化降阶动力学**，不是严格线性化模型，也不是悬停 Scenario；不得放入 `airframes/`。
- `ca_shc09_parameters.m` 是 Airframe 参数加载器，依赖自身目录下的 `reference/*.mat`。保留参考数据在 `models/shc09/reference`，只对该加载器做一处**路径兼容补丁**，不复制、不改冻结数据字节。
- 引擎当前 121 项；按映射后仍为 121 项（14 个模型相关 `.m`：8 活动 + 6 参考源码）。新增 `airframes`、`dynamics` 文件夹，Adapter 放入已覆盖的 `src/control`。
- 执行条件：用户授权、路径补丁审批、6 个 CRLF 目标的精确 `-text` 规则、`ca_setup`/engine/静态工具/文档配套，以及不得使用已过时的 `tests/baseline/protected_sources.json` 作为 C4 门禁。

## 1. 基线与证据

- DEV：`refactor/phase3-source` @ `9d8f8aec7d3b8316f5ae99cba45f422e74cc984c`，远端一致；工作区仅 `.dsh-plugins/` 未跟踪。
- AUDIT：`main` @ `1f8dfb5c51de4d80c17b434e4417505a5d65a8c5`，工作区干净。
- 证据：[C4_EVIDENCE.json](C4_EVIDENCE.json)、[C4_CURRENT_RUNTIME.json](C4_CURRENT_RUNTIME.json)、[逐文件映射](C4_FILE_MAPPING.csv)。
- 当前运行时检查（MATLAB R2025b，只构造模型，不运行仿真）：`ca_model` 默认 `shc09_6dof`，`hover_linear` 返回 `hover` 模型；`ca_plant_outputs` 对 hover 模型的力与 NED 加速度范数均为 0；参数表加载成功。该检查只证明**当前树**行为，不是 C4 迁移后的验证。

## 2. 源码事实与职责判断

### 2.1 `ca_model.m` — Airframe 模型工厂

`ca_model` 读取 `ca_shc09_parameters`，建立质量、惯量、真实 b 系舵效矩阵、加速度矩阵、配平舵角、限幅和悬停转速；按 `cfg.plant_model` 分派 `shc09_6dof` 或 `hover_linear`。它定义的是机型物理身份与名义模型，不是积分方程。归 **Airframe**；同时保留为模型工厂，目标 `airframes/shc09/ca_model.m`。

历史 `source_file='ICGNC_matlab2.0/SHC09_Sys.m'` 是来源说明，不应随移动改写。

### 2.2 `ca_model_hover.m` — Dynamics / 降阶，不是严格线性化

源码设置质量 2.1 kg、惯量、恒定舵效矩阵，并复用参考悬停气动/几何常数；`ca_plant_outputs` 的 `hover_linear` 分支返回：

- `force_body_n = zeros(3,1)`；
- `acceleration_ned_m_s2 = zeros(3,1)`；
- `torque_body_nm = model.torque_matrix * state.delta`。

`ca_plant_step` 仍做旋转矩阵增量积分和 `-cross(omega, J*omega)` 陀螺项，`ca_plant_outputs` 仍计算 `alpha`。因此它是**简化旋转/力矩降阶模型**，没有平移气动/推力，也存在非线性运动学与陀螺项；**不是围绕悬停点的严格 A/B 线性化**，更不是 Scenario。归 **Dynamics / hover_reduced_order**；目标 `dynamics/shc09/hover_reduced_order/ca_model_hover.m`。

它内嵌了部分 Airframe 常数，和 `ca_shc09_parameters` 存在重复；统一参数属于数值/结构重构，**C4 不做**，单独 DEFER。

### 2.3 `ca_plant_init/step/outputs` — Dynamics / plant

- `ca_plant_init`：从模型和配置初始化位置、旋转、配平舵角、电机转速；两条控制链共用。
- `ca_plant_step`：显式中点积分，推进舵机/电机、旋转、位置和速度；不依赖 SHC09 专属文件路径。
- `ca_plant_outputs`：计算真实力/力矩/NED 加速度，做旧原生系到 b 系的边界转换，并保留 `hover_linear` 分支。

三者属于 **Dynamics / plant**，目标 `dynamics/shc09/plant/`。`ca_plant_outputs` 是 plant I/O 适配器，不是 Airframe；C4 不拆分 hover 分支，拆分属于真实重构、DEFER。

### 2.4 `ca_shc09_aerodynamics.m` — Dynamics / nonlinear 6DOF

计算涵道/机翼/舵面气动力矩、低速正则化、舵效映射和表外推策略；依赖 `model.parameters` 和 `cfg`，不依赖自身文件路径。归 **Dynamics / nonlinear_6dof**；目标 `dynamics/shc09/nonlinear_6dof/ca_shc09_aerodynamics.m`。C4 只搬路径，不改方程、表、阈值或符号。

### 2.5 `ca_shc09_parameters.m` — Airframe 参数 + 冻结参考加载器

文件用 `fileparts(mfilename('fullpath'))` 定位自身目录，再 `load(fullfile(folder,'reference','duct_raw.mat'))` 和 `wing_raw.mat`。如果把文件移到 `airframes/shc09/` 而不处理，路径会变成 `airframes/shc09/reference`，加载必然失败。

推荐兼容方案：**参考数据仍留在 `models/shc09/reference`**，`ca_shc09_parameters` 移到 `airframes/shc09/` 后，用仓库根显式解析该旧路径：

```matlab
folder=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(folder));
reference=fullfile(root,'models','shc09','reference');
d=load(fullfile(reference,'duct_raw.mat'));
w=load(fullfile(reference,'wing_raw.mat'));
```

这是 8 个模型文件中唯一计划内的源码内容修改；配套的 `ca_setup`、engine、静态工具和文档改动另列。它不改变数值、样条、单位、坐标或数据字节。必须单独展示 diff 和 old/new SHA，不能混在纯 `git mv` 中冒充机械迁移。若该补丁不获批，回退方案是把 `ca_shc09_parameters.m` **KEEP 在 `models/shc09`**，Airframe 包暂时不完整；不能通过复制 `reference/` 来绕过。

### 2.6 `ca_reference_to_b.m` — Adapter，不是 Airframe

该函数只把参考的姿态/角速度/角加速度从旧原生系转换到 b 系，使用 `model.parameters.R_old_to_b` 和 `src/lib/math` 的旋转函数。它不定义机型物理，也不推进动力学。归 **Adapter / reference frame**；目标 `src/control/frame/ca_reference_to_b.m`，并在 `ca_setup` 增加该显式路径。若该新路径不获批，回退为 KEEP 在 `models/shc09`，不能放入 `airframes/shc09`。执行前发现 `check_phase3_paths` 禁止路径含 `/reference/`，故 Adapter 目标目录定为 `src/control/frame`，职责不变；原 `src/control/reference` 方案不执行。

### 2.7 `configs/airframes/shc09_airframe.m` — Scenario 预设

文件内容是 2 秒、`position_hold`、初始位置 `[0;0;-10]`、估计器模式等预设，调用点是 `apps/hover_app.m` 和 `tests/test_px4_log_export.m`。它是 **Scenario/app preset**，不是 Airframe 身份。C4 **KEEP 原位**；未来可改为 `scenarios/shc09_hover_preset.m`，但函数改名和调用点修改是真实重构，标记 **DEFER**，不得因为目录名含 `airframes` 就搬进 `airframes/shc09`。

## 3. 推荐边界

```text
airframes/shc09/
  ca_model.m                  # 机型模型工厂、物理身份、名义 B/J/配平
  ca_shc09_parameters.m       # 物理参数 + 指向冻结参考的显式路径
models/shc09/reference/       # KEEP：ICGNC 冻结源码/气动表，原字节、原路径
dynamics/shc09/plant/
  ca_plant_init.m
  ca_plant_step.m
  ca_plant_outputs.m
dynamics/shc09/nonlinear_6dof/
  ca_shc09_aerodynamics.m
dynamics/shc09/hover_reduced_order/
  ca_model_hover.m
src/control/frame/
  ca_reference_to_b.m         # Adapter，不属于 Airframe/Dynamics
configs/airframes/shc09_airframe.m  # KEEP；Scenario 预设，DEFER 改名
```

`ca_reference`、`ca_stage_reference` 仍是仿真参考生成器，C4 不动；它们是 Guidance/Scenario 后续整理对象，不进入 Airframe/Dynamics。`ca_model` 中的 `plant_model` 分派保留，避免破坏 registry、effectiveness 和已有配置。

## 4. 逐文件结论

| 文件 | 归属 | 目标 | 决策 |
|---|---|---|---|
| `ca_model.m` | Airframe | `airframes/shc09/ca_model.m` | ACCEPT MOVE |
| `ca_model_hover.m` | Dynamics / 降阶 | `dynamics/shc09/hover_reduced_order/ca_model_hover.m` | ACCEPT MOVE；REJECT 放入 Airframe/Scenario |
| `ca_plant_init.m` | Dynamics / plant | `dynamics/shc09/plant/ca_plant_init.m` | ACCEPT MOVE |
| `ca_plant_outputs.m` | Dynamics / plant I/O | `dynamics/shc09/plant/ca_plant_outputs.m` | ACCEPT MOVE；DEFER 拆分支 |
| `ca_plant_step.m` | Dynamics / plant | `dynamics/shc09/plant/ca_plant_step.m` | ACCEPT MOVE |
| `ca_reference_to_b.m` | Adapter | `src/control/frame/ca_reference_to_b.m` | ACCEPT MOVE；Fallback KEEP |
| `ca_shc09_aerodynamics.m` | Dynamics / nonlinear | `dynamics/shc09/nonlinear_6dof/ca_shc09_aerodynamics.m` | ACCEPT MOVE |
| `ca_shc09_parameters.m` | Airframe | `airframes/shc09/ca_shc09_parameters.m` | ACCEPT MOVE + COMPAT_PATCH |
| `models/shc09/reference/*`（8 项） | Frozen reference | 原位 | ACCEPT KEEP；REJECT 移动/复制/重规范化 |
| `configs/airframes/shc09_airframe.m` | Scenario | 原位 | DEFER 改名/移动；C4 KEEP |

全部 17 行的路径、动作、风险、兼容动作和验证见 [C4_FILE_MAPPING.csv](C4_FILE_MAPPING.csv)。配套的 `ca_setup`、engine、静态工具、文档、`.gitattributes`、旧 baseline 和 PPID manifest 见 [C4_SUPPORT_CHANGES.csv](C4_SUPPORT_CHANGES.csv)。

## 5. 冻结参考数据

- `models/shc09/reference/` 共 8 个文件：6 个 `.m` + 2 个 `.mat`；C4 全部 KEEP，路径和原始字节不变。
- 8 项 raw SHA256 与 `docs/physical_reference.json` 的 8 项逐一相同；`duct_raw.mat`=`a5140eea72b9…`，`wing_raw.mat`=`299bbd2b6b6e…`，其余 6 项也匹配。详见 [C4_EVIDENCE.json](C4_EVIDENCE.json)。
- `ca_shc09_parameters` 的新路径补丁只改变“从哪里读 reference”，不复制数据、不改变 MAT、不改变 spline、常数、坐标或限幅。
- `docs/physical_reference.json`、`THIRD_PARTY_NOTICES.md` 的 `models/shc09/reference` 说明仍然成立；C4 不需要改这两个来源记录。
- **REJECT**：把 `reference/` 一起移到 `airframes/shc09/reference`（改变冻结来源路径、历史锁失配）；把 reference 复制一份到新目录（重复实现/双重来源）；对 MAT 做重采样或重新生成。

## 6. 路径、engine 与来源影响

- 当前 engine 121 项，包含 14 个 `models/shc09/` 下的 `.m`：8 个活动文件 + 6 个 reference 历史 `.m`。
- 映射后：`airframes` 2 项、`dynamics` 5 项、`models` 保留 6 个 reference 历史 `.m`；Adapter 移到 `src/control/frame`，由既有 `src/control` 覆盖。模型相关 `.m` 仍为 14 项，engine 总数仍为 121（内存路径映射，不是迁移后 MATLAB 实测）。若 Adapter 回退为 KEEP，它留在 `models`，总数不变。
- `ca_setup.m` 需增加 `dynamics/shc09/plant`、`dynamics/shc09/nonlinear_6dof`、`dynamics/shc09/hover_reduced_order`，以及（若采纳 Adapter 移动）`src/control/frame`；`airframes/shc09`/`models/shc09` 双布局已存在。增加后 `ca_setup` 的 raw SHA 改变。
- `analysis/allocation_comparison_engine.m` 需加入 `airframes`、`dynamics`；`models` 保留。engine 内容 SHA 改变，旧 engine 值不得回写历史锁。
- `ppid_source_manifest` 的显式 files 集合不变；`ca_setup.m` 与 `analysis/allocation_comparison_engine.m` 两个显式文件 SHA 会变；研究控制器、协议、锁、ECL EXE 不变。新运行产生新来源身份，旧锁保持原字节。
- `platform_run` 的 `results.implementation` 路径列表会随实际文件变化；它本来动态扫描，不需要新增硬编码。
- `tests/baseline/protected_sources.json` 把 8 个模型文件标为 `fixed_path`；而且该 baseline 在 C2 后已经因 `drivers/actuators` 路径变化而失败（`verify_platform_sources.py` 当前在 `drivers/actuators/ca_actuator_step.m` 处失败）。它是历史固定路径基线，**不能作为 C4 门禁**；C4 需新建版本化验证/映射，不得修改旧 baseline 或旧锁。
- 6 个源文件为 CRLF：`ca_model`、`ca_model_hover`、`ca_plant_init`、`ca_plant_step`、`ca_shc09_aerodynamics`、`ca_shc09_parameters`。当前 `.gitattributes` 的 `*.m text eol=lf` 会在 `git mv`/`git add` 时把它们规范化为 LF，改变 raw SHA。必须像 C2 的七份 CRLF 目标一样，为这 6 个精确目标加 `-text` 规则，禁止全仓 renormalize；`ca_plant_outputs` 和 `ca_reference_to_b` 是 LF，无需该规则。迁移前后逐文件 raw SHA 必须相等（`ca_shc09_parameters` 除外，因路径补丁预期变化）。
- 文档影响：需要更新当前文档 `docs/repository_map.md`、`effectiveness/README.md`、`docs/refactor/PHASE3_MAPPING.md`、`docs/guides/architecture.md`；历史证据 `docs/file_inventory.csv`、`docs/migration_manifest.json`、`docs/matlab_references.json`、`docs/release_validation/*`、`docs/validation/*/protected_before.json`、`examples/*` 不改，保留旧路径作为历史记录。`THIRD_PARTY_NOTICES.md` 和 `docs/physical_reference.json` 的 reference 路径不变。
- DEV 文档漂移：`HANDOFF.md` 仍写“仅 C0/C1、不移动 .m”，`PHASE3_MAPPING.md` 仍把 allocators 指向 `allocators/plugins`；C4 执行时应做最小文档修正，不能把旧矩阵当当前指令。

## 7. C4 执行方案（尚未执行）

1. 冻结 DEV `9d8f8ae`，核对远端、status、worktree；保留 `.dsh-plugins`；核对 8 个源 raw SHA、8 个 reference SHA 和全部目标不存在。
2. 为 6 个 CRLF 目标加精确 `-text` 规则；`git mv` 8 个活动文件到第 3 节目录；不复制、不保留旧活动副本。
3. 单独应用 `ca_shc09_parameters` 的 reference 路径补丁；保存 diff、old/new raw SHA；reference 数据不动。
4. 更新 `ca_setup` 显式路径、engine folders、C4 静态检查器和当前文档；历史证据、旧锁、旧 baseline 不改。
5. 验证：8 个文件 raw/blob；参数补丁只改路径；MATLAB `which` 唯一且等于目标；`ca_model`/hover 模型与固定输入输出前后相等；engine 121 且 8 条路径映射；PPID 显式 files 集合不变；受保护 MAT/WTR/EXE/锁不变；独立 checkout 与回滚演练。全部只做路径/模型构造检查，不跑控制仿真。
6. 回滚：C4 独立提交的普通 revert；恢复 `ca_shc09_parameters` 旧字节；reference 从未移动；禁止 reset/clean/强推。

## 8. 执行准备结论

**READY_WITH_CONDITIONS**（不是无条件 READY，也不是 BLOCKED）。条件：

1. 用户明确授权 C4 执行及本报告范围；本轮只设计，未执行。
2. 批准 `ca_shc09_parameters` 的路径兼容补丁；否则该文件 KEEP，C4 的 Airframe 包不完整。
3. 批准 6 个 CRLF 目标的精确 `-text` 规则和逐文件 raw SHA 验证；禁止全仓 renormalize。
4. 批准 `ca_setup` 新增 dynamics/reference 路径、engine 增加 `airframes`/`dynamics`，以及 C4 静态检查器/文档配套。
5. 接受 `tests/baseline/protected_sources.json` 是 C2 前固定路径基线、当前已失败，不能作为 C4 门禁；新建 C4 版本化验证。
6. 明确不改控制器、估计器、气动方程、效能矩阵、执行器、协议、锁、MAT/WTR/EXE；不运行正式仿真/ECL。
7. `ca_model_hover` 保持降阶动力学定位，不改名 `plant_model`、不拆分支、不改成严格线性化。
8. HDT 55 秒复现是后续独立兼容性验收；本轮只核查依赖，不运行实验。

**决策**：ACCEPT 8 个活动文件的修订映射（其中 `ca_shc09_parameters` 为 MOVE+COMPAT_PATCH）；ACCEPT KEEP 8 个冻结 reference；DEFER `shc09_airframe` 的 Scenario 改名/移动；REJECT 把全部模型搬进 `airframes`、把 hover 当 Airframe/Scenario、移动或复制冻结 reference、改数值方程。

## 9. 未执行与限制

- 未移动任何源码，未创建 `airframes/`、`dynamics/`、`scenarios/`；未修改 `ca_setup`、engine、静态工具或既有文档。
- 未运行 C4 迁移后 MATLAB 检查、未计算迁移后 engine、未运行 HDT 55 秒复现、未运行控制仿真/ECL/全套测试。
- `C4_CURRENT_RUNTIME.json` 只记录当前树模型构造；不能当作迁移后验证。
- DEV `plan.md` 已创建，仅更新计划；本轮不提交、不推送，等待审查。
