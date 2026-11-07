# Phase 2B-Preflight 交接验收记录

日期：2026-11-05（Asia/Shanghai）。
执行者：DeepSeek Agent（本轮接手方）。
范围：只读核验两个仓库的 Git 现场、工作树、Phase 2A.5 影响范围与任务外变化；不执行备份、登记、迁移或删除。

## 1. 验收结论

**结论：ACCEPTED_WITH_CONDITIONS（有条件接受交接）。**

| 判定项 | 结果 |
|---|---|
| 主仓库 HEAD 与用户给定 SHA 的关系 | 一致方向；HEAD 已由 `d464ab5a` 前进到 `fdc93369`（仅 `AGENTS.md` +11 行，已推送），`d464ab5a` 仍为祖先 |
| 审计仓库 HEAD 与用户给定 SHA 一致 | 通过 |
| 远端 main 与本地一致（两仓库） | 通过 |
| 实际 Git worktree 数量 | 各 1 个，共 2 个，无遗留工作树 |
| Phase 2A.5 是否仅涉及 10 份 Markdown | 通过（0 个非 Markdown 文件） |
| 源码/协议/锁/原始数据是否出现非预期内容变化 | 未发现内容变化；但见 §4.1 的瞬时缺失事件 |
| 是否存在其他 Agent 留下的未提交修改 | 交接时刻无；过程中出现的 `AGENTS.md` +11 行已由外部提交为 `fdc93369`（§4.5）；另有 1 个未跟踪工具目录（§4.2） |
| 是否存在必须由本 Agent 修复才能继续的阻塞 | 无；但 §7 的 4 项条件需用户确认后才可进入实际复制 |

条件 C1–C4 是**备份位置与范围类审批**，不是 Git 缺陷，不阻塞本轮交付，但阻塞 Phase 2B 实际执行。

## 2. Git 现场核验（本轮实测）

| 项目 | 主仓库 | 审计仓库 |
|---|---|---|
| 本地路径 | `E:/Ducted-Fan-SHC09-matlab` | `E:/AeroGNC-Phase-Audit` |
| 当前分支 | `main` | `main` |
| 本地 HEAD | `fdc933694db9c16a0d9ffcd6d9c391b052352d22` | `4e16775ccfca416030c484ca317cbaab2c1cd803` |
| `origin/main` | `fdc933694db9c16a0d9ffcd6d9c391b052352d22` | `4e16775ccfca416030c484ca317cbaab2c1cd803` |
| `git ls-remote origin refs/heads/main` | `fdc933694db9c16a0d9ffcd6d9c391b052352d22` | `4e16775ccfca416030c484ca317cbaab2c1cd803` |
| 工作树状态 | 干净，仅 1 个未跟踪目录（§4.2） | 完全干净 |
| 暂存区 | 空 | 空 |
| stash | 无 | 无 |
| 远端分支 | 仅 `main` | 仅 `main` |

`git worktree list --porcelain` 实际结果：

```text
E:/Ducted-Fan-SHC09-matlab   HEAD fdc93369  branch refs/heads/main
E:/AeroGNC-Phase-Audit       HEAD 4e16775  branch refs/heads/main
```

两个 worktree 分别属于两个不同仓库，不是同一仓库的多个工作树。Phase 1、Git-Convergence 与 Phase 2A 报告中"仍保留 C 盘工作树"等描述保持为历史快照，不据此判断现场。

### 2.1 环境事实（不是仓库缺陷）

本机 `http.sslBackend=schannel` 在当前执行环境返回 `SEC_E_NO_CREDENTIALS`，导致 `git ls-remote`/`push` 无法通过 Schannel 建立 TLS。改用 Git 自带的 OpenSSL 后端（`git -c http.sslBackend=openssl ...`）后，与 GitHub 的读写均正常，上述远端 SHA 即由该方式取得。这是一次性环境适配，**未修改任何仓库配置**，也未写入全局或仓库级 `http.sslBackend`。

## 3. Phase 2A.5 影响范围核验

两种口径互相独立，结论一致：

