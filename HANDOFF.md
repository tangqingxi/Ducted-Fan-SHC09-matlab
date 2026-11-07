# 当前项目交接

更新时间：2026-11-07（Asia/Shanghai）。开发约束见[AGENTS](AGENTS.md)，路线见[plan](plan.md)，研究事实见[结果与证据](docs/guides/results_and_evidence.md)。

## Git 身份

| 身份 | 当前含义 |
|---|---|
| 当前开发分支 | `refactor/phase3-source`（C8–C9 直接在此集成分支执行） |
| C8 源码提交 | `a6976a070e08cbd8f76ea6925ede3788c9d906cd` |
| C8 文档/交接提交 | 本文件所在提交；最终 DEV HEAD 以推送结果为准 |
| main | `1c851a53804564314efb4d38943f829c419e48d9`（BSD-3-Clause PR #3） |
| 远端分支 | `main` 与 `refactor/phase3-source` 两个 |
| 工作区 | 仅既有 `.dsh-plugins/` 未跟踪；未创建备份或 Restore-Test |

## 当前阶段

| 阶段 | 状态 |
|---|---|
| C0–C7 | 已完成 |
| C8/W7 | 已完成：来源覆盖、历史锁映射、GNSS 路径、C7 文档引用修正；历史 ECL 仍 UNRESOLVED |
| C9/W8 | 下一阶段；只读收尾 Gate |
| Results 管理/平台整理 | 未开始 |
| Hover-Distance-Takeoff 55 秒复现 | 未开始；C8 未运行正式批 |
| 项目更名 AeroGNC-Sim | 未执行；安排在 55 秒复现验收之后 |
| change-B / Waypoint Tracking | Backlog；更名完成后再进入 |

## C8 结果

- **当前 engine**：`61fb8ceb191fb2b17e609d789ac0836495f75c72a5e0ad681e4a77fe6a8b8892`，连续计算两次一致。
- **Engine 覆盖**：`src/compat/ca_complete_allocation.m` 纳入 engine；旧空 `compat` 声明移除。该函数由 `allocators/interface/ca_allocate.m` 调用，其预测舵角、公共残差和优先级诊断字段进入当前日志/评价链，不能作为无关文件漏计。
- **PPID Source Manifest**：53 文件，连续生成一致，无重复；新增 `src/compat`、`shc09_gnss_config.m`、GNSS v2 config/protocol。
- **历史正式锁**：`research/ppid_pindi/formal_lock.json` 仍为 49 项、原字节；映射 36 项 `PATH_ONLY_EQUIVALENT`、4 项 `EXACT`、9 项 `CONTENT_CHANGED`（其中 3 项仅换行，6 项为路径/来源登记/engine 实现变化，无控制/估计数值算法变化）。历史锁 engine `ad9f910…` 不等于当前 C8 engine，不能追认。
- **历史实验**：原正式批 `d4c19f32…`、change-B `c6403c02…`、C1 `ec1491ec…` 的身份继续按 C2-Gate 保留；当前 C8 engine 不替代历史执行版本。
- **ECL**：当前 EXE `a68d4884…`；`build_manifest` 记录 `a3f01863…`；历史锁 `e9bee1e5…`。历史 `a3f`/`e9bee` 二进制不存在，状态 **UNRESOLVED**；本轮未重建、未修改任何 EXE 或旧锁。
- **GNSS 1000 s**：`ppid_gnss_v2_config` 改为从仓库根读取 `research/ppid_pindi/gnss_v2/protocol.json`；`shc09_gnss_config(9301,"f8")` 与 `(501,"takeoff55")` 配置构造通过，tau=1000 s、5 Hz、延迟 0.1 s，参数未改。
- **文档**：C7 遗留的 validation 引用已分别指向 `studies/ppid_pindi/README.md` 或 `eb40ef8` 原始 `codex-repo-16/17.md`；当前文档 0 断链。

## 验证

- MATLAB `check_phase3_paths`：287 名字、6 分配器、2 效能、14 句柄 PASS。
- `allocation_comparison_engine` 两次一致；`ppid_source_manifest` 两次一致。
- `test_bus`、`test_plugin_conformance`、`test_topic_chain` PASS。
- `hd_sources`/`hdt_sources`/`hdtf_sources` 分别 11/11/10 文件，无断链。
- C5/C6 静态检查 PASS；`check_docs_links`/`check_platform_docs` 0 断链。
- 未运行 55 秒 HDT、五方法批、ECL 重建、全套测试；未修改 MAT/WTR/协议/锁/Results。

## 下一步

1. 只读准备 C9/W8 Gate：首页、交接、兼容收尾、剩余来源边界和文档一致性；不自动执行 C9。
2. C9 完成后再做 Results 治理与平台整理；之后 55 秒 HDT 复现、正式更名 AeroGNC-Sim、change-B/Waypoint。
3. 历史 ECL 未解决状态必须继续显式保留，不得用新 EXE 冒充旧执行版本。

## 受保护资产

历史协议、formal_lock/source_lock、原始 MAT/WTR、正式指标、ECL EXE 和 build_manifest 保持原字节。C7 已删除 D 盘备份/Restore-Test；C8 未重建，也未创建任何整仓副本。
