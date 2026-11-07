# Results 登记与迁移方案（设计，未执行）

日期：2026-11-05（Asia/Shanghai）。
状态：**设计稿。本方案不创建、不覆盖任何正式批次 `manifest.json`，不修改 Results 原址，不实现或安装 Results Manager。** 迁移前必须先取得独立备份与恢复验证证据。

## 1. 目标布局与批次键

沿用 Phase 2A 合同（`RESULTS_LIFECYCLE.md` / `RESULTS_MANIFEST_SCHEMA.json` v1）：

```text
results/
├── _index/                      # 原址索引、批次键、历史路径与归档解析
├── _scratch/                    # 显式临时任务，不得作为正式证据唯一存放点
├── <study>/<batch_id>/
│   ├── manifest.json
│   ├── protocol/
│   ├── provenance/
│   ├── inputs/
│   ├── raw/
│   ├── metrics/
│   ├── figures/
│   ├── wtr/
│   ├── validation/
│   └── management/
```

批次键 = `study` + `airframe` + `batch_id`；`run_id` 在批次内唯一。当前只涉及 `airframe = shc09`。

三类状态**独立维护**，任何一类通过都不推导另一类：

| 字段 | 取值来源 | 本阶段允许写入 |
|---|---|---|
| `execution_status` | 原 `status.csv` / `completion.json` / 执行日志 | 否（登记阶段另批） |
| `acceptance_status` | 原协议阈值与已保存评价 | 否 |
| `retention_status` | `BACKUP_PLAN.csv` 的 `retention_class` | 否 |
| `storage.backup` / `storage.restore` | 第 3 节验证结果 | 否（目前 `not_executed`） |

历史正式批的正确表达是 `completed + failed + KEEP_EVIDENCE`：真实恢复 0/15、估计恢复 15/15。**不得**因为"值得保留"就改写 `acceptance_status`。

## 2. 身份登记顺序（先登记、后移动）

严格按下列顺序；前一步未通过不得进入下一步。**第 1–6 步全部只建索引，不移动文件。**

| 步 | 对象 | 前置证据 | 产出 |
|---|---|---|---|
| 1 | 两批历史正式批（`hover_distance_takeoff_formal_20261103_r1`、`..._changeB_20261104_r1`） | 备份 + 恢复验证通过 | `_index` 条目 + 两批 `manifest.json` |
| 2 | 三个预检（`precheck_20261103_r1`、`final_precheck_20261103_r1`、`final_precheck_changeB_20261104_r1`） | 同上；并保持 `final_precheck` 的原路径可解析（§5.2） | 三条批次记录 + 与正式批的前驱关系 |
| 3 | GNSS v2 单条回归（`gnss_1000s_regression_20261104_r1`） | 同上 | 单 `run` 批次记录；`acceptance_status = failed`（真实恢复未通过） |
| 4 | ECL Round 1–7 | 同上 | 按轮次分批次；保留 Round 6 原始（错误）统计与 Round 7 校正统计两者，标注 `supersedes` 不成覆盖 |
| 5 | 管理性中断 / 续跑关系 | 同上 | `events` 数组：`interrupted` → `resumed`（只补 14 项）→ `completed`；**不得**表述为 15 个失败或"全程无中断" |
| 6 | 旧 F8 / PPID / hover 轻量证据 | 同上 | 批次记录，`raw availability = missing/unknown`，明确"不可完整回放" |
| 7 | Viewer 软件工件 | 整包恢复 + 隔离启动通过 | `artifacts` 记录（非科学批次），与科学结果分开 |
| 8 | 首批实际迁移（§4） | 逐文件审批单 | 迁移计划执行记录 |

## 3. 源目录 → 统一目录映射

### 3.1 目录级映射

