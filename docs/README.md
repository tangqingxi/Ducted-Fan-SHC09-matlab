# 文档导航

项目介绍只在[首页](../README.md)维护；当前Git/任务状态只在[HANDOFF](../HANDOFF.md)维护。本导航按读者选择入口，不重复实验进度。

| 你要做什么 | 阅读路线 |
|---|---|
| 第一次使用项目 | [快速开始](guides/getting_started.md) → [架构](guides/architecture.md) → [仓库地图](repository_map.md) |
| 研究控制/分配问题 | [研究工作流](guides/research_workflows.md) → [结果与证据](guides/results_and_evidence.md) → 对应协议与验证报告 |
| 查看已有结果 | [证据阅读规则](guides/results_and_evidence.md) → examples / figures / validation；本机原始MAT不保证随Git提供 |
| 回放单次飞行 | [WindTrace说明](../apps/windtrace/README.md) → [WTR合同](interfaces/windtrace_flight_v1.md) → [运镜格式](interfaces/windtrace_camera_v1.md) |
| 增加分配器或理解接口 | [插件指南](guides/platform_plugin_guide.md) → [名义效能](../effectiveness/README.md) → [开发约束](../AGENTS.md) |
| Agent接手 | [AGENTS](../AGENTS.md) → [HANDOFF](../HANDOFF.md) → 本任务涉及的源码、协议及来源锁 |

## 技术参考

- [平台模块与总线](../platform/README.md)、[PX4职责映射](guides/platform_px4_mapping.md)、[离线日志字段映射](guides/px4_log_map.md)。职责类比不代表PX4 SITL或ULog兼容。
- [物理模型依据](reference/physical_model_audit.md)、[方法适配](reference/method_adaptations.md)、[静态PCA审计](reference/static_pca_algorithm_audit.md)。按文档日期和研究版本理解，不当作所有后续控制路径的统一说明。
- [平台分配比较](guides/allocation_comparison_guide.md)、[lite阅读索引](guides/lite/README.md)、[F8协议](reference/f8_protocol.md)与[四环研究说明](../studies/ppid_pindi/README.md)。

## 历史与证据如何区分

`docs/guides/`是使用入口；其中具体实验指南仍以所述版本为边界。`docs/reference/`说明依据与适配，`docs/validation/`及其他validation目录保存当时验证，`docs/history/`和`docs/releases/`保存历史报告。旧文件中“当前”“未提交”“不合并”等属于当时记录，不覆盖HANDOFF与本轮授权。

[历史索引](history/README.md)、[发布记录](releases/)、[原仓库迁移说明](../WORKSPACE_MIGRATION.md)和17份根目录codex-repo报告均保留追溯。盘点[file_inventory.csv](file_inventory.csv)、[函数冲突](function_collisions.json)及[MATLAB引用](matlab_references.json)是快照；无静态引用不证明可删除。

## 架构治理与下一阶段

[独立审计仓库](https://github.com/tangqingxi/AeroGNC-Phase-Audit)保存Phase1、Git分支收敛和Phase2A；[Results设计](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/RESULTS_LIFECYCLE.md)及[Phase2B审批](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/APPROVAL_REQUEST.md)尚未实施。当前主线为main，GNSS恢复问题在[Issue #1](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)暂缓，不作为文档/目录治理的最高优先级任务。
