# C7/W6 工程收敛计划

日期：2026-11-06（Asia/Shanghai）。执行分支：`refactor/phase3-source`（不新建 C7 阶段分支）。

## 目标与授权

1. BSD-3-Clause 正式生效，并同步到重构集成分支。
2. DEV 远端分支从 5 个收敛为 `main`、`refactor/phase3-source` 两个。
3. 17 份根目录历史 Agent 报告逐份审查，合并为一份长期摘要；原文由 Git 保存。
4. 兼容函数迁移到 `src/compat/`，接口与数值行为不变。
5. 当前有效文档、路径和分支工作流与实际结构一致。
6. 完成针对性 MATLAB/文档/静态验证，不修改科研原始数据。

## 预期处理

- 许可证：PR #3 的净 diff 仅 `LICENSE`、`README.md`、`THIRD_PARTY_NOTICES.md`；确认 BSD-3-Clause 后再合并。
- 分支：c5/c6 已由集成分支包含；docs/mit-license 合并后删除远端引用；不移除用户工作树。
- 历史报告：全部结论先标记 KEEP/MERGE/DROP；优先 MERGE 到 `docs/history/ENGINEERING_HISTORY.md`，保留整理前 SHA。
- 兼容层：`compat/ca_complete_allocation.m` → `src/compat/`；更新 `ca_setup` 与当前文档；记录 engine 变化，不改旧锁。
- 文档：README/AGENTS/仓库地图/历史索引/受影响链接；不批量改历史 validation 科学内容。

## 验收

- `LICENSE` 为 BSD-3-Clause，main 与集成分支均存在；第三方边界保留。
- 远端仅两个分支；c5/c6 为集成分支祖先。
- 17 份逐项有结论；根目录无历史报告；`git show eb40ef8:...` 可恢复。
- `ca_setup` 与 `which` 唯一解析 `src/compat`；MATLAB 轻量测试与 2 秒 smoke 通过。
- 当前文档链接 0 断链；C5/C6 静态检查通过。
- 无新备份、无原始数据修改、无强推/历史重写。
