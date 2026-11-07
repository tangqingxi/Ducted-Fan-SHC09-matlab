# AeroGNC-Sim 源码架构重构实施方案（Phase 3）

日期：2026-11-05（Asia/Shanghai）。
状态：**方案，未执行任何源码移动。** 主仓库本轮零修改。
基线：DEV `fdc93369`（科学基准 `339d7b1a`）；逐文件候选来自 `Phase1/MIGRATION_MATRIX.csv` 的 `execution_phase = Phase3` 子集（1,003 条）。
配套：[MIGRATION_PLAN.csv](MIGRATION_PLAN.csv)（1,003 行逐文件迁移单）。

## 1. 结论摘要

| 项目 | 结果 |
|---|---|
| 迁移范围 | 1,003 个 Phase3 条目（819 个 MOVE_CANDIDATE + 184 个 KEEP） |
| 当前缺失 | **0** |
| 目标路径冲突 | **0** |
| 与 Phase1 矩阵的偏差 | 1 处：`src/allocation/*` 改为顶层 `allocators/*`（39 个文件），理由见 §3 |
| 需要改写的接口文件 | **7 个**（§5） |
| 会改变 engine 指纹 | **是**，必须登记新旧映射（§5.9） |
| 第三方与冻结数据 | `third_party/` 176 项全部 KEEP，不移动 |
| 可执行性 | 可执行；分 6 个波次、9 个提交，每波次独立可回滚 |

一句话：

> **移动本身是机械的；真正的风险只有三处——`ca_setup` 的搜索路径、`allocation_comparison_engine` 的指纹、`ppid_source_manifest` 的来源清单。把这三处做成"一次提交、双路径兼容、新旧指纹并存"，重构就是安全的。**

## 2. 目标目录树

严格按本轮任务书 6.1 的目标结构：

```text
AeroGNC-Sim/
├── src/                        # 通用仿真与 GNC 核心
│   ├── runtime/                # 总线、调度、仿真推进、日志
│   │   ├── logger/
│   │   └── sim/
│   ├── control/                # 平台控制模块（姿态/角速度/位置/指令）
│   ├── allocation/             # 仅保留接口层（ca_allocate 等），插件在顶层 allocators/
│   ├── effectiveness/          # 气动效能插件与注册
│   ├── sensors/                # 传感器生成
│   ├── navigation/             # 导航与 ECL 桥接
│   │   └── px4_ecl/
│   ├── drivers/                # 执行器/PWM 驱动
│   ├── lib/                    # 数学与滤波
│   └── compat/                 # 旧 API 兼容层
├── airframes/
│   └── shc09/                  # 机型几何、模型、冻结参考
├── allocators/                 # 控制分配算法与注册机制（顶层，见 §3）
│   ├── interface/              # ca_allocate / ca_allocator_config / ca_allocator_name
│   ├── da_ns/  wls/  dca/  pca_static/  pca_predictive/  example_pinv/
│   └── registry.m
├── configs/                    # 公共参数、机型配置、协议常量
├── studies/                    # 研究课题、协议与实验入口
│   ├── hover_distance/
│   ├── ppid_pindi/
│   └── legacy_experiments/     # 原 experiments/
├── analysis/                   # 指标、诊断、离线导出（路径不变）
├── tools/                      # 构建、审计、导出工具
├── apps/                       # 应用入口与 WindTrace
│   └── windtrace/
├── results/                    # 统一 Results Manager 管理（本阶段不动）
├── artifacts/                  # 构建产物（本阶段不放行）
├── docs/                       # 项目与开发文档
├── tests/                      # 自动化测试与冻结夹具
├── third_party/                # 不动
└── compat -> src/compat        # 过渡期软链接或保留空壳
```

## 3. 与 Phase1 矩阵的唯一偏差：`allocators/` 保持顶层

Phase1 矩阵把分配器规划到 `src/allocation/plugins/`。本轮任务书 6.1 明确把 `allocators/` 列为顶层。采用后者，原因不是"听指令"，而是**依赖事实**：

```matlab
% allocators/registry.m 第 12 行
value = struct('name', string(name), 'directory', ['allocators/', directory], ...);
```

