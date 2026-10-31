# Ducted-Fan-SHC09-matlab

**版本：v0.2.0** · lite experimental · 默认 ideal · 物理偏置门禁仍未通过。见 [CHANGELOG](CHANGELOG.md)。

在同一套SHC09六舵面涵道飞行器六自由度闭环中，通过插件比较五种控制分配方法。

This MATLAB benchmark separates a PX4-inspired simulation platform from control-allocation plugins for the overactuated six-vane SHC09 ducted-fan vehicle. Five existing allocators share the plant, measurements, controllers, actuator dynamics and PWM schedule. The refactor preserves numerical behavior and adds an example pseudoinverse plugin; it does not establish flight accuracy or statistical superiority.

**Stage5验收未完成：** lite的实际六自由度小机动偏置门禁未过（0.0610°/s > 0.05°/s），现仅保留为显式研究候选，未切换为已验收默认。详见[失败记录与报告](docs/estimator_realism_report.md)。

**Stage 6A：** lite 仍 experimental，Stage 6A 诊断记录已完成，物理偏置门禁仍失败；默认保持 ideal。见[诊断记录](docs/estimator_diagnosis_report.md)。

## 定位与可信度

这是六自由度仿真、PX4风格职责分层和可插拔分配基准。它不是数字孪生、PX4固件移植、SITL、实机验证或统计显著性证明。

| 可信度卡 | 当前范围 |
|---|---|
| 已建模 | 刚体平动/转动、涵道/机翼气动、风扇/固定片力矩、电机及限速一阶舵机、异步PWM、传感器滤波；lite互补估计、可选ECL导航 |
| 未建模或未验证 | lite实际闭环偏置收敛门禁失败； 实机标定误差、完整柔性/非定常流场、硬件总线和实时调度延迟、真实飞行安全逻辑 |
| 来源 | ICGNC参考方程及气动表；[物理校对](docs/physical_model_audit.md)、[来源清单](docs/physical_reference.json)；源码一致不等于实机标定 |
| 适用域 | 悬停附近；涵道表0～130°、机翼表−20～130°。默认legacy；悬停预设hold_90，1～2m/s混合力，阈值外严格检查原迎角 |
| 不能主张 | 全包线有效、稳定性证明、所有工况算法排名、实机优势或统计显著性 |

## 五分钟开始

需要MATLAB R2025b和Optimization Toolbox。在MATLAB中打开仓库根目录；基础仿真无需Python或C++编译器。

```matlab
ca_setup;
o = shc09_airframe("lite");              % 研究候选，物理偏置门禁未通过
r = main(5,o);                         % 预测PCA，2秒，不保存文件
all_methods = main_comparison(o);        % 五方法，共用同一参考与预生成随机输入
```

```matlab
ca_setup;
legacy_tests = run_project_tests(false); % 固定14项旧测试
platform_tests = run_platform_tests();   % 平台及插件契约测试
baseline = test_platform_baseline();     % 20秒M0和五方法2秒冻结日志重放
new_tests = run_estimator_tests();       % 当前会在实际闭环偏置门禁失败
```

旧测试会在新标签下生成小型验证结果；默认不运行完整30次正式阶梯。底层`ca_config`和无参`shc09_airframe()`保留ideal回归语义；`shc09_airframe("lite")`为显式研究入口；无参`hover_app`继续保留ideal，待门禁通过再决定默认切换。预设明确选择位置保持、hold_90、严格门禁和不保存结果。

```matlab
ca_setup;
single = hover_app(3);                  % DCA，保留旧ideal默认的两秒悬停
smoke = mismatch_app();                 % 旧ideal协议，两秒M0/M2b十次烟雾
plot_mismatch_ladder(smoke.output_dir);  % 只重绘烟雾结果
```

需要落盘时，给覆盖结构设置`save_results=true`和新的`output_tag`；保存图还需`save_figures=true`。默认禁止覆盖已有目录。日志为`log.mat`、旧`control.csv/pwm.csv`和新增`topics.csv`；整组结果为`comparison.mat/metrics.csv`。

