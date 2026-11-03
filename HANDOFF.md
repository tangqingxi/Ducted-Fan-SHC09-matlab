# HANDOFF — SHC09 hover_distance研究与WindTrace配套交接

更新时间：2026-11-03（Asia/Shanghai）。以当前 **hover_distance** 为研究与配套可视化的共同开发线。本轮按用户批准快进同步WindTrace_merge，并整合交接文档、验证后在本地提交；不运行仿真、不push、不改main。

> **当前停点**：标称8/8 Hz五方法×501–503完成15条40秒飞行，原驱动12 completed／3个DA_NS failed；按原配置弧度容差独立审计15/15有效，原失败记录保留。六组滤波粗扫及两组复核共20/20完成，建议H1/H2=15/15 Hz，平均滚转残差4.741029%。**新的15/15 Hz五方法正式批尚未冻结、尚未运行，等待用户决定。**

AGENTS.md、README.md、research/hover_distance/README.md和WORKSPACE_MIGRATION.md仍含“仅两条预检”“正式批未启动”“hover未提交”等历史快照，不能覆盖本文当前停点。旧F8交接在Git历史和既有报告保留；不把旧F8结果与新四环／hover结果混为同一协议。

## 0. 当前状态与保存边界

| 项目 | 当前事实 |
|---|---|
| 工作目录／当前分支 | E:/Ducted-Fan-SHC09-matlab；hover_distance |
| 原hover研究保存点 | 99f5da477a2bb8c1e00223197e90331a66a7b6fc，已推送；含PPID／hover研究及报告4–9 |
| WindTrace同步保存点 | 2fff100f8745d584d9b9397b67e1c1fcf98cc57f；hover已快进包含2590949与2fff100两个原提交，当前本地HEAD以git rev-parse核实 |
| main | 9918d9dba180f38a62c36f602e37993b87d0d38d，未合并研究分支 |
| F8保存点 | f8-research@28595c01bd0f0472ebb8a4cbb38d19a43775b0f1，已验收并推送；是hover保存提交的直接父提交 |
| 新四环F8 | 五方法×401–403，15/15完成，通过新宽松工程任务门槛，不称为高精度跟踪 |
| hover预检 | 501伪逆／预测PCA各1条，旧lambda_min门槛未通过；原记录保留 |
| hover标称批 | 用户后续另行批准85%滚转压力、lambda_min只报告；15条完整飞行，原状态12 completed／3 failed，独立原容差审计15/15有效 |
| 滤波调参 | 六组501粗扫12条＋两组502/503复核8条，共20/20；方法仅预测PCA与DCA |
| 待决定 | 是否接受15/15 Hz共享工程配置并另立协议／来源锁／output_tag，运行五方法×501–503；未获执行批准 |
| WindTrace状态 | 源码、导出工具和轻量证据已同步到hover；dist／DLL／缓存继续忽略，本机已有自包含EXE保留 |
| 本轮变更范围 | 快进已有提交，新增整合文档提交；数值源码、旧协议／锁、原始结果与已安装EXE不变 |
| 本轮授权 | 用户批准备份当前交接、快进同步WindTrace_merge、整合文档、验证并本地提交；不push、不改main，不开展新的仿真或UI待办实现 |

用git rev-parse HEAD、git status --short --branch及git rev-list --left-right --count origin/hover_distance...HEAD核对本地保存状态；本轮不推送，远端hover仍保留原研究保存点。本文不写自己的未来提交SHA。

## 1. 阅读顺序与入口边界

先读本文，再读[滤波报告9](codex-repo-9.md)／[滤波轻量包](examples/hover_distance_filter_tuning_20261102/README.md)、[标称报告8](codex-repo-8.md)／[标称轻量包](examples/hover_distance_formal_20261102/README.md)，最后核对对应research协议和results来源。

- [父PPID协议](research/ppid_pindi/protocol.json)固定共享控制器、传感器和估计器，默认INDI滤波仍为8/8 Hz。
- [hover预检协议](research/hover_distance/protocol.json)保留早期开发门槛，不代表后续授权正式批的最终判据。
- [标称正式协议](research/hover_distance_formal_20261102/protocol.json)记录后续“85%深度饱和压力、lambda_min只报告”的独立授权。
- [滤波协议](research/hover_distance_filter_20261102/protocol.json)固定六组、不扩网格、不按PCA排名选型、正式五方法批未授权。
- [报告5](codex-repo-5.md)保留旧速率环修正及历史单测／基线失败，不能沿用旧“全部单测通过”。

本文列入口仅为定位源码，不是运行授权。现有实验不重跑；不修改旧锁绕过来源检查，不覆盖已有output_tag。

## 2. 核心研究问题与物理边界

固定控制器、对象、参考、初态、传感器、估计器及执行器配置，只替换控制分配器，考察跟踪与执行器活动的权衡。PCA指优先级控制分配，不是主成分分析。

