# 架构与依赖审计

范围：当前工作树静态检查、已保存协议和来源索引；没有执行MATLAB、测试套件、仿真、构建或导出器。静态引用仅是调用候选，不能证明某函数运行过，也不能以“无引用”证明可删除。

## 已核实的活跃边界

| 边界 | 已核实路径与职责 | 迁移约束 |
|---|---|---|
| 平台运行链 | `main.m → apps/main_comparison.m → shc09_run → platform_run → sim_driver → platform/sim/ca_simulate`，由总线/调度器连接模块 | 保留兼容入口与调度语义；不与研究控制器直接合并 |
| 四环研究链 | 研究入口与配置 → `research/ppid_pindi/ppid_simulate.m`，直接推进四环控制、估计、对象与分配 | 400 Hz研究控制等时间域及参考长度驱动容量属于数值行为；不能视为平台链的重复副本 |
| MATLAB路径 | `ca_setup.m`显式添加目录，再追加分配器和效能注册目录；没有全树genpath | 新路径必须显式维护；同名函数遮蔽检查是阶段3门槛；本轮未改ca_setup |
| 分配器注册 | `allocators/registry.m`显式注册五研究算法及EXAMPLE_PINV；`shc09_allocator_dispatch.m`调用函数句柄并校验manifest与输出 | 静态文本检索会漏掉函数句柄、方法名和feval；不能因此认定插件未使用 |
| 效能注册 | `effectiveness_registry.m`显式选择shc09_6dof、hover_linear；`effectiveness_for_model.m`按对象标识调用factory | 目录与factory必须配套迁移；禁止以分配算法名称分支选择效能 |
| 旧分配接口 | `modules/control_allocator/ca_allocate.m`构建白名单ctx、调用dispatch，再通过`compat/ca_complete_allocation.m`补齐旧结果 | 当前仍活跃；`platform/modules/control_allocator/shc09_allocator_module.m`是总线适配器，两者职责不同 |
| 参数隔离 | `shc09_allocator_context.m`只传demand、估计执行器状态、名义效能、timing及`ca_allocator_config.m`白名单 | 插件不应获得完整真实cfg/model；白名单包含sample/pwm/tau_model、约束和求解参数，未传真实风/传感器偏置 |
| 名义模型 | `shc09_6vane_effectiveness.m → shc09_nominal_effectiveness.m` | 静态可确认隔离设计；不能据此声称所有运行状态无泄漏，后续仍需接口测试 |
| ECL桥接 | `CaPx4Ecl.m`启动`build/px4_ecl/px4_ecl_bridge.exe`，INIT/STEP文本协议连接外部进程 | 保留可执行文件身份、构建依赖、初始化字段和返回数组布局；不能把桥接误作纯MATLAB函数 |
| 测试入口 | `run_project_tests.m`含显式测试名及可选feval调用，结果写入results | 本阶段未执行；静态调用图不覆盖全部测试依赖 |

`docs/px4_ecl_reference.json`实际存在，未发现该入口缺失。`docs/reference/px4_ecl_reference.json`不存在，但不是此处代码使用的路径。

## GNSS版本及时间链

**事实：** 新模型显式通过`shc09_gnss_config → research/ppid_pindi/gnss_v2/ppid_gnss_v2_config → 原ppid_config或hdtf_config → 父协议SHA及幅值校验 → 新协议1000 s叠加 → 原ppid_noise/ppid_simulate/ECL`加载。旧入口仍为历史60 s，不是配置遗漏。原协议、formal_lock与旧诊断必须保留。

`ppid_noise.m`以真实`dt=1/fs`构造一阶GM离散更新，1000 s是物理时间，不是样本数；现存新入口不改变原随机流。GNSS源样本、100 ms延迟接收、fresh时刻、ECL消费时钟应分别保存。Round 7及GNSS v2已有来源时刻校正证据；后续迁移必须逐样本比较source/receive索引，不能以当前接收时刻真值计算历史测量误差。

**事实与边界：** 旧60 s模型Round 7表明完整固定偏置初始化后的G与零slow的B轨迹差达到厘米级，而F残余受不同静置初始化历史与ECL收敛影响。该证据不支持将F残余直接解释为固定偏置独立贡献，也不改变历史55 s漂移与动态slow高度一致的判断。不同条件RMSE的简单差不能当作可加物理贡献。1000 s新55 s回归数值完成但真实恢复仍失败，属于另一个模型版本。

## 冻结来源与路径依赖

**事实：** `analysis/allocation_comparison_engine.m`纳入指定数值目录下`.m`的路径及原始字节，并处理标定数据身份。`ppid_source_manifest.m`另覆盖研究源码、旧协议、实验与配置范围；GNSS v2另有版本化source_lock。移动源码即使内容不变，也可能改变engine身份。

**事实：** `platform_run.m`还递归捕获较广范围的实现`.m`，排除reference、third_party、archive、results等目录；该捕获集合与ca_setup的运行搜索路径不同。某诊断源码被记录到实现快照，不等于会被运行。

**建议：** 保存旧源码原路径快照及旧MAT内的实现身份。新结构生成新engine；新增old_path/new_path/content_sha/old_engine/new_engine映射。禁止更新历史锁后宣称旧批“相同来源”。当前[LOCK_REFERENCES.csv](LOCK_REFERENCES.csv)记录显式锁路径，113个现存引用不是全部engine覆盖范围。

## 精简候选与不能删除的证据

| 候选 | 核实程度 | 建议 |
|---|---|---|
| `__pycache__`、`.pytest_cache`、`.pyc`、少量tmp/asv | 元数据识别到117个DELETE_CANDIDATE；未逐个确认恢复需要 | 仅经正式删除清单批准后清理；tracked文件、锁关联文件须再次拦截 |
| Viewer历史build、bundle、rollback | results下大量软件构建文件；44份EXE有16种EXE SHA | 可归档候选；先验证整包与在用版本，EXE相同不证明资源/DLL相同 |
| examples中的工具副本 | [DUPLICATE_SOURCE_GROUPS.csv](DUPLICATE_SOURCE_GROUPS.csv)识别小源码逐字节重复 | 多为复现快照；保留历史用途，不能用主工具新版本替代原证据 |
| `apps/legacy`、`compat`、包装函数 | 存在间接调用、动态注册及旧API责任 | 先绘制调用者/测试/协议关系；目前无充分依据指定可删数值模块 |
| `.venv` | 本地环境含53份包元数据；局部exclude；部分原创建路径陈旧 | REVIEW_REQUIRED；先冻结Python、构建依赖、完整环境信息，独立重建验证后才讨论旧环境 |

按职责重排是建议，不代表已经证明各目标路径均可直接导入。当前7157条静态候选边、逐文件矩阵和锁索引用于后续人工细化；文件内字符串、MAT内嵌代码、外部用户脚本、插件调用及GUI动态加载都可能超出静态覆盖。
