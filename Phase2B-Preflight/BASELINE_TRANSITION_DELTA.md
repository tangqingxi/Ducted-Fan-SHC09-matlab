# 基线过渡差异：339d7b1a → d464ab5a

日期：2026-11-05（Asia/Shanghai）。
目的：区分**科学基准的文件身份**、**Phase 2A 记录的保护文件身份**与**当前文档版本的文件身份**，并给出可复核的版本差异映射。不覆盖 Phase 2A 原清单，不把已授权的文档变化误判为科学源码修改。

## 1. 三个提交身份

| 身份 | SHA | 角色 | 本轮是否改变 |
|---|---|---|---|
| `science_baseline_commit` | `339d7b1a997de6ba350cef3207d8a5b7db3d838d` | 科学与重构起始基准；Phase 2A 保护清单的取样时刻 | 不变；冻结 |
| `documentation_update_commit`（Phase 2A.5） | `d464ab5ad5b368a5eb5876e53696aa7c607733f1` | 重写 README/AGENTS/HANDOFF 与入口指南；10 份 Markdown | 已存在；本轮不改写 |
| `documentation_update_commit`（后续） | `fdc933694db9c16a0d9ffcd6d9c391b052352d22` | 在 `AGENTS.md` 增加第 9 节"交接与文档更新"（+11 行）；1 份 Markdown | **preflight 期间产生**，见 §2.1 |
| `current_main_commit` | `fdc933694db9c16a0d9ffcd6d9c391b052352d22` | 当前 `main` = 本地 = `origin/main` = 远端 `main` | 本轮未提交主仓库 |

当前 `main` 包含两次纯文档提交，但**不改变冻结科学实验的来源身份**。备份目标路径 `${BACKUP_ROOT}/AeroGNC-Sim/339d7b1a/snapshot/...` 中的 `339d7b1a` 指基准身份，不是当前 HEAD。

## 2. 变化集合：恰好 10 份 Markdown

`git diff --name-only 339d7b1a d464ab5a` 的完整结果，与非 Markdown 计数 0：

| # | 路径 | 动作 | 基线字节数 | 当前字节数 |
|---|---|---|---:|---:|
| 1 | `README.md` | REWRITE | 22,647 | 7,908 |
| 2 | `AGENTS.md` | REWRITE | 55,053 | 8,125 |
| 3 | `HANDOFF.md` | REWRITE | 64,646 | 4,006 |
| 4 | `WORKSPACE_MIGRATION.md` | REWRITE | 2,336 | 1,629 |
| 5 | `docs/README.md` | REWRITE | 4,633 | 3,133 |
| 6 | `docs/repository_map.md` | REWRITE | 3,772 | 3,747 |
| 7 | `docs/guides/architecture.md` | REWRITE | 3,731 | 5,106 |
| 8 | `docs/guides/getting_started.md` | ADD | 0（不存在） | 4,192 |
| 9 | `docs/guides/research_workflows.md` | ADD | 0（不存在） | 5,286 |
| 10 | `docs/guides/results_and_evidence.md` | ADD | 0（不存在） | 5,362 |

合计 10 个文件、442 insertions / 1639 deletions。**没有数值源码、协议、`source_lock`/`formal_lock`、配置、测试或原始数据文件发生变化。**

### 2.1 preflight 期间追加的第二次文档提交

在本次 preflight 进行中，`main` 又前进了一次：

| 项目 | 内容 |
|---|---|
| 提交 | `fdc933694db9c16a0d9ffcd6d9c391b052352d22` |
| 说明 | `docs: add handoff and document-update rules to AGENTS.md` |
| 范围 | 1 个文件：`AGENTS.md`，+11 行 |
| 内容 | 新增第 9 节"交接与文档更新"（任务级/交接级区分、`check_handoff.py` 自检等） |
| 是否已推送 | 是；`origin/main` 与远端 `main` 均为该 SHA |

² 该提交使 `AGENTS.md` 的当前字节从 `d464ab5a` 的 8,125 变为 9,528，当前工作树 SHA256 为 `041c66cd…f5419be5`。它**仍然只改文档**，因此：