`ca_setup` 用 `plugin.directory` 做 `addpath`。**只要 `allocators/` 仍是顶层同名前缀，注册表一行都不用改**；改成 `src/allocation/plugins/` 则必须同时改 `registry.m`、`ca_setup.m` 和所有引用 `plugin.directory` 的地方，凭空增加一个故障点。

因此：`src/allocation/` 只保留接口层（`ca_allocate.m` 等 3 个文件），插件与注册留在顶层 `allocators/`。矩阵中 39 条 `src/allocation/*` 已自动重映射为 `allocators/*`，见 `MIGRATION_PLAN.csv` 的 `remap_rule` 列。

## 4. 迁移波次

| 波次 | 内容 | 条目 | 为什么这个顺序 |
|---|---|---:|---|
| **W1** | `platform/`→`src/runtime|control`、`modules/`→`allocators/interface|src/navigation`、`lib/`→`src/lib`、`drivers/`→`src/drivers`、`configs/` 原地 | 81 | 先动"被依赖的底层"，此时上层路径尚未变，可单独验证 `ca_setup` |
| **W2** | `allocators/` 原地确认、`effectiveness/`→`src/effectiveness` | 39 | 注册表与效能注册，紧接着 W1 |
| **W3** | `models/shc09/`→`airframes/shc09/` | 16 | 机型解耦；engine 的冻结参考表路径在此变化 |
| **W4** | `research/`→`studies/`、`experiments/`→`studies/legacy_experiments/` | 83 | 研究入口最后动，因为它引用前面所有层 |
| **W5** | `tests/`、`tools/`、`apps/`、`analysis/` 原地或小幅 | 223 | 测试与工具跟随被测代码 |
| **W6** | `docs/` 引用、`compat/`→`src/compat`、`archive/` | 385 | 文档链接最后统一修 |
| — | `third_party/` | 176 | **不动** |

每波次都必须满足"上一波次验证通过才进入下一波"。

## 5. 模块接口关系（任务书 6.2 的 10 项）

### 5.1 MATLAB 搜索路径与 `ca_setup`

`ca_setup.m` 是**唯一**的搜索路径入口，硬编码 35 个目录，之后追加 `registry()` 与 `effectiveness_registry()` 返回的目录。

```matlab
paths={'configs/params','configs/airframes','apps',...,'platform/sim','platform/tests','allocators','effectiveness','compat',...};
```

处理方式：**一次改写、不许散落**。改写后必须保证 `ca_setup` 仍只 `addpath` 显式目录（禁止 `genpath`，否则会把 `results/`、`archive/`、冻结证据全部拉进搜索路径）。

验证：对每个 `.m` 文件执行 `which <func>`，要求解析到新路径且唯一；同名函数冲突数为 0。

### 5.2 两套独立控制链路

- 平台链：`main → main_comparison → shc09_run → platform_run → sim_driver → platform/sim/ca_simulate`
- 四环链：`run_ppid_pindi → research/ppid_pindi/ppid_simulate → ppid_control_step`

两者共用 `airframes/`、`src/drivers/`、`src/allocation/` 接口与 `src/navigation/`，但**控制器实现不同**。重构只搬目录，不合并、不重命名函数，不把一条链的参数/时钟移植到另一条。

### 5.3 机型与控制器解耦

`models/shc09/*` → `airframes/shc09/*`；`configs/airframes/shc09_airframe.m` 原地。

需要保持：控制器只通过配置结构与白名单上下文获取机型参数，不直接 `load` 机型文件。重构后检查没有新增"控制器直接引用 airframe 内部变量"的耦合。

### 5.4 分配器注册与调用

- 注册：`allocators/registry.m`（6 个条目：DA_NS、WLS、DCA、PCA_STATIC、PCA_PREDICTIVE、EXAMPLE_PINV）
- 接口：`modules/control_allocator/{ca_allocate,ca_allocator_config,ca_allocator_name}.m` → `allocators/interface/`
- 调用：`shc09_allocator_dispatch` 与总线分配模块

**注册表是真实依赖，不是"看起来重复的目录"。** 静态搜索"无引用"不能作为删除依据（AGENTS §3）。

### 5.5 实验协议与来源锁

历史 `formal_lock.json` / `source_lock.json` 记录的是**仓库根相对路径**与源码 SHA。移动源码后：

- 旧锁**不得改写**；
- 旧锁记录的路径在新布局下不再解析 → 必须由"旧布局快照 + legacy 映射"提供复算能力；
- 新运行产生**新**锁与新 engine，与旧锁并存。

