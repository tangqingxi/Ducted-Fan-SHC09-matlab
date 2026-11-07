# Agent 报告治理建议

**事实：** 根目录`codex-repo-1.md`至`codex-repo-17.md`均存在；标题、字节数、原始SHA256与未来目标在[AGENT_REPORT_MIGRATION.csv](AGENT_REPORT_MIGRATION.csv)。当前17份原文未修改或移动。根README、AGENTS、HANDOFF、CHANGELOG的标题与SHA见[ROOT_DOCUMENT_INDEX.csv](ROOT_DOCUMENT_INDEX.csv)。

建议未来布局：

```text
docs/agent-reports/
├── README.md                       # 索引、状态语义、来源及证据规则
├── CURRENT.md                      # 当前任务持续更新
├── MILESTONES.md                    # 阶段成果、门禁和关键提交
├── recent/                         # 最多5个独立任务报告
└── legacy/codex-repo-{1..17}.md     # 原文与文件名保持
```

建议停止无限递增编号。同一任务连续更新CURRENT，包含任务范围、事实、未验证项、数值/科学验收分别结论、输出位置、原始证据与当前Git状态。任务结束且证据归档后，以日期/任务名生成独立报告；recent只保留最近5项，移出前验证原始数据保留等级、来源commit/dirty快照、哈希、链接和可访问的归档位置。容量不是删除报告的理由。

17份历史报告保留原始字节。旧报告中的“未提交”“已验收”等措辞是当时记录，不能就地改写为当前状态；README/MILESTONES另加后续更正与当前结论链接。迁移时记录old_path/new_path/sha256/original_commit/migration_commit，修正文档入口链接，保留旧路径兼容索引策略，经审批再执行。

`AGENTS.md`未来只保留稳定工程规则：中文代码注释、只读/写入边界、动态注册与隔离约束、来源锁、验证与失败陈述等。`HANDOFF.md`只保留当前任务、待审状态、最新关键提交与证据链接。历史章节迁入报告索引前必须保留追溯，不能直接截断删除。

此方案仅设计，当前根文件和报告均未编辑。未来报告迁移属于阶段6，必须在数据归档和Git追溯门禁完成后执行。