| 检查 | 命令 | 结果 |
|---|---|---|
| 基准到当前 HEAD 的差异 | `git diff --name-only 339d7b1a d464ab5a` | 恰好 10 个路径 |
| 上述路径中非 `.md` 的数量 | 过滤 `\.md$` | 0 |
| 文档提交自身范围 | `git show --stat d464ab5a` | 同上 10 个文件，442 insertions / 1639 deletions |
| baseline 与 HEAD 的 `.gitattributes` | `git diff 339d7b1a d464ab5a -- .gitattributes` | 无差异 |

即：`339d7b1a → d464ab5a` 之间除 10 份 Markdown 外，**没有任何源码、协议、锁、配置、测试或原始数据文件的 Git 内容变化**。逐文件身份与字节口径见[基线过渡差异](BASELINE_TRANSITION_DELTA.md)。

**在 preflight 进行中 `main` 又前进了一次**：`fdc933694db9c16a0d9ffcd6d9c391b052352d22`（`docs: add handoff and document-update rules to AGENTS.md`，仅 `AGENTS.md` +11 行，已推送）。因此截至交接时刻：

| 口径 | 结果 |
|---|---|
| `339d7b1a → d464ab5a` | 10 个文件，全 `.md` |
| `d464ab5a → fdc93369` | 1 个文件（`AGENTS.md`）+11 行 |
| `339d7b1a → fdc93369`（累计） | **仍是同样的 10 个 `.md`**，非 Markdown 计数 0 |

## 4. 任务外变化：记录、保护、未清理

按开发契约，发现非本任务修改时保留原状并报告，不执行 `reset`、`checkout`、`restore`、`clean` 或 `stash` 来制造干净状态。本 Agent 全程遵守该约束。

### 4.1 `examples/f8_comparison_20261101/` 的 172 个受保护文件瞬时缺失（重要）

| 时点 | 现场 |
|---|---|
| 首次核验（约 01:26） | `git status` 报 172 条 ` D`；该目录在磁盘上为空（0 个文件）；Python 现存性检查报 172 个缺失 |
| 字节级核验 | 对 172 个路径逐个执行 `git cat-file blob 339d7b1a:<path>`，其 SHA256 与保护清单计划值 **172/172 完全一致**，HEAD 亦一致 —— 字节未丢失，只是工作树副本不在 |
| 再次核验（约 01:40） | 172 个文件已全部回到工作树，`git status` 不再列出删除；文件 mtime 保留为 `2026-11-01 16:55:56` 等原始时间 |

判定与约束：

1. **本 Agent 没有执行任何恢复操作**。恢复并非由本轮工具产生：本轮对主仓库只有读取型命令（`git status`、`git ls-remote`、`git cat-file`、`git diff`、`git show`、`git reflog`、文件读取与哈希）。
2. 恢复来源与操作者未知。mtime 保留原始时间说明恢复工具保留了时间戳（`git checkout` 通常不会），可能是外部备份/同步/复制工具或另一会话的人工操作。
3. 该事件说明**主工作树在 preflight 期间并非静止**。因此备份执行必须在开始前重新核对源集合，并在复制期间做前后元数据/稳定性检查，不能假定计划生成时刻的状态仍然成立。
4. 由于字节可由 Git 对象完整重建，该事件未削弱备份可行性；但它是**执行期风险 R2**（见[风险与审批](RISKS_AND_APPROVALS.md)），不是可以忽略的噪声。

### 4.2 `.dsh-plugins/` 未跟踪目录

| 项目 | 现场 |
|---|---|
| 路径 | `E:/Ducted-Fan-SHC09-matlab/.dsh-plugins/skills-panel/` |
| 内容 | `client.js`、`index.js`、`cordis.patch.yml`、`package.json`、`icon.svg`、`locale/{en,zh}.json`、`README.md` |
| Git 状态 | 未跟踪（`??`），**未被 `.gitignore` 忽略** |
| 时间 | 目录创建 2026-11-04 23:54，最后写入 2026-11-05 01:03 |