平台不是PX4固件、SITL、数字孪生或实机验证。采用归档PX4 ECL桥接不等于完整复刻某版PX4。CUAV误差配置、舵机时间常数和部分延迟是工程假设，尚无对应实机标定或HIL证据。

| 物理量／约定 | 事实 |
|---|---|
| 质量／重力 | 2.1 kg／9.788 m/s²；重量20.5548 N |
| 名义惯量 | diag([0.0438,0.0436,0.005006]) kg·m² |
| 分配效能 | `model.acceleration_matrix` 为名义角加速度效能B0；`model.torque_matrix`为力矩效能；不能混用单位 |
| 坐标 | 导航NED；高度10 m对应z=−10 m；SHC09原生机体前向为y，导出PX4风格时转换到FRD |
| 舵角／舵速硬限 | ±40°／600 °/s；28°仅为M4的tanh拐点，在linear映射中不生效 |
| M2b真实舵效 | [1.2,1,0.8,1,1.2,1]；分配器仍用名义模型 |
| 真实／名义舵机τ | [24,27,30,33,36,40] ms／统一30 ms；非实测标定 |
| 静态模型最大推力 | 41.70816 N是模型上界；真实最大推力未知 |
| 唯一实测推力线索 | 2100 gf @70%遥控杆量；70%不是推力或转速百分比 |
| 气动数据 | `models/shc09/reference/duct_raw.mat`、`wing_raw.mat`冻结；域外不可靠外推或改表放行 |

## 3. 代码地图：两条控制路径不能混为一谈

| 职责 | 关键位置 |
|---|---|
| 路径注册／旧入口 | `ca_setup.m`、`main.m`、`shc09_run.m`、`apps/` |
| 旧平台仿真与控制 | `platform/sim/ca_simulate.m`、`platform/modules/position_control/`、`attitude_control/`、`rate_control/` |
| 新四环研究入口 | [run_ppid_pindi.m](run_ppid_pindi.m)、[研究说明](research/ppid_pindi/README.md) |
| 新四环控制／仿真 | [ppid_control_step.m](research/ppid_pindi/ppid_control_step.m)、[ppid_simulate.m](research/ppid_pindi/ppid_simulate.m) |
| 新传感器／估计器 | `research/ppid_pindi/ppid_noise.m`、`ppid_sensor_step.m`、`ppid_estimator_init.m`；`modules/state_estimator/px4_ecl/` |
| hover工况／预检 | [run_hover_distance.m](run_hover_distance.m)、`research/hover_distance/hd_config.m`、`hd_reference.m`、`hd_metrics.m` |
| hover标称正式批 | [hdf_run.m](research/hover_distance_formal_20261102/hdf_run.m)、同目录protocol.json及审计／导出工具 |
| hover滤波研究 | [hft_run.m](research/hover_distance_filter_20261102/hft_run.m)、`hft_metrics.m`、同目录protocol.json；入口仅支持coarse/review |
| 分配注册与派发 | `allocators/registry.m`、`modules/control_allocator/ca_allocate.m`、`ca_allocator_config.m` |
| 物理／舵机 | `models/shc09/`、`effectiveness/`、`drivers/actuators/` |
| F8旧协议／驱动 | `configs/f8*_protocol*.json`、`experiments/run_f8_comparison.m`、`run_f8_pressure_study.m` |
| 离线PX4命名层 | [px4_log_view.m](analysis/px4_log_view.m)、[px4_log_export.m](analysis/px4_log_export.m)、[字段说明](docs/guides/px4_log_map.md) |
| 轻量交付／原始数据 | `examples/`可进Git；`results/`、`archive/`、构建产物留本机，不随Git推送 |

`ca_setup`只加明确列出的路径，不递归加入archive。`main(5)`仍是旧入口，不能当作新四环研究的启动方式。旧F8使用lite反馈；新研究使用ECL桥接，两者结果不能跨协议拼成同一对照批。

## 4. 共用P–PID–P–(P＋INDI)控制器

实际结构为：位置P → 速度PID → 推力／期望姿态 → 姿态P → 角速度比例P＋INDI → 分配器。这里P表示比例控制；角速度环不是“PCA控制器”，也没有另设角加速度闭环。

以下为结构公式，具体限幅、积分和坐标运输以ppid_control_step.m为准：

```text
v_sp     = v_ff + K_pos .* (p_ref - p_hat)
a_sp     = a_ff + K_vp .* (v_sp - v_hat) + K_vi .* integral - K_vd .* filtered_d(v_hat)/dt
omega_sp = omega_ff + K_att .* e_att
gamma_sp = gamma_ff + K_rate .* (omega_sp - omega_hat)
nu_h     = B0 * filtered_delta_feedback - gamma_hat
nu_c     = gamma_sp
```