- 累计 `339d7b1a → fdc93369` 的差异集合**仍是同样的 10 份 Markdown**（`AGENTS.md` 被连续修改两次）；
- 保护清单的 11,144 项**没有增减**；
- 7 项漂移条目不变，只是 `AGENTS.md` 的"当前字节"又变了一次；
- 备份仍需从 Git 重建 `AGENTS.md` 的**基线 CRLF 字节**，与这次新提交无关。

这条记录同时是 §5 的现场证据：**protected set 的成员身份稳定，但工作树内容在 preflight 期间持续被外部推进。**

## 3. 与保护清单的交集

把上述 10 个路径与 `Phase2A/BACKUP_PLAN.csv` 的 11,144 个 `source_path` 求交：

| 类别 | 数量 | 是否在保护清单 |
|---|---:|---|
| REWRITE 且命中清单 | 7 | 是（第 4 节逐项核对） |
| ADD 且不在清单 | 3 | 否 |

3 份 ADD 文件在 `339d7b1a` 时刻**根本不存在**，因此不可能出现在以该时刻取样的清单中。这是**新增文档**，不是保护遗漏；其身份由 `Phase2A5-Docs/DOCUMENT_CHANGE_MANIFEST.csv` 与 Git 提交 `d464ab5a` 共同固定。

由此得到关键结论：

> 保护清单的 11,144 个条目**没有新增项、没有删除项**。变化只发生在 7 个条目的"当前工作树字节"与"计划字节"不一致。

## 4. 逐项版本差异映射（本轮实测）

对 7 个命中项，分别计算：计划 SHA256（Phase 2A 记录值）、基线 Git blob 正文 SHA256、blob 经 LF→CRLF 变换后的 SHA256、当前工作树 SHA256。

| 路径 | 计划 SHA256（=保护目标） | 基线 blob 正文 SHA | blob↔计划 | 当前工作树 SHA256 | 结论 |
|---|---|---|---|---|---|
| `AGENTS.md` | `e363a29f…19b91e` | `66e543d9…88ea63` | blob 不等；**CRLF 变换后相等** | `041c66cd…5419be5`（9,528 B）² | 计划记录的是 Windows CRLF 工作树字节 |
| `HANDOFF.md` | `1cecf4ce…e9aa807` | `c151cac0…f49af19` | blob 不等；**CRLF 变换后相等** | `4ba8fcc2…22317c0` | 同上 |
| `README.md` | `ee9b94c4…a806993` | `d7082d44…4396828` | blob 不等；**CRLF 变换后相等** | `c0951985…bc642896` | 同上 |
| `docs/README.md` | `71165052…c1cf5082` | `fcd72425…dfe93d` | blob 不等；**CRLF 变换后相等** | `d193a88d…499ec2d4` | 同上 |
| `WORKSPACE_MIGRATION.md` | `c3904715…7e026783` | `c3904715…7e026783` | **blob 直接相等** | `f28a6fa7…46dfc4` | 该文件原本就是 LF |
| `docs/guides/architecture.md` | `1b2d24b5…13f7c5166` | `1b2d24b5…13f7c5166` | **blob 直接相等** | `26f7dfaa…05f922c` | 该文件原本就是 LF |
| `docs/repository_map.md` | `ebbf81bd…78636cc2` | `ebbf81bd…78636cc2` | **blob 直接相等** | `5ad52745…5ec5f3b1` | 该文件原本就是 LF |

（表中省略号为排版截断；完整 64 位值见 `Phase2A5-Docs/DOCUMENT_CHANGE_MANIFEST.csv` 的 `before_local_sha256`、`before_git_blob_content_sha256` 与本目录 `BACKUP_DRY_RUN_PLAN.csv` 的 `sha256` 列，三者可逐项对齐。）

### 4.1 为什么这些字节"可重建但不可直接 checkout"

- 主仓库 `.gitattributes` 含 `*.md text eol=lf`，且该规则**在 `339d7b1a` 与 `d464ab5a` 完全相同**（`git diff 339d7b1a d464ab5a -- .gitattributes` 无差异）。
- 因此今天若在新目录执行 `git checkout 339d7b1a -- AGENTS.md`，得到的是 **LF blob 正文**，其 SHA256 是上表第 3 列，**不等于**计划值。
- 计划值对应的是当年 Windows 工作树上的 **CRLF 版本**。该版本可由 blob 确定性重建：`blob.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")`，对 4 个文件逐一验证后 SHA256 与计划值**完全相等**。

