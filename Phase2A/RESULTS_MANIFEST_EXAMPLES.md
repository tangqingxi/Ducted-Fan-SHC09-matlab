# 两个真实证据支持的Manifest示例

两个可机读示例仅在本审计仓库中，registration_phase均为DESIGN_EXAMPLE_ONLY。未向原Results写manifest，未移动原MAT/WTR，也没有把“示例通过结构验证”当成真实备份或科研通过。

| 示例 | 真实范围 | 状态 |
|---|---|---|
| [legacy_60s_formal.manifest.json](examples/legacy_60s_formal.manifest.json) | 2026-11-03正式批：五方法×501/502/503，15条55秒；每条列原MAT及对应WTR | completed / failed / KEEP_EVIDENCE，真实恢复0/15、估计恢复15/15 |
| [gnss_v2_1000s_single.manifest.json](examples/gnss_v2_1000s_single.manifest.json) | GNSS-GM-v2：501/PCA_PREDICTIVE单条55秒；1000 s三轴统一物理相关时间；无WTR | completed / failed / KEEP_EVIDENCE；恢复窗最小真实水平误差0.4770444895m > 原0.2m |

schema、字段说明及生命周期见[RESULTS_MANIFEST_SCHEMA.json](RESULTS_MANIFEST_SCHEMA.json)、[RESULTS_LIFECYCLE.md](RESULTS_LIFECYCLE.md)。schema_version是合同语义版本；$schema是JSON Schema方言；$id仅为逻辑标识，不宣称相关网页已经部署。

## 数据与SHA来源

artifact路径均为主仓库相对路径，由root_id=matlab_original与`${MATLAB_ROOT}`映射到当前工作树。字节数及SHA来自[BACKUP_PLAN.csv](BACKUP_PLAN.csv)，其中明确区分本轮读取字节和复用以前完整hash的元数据命中。33份正式及预检WTR源MAT身份在Phase1已验证，本轮只对保护清单定向复核，不重新积分对象。

旧正式批run_id采用实际WTR清单中的身份，15条各自保存输入签名；顶层input_signature=null表示整批含多个种子输入，不以一个种子的签名代表整批。GNSS单条示例未由本轮读取MAT提取输入签名，因此显式null并附限制，而不是借用旧批签名。

两批历史正式批共享协议ID，但change-B的engine/执行来源不同，实际登记时必须另建批次，不能把示例复制改名后沿用旧engine/SHA。

## 来源与时间的准确表述

旧正式source_commit是执行起点c381275，显式锁及冻结hdtf_run提供更精确源码证据；当前主库管理修复版不是原执行版。GNSS示例source_commit为回归启动基准b1cf139，版本化实现随后以ae03d6b交付，不能标为“精确干净执行提交”。两个例子source_dirty_state均保守为unknown。

示例引用当前build_manifest作为现存桥接工件的身份参考，不自动证明旧正式批执行时的二进制相同；应以每批原source_lock中记录的二进制SHA、冻结构建证据及已保存来源为准。后续登记如缺精确执行构建工件，要保持unknown，不能用新版本补写历史。

旧批的interrupted/resumed/completed事件引用已有异常与completion文件，只补14条未运行项，不重飞已完成DA_NS/501。历史精确事件时间本轮未确认，使用null。GNSS示例只引用已有完成证据，不产生新执行事件。

backup及restore均not_executed，storage=local_only，archives为空。现有CSV/JSON、已发布GitHub内容和本页不构成原MAT/WTR备份。

## 验证范围

使用Draft2020-12验证器核对schema本身与两个示例，并检查唯一run/artifact ID、root和artifact引用、方法/种子集合、评价计数及协议SHA引用。负例覆盖错误SHA、越界相对路径、非法状态、空verified证据、run重复及伪造验收通过计数。结果记录于[evidence/VALIDATION.json](evidence/VALIDATION.json)。

这些检查证明设计合同可表达已有事实；不能证明历史源码已可一键重放、所有WTR负载已逐拍独立复核、备份恢复已通过或真实恢复已改善。
