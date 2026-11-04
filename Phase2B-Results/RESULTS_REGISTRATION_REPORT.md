# Phase 2B Results 原始数据登记报告

日期：2026-11-05（Asia/Shanghai）。
前置：全量备份与目的地 SHA256 验证已通过（见 `Phase2B-Backup`）。
产物：`index.json`（71 个批次）、`batches.csv`、`path_dependency.csv`。
边界：**只建索引，未创建或覆盖任何正式 `manifest.json`，未移动任何原始数据，未修改任何锁文件。**

## 1. 结论

| 项目 | 结果 |
|---|---:|
| 索引批次总数 | 71 |
| 其中实验批次 | 14 |
| 软件工件批次 | 1（WindTrace 在用包） |
| 基线文件批次 | 2（`baseline_source`、`provenance`） |
| 历史证据批次 | 54 |
| 索引是否依赖当前磁盘绝对路径 | **否**（使用 `root_id` + POSIX 相对路径） |
| 原始数据是否被改动 | **否** |

**索引的目标只有一个：让实验身份可被解析，而不依赖"文件现在放在哪个盘"。** 备份根 `backup_339d7b1a` 与原始根 `matlab_original` 都只是 root 标识，真实路径在本地配置里解析。

## 2. 14 个实验批次的登记状态

| study / batch_id | 文件 | 执行 | 验收 | 保留 |
|---|---:|---|---|---|
| `hover_distance_takeoff_formal/hover_distance_takeoff_formal_20261103_r1` | 156 | completed | **failed** | KEEP_EVIDENCE |
| `hover_distance_takeoff_formal/hover_distance_takeoff_formal_changeB_20261104_r1` | 76 | completed | **failed** | KEEP_EVIDENCE |
| `hover_distance_takeoff_formal/hover_distance_takeoff_final_precheck_20261103_r1` | 14 | completed | passed | KEEP_EVIDENCE |
| `hover_distance_takeoff_formal/hover_distance_takeoff_final_precheck_changeB_20261104_r1` | 16 | completed | passed | KEEP_EVIDENCE |
| `hover_distance_takeoff/hover_distance_takeoff_precheck_20261103_r1` | 39 | completed | passed | KEEP_EVIDENCE |
| `ecl_navigation/gnss_1000s_regression_20261104_r1` | 25 | completed | **failed** | KEEP_EVIDENCE |
| `ecl_navigation/round5_changeB_20261104` | 28 | unknown | not_evaluated | KEEP_EVIDENCE |
| `ecl_navigation/round6_changeB_20261104` | 35 | unknown | not_evaluated | KEEP_EVIDENCE |
| `ecl_navigation/round7_changeB_20261104` | 47 | unknown | not_evaluated | KEEP_EVIDENCE |
| `ecl_navigation/audit_changeB_20261104` | 35 | unknown | not_evaluated | KEEP_EVIDENCE |
| `ppid_capacity/ppid_capacity_fix_20261103_r1` | 49 | unknown | not_evaluated | KEEP_EVIDENCE |
| `hover_distance_takeoff_formal/hover_distance_takeoff_formal_work_20261103_r1` | 8 | unknown | not_evaluated | KEEP_EVIDENCE |
| `hover_distance_takeoff_formal/hover_distance_takeoff_formal_work_changeB_20261104_r1` | 5 | unknown | not_evaluated | KEEP_EVIDENCE |
| `hover_distance_takeoff_formal/hover_distance_takeoff_work_20261103_r1` | 6 | unknown | not_evaluated | KEEP_EVIDENCE |

`unknown` 表示**没有原始 `status.csv` 或语义未确认**，不是"推测为通过"。索引里显式带 `limitations`，不允许后续用新架构重新解释。

## 3. 历史语义保留（本轮强制的四条）

| 规则 | 落地情况 |
|---|---|
| 运行完成 ≠ 科研验收通过 | 两批正式批 `execution_status=completed`、`acceptance_status=failed` 同时存在 |
| 真实恢复失败必须保留 failed | 正式批 `passed_runs=0 / evaluated_runs=15`；GNSS 批 `0/1` |
| 估计恢复通过 ≠ 真实恢复通过 | 未把估计恢复计入 `passed_runs`；`acceptance_note` 明写"真实恢复 0/15；估计恢复 15/15" |
| 缺失 raw 需明确可复算边界 | 历史证据批次统一附 `limitations`；`record_kind=evidence_batch` |

