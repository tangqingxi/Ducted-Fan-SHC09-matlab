# Phase2B进入前的审批清单

本次Phase2A的审计仓库提交/推送已获授权，不再请求该许可。main@339d7b1a重构起始基准已由用户确定，Issue #1暂缓/非阻塞也已决定，不列为待选项。

| 待审批项 | 可审阅的具体方案 | 未批准时的边界 |
|---|---|---|
| 独立设备与BACKUP_ROOT | 一份保护集合5,006,551,294字节，建议每处至少8 GiB可用；建议两处独立副本，另有恢复scratch | 不执行复制，不把审计仓库当备份 |
| 备份范围/优先级 | BACKUP_PLAN的11,144文件；P0先、P1后；477项归属未定证据先保护 | 不擅自缩减原始证据 |
| Viewer回退选择 | 当前完整运行包及命名r14的拟回退整包；后者未验证启动 | 在恢复成功前不清理任何软件包 |
| 验证与恢复范围 | 目的地全部文件完整SHA；30正式MAT/33WTR全覆盖、每Round与关键协议、17报告、两个Viewer整包 | 计划/缓存命中不能标verified |
| 原址登记权限 | 采用本轮schema v1及两个示例语义；先备份，再在批准位置登记真实manifest/_index | 不向主仓库写入manifest或manager代码 |
| 首批实际迁移清单 | 下一步需生成明确source→target、size/SHA、锁影响、原址保留与回滚条目；Phase1矩阵不是执行单 | 不执行移动或原址删除 |
| 额外历史构建归档 | 66,141个候选文件17.291 GB单独审阅；不能按EXE相同批量删除 | 当前均保持原位 |
| Phase1发布账本修订 | 新版本区分local_worktree与published_blob身份；原OUTPUT_MANIFEST保留 | 本轮只记录建议，不改历史清单 |
| 后续主库写入与验证预算 | Results Manager实施、有限迁移、结构等价性测试范围及单独提交/推送授权 | Phase2A不自动延伸为Phase2B/源码重构 |

本阶段没有正式删除清单，未授权删除原始数据、运行包、历史报告或修改锁；删除必须另批逐文件列表。仓库更名、WindTrace新库/Submodule仍属后续独立审批项。

审阅入口：[阶段报告](PHASE2A_REPORT.md)、[备份清单](BACKUP_PLAN.csv)、[Phase2B执行方案](PHASE2B_EXECUTION_PLAN.md)、[Manager规范](RESULTS_MANAGER_SPEC.md)、[交付字节核验](REMOTE_DELIVERY_INTEGRITY.md)。完成Phase2A发布后停止等待审核，不自动执行上述任何动作。
