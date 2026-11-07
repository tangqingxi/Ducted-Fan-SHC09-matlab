# Results Manager实施设计

下一阶段目标位置为主仓库`tools/results_manager/`。本阶段仅在审计仓库设计，没有向主仓库写代码或运行管理器。命令名称为未来接口约定，当前不得当成已安装工具。

## 通用调用与安全边界

所有命令显式接收`--root-map <本地配置>`、`--index <索引位置>`及可选`--study`、`--airframe`、`--batch-id`或`--manifest`；研究名称无硬编码白名单。默认只读；生成报告/计划必须给新`--output`并拒绝既有目标。源目录、索引输出、备份目的地分别配置，公共manifest不包含凭据或个人用户目录。

允许的命令均不直接执行移动、归档复制或删除。未来如果另行设计apply命令，必须独立审核，不因为已有plan-migrate接口而默认获准执行。

| 命令 | 输入 | 行为与输出 | 默认写入边界 |
|---|---|---|---|
| inventory | 已有manifest、旧CSV/receipt索引、显式扫描范围、可信hash ledger | 建立批次/工件/来源索引；输出inventory.jsonl、ambiguities.csv、scope.json；不从前缀猜成功状态 | 仅新输出目录 |
| validate | manifest、schema版本、root映射、hash policy | JSON结构、语义引用、计数、文件存在性/完整性、锁及时间域声明核查；输出validation.json和问题清单 | 源只读 |
| link | 显式批次键、旧新locator及证据SHA | 生成或建议跨results/logs/figures/docs关联；冲突不自动选边；输出link_plan.json、collision.csv | 只写建议索引 |
| plan-migrate | 已验证manifest、用户限定范围、目标布局、备份/恢复记录 | 输出逐文件src/dst/size/SHA、路径依赖、锁风险、空间、回滚、所需审批；不移动文件 | dry-run |
| plan-archive | retention类别、引用图、恢复证据、归档root模板 | 生成保留/归档候选及估算，保留失败证据；不把候选状态直接改为已归档 | dry-run |
| verify-backup | 源清单、目的地清单、介质身份、恢复抽样方案 | 目的地逐文件完整SHA、成员集合、源稳定性；按明确选项从备份恢复到空scratch并只读打开，输出backup/restore分开结论 | 默认只校验；恢复写入另给scratch |
| report | 已验证索引及评价标准引用 | 独立汇总execution/acceptance/retention、缺失raw、可复算等级、备份/恢复等级与容量 | 不启动仿真 |

退出码建议：0=请求的检查完成且通过；2=参数/路径/已有输出冲突；3=结构或语义不合法；4=文件缺失/hash不一致；5=审批或可信来源不足；6=I/O/离线介质。unknown与not_evaluated应显式列入报告，不能因命令进程正常退出就当科研通过。

## 文件与身份模型

采用[RESULTS_LIFECYCLE.md](RESULTS_LIFECYCLE.md)的批次键和[JSON合同](RESULTS_MANIFEST_SCHEMA.json)。run、artifact、protocol、engine/source_lock、输入、GNSS/估计器版本均有独立字段。跨批次相同协议ID不够判断相同实验，必须比较完整协议SHA、输入签名、engine及显式来源锁；同一个source_commit也不足以排除dirty执行来源。

源码身份与本机文件身份分开：历史锁保存原运行sha，当前源码快照保存当前sha。发现不同不能“修复”旧锁；输出明确差异和迁移映射需求。轻量Git证据与local-only原始MAT/WTR/EXE单独统计；Git clone成功不能升级backup_status。

## 哈希缓存与验证等级

缓存键至少含root身份、规范化相对路径、大小、高精度mtime、文件ID/介质信息及SHA来源/时间；复用记录还需确认该索引未被修改。缓存命中只表示metadata_matched_prior_full_hash，不得标成“本次重新读取全部字节”。主目录迁移、介质更换、mtime粒度下降或来源不可信时重新完整hash。

目的地首次备份验证必须重新读取目的地每个文件的完整SHA，不能因src/dst大小和mtime相同而省略。源端允许复用可信缓存，但复制期间前后元数据/文件稳定性必须核实；有变化整项失败，不将部分文件标verified。EXE哈希只标EXE，不推及DLL/GLB/主题/许可完整包。

## 并发、续跑及回滚

索引写入采用单写者锁、版本号及原子发布；运行发布必须no-clobber。不得依赖可覆盖目标的普通replace实现不可覆盖承诺。管理事件追加并包含plan_id、源/目标快照、run状态及原始异常。

迁移计划不可直接用字符串拼接shell执行。未来执行器重新解析绝对目标并检查受批准根边界、junction/symlink、源目标互相包含、目标是否存在及共享工件。以文件级状态机记录planned/copied/verified/indexed；跨盘保留源直到确认回滚可用。禁止对整个results执行通配符清理。

## Windows/Linux路径

manifest路径统一`/`，禁止绝对路径、盘符、反斜杠、NUL和`..`；resolver在各OS映射root_id后再次校验真实绝对路径与根边界，不跟随未批准的junction/symlink。执行前检查大小写碰撞、Unicode规范化、Windows保留名、尾随点/空格、长路径能力；Linux不同大小写路径不能默认在Windows无冲突。

程序用结构化进程参数和Path/文件API，不把JSON或用户字段直接插入shell。不可解析的原历史绝对路径以legacy opaque metadata保存，必须有显式映射后才能操作文件。

## 下一阶段实现与验证顺序

先schema/resolver/ledger与只读inventory、validate、report，再link和计划生成；verify-backup最后接入独立介质的实际批准范围。使用临时小fixture验证：真实失败批的状态不被改为成功、同协议不同engine、中断仅补not_run、存在目标拒绝覆盖、缺失/损坏/重复成员、路径穿越及大小写冲突、离线归档、缓存过期、回滚后旧索引可用。所有这些属于治理工具测试，不是控制仿真。

Phase2A只用两个真实证据manifest和小型变体验证合同及语义设计，没有实现主库manager，也未运行任何飞行或GUI测试。
