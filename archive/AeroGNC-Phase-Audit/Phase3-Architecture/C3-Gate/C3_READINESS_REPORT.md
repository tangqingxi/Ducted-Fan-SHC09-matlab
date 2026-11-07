# C3/W2 迁移准入报告

日期：2026-11-05（Asia/Shanghai）。结论：**READY_WITH_CONDITIONS；C3实际执行PENDING_USER_APPROVAL**。仅作架构统一、版本化执行单与执行前验证，不移动源码、不执行C3、不运行控制仿真。

## 固定身份

DEV refactor/phase3-source@`269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1`，远端同SHA；main=`fdc933694db9c16a0d9ffcd6d9c391b052352d22`。AUDIT起点main@`ef6216403b325b7f1492d3f11ee301652ad6f6d1`，与远端一致。DEV只读，既有.dsh-plugins保留；本轮仅向AUDIT新增C3-Gate轻量文本证据，未改历史矩阵或DEV文档。发布AUDIT SHA由Git历史与最终回复给出，避免自引用。

## 五项答复

| 条件 | 结论 |
|---|---|
| 33分配器KEEP是否最终统一 | 是；本轮用户决定及ADR-C3-W2-v1统一顶层allocators，W2版本单明确33KEEP，旧plugins目标只保留历史证据效力 |
| 五效能源是否具备移动条件 | 源存在、完整raw SHA、五目标缺失、父路径无文件覆盖；均LF且raw=Git blob，五份快照源SHA相同；无需新增属性规则 |
| 新路径/文档/注册冲突 | 无五目标或同名冲突；现有ca_setup足以映射；src目标README冲突以延期规避；旧效能README有两链接需精确修复，尚未实施 |
| C3必须改哪些配套 | engine加入src/effectiveness；静态工具支持W2固定基准/集合/新效能注册定位；旧effectiveness/README仅两链接。共三份配套文件 |
| 是否建议批准 | 建议有条件批准APPROVAL_REQUEST的五移动+三配套，KEEP33和目标README保护强制；本轮不执行 |

## 检查证据

- [W2_RESOLVED_PLAN.csv](W2_RESOLVED_PLAN.csv)：39行，KEEP33/MOVE5/DEFER1；绑定DEV当前树；raw SHA256、Git blob内容SHA256、Git OID分列。git_blob_sha字段定义为Git blob内容的SHA256；git_blob_oid是40位Git对象身份，不能混用。39/39 raw与blob内容一致。
- [ALLOCATION_ARCHITECTURE_DECISION.md](ALLOCATION_ARCHITECTURE_DECISION.md)：唯一有效W2执行方案的优先级和替代关系；原历史矩阵SHA仍`7f7930414a5f0c858226f944815b64810aa760fad9f178ed29c4e10c6598d38c`。
- [ENGINE_AND_REGISTRY_IMPACT.md](ENGINE_AND_REGISTRY_IMPACT.md)：当前MATLAB PASS，未来迁移后NOT RUN；现有engine移后会漏5项，需配套覆盖。
- [CURRENT_PATH_VERIFICATION.json](CURRENT_PATH_VERIFICATION.json)：R2025b 25.2.0.2998904 (R2025b)，287函数名、6分配器/2效能/14句柄、重复ca_setup均PASS；当前engine `19ce8d8136471d32f807de051183d3cca272233cb2b14d3e6fa988b0dfa89e63`。
- [VIRTUAL_ENGINE_PATH_MAP.json](VIRTUAL_ENGINE_PATH_MAP.json)：内存静态路径映射121项，五项路径改变/字节不变，名字无冲突。不是迁移后的运行或哈希值。
- [DOCUMENT_LINK_IMPACT.md](DOCUMENT_LINK_IMPACT.md)：解析全部152份跟踪Markdown，发现一处因五源迁移新失效的链接、同一README一处C2既有旧目录链接；最小修复白名单仅两处。
- [FILE_AND_LINK_ANALYSIS.json](FILE_AND_LINK_ANALYSIS.json)：逐项原/blob SHA和换行计数、历史目标、原链接及Git树/本机空目录区别。
- 既有C2 evidence-manifest的19项证据已核验；常规docs链接工具当前90份/565链接/0断链，但未覆盖effectiveness README，不能代替本次定向审查。

首次临时MATLAB证据导出直接包含function_handle而被jsonencode拒绝；改为将句柄名称转字符串后，当前布局检查与保存成功。未因此调用控制算法或修改DEV。所有后迁移检查、C3新engine、blob/独立检出、C3回滚演练均NOT RUN，必须在未来获批执行后完成。

历史ECL二进制a3f…恢复继续UNRESOLVED；当前a68d…及build_manifest不改。本轮没有ECL构建/运行或新控制仿真，没有重做全量备份或恢复实验。快照仅五份源作只读SHA核对；D/E同物理磁盘，属于逻辑回滚保护。

## 精确下一步

审查并批准[APPROVAL_REQUEST.md](APPROVAL_REQUEST.md)后，才从固定C2基准执行五MOVE与三配套并验证。C3未批准前不修改DEV；不得自动C4或合并main。未来README的DEFER仅指文件不迁移；获批的两处链接可变，目标占位README仍原字节。