所以：**7 项全部可在不修改任何冻结文件的前提下，重建为与 Phase 2A 计划逐字节一致的副本**；其中 4 项需要显式 CRLF 变换，3 项直接取 blob。

## 5. 172 个 F8 条目：内容未变，工作树副本曾瞬时缺失

`examples/f8_comparison_20261101/` 的 172 个受保护条目属于另一类差异，**与文档整改无关**：

| 检查 | 结果 |
|---|---|
| 计划 SHA256 vs `339d7b1a` blob 正文 SHA256 | 172/172 相等 |
| 计划 SHA256 vs `d464ab5a` blob 正文 SHA256 | 172/172 相等 |
| 说明 | 该目录自基线以来**内容从未变化**，只是本轮 preflight 期间工作树副本一度不存在，随后被外部恢复 |

因此这 172 项**不需要任何版本映射**，只需要"复制前确认文件在位"或"从 Git 导出"的容错分支。详细现场记录见[交接验收](HANDOFF_ACCEPTANCE.md) §4.1。

## 6. 判定：这是文档变化，不是科学来源变化

| 判据 | 结论 |
|---|---|
| 变化文件类型 | 全部为 `.md` 描述性文档 |
| 是否含数值实现 | 否；无 `.m`/`.py`/`.json` 协议/锁变化 |
| 是否改变 experiment identity | 否；`source_lock.json`、`formal_lock.json`、protocol JSON 的 Git 内容未变 |
| 是否改变 MATLAB 搜索路径或 engine | 否；未改 `ca_setup.m`、注册表或 `allocation_comparison_engine.m` |
| 是否改变论文/报告结论 | 否；只重排入口与说明，历史结论留在原协议/报告 |

## 7. 对保护清单的处理决定（不覆盖原清单）

**不修改 `Phase2A/BACKUP_PLAN.csv` 的任何一行。** 该文件是 Phase 2A 的审计记录，其 SHA256 列记录的是 `339d7b1a` 时刻的字节身份。本轮只新增派生视图：

| 产物 | 作用 |
|---|---|
| `BACKUP_DRY_RUN_PLAN.csv`（本目录） | 逐行给出 `PRESENT_MATCH` / `PRESENT_BYTES_SUPERSEDED_DOC` 与建议动作，保留原始 `sha256` 列作为**唯一验证目标** |
| 本文件 | 解释 7 项为何漂移、如何重建 |

### 7.1 需要用户选择的两条路径（条件 C4）

| 方案 | 做法 | 优点 | 代价 |
|---|---|---|---|
| **A（建议）** | 从 Git blob 重建 7 项基线字节（4 项加 CRLF 变换），写入快照并以计划 SHA256 验证 | 快照与 Phase 2A 计划**逐字节一致**；`339d7b1a` 快照语义完整 | 需要在备份工具中实现"从 Git 导出 + 换行重建"这一非普通文件复制分支，并单独记录该分支 |
| B | 7 项不进入快照，登记为"已被授权的文档提交取代" | 实现简单，纯文件复制 | 快照不再是 11,144 项；需在恢复验证与登记中显式声明 7 项缺失及其理由 |

在用户选择前，这 7 项在 `BACKUP_DRY_RUN_PLAN.csv` 中标记为 `RECONSTRUCT_FROM_GIT_BLOB`，审批门为 `BACKUP_ROOT_AND_SCOPE;DOC_BYTE_BASIS`。

无论选择哪条路径，**当前工作树中的新版文档都不得被冒充为基线字节**，也不得回写 Phase 2A 清单来"消除差异"。

## 8. 未涉及的事项

- 未创建主仓库分支、Tag、提交或推送。
- 未修改任何文档正文、`.gitattributes` 或换行策略。
- 未把 3 份新增文档补入保护清单（其字节已由 Git 与 Phase 2A.5 清单固定，且无原始科学数据角色）。
