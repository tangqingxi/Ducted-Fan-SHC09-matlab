# 平台化重构验收报告

本轮唯一工作仓库为E盘Ducted-Fan-SHC09-matlab，基于3d41369，分支platform-refactor。tag `pre-platform-refactor`冻结原始提交；main保持原提交；没有push、没有改写历史。Stage0～4已完成，以下为最终验收记录。

## 范围与不变量

本轮只有平台核心、包装、目录和文档变更：**无物理、原控制器、五种算法或实验协议改动**。模型/驱动、第三方、参考原件、legacy_reference、fixtures、既有轻量示例由254项保护清单检查；原算法/控制器仅原字节搬迁，Git显示100%重命名。原results不移动、不重写；隔离验证位于被忽略的archive/platform_refactor，各自生成新结果。

原工作树部分文件为CRLF，而Git原始blob为LF。保护清单同时记录开工时原字节SHA及原提交Git blob SHA，接受其中之一，兼容新克隆的换行策略；没有借此改写算法内容。现有根目录111个结果文件另外按大小及纳秒修改时间检查。

## 阶段与提交

| Stage | 提交 | 交付 | 验收 |
|---|---|---|---|
| 0 | 8fc1db7 | tag/分支、0.74MiB数值基线、保护清单 | 14旧测试、五入口0.2秒、6基线重放、JVM导航通过 |
| 1 | 9935b26 | Bus、Params、Scheduler、sim_driver、统一入口 | 14+3，五入口、完整旧字段SHA/PWM一致 |
| 2 | fa72fd2 | sensors/estimator/position/attitude/rate/commander topic包装 | 六次逐模块14旧测试+20秒及五方法2秒基线，各次五入口通过；JVM导航通过 |
| 3 | f7c8cbb | 两种effectiveness工厂、六插件、注册派发 | 14+5、六组基线与五入口通过；example_pinv集成通过 |
| 4 | 本报告所在提交：platform stage 4 | topic历史/索引、PWM输出、configs/apps、读者文档 | 最终结果见下表 |

本报告与Stage4一起提交，因此不嵌入自身尚不存在的哈希；可用`git log -5 --oneline`取得最终五阶段提交号。提交前已知日志：

```text
f7c8cbb platform stage 3: register effectiveness factories and allocator plugins
fa72fd2 platform stage 2: route sensors estimators and controllers through topics
9935b26 platform stage 1: add bus params scheduler and simulation entry
8fc1db7 platform stage 0: freeze numerical baselines and protected sources
3d41369 Initial SHC09 simulation benchmark
```

## 最终验证

MATLAB 25.2.0.2998904（R2025b）、PCWIN64，JVM启用，Optimization Toolbox；没有新增工具箱。所有运行在本仓库archive下隔离副本进行。机器记录见[运行摘要](../tests/baseline/stage4_runtime_verification.json)、[检查MAT](../tests/baseline/stage4_checks.mat)及[基线目录](../tests/baseline/README.md)。

| 检查 | 最终结果 |
|---|---|
| 旧测试 | 14/14；包含2秒M0/M2b、十次严格门禁烟雾，无气动外推 |
| 新平台测试 | 6/6：Bus、Scheduler、Params、插件、topic链、logger |
| 旧main标志 | 1～5各0.2秒通过 |
| 冻结六组基线 | 20秒M0/DA_NS及两秒五方法，完整旧非耗时字段SHA、稀疏样本和指标表完全一致，最大差0 |
| PWM | 旧更新/来源时间数组逐位一致；新输出topic历史与旧PWM数组完全一致 |
| 官方ECL导航/JVM | 有效估计与坐标变换通过；仅改变真实tau时分配命令变化0；GNSS偏置导致估计平移约[1.5011,−1.0012]m并改变控制指令 |
| README | 三个命令块原文执行；两个函数块保存为文件并通过插件一致性/入口测试 |
| apps | hover_app(3)两秒；mismatch_app默认两秒M0/M2b十次，均完成 |
| 旧图兼容 | 去掉topic_log的五方法旧格式comparison.mat可由plot_main_comparison重绘三组PNG/FIG；plot_mismatch_ladder重绘烟雾汇总，两张代表图已目视检查 |
| 文档 | 27个Markdown、114个相对链接检查通过；README161行、无旧盘符路径，无失效results链接；十问均可回答 |
| 固定源码/结果 | 254项保护检查通过；原根results的111个文件大小/修改时间未变；ECL/Matrix官方源校验通过 |
| Git边界 | main及冻结tag仍指向3d41369；不跟踪results/build/archive；无push |

CSV证据：[旧测试](../tests/baseline/stage4_project_tests.csv)、[平台测试](../tests/baseline/stage4_platform_tests.csv)、[六组基线](../tests/baseline/stage4_baseline_replay.csv)。[README运行记录](../tests/baseline/stage4_readme.mat)、[导航记录](../tests/baseline/stage4_navigation.mat)、[链接检查](../tests/baseline/documentation_links.json)一并保留。完整本地diary为archive/platform_refactor/stage4c_readme_output.txt；验证脚本没有启动正式30次阶梯。

## 数值基线

[numeric_baseline.mat](../tests/baseline/numeric_baseline.mat)为738997字节，冻结20秒M0/DA_NS及两秒五方法，共六组。保存全部非耗时旧日志字段SHA256、精确PWM更新/来源数组、401个稀疏采样点和whole指标。重放逐字段比较完整SHA；Stage4额外显式比较稀疏数值与指标表，允许误差没有被放宽。计时字段和新增topic_log不用于旧字段数值比较。

