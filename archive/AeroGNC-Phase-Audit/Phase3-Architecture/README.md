# Phase3 Architecture Audit 入口

本目录是 Phase 3 审计证据的顶层入口。历史报告保留原字节；当前状态以最新阶段交接为准。

| 阶段 | 当前交接 | 说明 |
|---|---|---|
| C8/W7 | [C8/HANDOFF.md](C8/HANDOFF.md) | 当前最新：来源身份、历史锁映射、覆盖修复 |
| C7/W6 | [C7/HANDOFF.md](C7/HANDOFF.md) | 许可证、分支收敛、历史精简、兼容层 |
| C6/W5 | [C6/HANDOFF.md](C6/HANDOFF.md) | 工具、应用、测试、分析整理 |
| C5/W4 | [C5/HANDOFF.md](C5/HANDOFF.md) | 研究代码迁移与公共模块抽离 |
| C0/C1 | [HANDOFF.md](HANDOFF.md) | 历史交接，仅用于追溯，不代表当前 HEAD |

- 当前阶段报告：[C8/REPORT.md](C8/REPORT.md)；计划：[C8/PLAN.md](C8/PLAN.md)；证据：[C8/evidence-manifest.json](C8/evidence-manifest.json)。
- C8 的历史 ECL 为 UNRESOLVED；不得用当前 EXE 冒充历史执行版本。
- C8 的下一次只读任务是 C9/W8 Gate；在获得独立授权前不得自动执行 C9。
- 历史 `HANDOFF.md` 和 C0–C7 报告不被覆盖。
