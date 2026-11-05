# C3 验证与回滚方案

本轮均为待执行流程；DEV 269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1只读。不得把未来验证写成PASS。

## 迁移前

核对DEV分支/HEAD/main、远端、worktree与status，保留.dsh-plugins。仅处理W2_RESOLVED_PLAN.csv的MOVE5，33KEEP不动，README不移动；再次核对所有源raw SHA、五目标不存在、父目录无普通文件占位。绑定执行单SHA `e2a63faf87830338df97e172e95a1b3036c33c1a5e5832244565f929529a7e4f`，保存完整C2 raw来源清单、PPID manifest、C2 engine及保护文件前态。

39项raw与Git blob内容SHA当前全部相同；五MOVE均为LF，无需新增.gitattributes规则，也不修改现有七份C2精确-text规则，不执行任何renormalize。若执行时发现字节漂移，应停止重新核对，而不是套用本结论强行转换。

## 执行与验收

1. 只用git mv迁移五份m，并完成engine、静态工具、旧README两链接这三份配套修订；其他文件无授权改动。33KEEP及allocators/interface全部原raw不变，src/allocation不增加实现，allocators/plugins不得创建。
2. 五个源路径不再作为活动实现，五个目标raw SHA等于执行单。DEFER README保留原位，只有已批准两链接可变，目标占位README原SHA不变。
3. 新MATLAB batch会话restoredefaultpath，执行ca_setup；对五个函数which -all逐项断言唯一且等于目标路径。检查平台main/shc09_run、四环run_ppid_pindi的独立入口；只重现研究路径上下文，不启动控制链。
4. 验证六分配器、两效能工厂、14句柄与各自文件；registry原字节不变。连续两次ca_setup后path字符串和实际解析不漂移。测试实际新路径，不能仅检查旧directory字段目录存在。
5. C2与C3 engine各自实测，记录121项路径和raw SHA；五项路径映射、字节不变，其他116项不变，无双计数。PPID显式files集合与预期唯一engine实现SHA差异核对，历史锁不修改。
6. 暂存精确路径，提交前候选树git show验证五个blob raw SHA，再在独立候选检出验证字节；提交后再核对精确提交git show及独立checkout。不得跳过检查直接提交纯移动版。
7. README精确两链接和候选Git树中的目标有效性核验；常规Markdown检查继续通过。源/目标覆盖、任务外删除、新重复函数一律FAIL。
8. 历史协议、锁、MAT/WTR、指标、EXE与build_manifest按前后字节核验不变；本文档之外不改来源记录。ECL仅记录既有UNRESOLVED，不运行或重建。

C3未来可形成一个独立提交，普通推送refactor/phase3-source；main不变。任何控制仿真、2秒短例、52/55秒、多方法/多种子、全套测试、ECL构建/运行均不在默认授权范围。

## 回滚

未提交时按批准执行单逆序、确认无占位且target SHA正确后git mv回原源；配套文件用已审查逆向补丁恢复。已提交时检查用户改动和后续依赖，普通git revert <C3_COMMIT>建立回滚提交，不reset/clean/stash/强推。C3 revert只恢复本波五项及三配套，不撤销C2、不移除C2的7份-text规则。

本轮已只读核对五份快照源文件，raw SHA全部等于执行单；若将来回滚raw不符，仅按精确旧源路径从D:/AeroGNC-Backup/AeroGNC-Sim/339d7b1a/snapshot恢复相应文件，先验证恢复目标位于DEV且无用户占位，恢复后重算SHA。当前五份均LF且raw=Git blob，正常revert预计无需额外字节修复，实际仍须核验，不能用预计替代实测。

快照D/E同物理磁盘，只提供逻辑回滚保护。Gate未演练C3 revert或迁移后MATLAB：NOT RUN，因为没有C3提交、没有移动源码。