`a`表示平动加速度；`gamma`（γ）表示角加速度，单位rad/s²。K_rate单位s⁻¹，因此比例反馈与角加速度前馈量纲相同。参考前馈来自规划轨迹及其解析导数，不来自对象真值或未来测量。参考机体向量经 `T=R_hat' * R_ff` 运输：`omega_ff=T*omega_ref`，`gamma_ff=T*gamma_ref-cross(omega_hat,omega_ff)`；坐标运输项不是姿态反馈误差的导数。

**优先级拆分**：nu_h只含trim／动态补偿；参考角加速度和全部速率跟踪比例反馈都在nu_c。PCA正常模式保nu_h、缩nu_c，并不等同于优先保滚转姿态：滚转误差反馈也会被缩放。不能为展示PCA优势而把参考前馈移回nu_h。

| 环路／时钟 | 增益或频率 |
|---|---|
| 位置P | [1.3,1.3,1]；25 Hz |
| 速度PID | P=[3.2,3.2,2.1]，I=[0.05,0.05,0.08]，D=[0.03,0.03,0.02]；50 Hz |
| 姿态P | [6,6,6]；100 Hz；规范化四元数误差 |
| 速率P＋INDI／分配器 | [12,12,12]；400 Hz／400 Hz |
| 对象／IMU | 800 Hz；对象在PWM事件处额外拆分积分步长 |
| ECL | 主滤波约100 Hz，输出观察器按IMU传播；更新率由日志计数核验 |
| PWM下发 | 333 Hz独立事件时钟，不能当成400 Hz下发 |
| GNSS／气压／磁计 | 5／50／50 Hz |

速度积分限幅2，输出加速度限幅时冻结本次积分；速度微分低通8 Hz，速度分量限幅3 m/s，加速度限幅4 m/s²，倾角45°，静态推力比0.9。五分配器共用这些参数。

父协议 [research/ppid_pindi/protocol.json](research/ppid_pindi/protocol.json) 的INDI H1/H2仍为8/8 Hz。仿真器从 `plan.controller.indi_output_filter_hz`（角加速度H1）和 `indi_input_filter_hz`（历史估计舵角H2）读取。调参仅覆盖这两项plan字段；没有修改父协议默认值、增益或分配器。

### 4.1 传感器与估计器的真实含义

配置面向CUAV V5 Nano＋NEO V2，采用ICM20689级单测量链的工程假设；具体启用传感器ID和固件版本未知。协议保存来源链接和assumptions，不能把设计值宣称为实际飞控测量精度。

- 陀螺噪声密度0.006 °/s/√Hz，残余偏置[0.03,−0.02,0.04] °/s，偏置游走0.001 °/s/√s。
- 加计噪声密度0.0014682 m/s²/√Hz，偏置[0.04,−0.03,0.06] m/s²，游走0.0002 m/s²/√s。
- IMU低通100 Hz、传输2.5 ms；GNSS延迟0.1 s，气压／磁计延迟0.03／0.01 s。
- GNSS每轴总σ约[2.1233,2.1233,3.5] m，白噪声σ=[0.35,0.35,0.6] m、慢变相关时间60 s，速度σ=0.08 m/s。水平σ由2.5 m CEP在各向同性高斯假设下换算，不把CEP直接当σ。
- 气压高度σ=0.25 m、偏置0.4 m；磁计σ=0.003 gauss、偏置[0.001,−0.001,0.002] gauss。

ECL先用30秒含噪静置测量对准；估计失效直接报错，不回退真值。去偏用估计偏置，角加速度由测得速率差分及H1链获得；舵角反馈由已下发指令和名义舵机模型重构，经H2滤波，不读取真实舵角。

飞前只用对准后的EKF位置与规划初点绑定一次局部任务原点，全程固定；原始导航位置另存。这是相对起飞点任务，不能据此宣称GNSS绝对定位更准。禁止事后按真值平移轨迹、动态重定中心或用真值作控制反馈。真值仅用于对象、传感器生成和离线评价。

## 5. 五分配器的接口、差异和解释边界

各插件共用名义B、估计舵角、时钟／约束及同一需求生成公式；真实τ、真实舵效、真实状态、扰动和噪声偏置不传给分配器。同种子预生成相同随机误差过程；闭环受分配器影响后，测量、估计及nu_h／nu_c数值自然分叉，这不是参考不一致，也不是逐拍强制重放同一个需求数组。

| 方法 | 实际求解含义 |
|---|---|
| DA_NS | 对nu_h+nu_c直接分配，处理幅值约束及零空间／伪逆恢复；受限时沿总需求方向处理 |
| WLS | 对总需求作带边界的加权最小二乘，含有限正则；不能无条件宣称与伪逆数学恒等 |
| DCA | 预测一个PWM周期名义舵机终点，最小化物理力矩误差；不采用预测PCA的等待／保持段结构 |
| PCA_STATIC | 在静态舵角可行集合上求nu_h+lambda*nu_c射线，再恢复舵面解 |
| PCA_PREDICTIVE | 在包含PWM等待／保持、名义动态和舵速约束的终点集合上处理同一优先级射线 |
| EXAMPLE_PINV | 公共控制器开发和接口示例；不作为研究五方法中的第六项 |