`research/ppid_pindi/ppid_gnss_v2_config.m` 第 31 行硬编码 `'protocol_path','research/ppid_pindi/gnss...'`，移动到 `studies/` 后必须改写。

### 5.6 外部 ECL 桥接与构建路径

`build_px4_ecl_bridge.m` 输出 `build/px4_ecl/px4_ecl_bridge.exe`；`CaPx4Ecl.m` 调用外部进程。`ppid_source_manifest.m` 直接读取该 EXE 的 SHA 作为 `ekf_executable_sha256`。

重构要求：**构建输出路径保持不变**（`build/px4_ecl/`），或提供向后兼容查找。二进制身份（SHA）不得因重构而变化。

### 5.7 WindTrace 与 WTR 导出接口

- 导出：`analysis/export_windtrace_flight`（写入 `.wtr`）
- 回放：`apps/windtrace/`
- 合同：`.wtr` 是 ZIP 容器，成员 `manifest.json / parameters.json / flight.mat / geometry.json`，`core/flight.py` 严格校验成员集合与逐成员 SHA

重构**不得改 `.wtr` 格式**。WindTrace 本阶段不拆仓（§9）。

### 5.8 Results Manager 与新旧路径解析

`results/` 本阶段不动。重构需要预留：

- `results/_index/` 解析器支持 `legacy_locator → canonical locator`；
- 源码路径变化不影响 Results 的 artifact locator（后者相对 `results/`，不是相对源码目录）。

注意：`allocation_comparison_engine` 只覆盖源码，不覆盖 `results/`，所以 Results 迁移与 engine 无关；但**源码迁移会改变 engine**（§5.9）。

### 5.9 历史复算与数值一致性（最关键）

`analysis/allocation_comparison_engine.m` 的行为：

```matlab
folders=["platform","allocators","effectiveness","models","drivers","lib","configs","modules","compat"];
...
parts{k,1}=erase(paths(k),string(root)+filesep);   % 相对路径参与哈希
parts{k,2}=fread(fid,Inf,'*uint8');                % 内容参与哈希
```

**相对路径和字节一起进哈希。** 因此移动目录后：

1. engine 指纹必然变化（即使内容一字不改）；
2. 旧锁记录的 engine 只对旧布局有效；
3. 不能"重算 engine 覆盖旧值"来让新布局冒充旧实验。

处理方式（必须执行）：

- 在**旧布局快照**（`D:\AeroGNC-Backup\AeroGNC-Sim\339d7b1a\snapshot`）上复算旧 engine，确认与历史锁一致；
- 在新布局上算新 engine；
- 登记 `old_engine → new_engine` 映射表并随报告发布；
- 任何历史实验复算必须声明使用的是旧布局还是新布局。

`ppid_source_manifest.m` 另有硬编码路径（`research/ppid_pindi/*.m`、`experiments/*.m`、`configs/*.json`、`build/px4_ecl/px4_ecl_bridge.exe`、`ca_setup.m`、`run_ppid_pindi.m`、`analysis/*`），移动后其覆盖集合变化，**必须同步改写并重新登记**。

### 5.10 更名后的兼容策略

GitHub 仓库改名会产生旧 URL 重定向，但**本地路径与 README 里的绝对路径不会自动变**。策略见 §9：改名放在最后，且先冻结入口脚本名（`ca_setup`、`main`、`run_ppid_pindi`、`shc09_run`）。

## 6. Git 提交拆分方案

| 提交 | 内容 | 可独立回滚 | 验证 |
|---|---|---|---|
| C0 | 新增 `docs/refactor/PHASE3_MAPPING.md` + 备份确认（不动代码） | 是 | 文档链接 |
| C1 | `src/` 骨架 + `ca_setup` 双路径兼容（新旧都能解析） | 是 | `which` 全部解析 |
| C2 | W1 移动（platform/modules/lib/drivers/configs） | 是 | `ca_setup` + `which` |
| C3 | W2 移动（effectiveness；allocators 原地） | 是 | 注册表 6 项可用 |
| C4 | W3 移动（models→airframes） | 是 | 冻结参考表 SHA 不变 |
| C5 | W4 移动（research/experiments→studies） | 是 | `ppid_source_manifest` 新指纹登记 |
| C6 | W5 移动（tests/tools/apps/analysis） | 是 | 测试入口路径解析 |
| C7 | W6 文档链接与 compat 清理 | 是 | 链接检查 0 断链 |
| C8 | engine 新旧映射表 + 来源清单更新 | 是 | 新旧 engine 双记录 |
| C9 | README/AGENTS/HANDOFF 更新 | 是 | GitHub 渲染 |

