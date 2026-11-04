# 工作区迁移历史与当前状态

本文记录迁移的来源关系，不再作为待执行迁移任务。当前Git和下一步统一见[HANDOFF](HANDOFF.md)。

## 当前状态（2026-11-04）

- 唯一开发工作树为`E:/Ducted-Fan-SHC09-matlab`，远端开发分支仅main。
- 旧controller-ppid-p-indi工作树及同名本地分支已按用户要求移除，已不占用Git worktree；不要继续尝试迁移、归档或恢复这个旧目录。
- 当时为清理准备的Worktree-Cleanup-20261104目录亦按用户要求移出活动目录，不作为现存科研备份依据。
- GitHub主仓库名称没有改变；AeroGNC-Sim更名、多机型结构及WindTrace拆分尚未实施。

## 2026-11-02迁移的历史含义

当时PPID-PINDI、hover代码/轻量证据及本地结果从旧工作树迁入E盘，记录359文件/655,559,558字节的映射和SHA一致性；有冲突的MAT与原C盘源码另存于当时迁移记录中，85个基础文件曾有CRLF/LF差异。详细原文见[codex-repo-7](codex-repo-7.md)。

上述计数、引擎和路径是历史证据，不是今天对旧目录或归档仍存在的承诺。原results/workspace_migration_20261102目录现已不在工作树，不能继续把其中归档当作当前可用备份；不要为修正文档重新生成它、搬动原始数据或重跑旧实验。

本次只更新状态说明；不改旧报告、源码锁、协议、MAT/WTR、WindTrace EXE或科学结论。历史完整说明仍可从[整改前版本](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/blob/339d7b1a997de6ba350cef3207d8a5b7db3d838d/WORKSPACE_MIGRATION.md)查阅。
