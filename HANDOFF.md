# 当前项目交接

更新时间：2026-11-05（Asia/Shanghai）。本文件只记录当前状态；开发约束见[AGENTS](AGENTS.md)，总体路线见[plan](plan.md)，研究事实见[结果与证据](docs/guides/results_and_evidence.md)。

## Git 身份

| 身份 | 当前含义 |
|---|---|
| 当前开发分支 | `refactor/c5-research`，从 C4 `661eecc` 创建；验收后集成到 `refactor/phase3-source` |
| C5 源码迁移提交 | `6d25f0e6aa02caa445adb5cd7b72cd1c377be248` |
| C5 文档/集成提交 | 本文件所在提交；最终 DEV HEAD 由推送结果确认 |
| main | `fdc933694db9c16a0d9ffcd6d9c391b052352d22`，未修改 |
| 工作区 | 仅既有 `.dsh-plugins/` 未跟踪；未创建完整备份或 Restore-Test |

## 当前阶段

| 阶段 | 状态 |
|---|---|
| C0–C4 | 已完成 |
| C5/W4 | 已完成：研究代码迁移、公共模块抽离、来源登记与 MATLAB 工程验证 |
| C6–C9 | 未开始；本轮不执行 C6 |
| Results 管理/平台整理 | 未开始 |
| Hover-Distance-Takeoff 55 秒复现 | 未开始；C5 只做配置/路径可追溯检查，未运行正式批 |
| 项目更名 AeroGNC-Sim | 未执行；安排在 55 秒复现验收之后 |
| change-B / Waypoint Tracking | Backlog；更名完成后再进入 |

## C5 结果

- 75 个研究/实验文件迁移：`research/*` 代码与 README 进入 `studies/<study>/`；30 个旧实验进入 `studies/legacy_experiments/`。
- 公共模块：`ppid_control_step` → `src/control/ppid/`；`ppid_estimator_init` → `src/navigation/`；`ppid_noise`、`ppid_sensor_step` → `src/sensors/`；`ppid_simulate` → `src/runtime/sim/`。
- 8 个 `protocol.json`/`formal_lock.json` KEEP 原路径、原字节；活动代码继续读取 `research/` 下的冻结协议/锁。
- 59 个纯迁移文件内容一致；16 个文件仅做路径/来源兼容补丁；未改控制律、估计器、传感器、分配器或协议参数。
- MATLAB：`check_phase3_paths` 287 名字 PASS；`ppid_config` 41601 点；`ppid_source_manifest` 49 文件、engine `52332948…`；`hdtf_config(501)` 55 秒/44001 点/18316 PWM；2 秒平台 smoke PASS。
- 旧 formal_lock、历史 MAT/WTR、ECL EXE、原始科研结果未修改。
- 详情见 AUDIT `Phase3-Architecture/C5/REPORT.md`（发布后生效）。

## 下一步

1. 只读准备 C6/W5 Gate：检查 tools、apps、tests、analysis、WindTrace 与 Results 接口；不执行 C6 迁移。
2. 按顺序完成 C6–C9，再做 Results 治理与平台整理。
3. 之后运行 Hover-Distance-Takeoff 55 秒历史复现验收；通过后才正式更名 AeroGNC-Sim。
4. 更名完成后再进入 change-B 与 Waypoint Tracking。

## 受保护资产与限制

历史协议、formal_lock/source_lock、原始 MAT/WTR、正式指标、ECL EXE 和 build_manifest 保持原字节；旧锁不追认新源码。`research/` 仅保留冻结协议/锁，代码已迁 `studies/`。历史 validation 中仍有两条指向旧 research README 的链接，属于冻结证据，未改写。

原 `D:\AeroGNC-Backup`、`D:\AeroGNC-Restore-Test` 已在核对全部 MAT/WTR/ECL 与当前 DEV 哈希一致后删除；今后默认禁止创建新的完整源码备份或 Restore-Test，源码恢复以 Git 为主。