| 现状 | 未来 | 说明 |
|---|---|---|
| `results/<批次名>/` | `results/<study>/<batch_id>/` | 当前批次名同时含 study 与日期；拆分后 study 进目录、日期留在 `batch_id` |
| `results/<批次名>/logs/*.mat` | `results/<study>/<batch_id>/raw/` | 运行时日志 MAT |
| `results/<批次名>/inputs/*.mat` | `.../inputs/` | 输入种子 |
| `results/<批次名>/{provenance.csv,source_lock.json,sources.json}` | `.../provenance/` | 来源证据，**字节不变** |
| `results/<批次名>/*protocol*.json` | `.../protocol/` | 协议 |
| `results/<批次名>/metrics.csv` | `.../metrics/` | 指标 |
| `results/<批次名>/checks_*.json`、`completion.json` | `.../validation/` | 验收与完成证据 |
| `results/<批次名>/{status.csv,run.log}` | `.../management/` | 执行管理 |
| `logs/wtr/<批次名>/` | `results/<study>/<batch_id>/wtr/` | WTR 与其 `manifest.json`、`audits/`、`replay_checks/` |
| `figures/<批次名>/` | `results/<study>/<batch_id>/figures/` | 图与表 |
| `docs/validation/<任务>/` | `results/<study>/<batch_id>/validation/`（**仅限已逐文件审批者**） | 部分批次把协议/锁/报告放在这里；见 §5.3 |

### 3.2 study 命名（建议受控词表）

| 现批次名前缀 | 建议 `study` | 建议 `batch_id` 示例 |
|---|---|---|
| `hover_distance_takeoff_precheck_*` | `hover_distance_takeoff` | `precheck_20261103_r1` |
| `hover_distance_takeoff_final_precheck_*` | `hover_distance_takeoff` | `final_precheck_20261103_r1` |
| `hover_distance_takeoff_formal_*` | `hover_distance_takeoff_formal` | `20261103_r1` |
| `gnss_1000s_regression_*` | `gnss_regression` | `1000s_20261104_r1` |
| `round5/6/7_changeB_*` | `ecl_navigation` | `round5_20261104` 等 |
| `ppid_capacity_fix_*` | `ppid_capacity` | `20261103_r1` |
| `windtrace_*` | `windtrace` | 软件工件，非 study |

**该词表本身需要审批**；未批准前不得据此改名。`batch_id` 一旦登记即为不可变键，后续新增批次不得复用。

## 4. 首批低风险试点

逐文件清单见 `FIRST_MIGRATION_CANDIDATES.csv`（64 条文件记录 + 10 条批次级延后记录）。

### W1：`hover_distance_takeoff` / `precheck_20261103_r1`（39 项 / 55,480,098 字节）

| 组成 | 项数 | 理由 |
|---|---:|---|
| `results/hover_distance_takeoff_precheck_20261103_r1/` | 11 | 含 protocol、`source_lock`、`sources`、inputs、raw MAT、metrics、checks、completion、status、run.log——**结构完整** |
| `logs/wtr/precheck_20261103_r1/` | 17 | WTR + manifest + independent_audit + replay_checks |
| `figures/hover_distance_takeoff_precheck_20261103_r1/` | 11 | 图与表清单 |

选择理由：单方法（`PCA_PREDICTIVE`）、单种子（501）、单次仿真（`simulation_calls: 1`）、非正式批（`formal_batch_launched: false`）、身份清楚、体量小、覆盖了统一布局的全部子目录。**它是最能"试出布局问题"又不伤正式证据的对象。**

### W2：`gnss_regression` / `1000s_20261104_r1`（25 项 / 39,102,531 字节）

第二个试点，用于测试**跨目录合并**：6 项来自 `results/`，19 项来自 `docs/validation/shc09_b_frame_20261104/gnss_1000s_model_20261104/`（协议、锁、报告、脚本、指标）。这一情形在真实迁移中必然出现，晚试不如早试。

**W2 必须在 W1 完全通过（含回滚演练）后才启动。**

### 明确延后（W3，见 CSV 的 `BATCH_SUMMARY` 行）