## 估计器与传感器

| 模式 | 输入与输出 | 真值反馈 / JVM |
|---|---|---|
| ideal | 真实姿态/位置透传，旧陀螺测量链；作为oracle和回归上界 | 是 / 不需要 |
| lite | gyro/accel/mag/baro/GNSS；Mahony式姿态及位置/速度互补估计，输出估计topic与健康状态 | 否 / 不需要 |
| px4_ecl | 原IMU及辅助观测包，官方归档ECL估计 | 否 / 桥接需要JVM |

用`shc09_airframe("ideal")`、`shc09_airframe("lite")`、`shc09_airframe("px4_ecl")`选择预设。旧`navigation_mode="px4_ecl"`入口继续兼容；旧ECL标志与默认ideal冲突时保留旧ECL语义。lite从加计/磁计/GNSS测量初始化，先静置对准15秒，失败停止，不回退真值。

任务指定的ICM-20689典型陀螺噪声密度0.004°/s/√Hz、100Hz一阶噪声带宽给出约0.050°/s标准差；偏置与0.01°/s/√s游走是仿真假设。CUAV V5 Nano三IMU仅模拟主IMU，不实现投票。GNSS5Hz/100ms、气压50Hz/30ms、磁计50Hz/10ms；这些值不是实机标定。lite不是ECL，不适合把持续线加速度无条件当成重力。

## 方法与边界

编号只在旧入口映射名称；核心通过[显式注册表](allocators/registry.m)调度。也支持`main("DCA",o)`和第六个`main("EXAMPLE_PINV",o)`。

| 名称/编号 | 核心思想及插件 | 状态/适用场景 | 已知限制 |
|---|---|---|---|
| DA_NS / 1 | [直接分配与零空间迭代](allocators/da_ns/README.md) | 冻结实现；总需求方向保持 | 对称界；不预测舵机动态、不区分补偿和跟踪 |
| WLS / 2 | [增量加权最小二乘](allocators/wls/README.md) | 冻结实现；通道偏好明确时 | 权重影响很大；全局默认[1000,1000,1]，失配主协议[1,1,1000] |
| DCA / 3 | [终点可达集及力矩最小二乘](allocators/dca/README.md) | 冻结适配；动态分配 | 原生预测不计等待旧命令阶段，非完整MPC |
| PCA_STATIC / 4 | [补偿优先LP及最小范数恢复](allocators/pca_static/README.md) | 冻结实现；受限需求分层 | 静态效能，不预测响应 |
| PCA_PREDICTIVE / 5 | [等待/保持预测及历史命令恢复](allocators/pca_predictive/README.md) | 冻结实现；终点补偿优先 | 保守非限速仿射界；依赖名义执行器模型 |
| EXAMPLE_PINV | [伪逆加逐元素限幅](allocators/example_pinv/README.md) | 接口示例；可达域内快速分配 | 限幅不保方向，无优先级与动态优化 |

原文与离散化区别见[算法适配](docs/method_adaptations.md)，静态PCA与论文对应见[审计](docs/static_pca_algorithm_audit.md)。本轮不修改上述五种算法或控制律。

## 工程结构

```text
platform/       总线、参数、时钟、模块、日志和仿真边界
allocators/     显式注册表、五种冻结算法及example_pinv插件
effectiveness/  SHC09与hover_linear固定名义效能工厂
models/shc09/   物理方程、气动表和不入运行路径的参考原件
drivers/        执行器动态与真实时间常数，保持原样
configs/        airframes预设、params历史配置适配
apps/           hover_app、mismatch_app读者入口
docs/           物理/协议记录、平台说明及重构验收
examples/       可分发的小型既有CSV/图片
tests/          14项旧测试、冻结输入、数值基线
third_party/    固定版本官方ECL/Matrix及原许可证
results/        本地生成结果，不进Git；旧结果不随仓库发布
archive/        本轮隔离验证工作区，不进Git
```