PCA的mode0为正常射线，mode1为高优先级回退，mode2为工程兜底；必须分别统计。mode1下lambda作用于高优先级射线，不能按正常跟踪缩放解读。缺失lambda不能补成1。

动态集合可能只与正lambda区间相交且不包含lambda=0。因此“nu_h单独不可达时长”不等于mode1时长；不能声称预测PCA全程能单独保持trim或已证明全局稳定性／鲁棒性。

## 6. 实验资产与当前结论

所有results路径均相对E盘根目录，属于本机重型证据，不随Git上传；examples为轻量摘要。以下各批是不同控制／估计协议，不能直接混排。

### 6.1 原F8研究：已验收、只读

- 基础批 `results/f8_v1_formal_20261101_frozen_3seeds/`：30/30完成；F8-R任务15/15通过，F8-D仅5/15通过，公共高度瓶颈不能归为某个分配器差。
- 压力开发筛选 `results/f8_pressure_screen_20261101_Rbase_v2_bounded_yaw/`：9次尝试，6完成／3气动域失败；有自适应设计与候选选择偏差，不能当成独立确认。
- 独立确认 `results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds_rerun1/F8PR-Y60-F075/`：201–203共15/15完成、通过；不要重跑。
- 确认航向RMS三种子均值：DA_NS/WLS 1.194296°，DCA 0.5150092°，PCA_STATIC 1.192514°，PCA_PREDICTIVE 0.5195776°。预测PCA与DCA航向接近但略差，实际舵速／行程约低5.5%–6.0%。
- 任务主窗lambda恒1；seed202启动有1点缩放，不满足持续激励要求。该批不能证明受限优先级保护。
- [F8轻量交付](examples/f8_comparison_20261101/README.md)：172个文件，`artifact_manifest.json`覆盖其余171个文件。旧锁和旧协议保持历史字节。

### 6.2 新四环F8：15/15宽松工程任务完成

原始目录 `results/ppid_pindi_formal_20261101_locked_v11/`，种子401–403，每条52秒，主窗[6,50]、巡航窗[10,46]。位置八字半幅3／1.5 m、周期20秒、高度10 m，偏航±60° @0.75 Hz，平滑起停；沿用M2b、τ失配，并包含继承的0.6名义偏航能力外载，不能称作电机负载。

15/15完成并通过新宽松阈值：水平RMS≤4 m、峰值≤8 m，高度RMS≤2 m、峰值≤4 m，航向RMS≤15°、峰值≤45°，倾角≤45°，气动越界0。水平RMS约2.253 m，不能称为高精度八字跟踪，也不能套用旧F8的0.5 m门槛追认通过。

该批DCA／预测PCA航向RMS约0.656411°／0.628172°；预测PCA实际舵速／行程约低14.54%／19.51%。详细域定义与逐种子数据见 [报告4](codex-repo-4.md) 及 [轻量包](examples/ppid_pindi_f8_20261101/README.md)（66个文件）。协议status和formal_lock的启动字段是跑前快照，运行进度以保存的status／completion为准，不为更新进度改写锁。

### 6.3 hover_distance：85%滚转权限深度饱和压力工况

| 配置 | 固定值 |
|---|---|
| 参考 | NED[0,0,−10] m，规划滚转／俯仰0；外环仍可为位置修正生成倾角指令 |
| 偏航 | 规划机体z轴角速度±280 °/s @0.75 Hz；0–2 s平滑起振，38–40 s平滑收振；偏航角解析积分获得 |
| 滚转干扰 | 名义滚转轴权限1.213133995 N·m的85%，幅值1.031163896 N·m；0.5 Hz正弦 |
| 时间 | 总40 s；10 s开始加载、22 s开始卸载，均0.5 s平滑；22.5 s完全卸载 |
| 评价 | 主窗[10,22)，恢复窗[22,32)；估计域和真值域分别评分 |
| 其余 | 沿用PPID控制器、M2b、τ失配、ECL、传感器和PWM时序；原F8偏航外扰已移除 |

`disturbance_type="random"`在此仅复用原生时间序列传输通道，实际装入确定性正弦，随机力矩幅值为0；不能解释为另加随机扰动。

501预检为EXAMPLE_PINV和预测PCA各1条；预测PCA主窗缩放占空比15%，lambda_min=0.00823089，未达到当时0.3–0.6目标。之后用户明确另行批准85%正式批、lambda_min仅报告不设门槛，故使用独立授权协议，不修改旧预检协议或门槛。

