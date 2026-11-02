# 工作区迁移说明

项目开发入口统一为 `E:/Ducted-Fan-SHC09-matlab`，当前分支 `hover_distance`。F8交付已提交并推送至f8-research，提交为28595c01bd0f0472ebb8a4cbb38d19a43775b0f1；main仍为9918d9d。hover新增代码和本地结果保持未提交。

原C盘工作树为 `C:/Users/32450/.codex/worktrees/controller-ppid-p-indi/Ducted-Fan-SHC09-matlab`。用户要求校验迁移一致后移除该重复目录。迁移和一致性校验已经完成；C盘副本尚未移除。Codex归档工具返回“The task's primary checkout cannot be removed.”，把本对话的C盘工作树视为主工作区；尝试绑定E盘又返回“The checkout exists but is not a managed worktree.”。未强删当前绑定目录，清理状态明确为受阻，不能视为全部完成。

- codex-repo-1.md至codex-repo-6.md现位于E盘根目录；报告中C盘原执行地址属于历史来源，不改写实验历史。
- research/ppid_pindi、research/hover_distance及其入口、测试、工具和examples均已迁入。
- 359个文件共655559558字节有明确迁移映射，包含完整本地实验结果和构建二进制；不是只搬报告或只切分支。
- 同名但不同的results/validation/shc09_physics.mat保留E盘原文件，C盘版本放在results/workspace_migration_20261102/from_C_conflicts/下，未覆盖。
- 根AGENTS/HANDOFF保留已验收的F8正文并增加hover当前交接；C盘原正文逐字节保存在迁移记录目录，README的新研究章节已衔接到E盘。

85个基础文件仅CRLF/LF不同。为避免改动旧冻结来源，E盘保留原字节；C盘原执行源码已保存在results/workspace_migration_20261102/original_C_execution_sources.zip及逐文件SHA清单中。由原字节计算的引擎指纹可能随工作区不同，不能篡改旧sources或formal_lock来掩盖；完整配置/参考/噪声输入另外做迁移一致性检查。

此前PPID正式15条和hover两条预检的原始MAT、图表、来源记录均保持原字节。新的hover正式锁不存在，λ_min未达要求，不因迁移启动新的仿真或正式批。

后续所有开发、报告和新output_tag均以E盘根为准。不自动提交或push hover，不改main，不删除旧F8结果。详细复制映射、校验和移除状态见results/workspace_migration_20261102/。