`experiments/`保存冻结研究协议；`analysis/`保留指标/绘图；`compat/`维护旧日志状态；`modules/`仅保留旧分配API及ECL进程互操作。运行路径显式添加，不使用`genpath`，不加入参考、归档、结果或第三方源码。

| 平台核心 | 职责 | PX4概念对应 |
|---|---|---|
| Bus | 单线程最新样本、时间戳、序号 | uORB主题语义的轻量类比 |
| Scheduler | 整数事件时刻、rate group及优先级；参考循环精确划分PWM积分段 | work queue/定时调度职责 |
| Params | declare/get/set/validate/log；cfg快照适配 | 参数服务 |
| Modules | 测量、估计、最小commander、三级控制、输出 | 飞行栈模块职责 |
| Effectiveness | 固定名义B、界、配平及tau；原DCA所需名义J/C | actuator effectiveness |
| Allocator | 校验清单、构造白名单上下文、调用插件 | control_allocator |
| Logger | 记录topic全部发布历史及原有真值/指标日志 | logger的职责类比 |
| Sim | 唯一真实状态、传感器生成和事件间积分 | 仿真接口边界 |

控制800Hz、PWM333Hz，同刻先控制后锁存；没有真实线程或实时截止保证。`vehicle_torque_setpoint`是旧`v_h/v_c`角加速度需求适配器（rad/s²），并非Nm；电机转速命令不参加六舵面优化。详见[平台](platform/README.md)与[模块表](platform/modules/README.md)。

## 添加一个分配器：三步

1. 新建插件目录，提供带唯一前缀的`*_manifest.m`、`*_allocate.m`，避免无package目录时同名函数冲突。下面是现有第六插件的两个完整文件。

```matlab
function m = example_pinv_manifest()
% 声明统一清单。
m=allocator_manifest("EXAMPLE_PINV",["demand.v_h","demand.v_c","model.B"],false);
end
```

```matlab
function [command,info] = example_pinv_allocate(ctx)
% 最小范数伪逆示例，随后逐元素限幅。
target=ctx.demand.v_h+ctx.demand.v_c;
command=pinv(ctx.model.B)*target;
command=min(max(command,ctx.model.command_lower),ctx.model.command_upper);
info=struct('allocated_effect',ctx.model.B*command,'iterations',1,'exitflag',1,'mode',0);
end
```

2. 在`allocators/registry.m`的数组中添加一项：`entry('EXAMPLE_PINV','example_pinv',@example_pinv_allocate,@example_pinv_manifest)`（该示例已注册，不要重复添加）。`ca_setup`按注册目录加路径，不修改核心。
3. 执行`ca_setup; test_plugin_conformance;`，然后用字符串名称调用`main`。清单包含name/version/requires/info_fields/supports/max_solve_time_s；最大耗时是观测预算，不会注入物理延迟。

插件只接收`ctx.demand/state/model/timing/config`，不得读plant、传感器、文件真值或全局变量。名义惯量J/力矩矩阵C是保留DCA原目标的固定度量，不是实际舵效。见[插件总览](allocators/README.md)、[example_pinv](allocators/example_pinv/README.md)、[完整指南](docs/platform_plugin_guide.md)及[效能模型](effectiveness/README.md)。

## 示例、结论与复现

[examples/mismatch_round2](examples/mismatch_round2/README.md)是重构前30/30正式运行的CSV和图片，原件冻结，本轮没有重跑30次。默认20秒、60%偏航负载、6～16秒主窗、hold_90+严格门禁；[协议](docs/vane_mismatch_round2.md)保留完整定义。全量复现可调用旧`main_mismatch_ladder`，会写新的本地结果目录；两秒烟雾不复现20秒结论。

M0/M1/M2主窗稳态接近；M2b/M3跟踪变化小，不代表实际力矩模型无误差。M4中DCA/预测PCA约0.0011°，静态/DA/WLS约0.3°且呈衰减振荡。主窗PCA缩减、mode1/mode2均为零，主要差异是收敛速度，不能称为优先级优势。M1整段偏航RMSE变化约−17%，不能推广为全动态鲁棒。

