# 文档导航：按你想做的事阅读

> 文档类型：当前。

先选下面的一项。无需从头读完所有报告。

## 我第一次来

读[根目录说明](../README.md)了解平台用途和限制，再看[仓库地图](repository_map.md)。
文档标签“当前”表示现行入口说明；“参考”解释模型或算法；“历史”保留当时结论；“证据”保存验证记录。

## 我想跑一次

按根目录“五分钟跑一次”执行。需要了解调用关系时看[架构](guides/architecture.md)。
常用入口在 apps；实验入口在 apps/experimental，旧研究入口在 apps/legacy，均由 ca_setup 显式加入路径。

## 我想比较分配器

从[比较指南](guides/allocation_comparison_guide.md)开始，先看可比性门禁，再看差异和种子波动。
[当前轻量报告](../examples/lite_comparison_v050/comparison_3seeds/report.md)是 v0.5 的 60/60 证据，不是要求你重新跑一遍。

## 我想理解 ideal/lite

先看[lite 阅读顺序](guides/lite/README.md)，再按问题选修复、峰值诊断或结果。
ideal 是真值参考上界；lite 是传感器估计反馈，但物理偏置门禁仍预期失败。
早期 Stage5/6A 的背景只放在[历史索引](history/README.md)，不当作当前验收结论。

## 我想按 PX4 字段查日志

看[PX4 命名映射](guides/px4_log_map.md)。这是离线 MAT/CSV 工具，明确帧、单位和缺失值，不生成 ULog。
[日志工具验证](px4_log_validation/checks.json)记录测试结果及本地导出路径。

## 我想加一个分配器/改平台

看[平台与插件指南](guides/platform_plugin_guide.md)、[架构](guides/architecture.md)和[PX4 职责映射](guides/platform_px4_mapping.md)。
算法和物理依据放在参考文档：[物理审计](reference/physical_model_audit.md)、[方法适配](reference/method_adaptations.md)、[静态 PCA 审计](reference/static_pca_algorithm_audit.md)、[候选筛选协议](reference/candidate_screen_protocol.md)。

## 我想看历史结论和证据

从[历史索引](history/README.md)进入；[发布记录](releases/)按版本保留。
[evidence](evidence/)中的旧实现、[发布验证](release_validation/)、[估计器证据](estimator_diagnosis/)和[验证目录](validation/)是证据，不是当前构建入口。
CSV/JSON 盘点清单和迁移 manifest 保留原路径以兼容既有工具；其中的旧文件路径按快照版本理解。
[文件清单](file_inventory.csv)、[函数冲突清单](function_collisions.json)和[引用清单](matlab_references.json)帮助查找用途，不能据“无引用”直接删文件。

## 我想知道当前状态/下一步

当前八字研究使用独立的[F8平滑轨迹与前馈协议](reference/f8_protocol.md)，不再按悬停门禁筛选动态任务；专用飞控参考见[DuctedFanUAV-Autopilot核查](reference/ductedfan_autopilot_reference.md)。

只看[HANDOFF](../HANDOFF.md)；发布差异看[CHANGELOG](../CHANGELOG.md)。
本地运行日志从[归档索引](../archive/logs/README.md)找。历史报告只移动和修正链接，不改写当时结论。
