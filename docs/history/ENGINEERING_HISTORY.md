# 工程历史摘要（C7 精简）

本文件合并原根目录 `codex-repo-1.md` 至 `codex-repo-17.md` 的长期有效信息。原文不再保留在当前 HEAD，但可通过 Git 恢复：

```text
git show eb40ef8:codex-repo-1.md
...
git show eb40ef8:codex-repo-17.md
```

整理前基线：`eb40ef865fbe71d71e32f8504c56d6dfc519720a`（C6 完成并同步 BSD-3-Clause 许可证）。下表 17 份均经逐份审查；结论均为 **MERGE**：保留主题、边界、失败状态和证据入口，删除过程性重复叙述。

## 1. 文件审查结论

| 原文件 | 主题 | 结论 |
|---|---|---|
| `codex-repo-1.md` | 项目重新接手、F8 与 main 关系、冻结机制审查 | MERGE |
| `codex-repo-2.md` | F8 图表、文档纠偏、轻量交付 | MERGE |
| `codex-repo-3.md` | F8 提交前审查、换行/哈希冲突 | MERGE |
| `codex-repo-4.md` | 新四环控制器构建与首组八字 15 条 | MERGE |
| `codex-repo-5.md` | PINDI 优先级拆分、测试停点 | MERGE |
| `codex-repo-6.md` | hover_distance 实现、40 秒预检、正式批停点 | MERGE |
| `codex-repo-7.md` | F8 提交与 C 盘→E 盘迁移 | MERGE |
| `codex-repo-8.md` | hover_distance 85% 滚转正式批（40 秒） | MERGE |
| `codex-repo-9.md` | hover 滤波 20 条调参 | MERGE |
| `codex-repo-10.md` | WindTrace 单飞行 `.wtr` 与界面迁移 | MERGE |
| `codex-repo-11.md` | WindTrace EXE 打包与安装 | MERGE |
| `codex-repo-12.md` | WindTrace 启动、加载、EXE 更新 | MERGE |
| `codex-repo-13.md` | WindTrace 布局、地面网格、项目内安装 | MERGE |
| `codex-repo-14.md` | 起飞型 hover 50 秒单条预检 | MERGE |
| `codex-repo-15.md` | 旧结果清理与 WindTrace 运行包保留 | MERGE |
| `codex-repo-16.md` | PPID 仿真时长容量与 EKF 统计修复 | MERGE |
| `codex-repo-17.md` | 55 秒起飞型 hover 正式交付 | MERGE |

没有 KEEP 的原文：其独立科研证据已由正式协议、来源锁、`docs/validation/` 轻量证据和本摘要保存；没有 DROP 的独有结论。原始文件仍可由上述 Git 提交恢复。

## 2. 平台演进

1. **原始平台与 F8 研究线**：F8 使用独立协议、开发/确认种子分离和冻结来源；确认批 15/15 完成，但原驱动 12 completed/3 failed 必须保留。三条 DA_NS 的“失败”来自旧检查把 `1e-7 rad` 当作度；真实舵角未超物理硬限，独立审计按弧度容差通过。不得把旧失败记录改写成通过。
2. **四环 PPID–PINDI**：新增位置 P、速度/姿态/角速度环与 INDI，公共代码后迁入 `src/control/ppid`、`src/navigation`、`src/sensors`、`src/runtime/sim`，研究场景在 `studies/`。52 秒正式批 15/15 完成，但求解耗时没有逐拍注入物理延迟，不能宣称实机实时性。
3. **hover_distance**：40 秒 85% 滚转批、滤波调参、50 秒起飞预检、55 秒起飞正式批依次发展。正式批 15/15 完成，管理性中断用独立续跑处理（1＋14，不是重跑）；旧预检锁与失败状态保持。
4. **WindTrace**：从离线三维日志回放发展为单飞行 `windtrace.flight.v1`/`.wtr` 容器；EXE 在项目内安装。它不参与闭环、不管理实验批次，也不改变原始 MAT/WTR。
5. **Phase 3 重构**：C2 迁移平台/机型/动力学，C5 迁移研究代码并抽公共模块，C6 收敛工具/测试/文档；C7 合并历史报告、迁移兼容层并落实 BSD-3-Clause。

## 3. 仍然有效的设计决策

- 两条链明确分离：平台链 `shc09_run → src/runtime/platform_run`；四环研究 `run_ppid_pindi → studies/ppid_pindi + src`。
- 六个分配器、显式注册表、两种效能模型和 `ca_setup` 显式路径白名单不可用 `genpath` 替代。
- 历史协议、`formal_lock/source_lock`、原始 MAT/WTR、正式指标保持原字节；新行为用新协议/新锁，不追改旧锁。
- `engine` 不覆盖全部研究/后处理源码；必须同时看 `ppid_source_manifest`、执行版快照和批次锁。
- 冻结过程是“哈希＋运行断言”，不是全仓自动防修改；旧锁不自动认新源码。
- 研究结论只适用于对应工况、种子和容差；单批三种子不支持统计显著、实机优势或全局最优。
- 图像/PDF 字节可能随字体、平台和库版本变化；数值汇总、配对关系和来源哈希才可独立复核。
- WindTrace 是离线回放应用，不拥有 Results，不把 `.wtr` 契约扩展为在线仿真。

## 4. 已知失败、缺陷与限制

- 旧行为兼容/逐位基线与 lite 物理偏置测试有历史失败；`run_project_tests` 和 `test_platform_baseline` 不能用作“全绿”证据。
- 旧保护基线 `tests/baseline/protected_sources.json` 固定 pre-C2 路径，C6 已将其标为历史，不据此改写。
- 旧 fixed-path 工具（`verify_platform_sources`、旧 F8/PPID/hover 打包器、`check_phase3_static`、`check_repo_hygiene` 等）仍可能失败；C6 已标记 DEFER，C7 不把历史基线改绿。
- 55 秒正式批虽完成，但真实恢复判据历史上为 0/15；`execution=completed` 不等于科研验收通过。
- 两条历史 validation 链接仍指向旧 `research/ppid_pindi/README.md`，作为冻结证据未改写。
- GNSS/ECL 的 1000 秒工程模型与实机能力不同；ECL EXE 重建或替换必须单独记录来源。

## 5. 关键证据入口

| 主题 | 当前入口 |
|---|---|
| F8 交付 | `examples/f8_comparison_20261101/`、`docs/validation/f8_*` |
| PPID 52 秒 | `examples/ppid_pindi_f8_20261101/`、`docs/validation/` 相关批次 |
| hover / takeoff | `studies/hover_distance*`、`logs/wtr/`、`figures/`、`docs/validation/hover_distance_takeoff_formal_20261103_r1/` |
| 容量修复 | `docs/validation/ppid_capacity_fix_20261103/` |
| WindTrace | `apps/windtrace/`、`logs/wtr/*/manifest.json` |
| C5/C6 架构证据 | AUDIT `Phase3-Architecture/C5`、`C6` |

原始报告中的提交 SHA、协议 SHA、批次目录和失败 JSON 名称，可通过上表 Git 提交追溯；不要用本摘要替代原始科研验证。