这些是单组配对种子、理想导航、真实/名义tau均30ms的结果。旧12秒pilot的WLS两组权重曾有4.84°与0.271°差异，不应混入主协议排名。[示例说明](examples/README.md)解释各文件和限制；完整日志在本地`results/`，不作为源码依赖。

## 估计反馈比较（Stage5）

<!-- ESTIMATOR_RESULTS_START -->
E1为12秒小角姿态跟踪、3组配对种子的平均姿态RMSE；E2为20秒M0/60%负载、单种子主窗偏航RMSE，单位均为度。比值静态/DCA大于1表示DCA误差更小。

| 实验/模式 | DA_NS | WLS | DCA | 静态PCA | 预测PCA | 静态/DCA |
|---|---:|---:|---:|---:|---:|---:|
| E1/ideal | 0.26566 | 0.26566 | 0.021761 | 0.26566 | 0.025616 | 12.208 |
| E1/lite | 1.0273 | 1.0273 | 0.9908 | 1.0273 | 0.99092 | 1.0369 |
| E2/ideal | 0.0010729 | 0.0010729 | 0.00097311 | 0.0010729 | 0.00097762 | 1.1025 |
| E2/lite | 0.84064 | 0.84064 | 0.84271 | 0.84064 | 0.84075 | 0.99754 |

40/40执行完成，但候选估计器的实际闭环偏置门禁未过；Stage5 当时未运行 E3；后续结构失配结果见下文 E3 节。该对比包含测量噪声结构变化，tau仍匹配，不能把变化全部归因于姿态真值。[完整表与限制](docs/estimator_realism_report.md) · [CSV](examples/estimator_realism/README.md)。
<!-- ESTIMATOR_RESULTS_END -->

## 测试、兼容与常见问题

- 14项旧测试覆盖物理参考、分配、闭环、PWM、测量滤波、随机输入和协议；新增6项平台测试覆盖Bus/Scheduler/Params/topic链/插件/logger。`test_platform_baseline`额外比较所有非耗时旧字段的完整SHA与PWM数组。
- ECL使用固定官方归档核心的独立进程桥接，不是完整EKF2固件。需要JVM，不能用`-nojvm`；可选测试还需Python3与支持C++14的g++。
- 可选导航：先执行`python tools/build_px4_ecl.py --verify-only`，设置本机`CXX`或编译器PATH后执行`python tools/build_px4_ecl.py`，再在MATLAB运行`ca_setup; test_realistic_navigation;`。基础快速开始不依赖此编译链。
- 缺Optimization Toolbox：`linprog/lsqlin`不可用；请在MATLAB安装并确认工具箱授权，没有另加工具箱。
- 为什么找不到结果：`results/build/archive`被Git忽略；已有目录默认禁止覆盖。重新运行会生成新结果，仓库只携带轻量示例。
- 旧命令：`main(1..5,overrides)`、`main_comparison(overrides)`、`main_mismatch_ladder`和`plot_main_*`签名保留；`plot_main_comparison(result_path,false)`可离线重绘已有比较结果。旧配置缺新字段时仍按兼容规则处理。
- 为什么保留ideal：它用于冻结回归和oracle对照。lite仍是未通过物理门禁的研究候选；切换ECL需要编译桥接与JVM。lite用估计姿态及偏置补偿角速度，角加速度继续走原滤波测量链；大线加速度、磁偏置及GNSS中断仍有限制。

[架构](docs/architecture.md) · [PX4映射](docs/platform_px4_mapping.md) · [插件指南](docs/platform_plugin_guide.md) · [重构验收报告](docs/platform_refactor_report.md) · [估计器真实化报告](docs/estimator_realism_report.md)

## 第三方、许可与路线图