| 对象 | 延后理由 |
|---|---|
| `final_precheck_20261103_r1` / `..._changeB_20261104_r1` | `formal_lock.json` 用**绝对路径**指向其 MAT（§5.2） |
| 两批正式批（30 MAT / 15+15 WTR） | 最高价值证据；先确认小批次流程可靠 |
| Round 5–7 | Round 之间存在依赖链，需按序 |
| WindTrace 在用包 / r14 回退包 | 17 GB 量级、需隔离启动；且 r14 从未启动验证 |
| `f8_comparison_20261101` | preflight 期间出现过瞬时缺失（[交接验收](HANDOFF_ACCEPTANCE.md) §4.1），需先确认稳定性 |

## 5. 锁文件与历史 engine 的影响检查（本轮实测）

### 5.1 路径引用普查

对 11,144 个受保护文件做全量内容扫描：

| 指标 | 数量 |
|---|---:|
| 含仓库路径字样（`Ducted-Fan-SHC09-matlab` 或 `results/hover` 等）的文件 | 409 |
| 含**绝对路径**（`E:\\Ducted-Fan-SHC09-matlab` 或 `E:/Ducted-Fan-SHC09-matlab`）的文件 | **331** |

按 study 分布：`historical_evidence` 163、`unclassified_existing_evidence` 76、`provenance` 37、`hover_distance_takeoff_formal` 25、`ecl_navigation` 13、`baseline_source` 9、`ppid_capacity` 6、`hover_distance_takeoff` 2。

**结论：迁移不是"移动文件"这么简单——331 个文件里写着旧绝对路径，而这些文件多数是锁、清单或审计记录，不允许改写。**

### 5.2 两个已确认的关键耦合

**(a) `formal_lock.json` 用绝对路径指向预检 MAT**

`results/hover_distance_takeoff_formal_20261103_r1/formal_lock.json` 含：

```json
"precheck_source": "E:\\Ducted-Fan-SHC09-matlab\\results\\hover_distance_takeoff_final_precheck_20261103_r1\\logs\\PCA_PREDICTIVE_s501.mat"
```

含义：**移动 `final_precheck_20261103_r1` 会使正式批的冻结锁记录的路径失效**。因为锁不得改写，唯一正确做法是保持该路径可解析（保留原址，或提供受控别名）。这就是它被列入 W3 的原因。

**(b) WTR 交付清单用仓库相对路径指回 results**

`logs/wtr/precheck_20261103_r1/manifest.json` 含：

```json
"source_mat": "results/hover_distance_takeoff_precheck_20261103_r1/logs/PCA_PREDICTIVE_s501.mat",
"figures": "figures/hover_distance_takeoff_precheck_20261103_r1"
```

含义：即使把整个预检批次一起搬走，清单里的两条字符串仍指向旧位置。处理方式见 §5.4。

### 5.3 `source_lock.json` 的路径语义

预检 `source_lock.json` 记录的源码路径是**仓库根相对**形式（`research\\ppid_pindi\\ppid_simulate.m`、`experiments\\ca_protocol.m` 等），不是相对锁文件自身。

- 因为它是**根相对**，把锁文件从 `results/<批次>/` 移到 `results/<study>/<batch_id>/provenance/` **不会**改变这些字符串的含义——只要解析器以仓库根为基准。
- 反之，如果某个消费方以"锁文件所在目录"为基准解析，移动就会破坏。**因此登记时必须显式声明 `root_id = matlab_original`（映射到仓库根），并在 `validate` 阶段检查解析基准。**

### 5.4 engine 影响

| 对象 | 是否受 Results 迁移影响 | 依据 |
|---|---|---|
| `analysis/allocation_comparison_engine.m` 记录的源码路径+字节 | **否**（移动 results 不改源码路径） | engine 覆盖源码，不覆盖 `results/` |
| `ppid_source_manifest` / `formal_lock` / `source_lock` 的源码 SHA | **否** | 被记录的源码文件不移动 |
| 若未来移动 `research/`、`platform/` 等**源码**目录 | **是**，会改变 engine 与锁的解析 | 属 Phase 3，需另批 |

**本阶段只登记/迁移 results 与 logs/figures 中的证据，不动源码，因此 engine 不受影响。** 任何把"源码迁移"混入 Results 迁移的做法都必须否决。

### 5.5 兼容与别名策略