原积分、控制、执行器、LP/恢复器的算术顺序保持。新增topic历史记录每次发布，包括同一时刻重复发布；latest语义仍取最新值。PWM topic的事件/源时间也已与旧数组逐位核对一致。

## 检查中发现并修复的问题

- Stage3首次清单检查发现两种PCA原生info没有exitflag，原入口曾在事后默认补1。薄包装调用allocator_info沿用原默认，算法文件未改；完整重跑通过。
- Stage4首次清理路径时漏迁六个simulation辅助函数，首项测试立即报找不到ca_disturbance_torque。六文件原样移入platform/sim，重新完整检查，没有改物理绕过失败。
- topic logger的小容量扩容测试发现MATLAB从标量扩容时默认生成行向量，现改为显式列下标扩容；单测及最终完整回归均已通过。
- 合并README绘图/JVM批处理完成所有断言和记录写出后，MATLAB自动退出停留，已按命令行身份核实并只终止该闲置验证进程。独立重复绘图+官方导航检查，随后显式close/clear/exit(0)，进程正常返回0；[清理复查记录](../tests/baseline/stage4_exit_cleanup.mat)保留。此问题属于批处理清理限制，未修改控制/物理绕过。
- 这些检查失败与退出诊断保留于本地archive，未把失败包装成数值通过，也没有回退main。

## README十问验收

这是按文档内容逐项复核的读者可回答性检查，不冒称进行了独立用户实验。

| 问题 | README提供的答案 | 结果 |
|---|---|---|
| 1 项目是什么/不是什么 | 六自由度+共享闭环+分配插件；不是固件移植、SITL、实机/显著性证明 | 可回答 |
| 2 怎么跑 | R2025b/Optimization Toolbox，ca_setup，单方法/五方法2秒代码块 | 可回答 |
| 3 五方法是什么 | DA_NS/WLS/DCA/静态PCA/预测PCA，思想、路径、适用和限制表 | 可回答 |
| 4 怎么加第六个 | 两函数+registry一项+一致性测试；已有example_pinv与指南 | 可回答 |
| 5 测试怎么跑 | 14旧测试、6平台测试、冻结基线，及JVM/ECL可选导航说明 | 可回答 |
| 6 示例是什么 | 重构前30次轻量CSV/PNG，烟雾不等于完整复现 | 可回答 |
| 7 结论能信到什么程度 | 单配对种子、ideal导航、匹配30ms；M4收敛差异不等于优先级优势 | 可回答 |
| 8 哪些没建模 | 可信度卡列实机标定、完整柔性/非定常气动、真实总线/实时安全边界 | 可回答 |
| 9 PX4对应什么 | 核心职责映射表、消息单位差异、非固件移植 | 可回答 |
| 10 旧命令是否兼容 | main/main_comparison/main_mismatch_ladder/plot_main_*保留调用，旧结果不随仓库发布 | 可回答 |

README约161行，包含中文定位和英文abstract、快速开始、目录、方法表、核心表、插件扩展、测试、结果限制、可信度卡、链接、兼容、FAQ、许可、路线图及术语。运行块与文件定义块分别验证；链接检查脚本不联网，只检查仓库相对目标存在。

## 科学结论保持

原第二轮30/30完成，无表外推；hold_90及1～2m/s平滑力混合不变，阈值外仍检查原始迎角。legacy/hold_90的M0跟踪差小于2%。本轮不重跑正式30次。

M0/M1/M2主窗稳态几乎不变，M2b/M3只有小幅跟踪差异，不能忽略实际力矩失配。M4中DCA/预测PCA约0.0011°、静态/DA/WLS约0.3°且衰减；主窗正常缩减/mode1/mode2均零，差异主要是收敛速度。M1整段偏航RMSE约−17%，不推广为全动态鲁棒。旧12秒pilot的WLS两组权重4.84°与0.271°不混入第二轮主权重[1,1,1000]排名。

单组配对种子、ideal导航、真实/名义tau均30ms，不宣称统计显著性或实机优势。见[原协议](vane_mismatch_round2.md)和[冻结轻量示例](../examples/mismatch_round2/README.md)。

## 残余风险与未做事项

- scheduler已提供确定rate group/优先级API，兼容仿真仍由原控制参考循环驱动并精确插入PWM；不宣称完整异步PX4执行器或实时截止。
- commander只实现状态，未做解锁安全检查或真实执行器门控；Params取仿真快照，不自动热更新。
- topic名称是职责适配：torque载荷仍是角加速度rad/s²，thrust载荷是电机rad/s，不可直接连接PX4消息。
- 默认ideal导航保持；可选官方归档ECL依赖JVM、Python3及本地C++14编译器，不是当前完整EKF2固件。
- 插件白名单隔离不是MATLAB恶意代码沙箱；名义J/C仅为原DCA目标度量，代码审查仍有必要。
- topic历史增加内存、MAT文件体积和桌面运行时间；计时预算信息性，未引入求解延迟/漏帧物理模型。绘图与JVM合并批处理应显式清理图窗/工作区并退出，曾观察到自动退出停留。
- 没有新增工具箱，没有改第三方许可，没有为自有模型/数据编造LICENSE。
- 未做新物理实验、完整失配阶梯、执行器真实化、参数不确定性、统计重复或HIL；后续另开任务。

交付说明：[平台](../platform/README.md)、[模块](../platform/modules/README.md)、[插件](../allocators/README.md)、[效能](../effectiveness/README.md)、[示例](../examples/README.md)、[插件指南](platform_plugin_guide.md)、[PX4映射](platform_px4_mapping.md)、[架构](architecture.md)。
