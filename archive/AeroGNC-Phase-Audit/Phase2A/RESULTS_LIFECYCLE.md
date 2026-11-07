# Results生命周期与身份规则

本文件为未来实现合同，当前不改主仓库目录或登记文件。研究类别动态新增，SHC09仅为首个airframe。

```text
results/
├── _index/                         # 原址索引、批次键、历史路径与归档解析
├── _scratch/                       # 显式临时任务；不能作为正式证据唯一存放点
├── hover_distance_takeoff_formal/<batch_id>/
├── figure_eight/<batch_id>/
├── actuator_failure/<batch_id>/
└── <future_study>/<batch_id>/
    ├── manifest.json
    ├── protocol/
    ├── provenance/
    ├── inputs/
    ├── raw/
    ├── metrics/
    ├── figures/
    ├── wtr/
    ├── validation/
    └── management/
```

study/airframe/batch_id组成批次键；run_id在批次内唯一，全局地址为该键加run_id。相同协议不同engine、GNSS模型、输入签名或执行来源应为不同批次，不依赖文件名前缀分组。artifact_id是manifest内部唯一键，locator使用root_id与POSIX相对路径；本机绝对盘符在本地根映射配置中解析，不写入可迁移的artifact路径。

## 三类状态独立维护

| 字段 | 允许状态 | 解释 |
|---|---|---|
| execution_status | planned / running / interrupted / completed / partial / failed / unknown | 计算与保存状态；completed不推导acceptance |
| acceptance_status | not_evaluated / passed / failed / partial / not_applicable / unknown | 指定原判据的结论；同时保存原阈值、评价域与证据 |
| retention_status | KEEP_ACTIVE / KEEP_EVIDENCE / ARCHIVE_CANDIDATE / DELETE_CANDIDATE / REVIEW_REQUIRED | 用户统一保留类别；失败实验可为KEEP_EVIDENCE |

storage.state另外记录local_only、backed_up_verified、archived_verified、deletion_approved、deleted或unknown。它不是第四种性能判定。备份、恢复验证分别有not_executed/partial/verified/failed/unknown及证据引用，不以写了计划就标verified。

历史正式批的正确组合是completed + failed + KEEP_EVIDENCE；真实恢复0/15、估计恢复15/15分别记录。仅剩轻量汇总时raw availability=missing/unknown，不自动将历史科学结论改成unknown，但必须限制可复算声明。不能将“值得保留”当成“性能合格”。

## 登记、执行与中断

Phase2A的两个manifest是审计示例，registration_phase=DESIGN_EXAMPLE_ONLY，未在原Results登记。Phase2B顺序为先批准并完成备份，再原址登记真实manifest，最后才申请物理迁移。

实际生产者先独占创建新batch_id；若已存在，默认失败，不覆盖任何MAT/WTR/CSV/协议。运行先写新临时文件，完整关闭及hash后以“目标不存在”原子发布；禁止以同名覆盖实现续跑。事件日志追加sequence、run_id、source identity、时间与证据，未知历史时间用null，不编造时间戳。

执行中断不改变已完成run；恢复时验证来源锁、输入、已保存hash与执行状态，只补not_run/未开始项。部分写入、failed、状态矛盾均先隔离并人工核实，不自动重飞。若批准重试，创建新attempt/run_id或新batch，保留supersedes关系及旧失败数据，禁止替换原run。历史首条DA_NS后的汇总中断与只补14项的管理性续跑原样保留，不能算作15个仿真失败或“全程无中断”。

## 迁移与归档

先原址登记旧results/logs/figures/docs/examples位置及sha，_index维护legacy locator→canonical artifact locator。不要重写原MAT内保存的路径或旧锁。路径别名不是复制：同一工件有多个逻辑引用时，其磁盘统计按实际source_path去重；不同原路径即使SHA相同也不自动物理去重，可能承担不同证据角色。

迁移审批必须具体到源、目标、字节、SHA、锁引用、共享引用、恢复来源和冲突策略。优先复制到全新目的地→逐文件校验→更新新索引→验证解析→保留原址观察；原址删除另行审批。跨卷不可假定rename原子，使用有日志的copy-verify-publish协议。失败先将索引退回旧版本，保留不完整目标作诊断，不删除源。

归档使用archive_id、介质身份、独立归档清单、成员路径/SHA及恢复测试记录；解析器依据root映射定位本地、挂载的归档或明确offline状态。归档未挂载不能静默回退另一同名批次，也不能仅根据EXE同hash就推定整包相同。

DELETE_CANDIDATE只是候选。删除另需路径级审批清单、备份/恢复证据、科学保留理由、引用检查及有效期；本轮不产生执行删除授权。未来如用户明确不保留某项，记录该决定和损失范围，不额外替用户创建未批准的大规模备份。

## 版本与一致性

schema v1拒绝未定义字段；扩展放extensions，重大语义改变升版本。结构校验使用[RESULTS_MANIFEST_SCHEMA.json](RESULTS_MANIFEST_SCHEMA.json)；唯一ID、引用存在、计数算术、方法/种子覆盖、实际文件hash与来源一致性由manager语义校验，JSON Schema本身不能证明文件存在或科研通过。[JSON Schema 2020-12验证规范](https://json-schema.org/draft/2020-12/json-schema-validation)定义的结构断言不替代这些外部检查。