约定：每步用 `git mv`（保留历史）；**不删除**旧目录直到 C8 验证通过；每步之后 `git status` 必须只包含该步预期的路径。

## 7. 自动化验证方案

| 检查 | 方法 | 通过条件 |
|---|---|---|
| 路径解析 | 对每个 `.m` 求 `which` | 全部解析到新路径，无重复、无落在 `results/` |
| 函数唯一性 | 统计同名 `.m` | 同名冲突 = 0（`example_pinv` 等已知重复除外，需显式白名单） |
| 文件完整性 | 迁移前后逐文件 SHA256 | 内容字节完全相同（只有路径变） |
| engine 映射 | 旧快照复算 vs 新布局复算 | 两者都被记录；不要求相等 |
| 冻结参考表 | `models/shc09/reference/*.mat` 的 canonical SHA | 与 engine 内写死的两个 canonical 值一致 |
| ECL 桥接 | `build/px4_ecl/px4_ecl_bridge.exe` SHA | 与 `ppid_source_manifest` 记录一致 |
| 文档链接 | `tools/check_docs_links.py` | 0 断链 |
| 运行验证 | MATLAB 短例 | **必须单独批准**；没有 MATLAB 环境时标记 NOT RUN，不得声称通过 |

**本轮与下一轮都不允许**用"目录能进去、文件数对"替代上述检查。

## 8. 回滚方案

1. 每个提交独立可 `git revert`；
2. 旧目录在 C8 之前不删除，回滚只需 revert 提交；
3. 若出现不可 revert 的状态：从 `D:\AeroGNC-Backup\AeroGNC-Sim\339d7b1a\snapshot` 逐文件恢复到**新目录**，SHA256 校验后再切换；
4. 旧 engine 永远可由备份快照复算，不依赖当前工作树。

## 9. 更名与 WindTrace 拆分的合理顺序

```text
1. Phase 3 源码目录重构（本方案）           ← 现在
2. Results Manager 落地（读取 _index）        ← 依赖 1 的路径稳定
3. WindTrace 导出接口冻结（analysis/export_windtrace_flight）
4. WindTrace 拆为独立仓库 + Submodule 固定 SHA
5. GitHub 仓库改名（AeroGNC-Sim）
6. 旧 URL/入口脚本的兼容期（保留 ca_setup 等入口名）
```

理由：先稳定内部结构，再冻结对外接口，最后改外部身份。反过来做会让每个改动都要同时处理两套路径。

## 10. 风险与待批

| 风险 | 影响 | 处置 |
|---|---|---|
| engine 指纹变化 | 旧锁无法在新布局复现 | 双记录 + 旧快照复算 |
| `ca_setup` 遗漏目录 | 函数找不到，运行期报错 | 静态 `which` 全覆盖 + 显式目录清单 |
| 同名函数冲突 | MATLAB 静默调用错误版本 | 迁移前做全仓同名统计 |
| 文档 333 个文件含绝对路径 | 链接失效 | 不批量替换；由索引与文档链接检查处理 |
| 无 MATLAB 环境 | 运行验证无法执行 | 标注 NOT RUN，禁止声称通过 |
| `third_party` 被误移 | 许可与冻结来源破坏 | 176 项 KEEP，禁止移动 |

待批准：源码移动的**提交与推送授权**（本轮只出方案）、运行验证预算（如需 MATLAB 短例）、仓库更名时机与 WindTrace 拆分方式。

## 11. 下一轮第一步（可直接执行）

```text
1. 读本文件与 MIGRATION_PLAN.csv；
2. 建分支 refactor/phase3-source；
3. 只做 C0 + C1：加 src/ 骨架与 ca_setup 双路径兼容，不移动任何 .m；
4. 跑 §7 的"路径解析"与"函数唯一性"检查；
5. 通过后再执行 C2（W1）。
```

这一路径保证：**任何一步失败都不影响现有可用布局**。
