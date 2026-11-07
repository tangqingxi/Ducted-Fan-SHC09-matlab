# 阶段交接 — Phase2B-P0（P0 保护门禁）

## 交接元信息

- Generated at（生成时间）: 2026-11-05（Asia/Shanghai，约 02:20）
- 生成者：DeepSeek Agent（deepseek-flash，DeepSeek Harness）
- 技能版本：dual-repo-agent-handoff 0.2.0
- 仅凭两个仓库链接即可继续：是

## 仓库与精确状态

- 开发主仓库（DEV）：https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab
- DEV 分支：`main`
- DEV 本次核验提交：`fdc933694db9c16a0d9ffcd6d9c391b052352d22`
- DEV 科学基准（冻结，非 HEAD）：`339d7b1a997de6ba350cef3207d8a5b7db3d838d`
- DEV 工作区：干净，仅有未跟踪的 `.dsh-plugins/`（Harness 界面插件，非项目内容）
- 审计仓库（AUDIT）：https://github.com/tangqingxi/AeroGNC-Phase-Audit
- 审计阶段目录：`Phase2B-P0/`
- 审计起始提交：`f803fb835b06fd8709ac9f8b3e7faaba2150e86d`
- 审计发布提交：写在完成回复中（提交无法记录自身 SHA）
- 来源判定：**一致**。preflight 与本单元都以冻结基准 `339d7b1a` 为参照；其后两个提交均为纯文档。

## 已验证完成的事项

| 检查项 | 结果 | 证据 | 说明 |
|---|---|---|---|
| 两仓库自 Phase2B-Preflight 以来无变化 | 通过 | `PHASE2B_P0_REPORT.md` §2 | 无新提交、新分支、新标签、工作区无变化 |
| Issue #1、#2 已登记为 Backlog | 通过 | `PHASE2B_P0_REPORT.md` §2 | 经 GitHub API 现场确认 |
| 4,036 个 P0 文件全部存在 | 通过 | `P0_SOURCE_VERIFICATION.csv` | 缺失 0 |
| P0 字节与计划一致 | 4,029 项通过，7 项已解释 | `P0_SOURCE_VERIFICATION.csv` | 7 项为已授权文档变化 |
| P0 计划字节总量闭环 | 通过 | `PHASE2B_P0_REPORT.md` §4 | 计划 2,731,688,785，磁盘 2,731,567,024，差 121,761 = 文档字节差 |
| 30 份正式 MAT 与 33 份正式/预检 WTR 均在 P0 内 | 通过 | `PHASE2B_P0_REPORT.md` §4.1 | 另含 `short_b.wtr`，P0 内共 34 份 WTR |
| A1（备份介质与 `BACKUP_ROOT`）已批准 | **未批准** | `PHASE2B_P0_REPORT.md` §1、§3 | 阻塞门禁 |
| A2（保护范围与 P0 优先）已批准 | 已批准 | `PHASE2B_P0_REPORT.md` §1 | 由本轮任务书授予 |
| A3（7 份文档从 Git 重建）已批准 | 已批准 | `PHASE2B_P0_REPORT.md` §1、§5 | 任务书选定推荐方案 |
| 实际复制 | **未执行** | — | 门禁未通过 |
| 目的地 SHA256 验证 | **未执行** | — | 依赖备份目标 |
| 恢复测试 / Viewer 启动 | **未执行** | — | 需 A4、A5 另行批准 |

## 复现说明

- 环境：Windows，Git 2.51.1，Python 3.12。TLS 注意：本机 `schannel` 后端报 `SEC_E_NO_CREDENTIALS`，远端操作需用 `git -c http.sslBackend=openssl`；不要把它写进仓库配置。
- 检出位置：DEV `E:/Ducted-Fan-SHC09-matlab` 于 `fdc93369`；AUDIT `E:/AeroGNC-Phase-Audit` 于发布提交。
- 复跑 P0 核验：读取 `Phase2A/BACKUP_PLAN.csv`，只保留 `backup_priority == "P0"`，对每行计算 `E:/Ducted-Fan-SHC09-matlab/<source_path>` 的 SHA256 并与 `sha256` 列比较。预期：4,029 项一致，7 项不一致（`AGENTS.md`、`HANDOFF.md`、`README.md`、`WORKSPACE_MIGRATION.md`、`docs/README.md`、`docs/guides/architecture.md`、`docs/repository_map.md`），0 项缺失。
- 种子与配置：不适用——本轮未运行任何仿真。
- 数据权威来源：`BACKUP_PLAN.csv` 是成员、大小与目标哈希的唯一权威。`P0_SOURCE_VERIFICATION.csv` 是只读派生快照，同时记录了用于稳定性比对的实测 mtime。

