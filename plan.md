# AeroGNC-Sim Development Plan

## 核心目标

建立以 MATLAB 为仿真核心、以无人机为主要对象的开放式飞行仿真与 GNC 研究平台。

## 项目进度

| 阶段 | 核心目标 | 状态 |
|---|---|---|
| C0–C3 | 架构准备与首批源码迁移 | 已完成 |
| C4 | Airframe / Dynamics 设计与迁移 | 已完成（设计、迁移、MATLAB 工程验证）；55 秒复现未开始 |
| C5 | 研究代码整理及通用模块抽离 | 已完成（研究迁移与 MATLAB 工程验证） |
| C6 | 工具、应用、测试与分析整理 | 未开始 |
| C7 | 文档及兼容层整理 | 未开始 |
| C8 | 来源身份与兼容性汇总 | 未开始 |
| C9 | 架构重构收尾 | 未开始 |
| 平台整理 | Results 治理与备份恢复 | 待完成 |
| 历史复现 | Hover-Distance-Takeoff 55 秒实验验收 | 未开始 |
| 项目更名 | 正式更名 AeroGNC-Sim（独立里程碑） | 未开始：55 秒复现验收后 |
| change-B | SHC09 物理模型与控制分配研究 | Backlog：更名后 |
| Waypoint Tracking | 首个新任务完整闭环 | Backlog：更名后 |

## 当前任务

C6/W5 Gate 只读准备：检查工具、应用、测试、分析与 Results 接口依赖；不执行迁移。

## 下一步

C6–C9 架构重构完成后，先做 Results 治理与平台整理；再进行 Hover-Distance-Takeoff 55 秒历史复现验收、正式更名 AeroGNC-Sim，最后进入 change-B 与 Waypoint Tracking。

## 约束

当前 GitHub 仓库名仍为 `Ducted-Fan-SHC09-matlab`；`AeroGNC-Sim` 是目标名称，更名尚未执行。规划项不得标记为已完成。
