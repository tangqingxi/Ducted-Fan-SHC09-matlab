# C2 专属回滚与验证方案

本文件是待批准流程，本轮未执行源码移动、检出重建或控制仿真。基线DEV为refactor/phase3-source@b2a287ceff34445bb7902890141be7a450d19de9。

## 执行前门禁

1. 核对DEV HEAD、分支、远端、worktree与status；保留.dsh-plugins，不reset/clean/stash。不覆盖新出现的用户文件。
2. 对W1_RESOLVED_PLAN.csv的81源逐项算raw SHA；只有70个MOVE可执行，KEEP9与DEFER_W6两行不得传给git mv。再次核对70目标不存在、大小写无重合、各父路径没有普通文件占位。
3. 固化完整原/目标raw SHA、engine、PPID显式来源与桥接exe SHA，记录C1原始版本；给4项必要配套文件及新增验证工具设精确变更白名单。
4. 七份CRLF源设精确目标-text规则，无BOM UTF-8写属性文件，git check-attr核对实际规则。禁止git add --renormalize全仓。
5. 建议将70项移动和必要配套修订组成一个可独立revert的C2提交；暂存只限计划源/目标、.gitattributes、engine、构建路径和静态验证工具的明确修改。若需要更多文件，先解释范围，不扩展算法或控制参数。

## 迁移后静态与MATLAB验证

| 检查 | 通过条件 |
|---|---|
| 精确集合 | MOVE70源不再是活动实现、目标全部存在；KEEP/DEFER源仍原SHA；无覆盖/删除任务外文件 |
| raw字节 | 70目标逐项等于执行单source_sha256，69m和cpp全部相同；Git只因路径/字节保存规则显示对应差异 |
| 新engine覆盖 | 列出新引擎完整路径/字节集合，69移入m无遗漏，无新旧副本双计数；旧ec和新值分列；不要求相等 |
| 注册/依赖 | 六分配器、两效能注册、14句柄文件存在；构建脚本字符串指向新cpp，cpp及exe原SHA不变 |
| 发布字节 | 对70目标git show <C2>:<target>的内容算SHA，等于执行单；独立临时检出同一提交再次比raw SHA，重点七份CRLF |
| 文档/锁保护 | 本轮规划保留的README、历史matrix、MAT/WTR、协议/锁/指标原字节不变 |

在新的隔离MATLAB batch会话中：restoredefaultpath；从DEV根调用ca_setup；加tools后运行check_phase3_paths(root)。在初次和重复ca_setup后保存path及which -all，对执行单69个目标函数还要显式断言which等于target_path；不能只断言“在仓库里”。检查ca_setup、main、shc09_run、platform_run、run_ppid_pindi、registry、effectiveness_registry、ca_allocate、allocation_comparison_engine、ppid_source_manifest、模型及五正式算法和示例插件。研究路径仅重现run_ppid_pindi添加research的上下文，不调用研究任务。

不得直接执行六个platform/tests测试函数，它们可能推进或写结果。不得实例化CaPx4Ecl；仅检查类定位/句柄文件。不得执行build_px4_ecl.py或包装入口；现有--verify-only只验证第三方，不验证新的cpp编译路径，不能据其PASS宣称构建通过。

本轮已经运行当前布局的上述路径/句柄检查和engine复算；**迁移后验证NOT RUN**。未来C2若另需2秒hover，也须用户明确批准运行预算；本申请默认零控制仿真。不得沿用C1的一次短例授权，不运行52/55秒、多方法、多种子或全套测试。

## 回滚路径

### 未提交阶段

先停所有运行进程并记录当前status、差异和raw SHA。按执行单逆序仅对已完成MOVE执行git mv target source，事先验证源缺失、目标存在且SHA等于计划；遇到其他文件占位立即停止，不覆盖。所有绝对目标都必须解析在E:/Ducted-Fan-SHC09-matlab内。配套文件用C1精确版本做有审查的逆向补丁；保存任务差异，不用reset/restore/clean/stash。

### 已提交或已推送阶段

先确认无未提交用户改动，再用普通git revert <C2_COMMIT>建立新回滚提交，正常推送开发分支，不强推、不改main；后续有依赖提交时先检查逆序依赖，不盲目revert。新的MATLAB会话重新检查旧路径。

**仅revert不足以保证原raw字节**：C1的7份源工作树含CRLF而Git旧blob为LF，revert/checkout可能恢复成LF。必须逐文件对照本执行单；不符时从下列已核验只读快照按精确源路径恢复该文件到DEV原位，再重算SHA及旧engine。不要批量恢复整个仓库，不覆盖新用户改动，也不修改快照本身。Git逻辑状态干净与raw科学字节一致须分别报告。

本轮已读取快照中70个对应源文件，70/70 raw SHA均等于执行单，可用于逐文件恢复。快照位于D:/AeroGNC-Backup/AeroGNC-Sim/339d7b1a/snapshot；D/E同物理磁盘，仅逻辑回滚保护，不是独立硬件容灾。未重新复制5GB或重跑全量备份验证。

## 停止条件

目标已存在；源/目标SHA不符；which解析到旧副本/结果目录；任一注册句柄失效；新engine漏计移动源码；出现需改数值算法、旧锁、MAT/WTR或构建exe的要求。保存完整状态、报告FAIL并停止，不改阈值、不追加仿真来掩盖问题。
