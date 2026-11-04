# 当前项目交接

更新时间：2026-11-04（Asia/Shanghai）。本文件只记录当前状态；开发约束见[AGENTS](AGENTS.md)，具体研究事实见[结果与证据](docs/guides/results_and_evidence.md)。

## Git身份

| 身份 | 当前含义 |
|---|---|
| 远端开发分支 | 仅main，默认分支main；不再使用旧远端分支作为入口 |
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
| Phase2A.5 | 本阶段：重写README/AGENTS/HANDOFF及入口指南，仅文档，不开展源码/Results重构 |
| Phase2B | 暂停，等待独立备份位置、保护范围、恢复验证和登记/迁移权限审批 |

阶段交付见[独立审计仓库](https://github.com/tangqingxi/AeroGNC-Phase-Audit)；[Phase2A报告](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/PHASE2A_REPORT.md)与[Phase2B执行计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/PHASE2B_EXECUTION_PLAN.md)为已完成设计，不能当成实际复制/迁移已发生。

## 下一步与暂缓事项

1. 审核本轮文档及审计目录Phase2A5-Docs；确认推送后HEAD和GitHub渲染结果。
2. Phase2B前批准备份介质/root、11,144文件保护范围、恢复抽查、真实登记位置与首批迁移/回滚清单。当前约5.007 GB只是保护计划，未执行复制。
3. 原change-B研究路线及其正式批/坐标/导航证据保留在main。后续围绕控制分配与飞行性能的研究需另行界定协议、来源、运行预算和验收；不重建旧分支、不自动追加正式批。

[GNSS/ECL真实恢复Issue #1](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)为Backlog、暂缓、非当前重构阻塞。1000 s模型已并入main，单条55秒数值回归完成，但原真实恢复判据未通过。保持失败结论，不调参、不改估计器/控制器、不放宽阈值来收尾。

## 受保护资产与限制

保护两批正式30份原MAT、33份正式及预检WTR、输入/协议/锁、管理中断及续跑记录、Round 1–7、GNSS新回归、WindTrace完整安装及必要回退包、17份历史Agent报告。它们的本地存在性、SHA复用口径与备份范围以[保护计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/BACKUP_PLAN.csv)为准；GitHub轻量证据不是原始日志备份。

部分旧F8/PPID/hover原始日志已按以前任务清理，只剩轻量证据，不承诺完整回放。旧平台兼容/逐位基线以及lite偏置测试存在已知限制，不宣称当前全套测试通过。WindTrace仍在主仓库内，尚未拆仓或接入Submodule；统一Results和多机型目录也尚未实施。

历史交接原文可从[文档整改前HANDOFF](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/blob/339d7b1a997de6ba350cef3207d8a5b7db3d838d/HANDOFF.md)及17份codex-repo报告追溯。不要将其中旧分支、未提交或待迁移描述当作当前指令。