判断：这是 DeepSeek Harness 的界面插件目录，属于**工具环境**，不是本项目内容。处理：不暂存、不提交、不移动、不删除、不加入 `.gitignore`。它只在主仓库工作树出现，本轮不向主仓库提交任何内容，因此不会误入库。

### 4.3 `.tmp_skill_review/` 与 `.tmp_skill_update/`

| 目录 | 当前是否存在 |
|---|---|
| `.tmp_skill_review/` | 否 |
| `.tmp_skill_update/` | 否 |
| `.tmp_skill/` | 否 |

Phase 2A.5 报告记录过收尾时出现的 `_tmp_skill_review/` 并于后续只读复查时消失。本轮复查确认两者当前均不存在。本轮**未创建、未清理、未忽略**任何此类目录，也不对其历史归属下结论。

### 4.4 其他未提交状态

- 暂存区为空（`git diff --cached` 无输出）。
- 无 stash。
- 交接时刻无被跟踪文件的未提交修改；`AGENTS.md` 的编辑在过程中已被外部提交（§4.5）。
- 无重命名、无删除（172 个 F8 文件的删除状态已由 §4.1 的外部恢复消除）。

### 4.5 `AGENTS.md` 被追加 11 行（先以未提交形式出现，随后已提交并推送）

| 项目 | 现场 |
|---|---|
| 文件 | `E:/Ducted-Fan-SHC09-matlab/AGENTS.md` |
| 首次观察（约 01:33） | ` M`（已跟踪、已修改、未暂存）；8,125 → 9,528 字节 |
| 再次观察（约 01:45） | 已由外部提交并推送为 `fdc933694db9c16a0d9ffcd6d9c391b052352d22`；`git status` 不再显示该修改 |
| 提交范围 | `git diff --stat d464ab5a fdc93369`：1 file changed, 11 insertions(+) |
| 当前 SHA256 | `041c66cdb9bfaacd67d8137af3bfc2d18cf1d11d67fef5c81c4d1947f5419be5` |
| 远端状态 | `origin/main` 与远端 `main` 均为 `fdc93369` |
| 新增内容 | 第 9 节"交接与文档更新"，引入任务级/交接级区分、`check_handoff.py` 自检等约束 |

判定与约束：

1. 该修改**不属于本 Agent**。本轮对主仓库只有读取型命令（`git status`、`git ls-remote`、`git cat-file`、`git diff`、`git show`、`git reflog`、文件读取与哈希），零写入、零提交。
2. 它的**提交发生在 preflight 进行中**。因此本轮早期表述"`current_main_commit = d464ab5a`"在交接时刻已更新为 `fdc93369`；`d464ab5a` 仍是 Phase 2A.5 的文档提交身份，两者角色不同、互不取代。
3. 对备份的影响：`AGENTS.md` 在保护清单中的目标字节是基线 CRLF 版本；无论工作树是 8,125 还是 9,528，都**不进入快照**，快照仍从 Git 重建，故**没有数据保护缺口**。
4. 对交接的影响：新增第 9 节改变了"交接级任务"的完成定义。本轮按其要求补充了 `HANDOFF.md` 与 `evidence-manifest.json`，并运行 `check_handoff.py`（结果见[阶段报告](PHASE2B_PREFLIGHT_REPORT.md)）。
5. 对现场稳定性的影响：这是 preflight 期间**第二起外部改动**（第一起为 §4.1），且呈现为"未提交 → 已提交并推送"的完整过程。两次都表明"计划生成时刻的工作树状态"不能直接当作执行时刻的状态。

## 5. 本轮只读边界（自我约束声明）

| 约束 | 执行情况 |
|---|---|
| 主仓库不提交、不改文档、不改源码 | 遵守；主仓库 0 次写入 |
| 不运行 MATLAB / 测试 / 仿真 | 遵守；未启动 MATLAB，未执行 `run_project_tests`、`run_platform_tests`、`test_platform_baseline` |
| 不复制、移动、删除原始数据 | 遵守；未对 `results/`、`logs/`、`examples/` 做任何写操作 |
| 不执行破坏性 Git | 遵守；未 `reset`/`clean`/`restore`/`stash`/`checkout`/强推 |
| 临时脚本位置 | 仅写入系统临时目录；本轮报告写入审计仓库 |
| 网络操作 | 仅只读 `ls-remote`；推送仅限审计仓库 `main` |

