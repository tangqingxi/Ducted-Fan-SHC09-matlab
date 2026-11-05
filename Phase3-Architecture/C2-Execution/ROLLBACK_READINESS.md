# C2 回滚准备与隔离验证

C2提交：`269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1`；父提交C1：`b2a287ceff34445bb7902890141be7a450d19de9`。普通推送开发分支，不涉及main。

已在独立临时检出执行 `git revert --no-commit 269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1`；得到的Git树与C1树完全相同。随后逐项检查原70源文件：七份CRLF源需要从只读快照按精确旧路径恢复raw字节，恢复后70/70 SHA均等于批准执行单，70新目标均不存在。证据：[ROLLBACK_DRY_RUN.json](ROLLBACK_DRY_RUN.json)。DEV未执行revert，也未从快照恢复任何文件。

实际需要回滚时，先核对工作区及后续提交依赖，保存用户改动；使用普通git revert建立回滚提交并正常推送，不reset/clean/stash/force-push。逐项核对70源raw SHA；仅对不符的七份文件从D:/AeroGNC-Backup/AeroGNC-Sim/339d7b1a/snapshot逐项恢复，恢复前确认绝对路径位于DEV根内、目标没有任务外改动。不要把整棵快照覆盖工作区。

临时revert只证明Git逆操作和70项raw恢复可行；真实回滚后的MATLAB验证NOT RUN，因为DEV未回滚。实际回滚还须在全新MATLAB会话运行旧路径检查，旧engine应按完整raw来源记录复算，不追加控制仿真。

D/E同物理磁盘；快照仅逻辑回滚保护，不是独立容灾。七份文件的Git旧blob为LF，而旧工作树raw为CRLF，故普通revert与科学字节恢复必须分开核验。
