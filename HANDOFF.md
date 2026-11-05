# 当前项目交接

更新时间：2026-11-05（Asia/Shanghai）。本文件只记录当前状态；开发约束见[AGENTS](AGENTS.md)，总体路线见[plan](plan.md)，研究事实见[结果与证据](docs/guides/results_and_evidence.md)。

## Git 身份

| 身份 | 当前含义 |
|---|---|
| 远端开发分支 | main 保持默认分支；本轮开发使用 refactor/phase3-source，不合并 main |
| C3 科学/重构基线 | `9d8f8aec7d3b8316f5ae99cba45f422e74cc984c`（C3/W2 完成） |
| C4 源码迁移提交 | `d21b49fc01aa36d70637991916ad485a9b4653a8`，已提交；C4 文档/验证提交见本文件所在提交 |
| C4 设计冻结 | AUDIT `4c49a9a`，Adapter 路径修订 `fc4df3b`；最终执行报告见 AUDIT |
| 当前 main | `fdc933694db9c16a0d9ffcd6d9c391b052352d22`，未修改 |
| 本地工作树 | 唯一开发目录 E:/Ducted-Fan-SHC09-matlab；保留既有 `.dsh-plugins/` 未跟踪 |

## 当前阶段

| 阶段 | 状态 |
|---|---|
| C0–C3 | 已完成；C3 效能迁移与工程验收已推送 |
| C4/W3 | 已完成：Airframe/Dynamics/Adapter 分离、8 文件迁移、MATLAB 路径/模型/engine/短时 smoke 验证 |
| C5–C9 | 未开始；本轮不执行 C5 迁移 |
| Hover-Distance-Takeoff 55 秒复现 | 未开始；C4 只建立兼容基础，未重跑正式研究批 |
| 项目更名 AeroGNC-Sim | 未执行；独立里程碑，安排在 55 秒复现验收之后 |
| change-B / Waypoint Tracking | Backlog；更名完成后再进入 |

## C4 结果

- 8 个活动文件：`ca_model`、`ca_shc09_parameters` → `airframes/shc09/`；plant 三件套 → `dynamics/shc09/plant/`；气动 → `dynamics/shc09/nonlinear_6dof/`；hover 降阶 → `dynamics/shc09/hover_reduced_order/`；参考坐标适配器 → `src/control/frame/`。
- 8 个 `models/shc09/reference` 冻结文件原位 KEEP；`configs/airframes/shc09_airframe.m` 作为 Scenario 预设 KEEP，改名 DEFER。
- 7 个纯迁移文件 raw 字节一致；`ca_shc09_parameters` 只改冻结 reference 定位路径，不改数值。
- MATLAB：287 名字、6 分配器、2 效能、14 句柄通过；six_dof/hover 模型构造与迁移前逐字段一致；engine 由 `481bd57c…` 变为 `fb7cf780…`，121 项；2 秒 DA_NS smoke PASS。
- 详细证据：[C4 执行报告](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase3-Architecture/C4-Execution/C4_EXECUTION_REPORT.md)（发布后生效）。

## 下一步

1. 只读准备 C5/W4 Gate：核查 research/experiments 拆分、研究入口、来源锁和 engine 覆盖；不执行 C5 迁移。
2. C5 审查通过后另获授权执行；之后完成 C6–C9 架构重构。
3. 再做 Hover-Distance-Takeoff 55 秒历史复现验收；验收通过后才正式更名 AeroGNC-Sim。
4. 更名完成后再进入 change-B 与 Waypoint Tracking。

## 受保护资产与限制

保护两批正式 30 份原 MAT、33 份正式及预检 WTR、输入/协议/锁、管理中断记录、Round 1–7、GNSS 回归、WindTrace 完整安装、17 份历史 Agent 报告；范围以 [保护计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/BACKUP_PLAN.csv) 为准。

部分旧 F8/PPID/hover 原始日志已按以前任务清理；旧平台兼容/逐位基线及 lite 偏置测试存在已知限制，不宣称当前全套测试通过。WindTrace 仍在主仓库内，尚未拆仓或接入 Submodule；统一 Results 和多机型目录尚未实施。历史 ECL `a3f…` 二进制恢复仍 UNRESOLVED；当前 `a68d…` 与历史 build_manifest 保持原字节。