标称8/8 Hz正式批为 `results/hover_distance_formal_20261102_r1/`，五方法×501–503，各飞一次40秒。**完成飞行15/15，但原日志审计12 completed／3 DA_NS failed。** 三条DA_NS在完整MAT保存后被旧日志边界检查拒绝；旧检查余量写为1e−7度，分配器原配置实际为1e−7 rad≈5.73e−6度。命令最大超界约5.51／5.35／5.46e−6度，均在原有弧度容差内；真实舵角不越物理硬限，气动越界0、无发散。独立原容差审计15/15有效，原status、completion、failures和旧检查代码均未改。

主窗估计反馈域均值±三种子样本标准差：

| 方法 | 水平位置RMS m | 滚转RMS ° | 偏航角速度RMS °/s |
|---|---:|---:|---:|
| DA_NS | 0.180665 ± 0.0296505 | 3.51426 ± 0.381321 | 18.0158 ± 3.68331 |
| WLS | 0.205052 ± 0.0419231 | 4.17142 ± 0.636379 | 5.82442 ± 0.833708 |
| DCA | 0.131241 ± 0.0245787 | 1.54654 ± 0.100468 | 10.5005 ± 4.29251 |
| PCA_STATIC | 0.160016 ± 0.0150525 | 2.92443 ± 0.227853 | 48.7018 ± 15.5783 |
| PCA_PREDICTIVE | 0.13372 ± 0.0241421 | 1.72091 ± 0.137661 | 18.3335 ± 5.85176 |

解释必须成对报告：预测PCA相对DA_NS／WLS／静态PCA的估计位置与滚转改善，同时如实报告偏航代价。DCA本批位置／滚转／偏航均优于预测PCA，预测PCA实际舵速约低12.80%、行程约低15.89%，是权衡。真值水平位置RMS约1.74 m、种子标准差约0.81 m，并没有相同的位置优势；不能把估计域改善写成实际绝对定位更准。

预测PCA三种子正常缩放lambda_min分别0.00823089／0.275914／0.129507，占空比15.000%／15.8125%／14.9583%；mode1分别0.0425／0.0400／0.0350秒，mode2分别0.2225／0.1975／0.1725秒。六条PCA主窗独立几何审计共28800点，正常模式lambda最大误差1.35e−14；nu_h单独动态不可达约11.8秒，与mode1不是同一指标。

完整成对差值、真值表、恢复时间与超调定义、逐种子数据见 [报告8](codex-repo-8.md) 和 [标称轻量包](examples/hover_distance_formal_20261102/README.md)（44个文件，含六组PNG／PDF和原失败记录摘要）；[预检包](examples/hover_distance_precheck_20261102/README.md)有31个文件。501是开发种子，不能称作全部独立留出确认。

### 6.4 INDI滤波调参：推荐已形成，新正式批未启动

仅六组：8/8、10/10、12/12、15/15、12/8、8/12 Hz。15/15是用户批准的一次性网格特例，不自动扩展。501用预测PCA＋DCA粗扫12条；最优两组15/15和12/12在502、503复核8条，合计20/20。没有角加速度相位超前、没有增益／对象／参考／扰动／分配器调整。

主指标按用户固定为滚转分量0.5 Hz幅值比：`r=nu_h+J^(-1)*M_dist(t)`，取400 Hz更新点[10,22)共4800点，r的滚转傅里叶幅值除以实际平滑扰动J^(-1)M_dist的滚转幅值。三轴0.5 Hz幅值向量范数比并列报告。两方法、三种子等权；残差接近≤0.1个百分点时按实际舵速、PWM步变、行程及固定顺序择优，未按PCA排名或跟踪误差选择。

| H1/H2 Hz | 滚转残差均值 | 种子标准差（两方法均值） | 三轴范数均值 |
|---|---:|---:|---:|
| 15/15 | 4.741029% | 0.423837个百分点 | 25.555845% |
| 12/12 | 5.873630% | 0.487069个百分点 | 25.8142% |

15/15的逐种子两方法均值为501:4.669591%、502:5.196045%、503:4.357451%；六条中仅4/6低于5%。只能说平均目标达到，不能说所有种子均达标或已做泛化确认。

建议参数下预测PCA／DCA估计滚转RMS约1.287096°／1.227731°，逐种子成对差值均值＋0.059366°、样本标准差0.036057°，预测PCA仍略差；偏航速率RMS约8.708061／6.273199 °/s；实际舵速约202.413／230.550 °/s，行程约10653.9／12555.2°。这些是两方法调参数据，不是五方法调优正式结果。

独立核验20条，重建nu_h误差0，独立傅里叶比值最大差4.44e−16；8/8的501复跑与标称两方法状态最大差0。H1/H2目的在时间对齐，但相同截止频率不等于全链对齐，不等截止频率也可能是合理补偿。局部名义链在同值设置下尚有差分半拍1.25 ms和已知测量链延迟，合计相对延迟约6 ms；不是完整ECL链实测。不能仅凭残差下降断定唯一因果或完全同步。

