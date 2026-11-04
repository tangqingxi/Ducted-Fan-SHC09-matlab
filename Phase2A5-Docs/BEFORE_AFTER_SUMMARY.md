# 文档整改前后对照

science_baseline_commit：`339d7b1a997de6ba350cef3207d8a5b7db3d838d`。

documentation_update_commit / current_main_commit：`d464ab5ad5b368a5eb5876e53696aa7c607733f1`。本轮仅文档，科学基准没有随HEAD漂移。

| 文档 | 动作 | 行数 | 原始字节数 |
|---|---|---:|---:|
| `README.md` | REWRITE | 327 → 119 | 22647 → 7908 |
| `AGENTS.md` | REWRITE | 770 → 76 | 55053 → 8125 |
| `HANDOFF.md` | REWRITE | 498 → 49 | 64646 → 4006 |
| `WORKSPACE_MIGRATION.md` | REWRITE | 17 → 18 | 2336 → 1629 |
| `docs/README.md` | REWRITE | 60 → 28 | 4633 → 3133 |
| `docs/repository_map.md` | REWRITE | 64 → 57 | 3772 → 3747 |
| `docs/guides/architecture.md` | REWRITE | 37 → 51 | 3731 → 5106 |
| `docs/guides/getting_started.md` | ADD | 0 → 70 | 0 → 4192 |
| `docs/guides/research_workflows.md` | ADD | 0 → 58 | 0 → 5286 |
| `docs/guides/results_and_evidence.md` | ADD | 0 → 50 | 0 → 5362 |

共10份文档，7份重写、3份新增，总计1773 → 576行。行数减少只是结构变化的说明，不是可读性或技术准确性的独立证明。

## 首页

以前把历史分支公告、实验参数和逐日任务叠加在项目介绍前。现在先解释用途和六舵面分配问题，再介绍模块、两条运行链、反馈模式、一个2秒短例、实际目录、研究证据和按角色阅读路线。首页没有搬入完整实验数值表或重复研究公式。

## Agent与当前交接

AGENTS从770行压缩到76行，维护稳定契约：信息隔离、冻结来源、权限、路径、中文注释、验证与Git。删除旧“不合并/不push/旧分支待审”等临时指令；没有删去科学证据保护要求，也不再建议更新旧锁来追认新实现。

HANDOFF从498行压缩到49行，只保留main、三种提交身份、已完成阶段、Phase2A.5和Phase2B审批。文档提交/当前HEAD使用git现场查询，避免在包含自身的提交中硬编码自引用SHA；本审计报告另记录实际新提交。

## 分层阅读

docs/README按首次使用、研究、贡献与Agent导航；repository_map只说明实际目录；architecture解释两条控制链与信息/时钟边界。新增getting_started、research_workflows、results_and_evidence分别维护运行、任务规模和证据语义，不再让根README承担所有角色。

WORKSPACE_MIGRATION转为迁移历史说明，明确旧controller worktree已清理及旧迁移归档不再存在。不能继续把历史路径当作可用备份。旧正文通过339d7b1a固定提交、17份原报告追溯，不复制或改写历史结论。

## 保持原样

数值源码、源锁/协议、MAT/WTR、输入/指标、在用WindTrace、17份codex-repo报告和Phase1/Phase2A交付均未修改。未执行仿真、参数扫描、MATLAB测试套件、ECL/WindTrace构建、原始数据备份或Results迁移。
