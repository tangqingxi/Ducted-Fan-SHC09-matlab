# 当前项目交接

更新时间：2026-11-05（Asia/Shanghai）。本文件只记录当前状态；开发约束见[AGENTS](AGENTS.md)，具体研究事实见[结果与证据](docs/guides/results_and_evidence.md)。

## Git身份

| 身份 | 当前含义 |
|---|---|
| 远端开发分支 | main 保持默认分支；本轮开发使用 refactor/phase3-source，不合并 main |
| science_baseline_commit | `339d7b1a997de6ba350cef3207d8a5b7db3d838d`，科学与重构起始基准，包含原change-B、GNSS v2和诊断历史 |
| documentation_update_commit | 本轮仅文档提交；用下列git log命令获取实际SHA，不在本文件中写入自引用SHA |
| current_main_commit | 本轮推送后的main HEAD；用git rev-parse查询，不等同于固定科学基准 |
| 本地工作树 | 唯一开发目录E:/Ducted-Fan-SHC09-matlab；旧controller-ppid-p-indi工作树及本地分支已移除 |

```bash
git status --short --branch
git rev-parse main
git log -1 --format=%H -- README.md AGENTS.md HANDOFF.md
git ls-remote origin refs/heads/main
git worktree list --porcelain
```

## 当前阶段

| 阶段 | 状态与入口 |
|---|---|
| Phase1 | 只读审计完成，保存文件/批次/迁移候选索引；其分支和worktree状态为当时快照 |
| Git Convergence | 完成：远端仅main，viz-replay独有历史保存在archive/viz-replay-20261104 Tag |
| Phase2A | 完成并推送，审计提交`ce1d675d27a41e76dcdb373f9f1abb4c4f6c80ef`；冻结基准、保护计划和Results合同设计 |
| Phase2A.5 | 已完成文档与入口指南整理 |
| Phase2B | 已完成备份、恢复验证、71批次登记及64文件非破坏性试点 |

阶段交付见[独立审计仓库](https://github.com/tangqingxi/AeroGNC-Phase-Audit)；[Phase2A报告](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/PHASE2A_REPORT.md)与[Phase2B执行计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/PHASE2B_EXECUTION_PLAN.md)保留为历史设计；实际执行证据见 Phase2B-Backup、Phase2B-Restore、Phase2B-Results、Phase2B-Migration。

当前进入 Phase3，开发分支 `refactor/phase3-source`；本轮仅 C0/C1（映射、骨架、ca_setup 双路径），不移动现有 `.m`。依据：[Phase3-Architecture](https://github.com/tangqingxi/AeroGNC-Phase-Audit/tree/main/Phase3-Architecture)；[本地映射](docs/refactor/PHASE3_MAPPING.md)。验证、身份变化和后续准入以审计阶段交接为准。

## 下一步与暂缓事项

1. 核对审计仓库 Phase3-Architecture 的 C0/C1 报告、路径与来源证据。
2. C0/C1 完成后停止；C2/W1 必须另获移动授权并通过映射中的准入门槛。
3. 原change-B研究路线及其正式批/坐标/导航证据保留在main。后续围绕控制分配与飞行性能的研究需另行界定协议、来源、运行预算和验收；不重建旧分支、不自动追加正式批。

[GNSS/ECL真实恢复Issue #1](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)为Backlog、暂缓、非当前重构阻塞。1000 s模型已并入main，单条55秒数值回归完成，但原真实恢复判据未通过。保持失败结论，不调参、不改估计器/控制器、不放宽阈值来收尾。

## 受保护资产与限制

保护两批正式30份原MAT、33份正式及预检WTR、输入/协议/锁、管理中断及续跑记录、Round 1–7、GNSS新回归、WindTrace完整安装及必要回退包、17份历史Agent报告。它们的本地存在性、SHA复用口径与备份范围以[保护计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/BACKUP_PLAN.csv)为准；GitHub轻量证据不是原始日志备份。

部分旧F8/PPID/hover原始日志已按以前任务清理，只剩轻量证据，不承诺完整回放。旧平台兼容/逐位基线以及lite偏置测试存在已知限制，不宣称当前全套测试通过。WindTrace仍在主仓库内，尚未拆仓或接入Submodule；统一Results和多机型目录也尚未实施。

历史交接原文可从[文档整改前HANDOFF](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/blob/339d7b1a997de6ba350cef3207d8a5b7db3d838d/HANDOFF.md)及17份codex-repo报告追溯。不要将其中旧分支、未提交或待迁移描述当作当前指令。
