# Phase3 C0/C1 交接

## 交接元信息

- Generated at: 2026-11-05T10:58:08+08:00（Asia/Shanghai）
- 生成者：Codex（GPT-6）；dual-repo-agent-handoff 0.2.2。
- 仅凭两个仓库链接可继续：是。本轮C0/C1完成，C2尚未获授权。

## 仓库与精确状态

- DEV：https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab
- DEV已测试并推送提交：`b2a287ceff34445bb7902890141be7a450d19de9`，分支 `refactor/phase3-source`。
- C0：`f3b01152b33c59ac890c5f907405a300f87da4f0`；C1：上述HEAD。main仍为 `fdc933694db9c16a0d9ffcd6d9c391b052352d22`。
- 科学基准：`339d7b1a997de6ba350cef3207d8a5b7db3d838d`，不得追认到新源码。
- DEV工作区：仅未跟踪 `.dsh-plugins/`，保持原状。
- AUDIT：https://github.com/tangqingxi/AeroGNC-Phase-Audit，分支main。本交接随本轮轻量证据提交推送，实际发布SHA在Git历史及最终回复，不自引用。
- 报告：[C0_C1_EXECUTION_REPORT.md](C0_C1_EXECUTION_REPORT.md)；[evidence-manifest.json](evidence-manifest.json)。原方案仍是历史计划，当前实施状态以本报告为准。
- 来源判定：C0/C1按现有源码对齐；旧历史engine锁与本机实测的对应关系尚未建立，不改旧锁。

## 已验证与未完成

静态检查PASS；MATLAB R2025b下287个名字which -all、6分配器/2效能插件/14句柄、重复初始化PASS；临时重复函数负例PASS；唯一一次PCA_PREDICTIVE 2秒短例PASS，未保存结果或图。原m零移动，原文件仅ca_setup及两文档改动；73,292项历史输出文件状态未变。

ca_setup raw SHA改变，PPID显式来源身份改变；engine覆盖集合不变，当前与快照原生根路径实测一致，仍与历史锁不等。详情与初次验证脚本错误记录均见报告及c0-c1 JSON。没有运行全套、正式PPID、52/55秒、多种子、ECL重建。没有未结束后台任务。

## 复现与保护

按报告运行两个Python检查和独立MATLAB路径检查；不要自动重跑短例或正式任务。快照 D:/AeroGNC-Backup/AeroGNC-Sim/339d7b1a/snapshot 本轮只读核查数量/大小；既有SHA/恢复证据不因换Agent重做。D/E同物理磁盘，仅逻辑回滚保护。Windows compat原目录保留，无软链接。

## Next bounded task（下一项任务）

- 目标：先只读核对历史正式锁的engine与原执行源码/根路径/序列化环境的对应关系，输出差异证据；不得重算覆盖旧锁。用户另行授权后才执行C2/W1移动。
- 涉及文件：DEV docs/refactor/PHASE3_MAPPING.md、ca_setup.m、analysis/allocation_comparison_engine.m、research/ppid_pindi/ppid_source_manifest.m；AUDIT MIGRATION_PLAN.csv的W1行与c0-c1/identity.json。
- 前置：核对当前DEV精确SHA、远端和manifest；保留原锁、数据与快照。C2移动尚未授权。
- 验收：历史身份差异有可复核解释；W1逐文件raw SHA/相对路径/新来源覆盖明确；路径、注册、重复检查继续PASS；普通revert可回滚。
- 应产出：身份差异报告、C2准入结论；获授权迁移后另产当波engine和逐文件证据。
- 停止条件：需改写历史锁、数值算法或扩大运行预算；保留成果并报告。分配器CSV与正文的plugins矛盾必须在C3前统一，不能自行迁移。

## 接手启动

1. 读取DEV README/AGENTS/HANDOFF、映射与本报告。
2. fetch两个仓库，核实DEV分支HEAD和远端、工作区及worktree；不reset/clean/stash。
3. 使用 dual-repo-agent-handoff 的 verify_evidence.py 和 check_handoff.py 核验本阶段manifest与交接。
4. 仅推进上述只读身份核对；不得自动执行C2、合并main或启动change-B Issue #2。