原始证据在 `results/hover_distance_filter_{coarse,review,selection,report,audit,phase,work}_20261102_r1/`；[报告9](codex-repo-9.md) 和 [滤波轻量包](examples/hover_distance_filter_tuning_20261102/README.md)（47个文件）含tuning表、逐种子对照、推荐记录、相位诊断和审计。当前15/15仅工程建议，`configuration_frozen_for_formal=false`、`formal_batch_launched=false`；用户要求先审阅调参表再决定，不能自行启动新15条。

## 7. 已知测试失败与冻结机制

### 7.1 旧平台速率环的两行修正不能被遗漏

用户此前另行授权修改 `platform/modules/rate_control/ca_indi_rate_control.m`，将参考角加速度从v_h移到v_c；它已包含在hover保存点。新四环ppid_control_step本来就使用正确拆分，是另一条执行路径。

| 项目 | 历史修改前 | 当前文件 |
|---|---|---|
| 速率环SHA256 | `2a5eb7b3d6d7b981af3b45a7413ffe300f101952800ab2490f0f123959da9a39` | `45def4d44c397a10e6aa538191955da8952fe837f2ae947377b889338517352f` |
| 原C盘引擎指纹 | `ad9f910438cd71da2fdcc2f18c3553cc1e4b47d9b90287ef7200a032f201ef17` | 修正后 `86a39d2241d3d7b6c5d6814b7149e1ceb1f812aab530889f73efd09336ba8ec9` |
| E盘hover来源记录 | — | `d4c19f329e92fb6b0b272498837d926e33312846d32f31fc35622b6f518cb750` |

C／E盘部分基础源码仅LF／CRLF不同，E盘保留原字节，原C执行源码另归档；这解释字节指纹差异，不可改写旧来源记录掩盖。本文更新不改变数值源码或上述研究来源。

[报告5](codex-repo-5.md)记录实际测试结果，**不能声称当前全部单测通过**：

| 检查 | 当时实际结果 |
|---|---|
| `run_project_tests(false)` | 首项physics通过；第二项test_comparison第117行旧PCA行为兼容失败；后12项中止未运行 |
| `run_platform_tests` | 6/6通过 |
| `test_platform_baseline` | 首个M0案例逐位SHA不同，未通过；稀疏位置／姿态差约1e−15，总需求同输入浮点重组差约1e−14 |
| 旧PCA行为对照 | 受限时拆分变化产生实际命令差，不能全归为浮点误差或靠放宽门槛处理 |
| 原计划s201闭环回归／load0.78探索 | 测试门槛失败后未执行，不补写成完成 |
| 旧lite偏置门禁 | LitePhysicalBias约0.061 °/s >0.05 °/s，预期失败保留；lite仍experimental，不等于ECL |

论文表1Kp=[1.3,1.3,1]、Kv=[3.2,3.2,2.1]与当前比例项一致；Kq论文[5,5,4]、旧F8[8,8,8]、新四环[6,6,6]；Kω论文[9.2,9.2,7.4]、两路径均[12,12,12]。这里只报告差异，不为追求论文一致而改增益。

### 7.2 复现与证据保护

`allocation_comparison_engine(root)`覆盖platform、allocators、effectiveness、models、drivers、lib、configs、modules、compat中的MATLAB源码、ca_mismatch_protocol及气动表检查；**不是全仓指纹**，不覆盖大部分experiments、analysis和research。新研究必须另记录显式来源清单、协议SHA、ECL二进制SHA和实际输入签名。

滤波覆盖发生在plan；仅对cfg/model/ref/experiment求哈希会漏掉生效参数。滤波研究已把plan加入签名。后续日志导出必须从该次保存的plan和输入快照导出，而非重新读磁盘默认协议。

旧F8协议、numerical_sources锁、原PPID formal_lock以及全部旧结果保持原样。当前共享速率环已明确改过，所以不能声称当前全仓与历史锁完全一致。旧正式入口因来源不一致拒绝追加是应有保护，不得更新旧锁来绕过。需要新实验时另立协议／锁／output_tag并先取得对应授权。

五个轻量包的manifest均已在hover提交准备中逐文件核对，原始MAT、完整tracks／geometry、results构建目录、EXE／DLL、Python缓存没有纳入该次新增交付。Git轻量包是报告摘要，无法替代本地原始日志；仅clone不能取得全部重型证据。

MATLAB环境为R2025b（本机 `E:/Matlab/R2025b/bin/matlab.exe`）＋Optimization Toolbox；ECL桥接还依赖JVM和本机构建二进制，其SHA在来源记录。新机器需先检查构建说明和环境，不能把忽略的本机EXE当成仓库自带。`run_project_tests`会写results/validation，文档审查时不要随手运行覆盖旧验证输出。

