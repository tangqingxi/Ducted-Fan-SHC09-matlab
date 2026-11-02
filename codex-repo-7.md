# F8提交与E盘迁移交付报告

记录日期：2026-11-02。目标目录：E:/Ducted-Fan-SHC09-matlab。

## 完成情况

F8已提交并推送；PPID-PINDI和hover代码、报告与本地实验结果已迁入E盘，一致性检查通过。E盘当前分支为hover_distance。C盘重复工作树仍存在，移除受到Codex主工作区保护，迁移清理尚未全部完成。

## Git实际状态

- f8-research及origin/f8-research：28595c01bd0f0472ebb8a4cbb38d19a43775b0f1。
- 本次F8提交：c598c41、be84e93、2dc92ff、28595c0。最后一个提交用于正确识别冻结交付中的CRLF，未更改交付文件字节。
- main：9918d9dba180f38a62c36f602e37993b87d0d38d，未修改。
- E盘hover_distance：28595c0为基底，迁入的研究改动保持未提交、未暂存、未推送。
- C盘controller-ppid-p-indi：7c5c9ab；为释放hover分支占用而切换，原有未提交文件仍在。
- 未执行merge、rebase或cherry-pick，未打tag。无新仿真。

## 迁移与核验

359个文件、655559558字节有逐项迁移映射；源文件与映射目的文件的SHA256全部一致。迁移内容包含research/ppid_pindi、research/hover_distance、两个独立入口、测试、后处理工具、轻量examples，以及原始本地结果和必要构建产物。两个Python缓存不迁移。

codex-repo-1.md至codex-repo-6.md均已位于E盘项目根目录；其中4–6为C盘原报告的逐字节复制。历史报告和结果中的原C盘执行地址保留，作为来源记录。

根AGENTS.md、HANDOFF.md、README.md保留E盘已验收的F8说明，衔接新研究和当前hover状态。C盘原文单独保存在迁移记录目录，不静默丢弃。

同名且内容不同的results/validation/shc09_physics.mat未覆盖E盘原件；C盘版本保存到迁移记录的from_C_conflicts目录。

85个基础文件仅CRLF/LF不同。E盘保留原字节，避免改写旧冻结来源；C盘原执行源码已打包original_C_execution_sources.zip并逐成员验证SHA。因此不能宣称两棵完整工作树逐字节相同，也不能把引擎指纹差异藏起来：

| 项目 | 值 |
|---|---|
| C盘原引擎 | 86a39d2241d3d7b6c5d6814b7149e1ceb1f812aab530889f73efd09336ba8ec9 |
| E盘当前引擎 | d4c19f329e92fb6b0b272498837d926e33312846d32f31fc35622b6f518cb750 |
| 两边相同的实验输入签名 | a5bde05815ca5c826cbb516153aead5ac4a5b8751a2bacfb7a76014b09c5cd6d |

E盘重新构造配置、模型、参考和计划，与已保存C盘预检配置精确相同；确定性随机输入签名相同。仅构造并核验输入、读取既有日志，未重飞。日志契约验证通过，记录32001个状态点、16001个速率控制点和13321次PWM事件。

280个旧F8结果文件字节未变。三个轻量交付包核验通过：F8为172文件，PPID为66文件，hover预检为31文件。文档检查67个Markdown、456链接、0断链；Git diff --check通过，暂存区为空。

## hover研究状态

只有seed501的EXAMPLE_PINV和PCA_PREDICTIVE两条40秒预检，没有执行五方法三种子的正式15条。PCA预测预检的主窗缩放占空比为15%，但lambda_min约0.00823，未达到0.3–0.6目标；因此迁移不触发新的调参或正式批。具体数据和限制见codex-repo-6.md。

## 尚未完成：C盘工作树清理

用户已授权在迁移核验一致后不保留C盘副本，授权无需重问。实际调用Codex托管工作树归档接口，返回：

> The task's primary checkout cannot be removed.

随后尝试将本对话绑定E盘，接口返回：

> The checkout exists but is not a managed worktree.

因此C盘目录仍在，未通过底层强删绕过应用的主工作区保护。需要先由Codex解除本对话对C盘工作树的主工作区绑定，之后才能通过托管归档完成清理。E盘迁移副本、来源归档和校验材料已齐全，后续命令均显式以E盘为工作目录。

## 证据位置

results/workspace_migration_20261102/包含migration_plan.json、migration_execution.json、copy_verification.json、numeric_input_verification.json、f8_push.json、原执行源码压缩包及清单、文档原件与冲突保留件。WORKSPACE_MIGRATION.md为根目录入口说明。