## 未决问题与风险

1. **高 — A1 是唯一阻塞项。** 没有介质与 `BACKUP_ROOT`，一个字节都不能复制。解除条件见 `PHASE2B_P0_REPORT.md` §3 的六项参数。
2. **高 — P0 完成仍剩 2,274,862,509 字节未受保护**（7,108 个 P1 文件，含全部 172 个 F8 证据）。不得把 P0 说成"数据已保护"。
3. **中 — P0 内含 2,441 个文件的 WindTrace 整包**（273 个 EXE/DLL，599 MB）。A2 允许复制，但"恢复测试"需 A4 隔离启动，尚未批准。
4. **中 — 上一个 preflight 期间源工作树曾两次被外部改动。** 本单元期间未再变化，但复制前与复制中都必须重新核验。
5. **中 — 7 份 P0 文档必须从 Git 重建**，不能直接复制工作树版本；重建是确定性的，但必须逐份做 SHA256 验证。
6. **低 — 单副本风险**取决于 A1 的"副本份数"回答；若只有一处，必须在完成记录中显式写明。

## Next bounded task（下一项任务，请勿猜测）

- 目标：在用户给出 A1 的六项参数（介质身份、绝对 `BACKUP_ROOT`、可用空间 ≥ 8 GiB、副本份数、写入权限、恢复负责人）后，执行 **P0 复制与目的地全量 SHA256 验证**：复制 4,029 个现存文件，从 `git show 339d7b1a:<path>` 重建 7 份文档字节，写入 `<BACKUP_ROOT>/AeroGNC-Sim/339d7b1a/snapshot/<原相对路径>`，对目的地 4,036 项逐文件重算 SHA256 并与计划值比对。
- 涉及文件与子系统：`Phase2A/BACKUP_PLAN.csv`（权威清单）、`Phase2B-P0/P0_SOURCE_VERIFICATION.csv`（只读核验与 mtime 基线）、`Phase2B-P0/PHASE2B_P0_REPORT.md` §6（执行序列）。源侧只读：`E:/Ducted-Fan-SHC09-matlab`。
- 前置条件：A1 已给出并记录；目标目录**不存在**（已存在即停止）；可用空间 ≥ 2,731,688,785 字节（建议预留 ≥ 8 GiB）；执行前对 4,036 项重做存在性/大小/mtime 核验并与 `P0_SOURCE_VERIFICATION.csv` 比对。
- 验收标准：目的地 4,036 项 `dest_full_sha256` 全部等于计划 `sha256`；无多余成员；复制期间源 size+mtime 稳定；7 份文档重建后逐一匹配计划 SHA256；任一项失败即停止，不进入 P1。
- 应产出的审计证据：`Phase2B-P0/` 下的复制事件日志、目的地逐文件验证 CSV、源稳定性报告、失败清单、P0 完整性结论，并更新阶段报告与证据 manifest。**不得修改** `Phase2A/BACKUP_PLAN.csv`。
- 停止 / 上报条件：目标目录已存在、空间不足、源文件在复制中变化、出现计划外文件、需要删除或移动任何源数据、或需要修改锁/协议字节——立即停止并回到用户审批。

## 接手者启动步骤

1. 阅读 DEV 的 `README.md`、`AGENTS.md`、`HANDOFF.md` 与本文件。
2. 核对 DEV HEAD 仍为 `fdc93369`；若已前进，与 `339d7b1a` 做差异，确认变更集仍然只是文档，再信任保护计划。
3. 校验审计证据：在审计仓库根目录运行 `python <skill>/scripts/verify_evidence.py . Phase2B-P0/evidence-manifest.json`。
4. 确认尚未发生复制（不存在快照目录，所有记录仍为 `PLANNED_NOT_COPIED`）。
5. 在 A1 得到明确回答之前，不复制、不迁移、不删除任何内容；不得为了"补数据"而运行仿真。
