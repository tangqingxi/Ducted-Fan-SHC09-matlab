# Phase 2B W1/W2 迁移试点报告

日期：2026-11-05（Asia/Shanghai）。
试点目录：`D:\AeroGNC-Backup\_work\migration-pilot\pilot_20261105T022204`
候选来源：`Phase2B-Preflight/FIRST_MIGRATION_CANDIDATES.csv`
方式：**复制式、非破坏性**。原址文件全部保留，未切换生产路径，未删除任何文件。

## 1. 结论

| 波次 | 计划 | 复制并校验 | 字节 | 正向解析 | 原址解析 | 回滚可用 |
|---|---:|---:|---:|---|---|---|
| W1（预检批） | 39 | **39** | 55,480,098 | 39/39 | 39/39 | 是 |
| W2（GNSS 回归） | 25 | **25** | 39,102,531 | 25/25 | 25/25 | 是 |

**两个波次全部通过：目标字节正确、新区布局可解析、原址仍可访问、索引可回退。**

## 2. W1：`hover_distance_takeoff` / `precheck_20261103_r1`

| 项目 | 内容 |
|---|---|
| 源 | `results/hover_distance_takeoff_precheck_20261103_r1/`（11 项）、`logs/wtr/precheck_20261103_r1/`（17 项）、`figures/hover_distance_takeoff_precheck_20261103_r1/`（11 项） |
| 目标 | `results/hover_distance_takeoff/precheck_20261103_r1/{protocol,provenance,inputs,raw,metrics,validation,management,wtr,figures}/` |
| 校验 | 复制前源 SHA256、复制后目标 SHA256、逐项与计划值比对 |

这一波次覆盖了统一布局的全部子目录，且包含 3 类跨目录来源（results / logs / figures），因此能真实暴露映射错误——不是只搬一个目录的"假试点"。

## 3. W2：`gnss_regression` / `1000s_20261104_r1`

| 项目 | 内容 |
|---|---|
| 源 | `results/gnss_1000s_regression_20261104_r1/`（6 项）+ `docs/validation/shc09_b_frame_20261104/gnss_1000s_model_20261104/`（19 项） |
| 目标 | `results/gnss_regression/1000s_20261104_r1/{protocol,provenance,raw,metrics,validation,figures,management}/` |
| 特殊点 | 跨 `results/` 与 `docs/validation/` 两个根合并到同一批次 |

这一步刻意安排在 W1 之后：它测试的是"跨根合并"，风险高于单根搬迁。合并后 `report.md` 从 `docs/validation/` 移入 `validation/`，原文档链接仍指向旧位置——**这正是必须保留原址的原因**。

## 4. 四项验证的含义

| 验证 | 做法 | 结果 |
|---|---|---|
| 目标 SHA256 | 每个文件读回并计算 | 64/64 与计划一致 |
| 正向解析 | 用试点索引从**新结构**定位并重算哈希 | 64/64 可解析 |
| 原址可访问 | 用同一索引退回 `matlab_original` 根定位 | 64/64 可解析 |
| 回滚演练 | 把索引指针整体退回 legacy locator 后再解析 | 两波次均可用 |

"回滚可用"的判定不是看计划文档，而是**实际按旧路径重新解析并通过哈希校验**。

## 5. 已知耦合与限制

| 项 | 说明 |
|---|---|
| W1 的 `wtr/manifest.json` | 内含 `source_mat` 与 `figures` 两条仓库相对路径；因原址保留，仍可解析。若将来删除原址，必须先建立 legacy 别名。 |
| W2 的 `validation/report.md` | 原位于 `docs/validation/`，被文档链接引用；合并后旧链接指向旧位置，需在文档层统一处理。 |
| `source_lock.json` | 试点中**未改写**；其记录的源码路径是仓库根相对，与新布局无关。 |
| 生产路径 | **未切换**。`results/` 与 `logs/` 仍是唯一在用的读取路径。 |
| W3 批次 | 涉及 `formal_lock.json` 绝对路径的 `final_precheck_*` 继续延后，未纳入试点。 |

## 6. 本阶段未做的事

- 未删除、未移动原址任何文件；
- 未修改 `results/`、`logs/`、`figures/`、`docs/` 下的任何内容；
- 未创建正式批次 `manifest.json`；
- 未切换 Results Manager 的正式根；
- 未对 W3 批次做任何试搬。

## 7. 可复核入口

| 文件 | 内容 |
|---|---|
| `pilot_events.csv` | 64 条逐文件复制与校验事件 |
| `W1_index.json` / `W2_index.json` | 试点索引（legacy 与 target 双向 locator） |
| `pilot_summary.json` | 汇总（含正向/原址/回滚解析结果） |
| 试点目录 | `D:\AeroGNC-Backup\_work\migration-pilot\pilot_20261105T022204\` |