第三方来源和原许可证见[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。仓库尚未为全部自有代码/参考数据选择统一LICENSE，本轮不编造开源许可。

Stage5增加lite现实预设与估计反馈比较，保持物理、控制器、五分配算法和旧协议不变。执行器真实化、参数不确定性、完整失配阶梯和HIL留待后续，本轮不做。

## 术语

| 术语 | 含义 |
|---|---|
| SHC09 | 本仓库六舵面过驱动涵道飞行器对象 |
| DA_NS | 直接分配和零空间迭代 |
| WLS | 加权最小二乘控制分配 |
| DCA | 动态控制分配，本项目采用单步终点适配 |
| PCA | 补偿优先、跟踪次之的控制分配 |
| INDI | 增量非线性动态逆，生成补偿/跟踪需求 |
| PWM | 脉宽调制；本仿真指独立锁存时钟 |
| effectiveness | 指令到虚拟控制量的名义效能及边界 |
| allocator / plugin | 分配算法 / 通过清单与注册表接入的实现 |
| uORB-like bus | 本地单线程最新样本总线，无PX4消息中间件 |

## 估计反馈下比较分配器

`ca_setup; s=estimated_allocation_comparison_app;` 一次运行默认 lite 的 E1/E2 五方法缓存比较；也可指定 `'mode','ideal'` 或 `'mode','px4_ecl'`、`'experiments','E2'`、`'seeds',1:3`。ideal 是 oracle，lite 仍 experimental，归档 ECL 为独立交叉验证且需要 JVM；平台默认仍 ideal。

入口输出分窗跟踪、分配、控制代价与估计指标，以及 Pareto 表/图，不计算综合得分。E2 同时看 whole 瞬态收益与 task 稳态；姿态差异小于种子波动时标“不可分辨”。单种子/三种子、lite 未验收、ECL 旧版、tau 匹配均限制结论，不能称某方法全局最优。见[使用与指标定义](docs/estimated_allocation_comparison.md)。

## 估计反馈下的结构失配

```matlab
ca_setup;
s = e3_estimated_mismatch_app;          % 三工况、两模式、五方法，三十次全新运行
check = test_e3_estimated_mismatch;     % 两秒 M0/M2b 烟雾及独立重复
```

E3 固定 M0/M2b/M4、ideal/lite、20秒60%负载、2秒加载/16秒卸载；whole/主窗/瞬态为 [0,20]/[6,16]/[0,6]。严格气动域 error，失败记录后停止。沿用 MVP 的指标和二维 Pareto，不计算综合得分。lite 仍 experimental，默认 ideal；未运行可选 ECL，单种子不能作统计或实机结论。

30/30全新完成。M0/M2b的主窗细微跟踪差别在本次单种子下不能排名；M4/lite保留明显方法差异，同时出现高饱和和大姿态退化，没有完整复现ideal的两组收敛结论。共同残差、PWM活动和饱和的Pareto权衡依赖所选两轴，不宣布单一最优。

[设计与结果](docs/e3_estimated_structural_mismatch.md) · [轻量示例](examples/e3_estimated_mismatch/README.md)。完整日志保留在忽略的本地 results，不随 Git 发布。

## 工程结构与文件治理

活跃运行层为 platform/allocators/effectiveness/models/drivers/lib/configs，apps 提供用户入口；modules/compat 及根目录入口仍保留兼容职责。analysis/experiments 同时包含活跃分析与按需历史包装，不能整体删去。tests 与 fixtures/baseline 冻结；docs/examples 为文档和结论证据；一次性 Stage6A 实现保存在版本化 docs/evidence，原调用保留。archive/results/build/.tmp_matlab 是忽略的本地历史/生成目录，不加入运行路径或 Git。

[仓库地图](docs/repository_map.md) · [全文件决策清单](docs/file_inventory.csv) · [治理报告](docs/repo_hygiene_report.md) · [文档索引](docs/README.md)。本地几千个 .m 不等于几千份活跃源码；未引用仅列待审，未删除核心、测试、参考或证据。
