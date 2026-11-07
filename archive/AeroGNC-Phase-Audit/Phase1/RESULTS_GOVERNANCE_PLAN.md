# Results 身份、状态与保留方案

## 本轮核实与统计边界

[RESULTS_BATCHES.csv](RESULTS_BATCHES.csv)共247条目录/批次登记，包含179条从历史复制回执恢复的原始批次身份、28条软件构建/回滚登记以及汇总集合。**这不是247次互斥的数值实验，也不能将每行total_size_bytes求和作为磁盘总量。** 某些汇总行与批次行共享证据路径；磁盘总量以FILE_INVENTORY去重路径计算。

对98份非软件构建的数值MAT检查了保存元数据；其中62份具有原始L/ref，已从已保存数组独立复算水平跟踪RMSE与峰值。该复算不推进对象、不执行控制器，不等于从源码完整重跑。其余MAT可能是输入、静置对准或指标容器，不以扩展名推定原始轨迹。

两批正式运行的30份原始MAT与30份WTR按完整源MAT SHA256逐一对应；加上三条预检，共33/33源MAT身份匹配。WTR读取范围是ZIP目录及manifest/parameters/geometry；没有加载所有内嵌flight.mat，也没有据此声称全部WTR负载已做独立数值复核。identity、engine、input_signature详见[RUN_IDENTITIES.csv](RUN_IDENTITIES.csv)。

旧F8、PPID、hover、滤波等不少原始MAT已不在现存轻量集合中；保留的examples、CSV、图、锁、报告和复制回执支持历史交付追溯，不能据此承诺完整轨迹复算或从当前源码一键复现。179条回执批次与现存文件的关系在[HISTORICAL_BATCH_PATH_LINKS.csv](HISTORICAL_BATCH_PATH_LINKS.csv)中保留，未凭前缀补全unknown状态。

## 建议的通用输出结构

```text
results/<study>/<batch_id>/
├── manifest.json                   # schema、身份、三类状态、证据路径
├── protocol/                       # 协议、参数、输入签名
├── provenance/                     # 源码锁、commit、dirty来源、环境、执行记录
├── inputs/                         # 场景/风/参考等冻结输入
├── raw/<run_id>.mat                 # 原始轨迹；存在性单独记录
├── metrics/                        # 可重算CSV及算法版本
├── figures/                        # 可重生成图及来源
├── wtr/<run_id>.wtr                 # 单飞行交付
├── reports/                        # 科学验收报告
└── management/                     # 中断、续跑、清单、归档回执
```

这是未来结构，当前没有移动文件。矩阵中的`raw/wtr/figures/evidence`是第一层归属候选，执行前还须按角色细分到以上inputs/provenance/metrics等目录并做目标冲突检查。

## 建议的manifest约束

身份至少包括`study`、不可变`batch_id`、`schema_version`、协议路径/完整SHA、GNSS模型版本/物理tau、方法/种子、计划与实际时长、输入签名、source_commit及其角色、engine、运行来源是否dirty、源码快照/锁、工具链与随机流定义。每个run保存独立run_id、原MAT SHA、WTR源SHA和实际状态；不能只用method_seed当全局唯一键。

三类状态分别维护，附evidence引用、记录者和时间：

| 字段 | 建议枚举 | 约束 |
|---|---|---|
| execution_status | planned / running / interrupted / completed / failed / unknown | completed只表示预定计算完成；管理性续跑保留原事件 |
| acceptance_status | not_evaluated / passed / failed / partial / not_applicable / unknown | 保存原阈值、指标域、门禁与逐run判定；诊断不自动等于passed |
| retention_status | active_protected / frozen / archived_verified / lightweight_only / missing_raw / deletion_approved / unknown | 删除批准不等于已删除；已归档需备份位置与恢复验证 |

另设`raw_mat_available`、`raw_L_ref_available`、`metrics_recomputable_from_saved_raw`、`full_source_replay_ready`，不能合并成一个布尔“可复现”。现有审计CSV保留细化事实描述；未来登记工具需要受控转换，不能把当前自由文本直接当新枚举。

## 建议的管理工具

未来工具使用显式`--root`、`--study`、`--batch-id`或manifest参数；不能把hover_distance硬编码为全局规则。建议子命令：`inventory`原址只读登记、`validate`身份/状态/负载检查、`link`跨目录关系、`recompute`只读原MAT并写新独立目录、`plan-migrate`生成移动计划、`plan-archive`生成归档计划、`verify-backup`逐文件校验与恢复抽查。写操作另设显式批准清单和预期SHA；默认dry-run，拒绝覆盖既有batch_id。

执行记录采用追加事件和原子写入；中断后按run状态恢复，只跳过已完成且hash正确的run，禁止覆盖原始MAT。指标重算单独带analysis_revision，不覆盖旧报告。关系索引可指向原址，先治理身份再迁移物理路径。

## 保留优先级与门禁

1. 两批正式30条原始飞行、33条WTR、三个预检、输入/协议/锁/管理记录：保护原件，先独立备份。
2. Round 1–7与新1000 s回归：分别冻结，保留采样时刻修正文件及被修正的原始文件。12 s任务、30 s静置重放、55 s正式运行不得混合统计。
3. 失败或中断批：保留诊断与决策证据。管理性续跑与算法重跑分开；不因验收失败删除。
4. 已仅剩轻量汇总的历史批：保留原回执、来源路径和报告；raw不可用明确标注。除非找到原始文件，不升级可复算级别。
5. 软件构建/环境：与科学结果分离；在用安装及唯一回滚包保护。全包清单、许可、环境锁和恢复验证通过后才提交归档候选。

任何移动先核准source→target清单、冲突检测和备份；移动后比较逐文件SHA与原锁身份，不改写历史文件内路径。任何删除均需用户批准的独立清单，并说明证据损失和回退来源；本轮未做删除或归档。