验收判据字段 `criterion` 固定为"原协议真实状态恢复判据（未放宽）"，防止未来把阈值改写后重算。

## 4. 路径依赖检查（任务书 4.3）

对 11,144 个受保护文件做全文扫描，匹配 `E:\` / `E:/` 形式的仓库绝对路径：

| 指标 | 数值 |
|---|---:|
| 含绝对路径的文件 | **333** |
| 绝对路径引用总数 | **2,981** |
| 这些引用仍能在快照中解析 | **220（7.4%）** |
| 已悬空（指向早已不存在的路径） | **2,761（92.6%）** |
| 其中是锁文件（`source_lock.json`/`formal_lock.json`） | **6** |

> 说明：`Phase2B-Preflight` 用较窄的匹配式得到 331；本轮匹配式更宽（含无扩展名与目录形式），得 333。差异来自匹配范围，不是数据变化。

### 4.1 四类处理

| 类别 | 判据 | 处理 |
|---|---|---|
| **A. 可由索引解析** | 引用目标存在于快照，且可由 `root_id` 映射 | 由 `_index` 建立 `legacy → canonical` 映射 |
| **B. 需要兼容映射** | 引用目标存在但位于将被移动的目录 | 迁移时保留旧路径别名或 legacy locator |
| **C. 锁内引用，不可修改** | 文件本身是 `source_lock`/`formal_lock` | **绝不改写**；靠"原址保留 + 别名"维持解析 |
| **D. 不适合迁移的批次** | 其路径被其他批次的锁以绝对路径引用 | 列入 W3 延后，不纳入试点 |

### 4.2 关键耦合（实测）

- `results/hover_distance_takeoff_formal_20261103_r1/formal_lock.json` 含
  `precheck_source = E:\Ducted-Fan-SHC09-matlab\results\hover_distance_takeoff_final_precheck_20261103_r1\logs\PCA_PREDICTIVE_s501.mat`
  → 移动 `final_precheck_20261103_r1` 会让该锁定路径失效。**该批次继续延后（W3）。**
- `logs/wtr/precheck_20261103_r1/manifest.json` 含 `source_mat` 与 `figures` 两条仓库相对路径 → 试点中通过"原址保留"维持可解析。
- `current_summaries` 单个批次贡献 2,164 条引用（其中 2,158 条悬空）→ 以历史指针为主，不是活依赖；不据此做批量替换。

### 4.3 明确禁止

- 不批量替换 MAT / JSON / 锁文件内部的绝对路径；
- 不因为"引用悬空"就删除对应文件；
- 不把悬空引用"修正"成新路径来让检查变绿。

## 5. 索引与 schema 的关系

本索引是**登记索引**（`aerognc.results.index.v1`），字段语义对齐 `RESULTS_MANIFEST_SCHEMA.json` v1：

| 索引字段 | 对应 schema 概念 |
|---|---|
| `batch_key` / `study` / `airframe` / `batch_id` | 批次键 |
| `runs[].run_id/method/seed/execution_status/input_signature` | `runs[]` |
| `execution_status` / `acceptance_status` / `retention_status` | 三个独立状态 |
| `acceptance.passed_runs/evaluated_runs/criterion` | `acceptance_summary` |
| `backup_locator` / `storage.backup/restore` | `storage` + `artifact.locator` |
| `protocol.sha256` / `engine.id` / `source_commit` | `protocol` / `engine` / `provenance` |

**未做的部分（明确声明）**：本阶段没有为每个批次生成正式 `manifest.json`。原因有二：

1. 生成 schema v1 全字段 manifest 需要逐 run 的 artifact id、事件序列与验收证据引用，属于 Results Manager 的实现工作（Phase 3）；
2. 本机没有 Draft 2020-12 校验器（`jsonschema` 未安装），在无法完整校验的情况下批量产出 manifest，会构成"自称符合 schema"的未验证断言。

因此本轮只交付**可验证的索引**，并把它作为 Manager 的输入；这符合"先登记身份、再生成合同"的顺序。

## 6. 可复核入口

| 文件 | 内容 |
|---|---|
| `index.json` | 71 个批次的完整索引（含 root 定义、runs、limits） |
| `batches.csv` | 扁平清单 |
| `path_dependency.csv` | 333 个含绝对路径文件的逐条统计 |
| `path_dependency_summary.json` | 按批次聚合 |