[迁移说明](WORKSPACE_MIGRATION.md)保存了映射与冲突处理。**C盘重复工作树仍在**：应用归档工具拒绝删除当前对话绑定的primary checkout；E盘也未被接受为managed worktree。用户已授权一致后移除，但工具阻挡尚未解除，不强删、不声称完成。继续只在E盘开发。

## 8. WindTrace：已同步的配套可视化

### 8.1 分支与代码归属

WindTrace_merge从原hover保存点99f5da4分出，新增2590949交接提交及2fff100f8745d584d9b9397b67e1c1fcf98cc57f实现提交。本轮用户批准后，hover以git merge --ff-only WindTrace_merge快进到同一保存点；两个原提交及其历史完整保留，没有产生合并提交，没有rebase／cherry-pick。WindTrace_merge分支保留，main不变。

WindTrace源码现在属于hover的跟踪文件，主要为[apps/windtrace](apps/windtrace/README.md)、[MATLAB离线导出入口](analysis/export_windtrace_flight.m)、tools/export_windtrace.py、tools/audit_windtrace.py及基准／安装工具。原来源为E:/Ducted-Fan-SHC09-matlab-merge的merge/windtrace-v02@1bbdb51b278bc9ce8a50965a40808acae314c56b；选择性引入资产和界面，不覆盖控制研究数值源码，来源与许可在apps/windtrace/IMPORT_PROVENANCE.json等文件保留。

### 8.2 单飞行.wtr与只读参数

内部项目字段不改名，离线导出层映射为PX4风格topic.field、单位和坐标；这不是ULog或PX4二进制兼容。一次飞行一个windtrace.flight.v1的.wtr，控制分配方法只是manifest字段；不保留旧固定五方法bundle接口。可以同时打开多个独立日志叠加曲线，三维显示当前选中的一个。

.wtr为自包含ZIP，含manifest.json、parameters.json、flight.mat和geometry.json。保留参考／测量／估计／真值分域及原生时钟，缺失lambda不补1、不从真值伪造测量。机体转到FRD、导航仍NED；界面三维再转ENU显示，不重复机体坐标变换。完整约定见[格式说明](docs/interfaces/windtrace_flight_v1.md)。

参数表仅查看／搜索／复制，不能改日志或下发飞控。生效值来自该次保存cfg／plan和输入快照；例如controller.indi_output_filter_hz显示实际15 Hz，父协议8 Hz在scenario.parent_controller保留并注明覆盖。未知字段不能补成磁盘当前默认值。三份现有日志导出得到378／378／315个参数，unknown均0，历史执行与审计状态不改。

当前支持PPID／hover保存日志的独立离线导出；尚未把自动“一飞一交付”接到新飞行包装入口，也未补旧F8适配。不要修改冻结批驱动加钩子或重飞生成新格式。完整真实.wtr在results/windtrace_integration_20261102_r1/deliveries；[轻量包](examples/windtrace_flight_20261102/README.md)含表图、来源及合成契约夹具，不把夹具当作真实飞行证据。

### 8.3 已完成界面、回放与安装

保留原主题、黑白机体、顶栏／左抽屉／底部曲线抽屉。主画面无英文Replay水印、无真实／估计轨迹线；默认飞机＋地面网格，网格可关闭，参考轨迹可选且默认关闭。“显示状态”只有真实状态／估计状态；该选项仅改变显示，不影响控制反馈。相机默认跟随平移、保持观察角度，不随飞机偏航自转。

已实现后台读取、进度提示、坏文件报错与无数据按钮保护。打开卡片空启动420×160逻辑像素，按钮内容高44；地面网格交互裁剪已修复，拖动不再按机体边界把远裁剪从500米缩到约4.28米。普通Windows窗口与离屏均验证过。回放提供流畅／节能档、独立曲线限频及绝对时钟推进；不把离屏更新频率称为实测桌面FPS。

本机运行包仍为E:/Ducted-Fan-SHC09-matlab/apps/windtrace/dist/WindTrace/WindTrace.exe，桌面／开始菜单快捷方式已指向这里。EXE SHA256为6aa23c909e124a5dc337879d6f6ff973211db927e3b9effb37fbcdbeedf84a54；本轮没有重新打包／替换或占用桌面。dist由应用.gitignore排除，源码与轻量证据进Git，EXE／DLL／虚拟环境／缓存／重型results不进Git。新机器需按应用README准备环境并构建，不能认为clone自带本机EXE。

构建脚本隔离PATH，避免Poppler等工具的同名ICU DLL污染Qt。独立旧安装及备份保留作回滚，不再作为当前入口。阶段实现和限制见[报告10](codex-repo-10.md)、[报告11](codex-repo-11.md)、[报告12](codex-repo-12.md)、[报告13](codex-repo-13.md)。历史报告中的分支／安装位置／未提交状态是当时快照，当前以本文与Git为准。

