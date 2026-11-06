# 当前项目交接

更新时间：2026-11-06（Asia/Shanghai）。开发约束见[AGENTS](AGENTS.md)，路线见[plan](plan.md)，研究事实见[结果与证据](docs/guides/results_and_evidence.md)。

## Git 身份

| 身份 | 当前含义 |
|---|---|
| 当前开发分支 | `refactor/phase3-source`（C7–C9 直接在此集成分支执行，无新阶段分支） |
| C7 合并/整理提交 | `98e316690c1222881dfdae1714f51802527ccbaa` |
| C7 文档/集成提交 | 本文件所在提交；最终 DEV HEAD 以推送结果为准 |
| main | `1c851a53804564314efb4d38943f829c419e48d9`（BSD-3-Clause PR #3） |
| 远端分支 | `main` 与 `refactor/phase3-source` 两个 |
| 工作区 | 仅既有 `.dsh-plugins/` 未跟踪；未创建备份或 Restore-Test |

## 当前阶段

| 阶段 | 状态 |
|---|---|
| C0–C6 | 已完成 |
| C7/W6 | 已完成：BSD-3-Clause、分支收敛、17 份历史报告精简、兼容层迁移、当前文档修正 |
| C8/W7 | 下一阶段；只读来源身份/兼容映射 Gate |
| Results 管理/平台整理 | 未开始 |
| Hover-Distance-Takeoff 55 秒复现 | 未开始；C7 未运行正式批 |
| 项目更名 AeroGNC-Sim | 未执行；安排在 55 秒复现验收之后 |
| change-B / Waypoint Tracking | Backlog；更名完成后再进入 |

## C7 结果

- **许可证**：PR #3 已 merged，合并提交 `1c851a5…`；根 `LICENSE` 为 BSD-3-Clause；`README` 与 `THIRD_PARTY_NOTICES` 明确自有代码/文档采用 BSD-3-Clause，第三方与未明确许可的参考资产保留原权利。main 与 phase3 均含许可证。
- **分支**：远端从 5 个收敛为 `main`、`refactor/phase3-source` 两个；`docs/mit-license`、`refactor/c5-research`、`refactor/c6-toolchain` 已删除。C5/C6 提交均为集成分支祖先。
- **历史报告**：根目录 17 份 `codex-repo-*.md` 全部审查，结论均为 **MERGE**；合并为 `docs/history/ENGINEERING_HISTORY.md`，原文可由 `eb40ef8:codex-repo-N.md` 恢复。未保留重复原文，未删除科研证据。
- **兼容层**：`compat/ca_complete_allocation.m` 以 `git mv` 移到 `src/compat/`，内容 SHA 不变；`ca_setup` 只注册 `src/compat`，旧空目录删除；调用方 `allocators/interface/ca_allocate.m` 不变。
- **文档**：AGENTS 分支工作流、README 许可证/Phase3 状态、repository_map、C5/C6/C7 映射、历史与旧链接修正；当前文档链接 0 断链。
- **验证**：MATLAB `check_phase3_paths` 287 名字 PASS；`ca_complete_allocation` 唯一解析到 `src/compat`；6 项单元/集成测试 PASS；2 秒平台 smoke PASS；C5/C6 静态检查 PASS；`check_docs_links`/`check_platform_docs` 0 断链。
- **来源**：compat 内容 SHA 不变，但路径迁移使 engine 从 `696da7e6…` 变为 `b922c32b…`；旧锁未改写，旧正式批次不追认新 engine。未修改 Results/MAT/WTR/协议/锁/ECL。

## 下一步

1. 只读准备 C8/W7 Gate：新旧 engine/来源身份、历史锁与当前源码差异、兼容映射、未解决来源证据；不自动执行 C8。
2. C8–C9 完成后再做 Results 治理；之后 55 秒 HDT 复现、正式更名 AeroGNC-Sim、change-B/Waypoint。
3. C6 的 DEFER 历史工具（旧固定路径基线、旧打包器、旧 inventory 门禁）保留记录，不据此改写历史证据。

## 受保护资产

历史协议、formal_lock/source_lock、原始 MAT/WTR、正式指标、ECL EXE 和 build_manifest 保持原字节。原 D 盘备份/Restore-Test 已在 C5 删除；C7 未重建，也未创建任何整仓副本。
