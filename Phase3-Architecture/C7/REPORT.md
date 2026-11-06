# C7/W6 工程收敛与历史精简报告

日期：2026-11-06（Asia/Shanghai）。执行者：DeepSeek Harness / deepseek-flash；dual-repo-agent-handoff 0.2.2。

状态：**C7/W6 PASS**。C8/W7 未执行；55 秒 HDT 正式复现 NOT RUN。

## 1. 许可证

- PR [#3](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/pull/3) 已由 GitHub 标记 **merged**，merge commit `1c851a53804564314efb4d38943f829c419e48d9`。
- PR head `b6500af…`；净 diff 仅：
  - 新增 `LICENSE`（BSD-3-Clause，版权 2026 tangqingxi）；
  - `README.md` 增加许可证说明；
  - `THIRD_PARTY_NOTICES.md` 明确 BSD-3-Clause 只覆盖项目自有代码/文档，第三方与未明确许可的参考资产保留各自权利。
- main 与 `refactor/phase3-source` 的 `LICENSE` SHA256 均为 `75e7d09a…`。phase3 保留了 C5/C6 的 `studies/`、`src/` 布局，不因同步许可证覆盖架构重构。
- 未改动 `third_party/`、`models/shc09/reference`、WindTrace 既有许可证或任何第三方版权声明。

## 2. Git 分支收敛

清理前 5 个远端分支，清理后仅：

```text
main                        1c851a5  BSD-3-Clause / PR #3
refactor/phase3-source      9173261  C7 完成
```

删除的远端引用：

- `docs/mit-license`（已合并到 main/phase3）
- `refactor/c5-research`（`a572f37`，phase3 祖先）
- `refactor/c6-toolchain`（`400f6b2`，phase3 祖先）

c5/c6 的 ancestry 已用 `git merge-base --is-ancestor` 验证。用户的其他本地 worktree（`C:/Users/32450/.codex/worktrees/mit-license`）保持原状；其远端分支已删除，未删除或移动工作树。没有强推或历史重写。

## 3. 17 份历史 Agent 报告

17 份均逐份审查，结论均为 **MERGE**（0 KEEP、0 DROP），合并为 [ENGINEERING_HISTORY](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/blob/91732610866b37f578a0e6d016b1a3dfb10bccbb/docs/history/ENGINEERING_HISTORY.md)：

- 平台/F8：`codex-repo-1/2/3/7`
- 四环 PPID、hover、takeoff：`4/5/6/8/9/14/16/17`
- WindTrace：`10/11/12/13/15`
- 容量/统计修复：`16`

摘要保留工程决策、科研结论边界、失败状态、关键证据入口；过程性流水账不保留。原文可由整理前提交 `eb40ef8` 恢复：

```text
git show eb40ef8:codex-repo-1.md
...
git show eb40ef8:codex-repo-17.md
```

根目录已无 `codex-repo-*.md`；逐项映射见 [C7_HISTORY_REVIEW.csv](C7_HISTORY_REVIEW.csv)。未修改 MAT/WTR、协议、锁或正式结果。

## 4. 兼容层

- `compat/ca_complete_allocation.m` 以 `git mv` 移到 `src/compat/ca_complete_allocation.m`，旧/新文件 SHA256 均为 `d96e70b2…`。
- `ca_setup` 的 `compat` 旧路径改为 `''`，只注册 `src/compat`；旧空目录已删除。
- 调用方 `allocators/interface/ca_allocate.m` 未改；接口和数值行为不变。
- 路径迁移使公共 engine 从 `696da7e6…` 变为 `b922c32b…`；这是来源身份变化，已记录。历史锁、正式批来源和 MAT 未改写，后续按 C8 单独映射。

## 5. 文档与验证

| 检查 | 结果 |
|---|---|
| `check_phase3_paths` | PASS：287 名字、6 分配器、2 效能、14 句柄 |
| `ca_complete_allocation` | 唯一解析到 `src/compat/`；旧 `compat/` 不存在 |
| MATLAB 单元/集成 | 6/6 PASS：bus、scheduler、params、plugin conformance、topic chain、sensor model |
| 平台 smoke | 2 秒 DA_NS PASS，数值有限 |
| C5/C6 静态 | PASS |
| `check_docs_links` | 91 份、569 链接、0 断链 |
| `check_platform_docs` | 164 份、647 链接、0 断链 |
| 原始数据 | 未修改 Results/MAT/WTR/协议/锁/ECL；未创建新备份 |

当前文档已同步：README 许可证/Phase3 状态、AGENTS 分支工作流、`docs/repository_map.md`、`docs/refactor/PHASE3_MAPPING.md`、历史索引、平台/研究 README 和受影响的 validation 链接。历史 validation 的科学正文未被批量改写。

## 6. Git 与存储

- **DEV 最终 HEAD：`91732610866b37f578a0e6d016b1a3dfb10bccbb`**，分支 `refactor/phase3-source`，已推送。
- C7 合并/整理提交：`98e316690c1222881dfdae1714f51802527ccbaa`。
- main：`1c851a53804564314efb4d38943f829c419e48d9`，未再修改。
- 远端 DEV 只有 `main`、`refactor/phase3-source`。
- 未创建整仓备份、Restore-Test、镜像或历史 Markdown 副本；D 盘旧备份保持 C5 删除状态。

## 7. 未完成与下一阶段

- C6 的旧固定路径工具/旧打包器 DEFER 仍存在；C7 未把它们改绿。
- Results Manager 未实施；55 秒 HDT、五方法批、ECL 重建未运行。
- **C8/W7 可开始只读准备**：建立新旧 engine/来源身份、历史锁与当前源码、兼容映射的逐项差异；进入 C8 前需独立授权。

C7 的完成不构成 55 秒科研验收，也不表示完整 Phase 3 已合并到 main。
