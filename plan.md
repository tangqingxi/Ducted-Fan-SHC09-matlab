# AeroGNC-Sim Development Plan

## 核心目标

建立以 MATLAB 为仿真核心、以无人机为主要对象的开放式飞行仿真与 GNC 研究平台。

## 项目进度

| 阶段 | 核心目标 | 状态 |
|---|---|---|
| C0–C3 | 架构准备与首批源码迁移 | 已完成 |
| C4 | Airframe / Dynamics 设计与迁移 | 已完成（设计、迁移、MATLAB 工程验证）；55 秒复现未开始 |
| C5 | 研究代码整理及通用模块抽离 | 已完成（研究迁移与 MATLAB 工程验证） |
| C6 | 工具、应用、测试与分析整理 | 已完成（工程验证；部分历史工具 DEFER） |
| C7 | 文档及兼容层整理 | 下一阶段 |
| C8 | 来源身份与兼容性汇总 | 未开始 |
| C9 | 架构重构收尾 | 未开始 |
| 平台整理 | Results 治理与备份恢复 | 待完成 |
| 历史复现 | Hover-Distance-Takeoff 55 秒实验验收 | 未开始 |
| 项目更名 | 正式更名 AeroGNC-Sim（独立里程碑） | 未开始：55 秒复现验收后 |
| change-B | SHC09 物理模型与控制分配研究 | Backlog：更名后 |
| Waypoint Tracking | 首个新任务完整闭环 | Backlog：更名后 |

## 当前任务

C7/W6 Gate 只读准备：检查文档、兼容层、历史资料归档与仓库导航；不自动执行 C7。

## 下一步

C7–C9 架构重构完成后，先做 Results 治理与平台整理；再进行 Hover-Distance-Takeoff 55 秒历史复现验收、正式更名 AeroGNC-Sim，最后进入 change-B 与 Waypoint Tracking。

## 约束

当前 GitHub 仓库名仍为 `Ducted-Fan-SHC09-matlab`；`AeroGNC-Sim` 是目标名称，更名尚未执行。C6 未实施 Results Manager；历史工具/链接 DEFER 见 AUDIT C6 REPORT。规划项不得标记为已完成。
