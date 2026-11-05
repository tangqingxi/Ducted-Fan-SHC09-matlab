# 当前项目交接

更新时间：2026-11-05（Asia/Shanghai）。本文件只记录当前状态；开发约束见[AGENTS](AGENTS.md)，总体路线见[plan](plan.md)，研究事实见[结果与证据](docs/guides/results_and_evidence.md)。

## Git 身份

| 身份 | 当前含义 |
|---|---|
| 当前开发分支 | `refactor/c6-toolchain`；C6 验收后集成到 `refactor/phase3-source` |
| C6 工具链提交 | `100061cae7e3c76c9293f8c443213d0175c91a0a` |
| C6 文档/集成提交 | 本文件所在提交；最终 DEV HEAD 以推送结果为准 |
| main | `fdc933694db9c16a0d9ffcd6d9c391b052352d22`，未修改 |
| 工作区 | 仅既有 `.dsh-plugins/` 未跟踪；未创建完整备份或 Restore-Test |

## 当前阶段

| 阶段 | 状态 |
|---|---|
| C0–C5 | 已完成 |
| C6/W5 | 已完成工程整合：215 KEEP、1 PATCH、7 DEFER；部分历史工具/链接明确未作为活动门禁 |
| C7–C9 | 未开始；C7/W6 只读 Gate 为下一阶段 |
| Results 管理/平台整理 | 未开始 |
| Hover-Distance-Takeoff 55 秒复现 | 未开始；C6 未运行正式批 |
| 项目更名 AeroGNC-Sim | 未执行；安排在 55 秒复现验收之后 |
| change-B / Waypoint Tracking | Backlog；更名完成后再进入 |

## C6 结果

- W5 223 项：**215 KEEP、1 PATCH、7 DEFER、0 MOVE**；未为了差异移动文件。
- PATCH：`tools/repo_inventory.py` 的 `active_dirs` 从旧 `paths={` 改为当前 `layouts = {`，并更新当前目录分类。
- 文档：`AGENTS.md` 的 main/phase3 分支工作流、`docs/repository_map.md` 的 C5 后布局、AUDIT 顶层入口指针已修正。
- 工具：31 个 Python 工具语法通过；C5/C6 静态检查 PASS；当前文档链接 565 条中仅 2 条历史 validation 旧 research README 链接；`check_platform_docs` 的历史 codex 断链留 C7。
- Tests：7 项 MATLAB 单元/集成测试 PASS；24 个 Apps 入口全部解析；WindTrace 只读容器读取 PASS，pytest **38 passed / 20 skipped**。
- MATLAB：287 名字、6 分配器、2 效能、14 句柄；PPID 41,601 点；manifest 49 文件/engine `696da7e6…`；2 秒平台 smoke PASS。
- **DEFER**：`verify_platform_sources`（旧固定路径基线）、`check_phase3_static`、旧 F8/PPID/hover 打包器、`platform_stage_checks`、`check_repo_hygiene`、`check_platform_docs`。
- 未修改 Results/MAT/WTR/协议/来源锁/ECL；未创建新备份；未运行 55 秒正式批、五方法批、ECL 重建或全套测试。

## 下一步

1. 只读准备 C7/W6 Gate：文档、兼容层、codex-repo 历史资料归档、仓库导航、过期接口与历史来源引用；不自动执行 C7。
2. 处理 C6 DEFER 中适合 C7 的文档/兼容项，但不改历史 validation/MAT/WTR/锁。
3. C7–C9 完成后再做 Results 治理、55 秒 HDT 复现、正式更名和 change-B/Waypoint。

## 受保护资产与限制

历史协议、formal_lock/source_lock、原始 MAT/WTR、正式指标、ECL EXE 和 build_manifest 保持原字节；旧锁不追认新源码。`research/` 仅保留冻结协议/锁，代码已迁 `studies/`。2 条历史 validation 旧 research README 链接保留为冻结证据。

原 `D:\AeroGNC-Backup`、`D:\AeroGNC-Restore-Test` 已在 C5 核对后删除；C6 未重建，今后默认禁止新完整备份/Restore-Test。
