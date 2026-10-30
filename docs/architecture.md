# 架构与行为保持

SHC09六自由度物理、五种分配器、三级控制器和研究协议保持原实现。本轮新增平台边界，按职责封装，不改变控制算式或物理积分顺序。

## 入口和依赖

`main(flag,overrides)`保留1～5映射，字符串名称由显式registry校验；`main_comparison → shc09_run → platform_run → sim_driver → ca_simulate`。apps提供两秒悬停/失配烟雾预设，旧研究`main_*`与`experiments`不变。`ca_setup`仅添加显式源码路径，不加入results、archive、third_party或物理参考。

[平台数据流与时序](../platform/README.md)包含mermaid图，[模块表](../platform/modules/README.md)列出订阅/发布及频率，[PX4映射](platform_px4_mapping.md)解释职责类比的边界。

## 物理和名义控制分离

真实state、气流、真实tau、舵效非线性/弱化、扰动和传感器偏置只在sim/物理生成与兼容真值日志中。公开总线没有plant_truth；测量模式显式选择理想或滤波/导航链，ideal不等于仿真已达到现实精度。

融合模块接收传感器packet，不接收真实状态。位置/姿态/角速度控制只订阅估计topic，调用原冻结控制器；位置环的质量、重力、推力系数是固定名义参数。分配器经未修改的`ca_allocator_config`白名单和effectiveness视图，仅得到名义B/J/C、界、配平、tau、timing和delta_hat。

名义J/C保留DCA原物理力矩目标；不能把C改成J*B重构后假定舍入逐位相同。真实矩阵不进入该视图。白名单隔离是代码接口，不是防恶意插件的MATLAB沙箱。

## 插件与兼容

`allocators/registry.m`显式列name→句柄/目录，无目录扫描或核心方法分支。插件文件使用唯一前缀，避免无package目录下函数冲突。五个原实现只搬迁，统一包装调用它们；example_pinv是独立第六项。

新状态topic只保存通用`allocator/info`。旧`ca_allocate`签名与`compat/ca_complete_allocation`补齐历史字段，sim继续复制lambda/beta/mode/restore等旧分析字段，不根据方法名决策。新topic logger不解释这些字段。

## 日志和测试

`log.topic_log`新增每次topic发布的时间、序号与载荷；所有旧log字段与CSV列保留。`topics.csv`只是索引，完整载荷随log.mat保存。真实状态仍为sim私有兼容字段供离线指标使用。旧plot_main_*可读取旧结果，不要求topic_log存在。

原14项测试加6项平台测试；冻结基线比较20秒M0单方法和五方法2秒的所有旧非耗时字段完整SHA、数值样本和PWM时序。六个Stage2模块分别跑旧测试与基线，Stage4另外验证JVM导航和重绘。证据见[重构报告](platform_refactor_report.md)与[基线说明](../tests/baseline/README.md)。

## 研究结论不随目录改变

对象侧vane_*和aero_low_speed_*不进入插件。legacy默认不改；正式第二轮hold_90在低速90°查表并于1～2m/s混合力，阈值外仍检查原迎角。参见[第一阶段](vane_mismatch_phase1.md)、[第二轮协议](vane_mismatch_round2.md)和[轻量结果](../examples/mismatch_round2/README.md)。

30/30既有结果是单配对种子、ideal导航、tau匹配30ms的机制实验。M4主窗无PCA缩减/回退，差异主要是收敛尾迹；M1整段变化不能由主窗稳态概括。WLS固定权重敏感性不得混入主排名。本轮不新增优越性结论。