## 6. 交接资产可达性

14 份必读材料全部存在、可读、内容与本轮引用一致：

| # | 文件 | 状态 |
|---|---|---|
| 1 | 主仓库 `README.md` | 已读 |
| 2 | 主仓库 `AGENTS.md` | 已读 |
| 3 | 主仓库 `HANDOFF.md` | 已读 |
| 4 | 主仓库 `docs/guides/architecture.md` | 已读 |
| 5 | 主仓库 `docs/guides/results_and_evidence.md` | 已读 |
| 6 | 审计 `Phase1/PLAN.md` | 已读 |
| 7 | 审计 `Phase2A/PHASE2A_REPORT.md` | 已读 |
| 8 | 审计 `Phase2A/BASELINE_FREEZE.md` | 已读 |
| 9 | 审计 `Phase2A/BACKUP_PLAN.csv` | 已解析（11,144 行全量） |
| 10 | 审计 `Phase2A/RESULTS_MANIFEST_SCHEMA.json` | 已读（全文 988 行） |
| 11 | 审计 `Phase2A/RESULTS_MANAGER_SPEC.md` | 已读 |
| 12 | 审计 `Phase2A/PHASE2B_EXECUTION_PLAN.md` | 已读 |
| 13 | 审计 `Phase2A/APPROVAL_REQUEST.md` | 已读 |
| 14 | 审计 `Phase2A5-Docs/DOCUMENTATION_REFACTOR_REPORT.md` | 已读 |

另按需读取：`Phase2A/RESULTS_LIFECYCLE.md`、`RESULTS_MANIFEST_EXAMPLES.md`、`BACKUP_SCOPE_EXCLUSIONS.csv`、`evidence/BACKUP_SUMMARY.json`、`Phase2A5-Docs/DOCUMENT_CHANGE_MANIFEST.csv`。

## 7. 验收条件（进入实际备份前需用户确认）

| 编号 | 条件 | 未确认时的边界 |
|---|---|---|
| C1 | 指定独立备份设备与 `BACKUP_ROOT`（含介质身份、容量、访问权限） | 不开始任何复制 |
| C2 | 确认 §4.1 的 F8 瞬时缺失/恢复是已知且有意为之的操作，或说明仍在进行中的外部作业 | 不把该目录纳入首批执行；先在执行前重新核验 |
| C3 | 确认 `.dsh-plugins/` 属工具环境、保持未跟踪 | 不暂存、不提交、不忽略 |
| C4 | 对 7 份文档的基线字节口径作出选择（重建 vs 排除），见[基线过渡差异](BASELINE_TRANSITION_DELTA.md) §4 | 7 项保持 `PLANNED_NOT_COPIED`，快照不完整 |

C5（原"`AGENTS.md` 未提交编辑归属"）已由外部操作解决：该编辑已提交并推送为 `fdc93369`。本文件不再把它列为待批条件；但其对"交接级完成定义"的影响仍记录在 §4.5。

## 8. 事实、推断与未验证

| 类型 | 内容 |
|---|---|
| 本轮实测 | 两仓库 HEAD/远端 SHA、worktree 数量、Phase 2A.5 的 10 文件范围、11,144 个受保护文件的全量 SHA256 重算结果、172 个文件与 Git blob 的字节一致性、409/331 个文件中的路径引用计数 |
| 历史复述 | Phase 2A 的 11,144/5,006,551,294 保护结论、Phase 2A.5 的 10 份文档结论、Issue #1 的暂缓决定（均未重新论证其科学结论，只复核编号与范围） |
| 推断 | §4.1 的"外部恢复"来自操作痕迹（mtime 保留、非本 Agent 命令）；未取得操作者日志 |
| 未验证 | 备份/恢复本身（未执行）、WindTrace 启动、MATLAB 环境可用性、GitHub 网页渲染 |