| 策略 | 内容 | 适用于 |
|---|---|---|
| **S1 原址保留 + 索引**（默认） | 文件不动，`_index` 建立 canonical ↔ legacy 双向映射 | 全部批次，尤其 W1/W2 |
| **S2 复制到新址 + 索引**（迁移） | 复制到 `results/<study>/<batch_id>/`，逐文件校验，更新 `_index`，**原址保留观察** | W1/W2 的"迁移"步骤 |
| **S3 受控别名** | 为被绝对路径引用的旧位置保留目录联接/兼容路径，使旧字符串仍能解析 | `final_precheck_*`（被 `formal_lock` 引用） |
| **S4 显式 legacy locator** | 在 `manifest.json` 的 `legacy_locations` 记录旧路径，供解析器回退 | W2 跨目录合并项 |

禁止：改写锁内路径、改写 WTR manifest 的 `source_mat`、用"修正相对路径"消除差异、把 `..` 或盘符写入可迁移 artifact 路径（schema 已禁止）。

## 6. 回滚策略

| 阶段 | 回滚动作 | 边界 |
|---|---|---|
| 复制中断 | 保留不完整目标用于诊断，源不动；`_index` 不发布 | 不删除源，不重命名 |
| 校验失败 | 该文件标 `failed`，整批不发布索引 | 不用"容差"放行 |
| 索引发布后发现问题 | 回退到上一个完整索引版本（保留事务日志） | 不覆盖旧索引文件 |
| 需要撤销迁移 | 把 `_index` 指回 legacy locator，原址仍在 | 跨卷不假定 `rename` 原子性 |
| 源损坏 | 从已完成 SHA 核验 + 恢复测试通过的 snapshot 恢复到**新目录**，验证后再批准切换 | 不用恢复操作覆盖主工作树或旧 MAT |

每个迁移批次必须满足：**源在观察期内始终存在**，且 `_index` 每次发布保留前一完整版本。

## 7. 验收门槛

| Gate | 条件 | 由谁批准 |
|---|---|---|
| M1 | 独立备份完成，11,144 项 `dest_full_sha256` 通过 | 用户 + 执行者 |
| M2 | 恢复抽查按 `RESTORE_VERIFICATION_PLAN.md` 通过 | 用户 |
| M3 | schema v1 校验通过（结构 + 唯一 ID + 引用存在 + 计数算术） | 执行者 |
| M4 | 逐文件迁移审批单（src/dst/size/SHA/锁引用/回滚） | **用户逐批批准** |
| M5 | 路径解析验证（旧字符串仍可解析或已登记 legacy locator） | 执行者 + 用户确认 |
| M6 | 回滚演练通过 | 执行者 |
| M7 | 试点批次连续 30 天无回滚需求后才推进下一批 | 用户 |

**M4 是硬门槛**：Phase 1 的 `MIGRATION_MATRIX.csv` 是**候选矩阵，不是执行单**，不得直接当作移动脚本。

## 8. 需要单独审批的操作

| 操作 | 为何单独审批 |
|---|---|
| 创建/写入任何正式批次 `manifest.json` | 一旦写入即成为证据声明 |
| 在原址以外新建 `results/<study>/<batch_id>/` 目录 | 改变布局 |
| 物理移动（而非复制）任何原始 MAT/WTR | 不可逆风险 |
| 删除原址 | 删除需独立清单 + 有效期 |
| 实施/安装 Results Manager 到主仓库 | 代码变更，属 Phase 3 范畴 |
| 改写任何锁、协议、WTR manifest | 破坏冻结字节 |
| 把 `docs/validation/` 内容并入 results | 影响文档链接 |

## 9. 本轮未做的事（明确边界）

- 未创建、未覆盖任何正式批次 `manifest.json`；`Phase2A/examples/*.manifest.json` 仍为 `DESIGN_EXAMPLE_ONLY`。
- 未修改 Results 原址，未移动任何文件。
- 未实现、未安装 Results Manager。
- 未把 Phase 1 迁移矩阵当作执行单。
- 未重跑任何仿真以"补全"缺失 raw。