## 9. 未完成事项与执行边界

### 9.1 hover研究：先决定共享配置，再冻结新批

1. 15/15 Hz仅达到平均滚转残差目标，502均值仍大于5%，不是所有种子通过或泛化确认。先由用户决定是否进入新的五方法比较。
2. 获批准后另立协议副本、有效plan、输入签名、显式来源SHA／引擎／ECL记录及新output_tag；不改父协议、旧锁或标称批。五方法×501–503的运行与审计口径先固定，再一次运行，失败保留、不改参重飞。
3. DA_NS原hd_check_log的1e-7度余量和旧失败记录不改写。新批独立审计需明确原1e-7 rad命令容差与真实物理硬限；不能事后放宽或删除该方法。
4. 不预设PCA赢DCA；位置／滚转与偏航代价成对报告，保留逐种子波动及执行器活动。滤波不改变滚转反馈仍在nu_c的结构，不从两方法调参外推其余三种方法。
5. 当前未做相位超前；不等截止频率可作补偿思路，但不能自行扩网格、改公共增益／对象／传感器。额外实验须另行批准。
6. 第7节旧平台测试／基线及未执行项保留，不改门槛或基线掩盖；本轮不重跑MATLAB测试。

### 9.2 WindTrace下一项：欢迎页＋手动选择最近日志【未完成】

用户确定的行为是“启动显示欢迎页，最近日志列出来，由用户点击打开”。该待办已随WindTrace交接同步到hover，但**本轮不实施**。

- 普通无文件参数启动时始终停在欢迎页，即使QSettings有recent_file也不能自动读取；欢迎页列出可识别的最近文件名与路径，由用户点击后才调用后台读取／校验。
- 保留“打开飞行日志…”入口，将当前单个recent_file兼容迁移到最近列表；失效路径明确提示，不静默换文件，不扫描／生成新实验。
- 成功打开后更新最近列表，失败可重选；未加载时继续禁用播放／时间轴／曲线／导出。显式命令行传入.wtr是主动选定文件，保留该入口。
- 保留现有审美、卡片比例、网格和参数／状态切换，不改.wtr契约或控制研究代码。

当前事实：app.py无文件、非截图启动仍调用restore_recent，main_window.py仍从QSettings读取recent_file并自动load_async；已安装EXE行为相同。不能把本文登记待办说成已改程序。

实施后要验证：预置有效历史仍停欢迎页、点击后才加载、无历史／失效路径／读取失败可恢复；更新现有自动恢复测试的预期并增加列表／点击测试，再重新打包到项目内apps路径。自动“一飞一交付”新包装入口与旧F8适配也仍未接入，不能借同步去改冻结驱动。

### 9.3 C盘迁移清理仍受阻

[迁移说明](WORKSPACE_MIGRATION.md)记录内容已校验迁入E盘，但C盘controller-ppid-p-indi工作树仍存在。Codex应用将其视为本对话primary checkout，移除受阻；没有强删，不能称清理完成。后续开发以E盘为准，不把C盘旧指针7c5c9ab解释为E盘成果未保存。

C／E部分源码仅CRLF／LF不同，E盘保留原字节，原C执行源码及冲突副本留在results/workspace_migration_20261102。原始MAT地址与来源指纹不改写。

共同约束：新增代码注释中文；不访问C:/Users/32450/Desktop/专利/control_allocation/comparison_simulation；不把PWM步变称为能耗／机械损耗；不宣称统计显著、实机优势、全局最优或完整PX4验证；不删除旧失败／数据，不改main，不自行push／打tag。

## 10. 本轮同步与验证范围（2026-11-03）

快进前将更新后的hover HANDOFF逐字节备份为results/hover_windtrace_sync_20261103_r1/HANDOFF.hover.before.md，同时保存精确补丁、WindTrace交接和before.json；备份SHA核对后，仅恢复该已备份文件以允许快进。其他未跟踪运行产物没有删除或覆盖，预检确认没有同路径冲突。随后从99f5da4快进到2fff100，再以hover研究交接为主整合本文；AGENTS和README导引同步到当前hover开发线。

核对快进差异不涉及platform／allocators／models／configs／research／tests等已有数值与协议目录；原锁、原始结果、main、WindTrace_merge指针及已安装EXE保持不变。新的整合提交只含文档，不把本机运行包纳入Git，不推送。

本轮验证WindTrace现有21项测试、文档链接／diff检查及轻量包清单。它们不是新飞行实验，也不替代第7节未通过的历史MATLAB测试。之前核对的标称15份MAT、滤波粗扫12份／复核8份及recommendation仍保持原状：configuration_frozen_for_formal=false、formal_batch_launched=false。本文引擎和数值审计误差来自已有记录，不重新计算全部MAT或调用MATLAB重算引擎。
