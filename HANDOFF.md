# HANDOFF — SHC09 控制分配研究与 WindTrace 集成交接

更新日期：2026-11-03（Asia/Shanghai）。本文件在 `WindTrace_merge` 上更新，基于已推送的 `hover_distance@99f5da477a2bb8c1e00223197e90331a66a7b6fc`。

本文是当前状态与下一阶段任务的交接入口。根目录 AGENTS.md、README.md、WORKSPACE_MIGRATION.md 以及报告4–9保留了不同时刻的快照；其中“hover只完成预检”“hover未提交”“C盘副本已移除”等说法不能当作当前事实。当前进度以本文、Git现场状态和各批次原始证据为准。旧版本可在Git历史中查阅，不改写旧实验记录。

> **最新停点（2026-11-03）**：WindTrace现有实现、布局／网格修复与项目内安装已完成，本轮获用户授权保存并推送至WindTrace_merge。**“启动显示欢迎页，列出最近日志，由用户点击打开”尚未实现**，是下一项明确待办；当前源码及已安装EXE仍会自动恢复最近日志。本轮只更新任务与状态，不修改启动逻辑、不重新打包。见第16节。

## 1. 当前状态与授权范围

| 项目 | 当前事实 |
|---|---|
| 项目 | SHC09六舵面／三轴力矩的MATLAB离线控制分配比较平台 |
| 工作目录 | `E:/Ducted-Fan-SHC09-matlab`；后续开发与报告均在此进行 |
| 当前开发分支 | `WindTrace_merge`，从已推送的hover提交创建；现有WindTrace实现随本轮保存，提交／远端准确值以Git现场核对，不在本文写自引用SHA |
| hover保存点 | `hover_distance@99f5da477a2bb8c1e00223197e90331a66a7b6fc`，已推送到origin；252个文件，含研究源码、报告和轻量证据 |
| F8保存点 | `f8-research@28595c01bd0f0472ebb8a4cbb38d19a43775b0f1`，已推送；F8交付已验收 |
| main | `9918d9dba180f38a62c36f602e37993b87d0d38d`，未修改、未合并研究分支 |
| PPID-PINDI八字 | 401–403，五方法15/15完成，通过新协议的宽松工程任务要求 |
| hover标称8/8 Hz批 | 15/15完成40秒飞行；原驱动12 completed／3 failed；独立原容差审计15/15有效，失败记录保留 |
| hover滤波调参 | 六组501粗扫12条＋两组502/503复核8条，20/20完成；建议H1/H2=15/15 Hz |
| 调优后的五方法15条 | **尚未运行，尚未冻结为新正式协议，等待用户另行决定** |
| WindTrace集成 | 已实现单飞行.wtr导出／读取、原版抽屉界面、参数搜索、布局／网格修复及项目内EXE；源码21项／EXE六项检查通过，见报告10–13 |
| 下一项WindTrace任务 | **未完成**：无显式文件参数启动时显示欢迎页及最近日志列表，由用户点击后才加载；当前仍自动恢复最近日志，详见第16节 |
| 当前授权范围 | 用户要求将上述新启动行为登记为待办、更新交接，并提交／push当前已完成的WindTrace内容与文档到WindTrace_merge；本轮不实现待办、不重新打包，不运行仿真、不改数值源码／旧锁／main、不打tag |

远端为 `https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab.git`。本文不写自己的未来提交SHA；提交／推送后的准确值使用 `git rev-parse HEAD`、`git status --short --branch` 和 `git ls-remote --heads origin refs/heads/WindTrace_merge` 核实。

历史关系须分清：main是F8研究线的祖先；当前hover保存提交的直接父提交是F8保存点28595c0。PPID/hover内容从原C盘工作树校验迁入E盘后在hover提交中保存，不应把旧C盘分支指针7c5c9ab解释为最新hover成果未保存。另一个WindTrace源仓库的旧基底也不是当前控制研究线。

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

滤波覆盖发生在plan；仅对cfg/model/ref/experiment求哈希会漏掉生效参数。滤波研究已把plan加入签名。未来.wtr必须从该次保存的plan和输入快照导出，而非重新读磁盘默认协议。

旧F8协议、numerical_sources锁、原PPID formal_lock以及全部旧结果保持原样。当前共享速率环已明确改过，所以不能声称当前全仓与历史锁完全一致。旧正式入口因来源不一致拒绝追加是应有保护，不得更新旧锁来绕过。需要新实验时另立协议／锁／output_tag并先取得对应授权。

五个轻量包的manifest均已在hover提交准备中逐文件核对，原始MAT、完整tracks／geometry、results构建目录、EXE／DLL、Python缓存没有纳入该次新增交付。Git轻量包是报告摘要，无法替代本地原始日志；仅clone不能取得全部重型证据。

MATLAB环境为R2025b（本机 `E:/Matlab/R2025b/bin/matlab.exe`）＋Optimization Toolbox；ECL桥接还依赖JVM和本机构建二进制，其SHA在来源记录。新机器需先检查构建说明和环境，不能把忽略的本机EXE当成仓库自带。`run_project_tests`会写results/validation，文档审查时不要随手运行覆盖旧验证输出。

[迁移说明](WORKSPACE_MIGRATION.md)保存了映射与冲突处理。**C盘重复工作树仍在**：应用归档工具拒绝删除当前对话绑定的primary checkout；E盘也未被接受为managed worktree。用户已授权一致后移除，但工具阻挡尚未解除，不强删、不声称完成。继续只在E盘开发。

## 8. WindTrace源项目：可复用资产和不能照搬的部分

源仓库 `E:/Ducted-Fan-SHC09-matlab-merge`，只读检查时为 `merge/windtrace-v02@1bbdb51b278bc9ce8a50965a40808acae314c56b`，工作区干净。它基于旧F8提交7c5c9ab，不含当前PPID／hover研究。

可复用内容为 `apps/windtrace/`（PySide6、PyVista／VTK、PyQtGraph的三维、曲线和时间轴）、几何及相关测试／许可。另有 `analysis/export_windtrace_bundle.m`、`export_windtrace_study.m` 和旧接口文档可作适配参考。历史smoke／测试记录只代表当时源项目，不代表本分支已复验。

旧契约为 `windtrace.study.v1`、`.wtr.mat`，一个case／mode／seed包含固定五方法。旧导出器依赖旧日志命名及 `_ned_m`／`_rad` 字段；当前hover日志是L.position、L.euler、L.actual_delta等，不能直接接上。旧GUI“参数”抽屉主要是显示／场景设置，并不是飞行生效参数浏览器。

**用户明确不保留旧多方法bundle兼容。** 集成时移植所需应用资产和适配代码，不把源仓库旧AGENTS／README／HANDOFF、控制器、对象、协议或锁覆盖到当前分支。`WindTrace_merge`只是分支名，当前没有执行Git merge、rebase或cherry-pick；后续选择性引入也须保持研究代码和冻结资产不变。

## 9. 已确认的WindTrace／.wtr方案

### 9.1 对外只有一种单飞行交付物

一次轨迹运行产生一个自包含 `.wtr`，可称WindTrace Flight Log。分配方法只是该次运行元数据字段，单文件不捆绑五方法、不强制固定方法枚举；五方法比较通过加载多个独立.wtr实现。旧内部MAT继续作为研究证据，但不作为新的用户侧交付格式；不需要兼容旧bundle。

项目内部保持自己的字段、控制总线和数值实现。**导出层映射PX4风格字段；WindTrace按该导出契约显示。** 这不是ULog／`.ulg`二进制，不承诺PX4原生uORB、固件参数名或Flight Review直接兼容。

已实现契约名 `windtrace.flight.v1`，使用ZIP容器；完整定义见 [格式契约](docs/interfaces/windtrace_flight_v1.md)：

```text
<run_id>.wtr
  manifest.json     格式版本、运行标识、方法／种子／工况、执行与审计状态、来源及成员哈希
  parameters.json   此次飞行实际生效参数、类型／单位／来源和覆盖信息
  flight.mat        按topic组织的数值、原时间轴、参考／估计／测量／真值与诊断
  geometry.json     回放所用几何、V1–V6编号、坐标约定及来源
```

manifest应包含源日志SHA、协议／显式来源SHA、引擎指纹、输入签名（含生效plan）、导出器版本和成员完整性信息。执行状态与审计状态分开：例如完整40秒但旧审计failed的DA_NS，应同时保存这两个事实，不替换成成功，也不丢弃完整轨迹。没有日志的运行失败不能伪造时间序列。

### 9.2 字段命名、坐标和时间契约

已有 [PX4离线视图](docs/guides/px4_log_map.md) 可复用转换数学；它目前支持旧日志并输出px4.mat／CSV，尚不是新.wtr。旧视图的部分vehicle_*映射物理真值，扭矩字段采用Nm等项目语义，不能原封不动宣称是PX4原生估计topic或归一化固件指令。

新适配应明确以下原则：

| 数据域 | 建议映射／要求 |
|---|---|
| 估计位置／姿态 | `vehicle_local_position`、`vehicle_attitude`；每字段声明实际源和语义 |
| 规划目标 | `trajectory_setpoint`及明确的姿态／速率／角加速度参考字段，不能与反馈合并 |
| 角速度／测量 | `vehicle_angular_velocity`等；测量、去偏估计及物理真值分开 |
| 真值 | 独立 `*_groundtruth` 或明确真值命名空间，仅用于回放／评价 |
| 执行器 | `actuator_servos`归一化命令；原命令、PWM保持命令、估计与真实舵角分别保存 |
| 项目诊断 | `shc09_indi.v_h/v_c`、`shc09_allocation.lambda/mode`等扩展；不冒充不存在的PX4字段 |
| 单位 | 明确rad、rad/s、rad/s²、m、N·m等；显示转度时由单位驱动，不能靠字段名猜测 |
| 时间 | 保留原生时间轴和更新标志；800 Hz状态、400 Hz控制、333 Hz PWM等不强制压成一个伪同步时钟 |

SHC09机体到FRD使用 `C=[0,1,0;-1,0,0;0,0,1]`：向量乘C，姿态 `R_frd_to_ned=R_shc_to_ned*C'`；位置／速度NED不变。四元数应声明Hamilton、wxyz和旋转方向。转换集中在导出层，Viewer不得再次隐式变换。几何也要遵循同一坐标约定。

时间戳保存原始采样／更新时间信息，微秒整数时间须说明相对起点和精度，不能伪装绝对UTC。未记录的传感器topic标为缺失，不用真值合成；缺失lambda不填1。旧日志被保持到800 Hz记录的控制量，应利用control_updated提取真实400 Hz更新点，PWM用独立pwm_time；若源数据没有某观测时间，不推造新的采样精度。

### 9.3 可搜索、只读的飞行参数表

WindTrace新增QGC风格的参数浏览表，可按完整字段路径／字段名搜索，展示该次飞行的**实际生效值**、类型、单位、来源／覆盖信息，并允许复制；不提供修改、保存回写或向飞控下发。

保留项目参数原名和完整层次，例如 `controller.indi_output_filter_hz`；无需伪造PX4固件参数编号。表应覆盖实际cfg、plan.controller、传感器、估计器、参考、扰动、执行器和分配配置，区分真实对象／名义模型参数以及工程假设。包含真值模型参数的交付文件是离线证据，不改变在线分配器可见接口。

参数快照从该次保存的输入／日志生成，合并并标明默认与覆盖来源。例如父协议为8 Hz而调参plan实际为15 Hz，表必须显示生效15 Hz，同时保留默认8 Hz与覆盖来源，不能用查看时磁盘protocol替换。旧日志无法恢复的参数标为未知，并报告缺失来源，不能补成看似完整的默认值。

## 10. 后续实施顺序与验收

本节保留原实施顺序。2026-11-02用户随后批准推进：步骤1–7及步骤8的轻量样例已实现并验证；冻结驱动未补钩子，未来新飞行包装入口自动导出尚未接入。详细实现、测试与限制见 [报告10](codex-repo-10.md)。未运行新飞行；实现完成时未提交，2026-11-03后续保存授权与最新待办见第16节。

1. 在WindTrace_merge固定单飞行.wtr契约，写字段映射、单位／坐标／时间／参数来源规则；明确执行与审计两层状态。
2. 从源项目选择性引入WindTrace应用、必要几何和测试，记录源提交及许可；删除新入口对旧study／五方法bundle的依赖，不迁入旧研究文档和数值文件。
3. 编写独立后处理导出适配，优先支持当前PPID／hover保存日志；结合现有px4_log_view转换逻辑，保证导出不改变任何仿真源码、协议或原始MAT。原始F8如需支持，另写旧字段适配。
4. 编写.wtr读取／校验和单飞行数据模型，GUI、CLI和索引以run_id为单位；一次可打开多个独立日志，但文件本身只有一次飞行。
5. 接入三维／曲线／时间轴及真实／估计状态切换，增加只读参数表与搜索；UI不重复坐标转换，不以方法数量决定能否打开。
6. 使用现有PPID、标称hover和滤波日志验证：参数覆盖8→15、异步时钟、FRD姿态／几何、缺失字段、非PCA缺失lambda、DA_NS完整飞行但旧审计失败；校验输入输出哈希和原始文件未变。坏schema／缺成员／哈希错／越界时间应有明确错误。
7. 做有针对性的导出／读取测试及真实GUI打开、搜索、只读核验；记录本分支实际测试结果，不引用源项目旧测试数冒充本次通过。
8. 在新的输出目录生成样例.wtr与说明，只提交适量轻量样例／测试夹具和源码；原始MAT与大型交付留results。未来自动“一飞一交付”挂在新研究包装入口运行完成之后，不修改冻结驱动补钩子。

验收以单日志可独立打开、自包含、参数可搜索且等于生效输入、参考／估计／真值无混淆、时间／坐标转换正确、原证据哈希不变为准。上述集成不需要重飞现有实验。新的五方法15/15 Hz正式批是另一项待批准任务，不能借可视化集成启动。

## 11. 开发硬约束与交接阅读顺序

- 后续只在E盘当前工作目录开发；代码注释全部中文。禁止递归把archive加入MATLAB路径。
- main、旧F8／PPID／hover协议与锁、旧results和archive只读；不删除历史失败、不覆盖已有output_tag，不自动改门禁或基线。
- 不把PWM步变叫作能耗／机械损耗；不把三种子差异叫统计显著、实机优势或全局最优。调参结论写“工程调参配置下的比较”，不是泛化确认。
- 不把“保trim”说成“优先保滚转”；不把mode1／mode2并入正常lambda缩放；DCA排序不预设。
- 不访问 `C:/Users/32450/Desktop/专利/control_allocation/comparison_simulation`。
- 当前用户已授权hover及WindTrace_merge本次保存／推送；该授权不自动涵盖未来仿真、旧锁修改、合并main、打tag或清理C盘受阻工作树。

阅读顺序：本文 → [PPID结构说明](research/ppid_pindi/README.md)与保存协议 → [hover报告8](codex-repo-8.md) → [滤波报告9](codex-repo-9.md) → 对应examples表／manifest；追溯旧行为修正看 [报告5](codex-repo-5.md)，追溯原F8看 [F8交付](examples/f8_comparison_20261101/README.md)。开发前再核对Git现场状态，避免把任何历史快照当作新的运行授权。

## 12. WindTrace实现快照（2026-11-02，保存授权见第16节）

当前在WindTrace_merge的未提交实现：`apps/windtrace/`、`analysis/export_windtrace_flight.m`、`tools/export_windtrace.py`和`tools/audit_windtrace.py`。使用现有三份日志完成导出和独立核验，不重飞；完整交付在 `results/windtrace_integration_20261102_r1/deliveries/`，轻量包在 [examples/windtrace_flight_20261102](examples/windtrace_flight_20261102/README.md)。参数378／378／315项，unknown均0，保留历史执行与审计状态。

界面按用户审美要求恢复原版主题、52px顶栏、左侧抽屉、底部曲线抽屉和48px时间轴，默认三维高度约89%；新增参数表从抽屉打开。无常驻标签页。复用原shell/theme、logo及GLB资产，记录来源与许可。新后处理不会让旧测试失败自动消失，不重置旧门禁。

本轮桌面核验曾短暂使用Computer Use，随后按用户要求释放会话；用户允许必要时短暂打开再关闭，但不得持续占用鼠标。最后的界面验证使用离屏Qt／VTK。旧F8字段适配和冻结批驱动自动挂钩未实施；EXE后续已打包原位安装，见报告11；这不影响现有PPID／hover日志手工一飞一交付。

用户后续界面定调已落实：主画面无英文Replay水印、无真实／估计轨迹线；默认飞机＋地面网格，网格可关闭，参考轨迹可选且默认关闭。“显示状态”切换真实状态／估计状态，规划参考不作为第三种飞机状态。回放提供流畅／节能档、独立限频曲线和真实时钟推进；后台测试见报告10，不能把离屏更新频率称作桌面实测FPS。

## 13. EXE安装交接（2026-11-02）

用户批准打包并覆盖旧版，已安装至 `E:/Ducted-Fan-SHC09-app/dist/WindTrace/WindTrace.exe`，桌面／开始菜单快捷方式沿用。旧版备份为同级 `WindTrace_backup_20261102_r4`。构建与安装证据在 `results/windtrace_packaging_20261102_r4/`，详见 [报告11](codex-repo-11.md)。源码16/16测试与EXE六项检查通过，安装后原路径再校验通过。相机默认跟随平移、保持角度，可关闭；修正了移动后裁剪造成机体不可见的问题。此功能是显示改动，不改实验数据。未提交／推送。

## 14. 启动与加载修复（2026-11-02）

用户反馈首次打开是空白界面。截图没有已载入日志的信息；此前无日志状态缺少引导，且播放仍可点。现增加居中的打开入口，无数据时禁用播放／时间轴／曲线／导出；读取与校验放后台线程，Qt／VTK仍在主线程更新；加载有提示、失败可见且可重选，不伪造飞行数据。新打开日志自动成为当前三维显示；重载会替换同run_id内容；正常启动恢复最近仍存在的成功日志，记录仅存在本机QSettings。

实际普通Windows窗口验证进一步捕获 `QtInteractor has no attribute 'off_screen'`。此前离屏Plotter具有该属性，测试没有暴露QtInteractor差异，异常可能中断交互打开流程；已改为使用视图自身明确选择的渲染模式。新EXE六项检查明确断言last_error为空，并实查普通窗口截图中机体与网格可见。源码20/20通过。

最终构建为 `results/windtrace_startup_fix_20261102_build2/`，测试、截图、基底1358项核对在 `results/windtrace_startup_fix_20261102_r1/`。build1失败证据保留，未用于安装。原安装路径已更新，备份同级 `WindTrace_backup_20261102_startup_fix_r1`；EXE SHA256为 `1fa91bfb57534904b935e25b6a95fcd8eccca0c4652184d9117572266be160c8`。详见 [报告12](codex-repo-12.md)。不改数值源码、旧协议／锁和原始数据，不运行仿真，不提交／推送。

## 15. 卡片比例、交互网格与项目内运行包（2026-11-03）

当前唯一推荐入口为 `E:/Ducted-Fan-SHC09-matlab/apps/windtrace/dist/WindTrace/WindTrace.exe`。源码一直在apps/windtrace；此前EXE保留旧独立安装路径是为了沿用快捷方式，并不代表源码未导入。用户要求统一在apps下后，已安装项目内自包含运行包，桌面／开始菜单及旧应用目录的3个既有快捷方式全部改指此处，原.lnk备份保留在本轮results。旧独立安装和旧版本备份未删除，只作回滚。应用.gitignore明确排除dist和本地.venv；不把2436个EXE／依赖文件纳入Git。本节功能在修复完成时尚未提交，后续用户已授权保存／push，最新停点见第16节。

打开卡片从440×250逻辑像素改为宽420、高随内容（空启动160），按钮内容高44（含边框实测46），去掉大块底部留白，加载／错误内容改变时重新居中。配色与原抽屉布局保持。

网格问题已用VTK内部左键事件复现：交互器按机体边界将裁剪区间从0.05–500米收缩到约2.9468–4.28295米，网格actor仍开启却被裁掉。现关闭此自动收缩，用场景范围维护远裁剪面（至少500米，相机拉远时扩展），网格仍不参与机体取景边界，保留原机体视角及网格开关。源码21/21，新增旋转后网格渲染像素差、拉远与回到机体／总览检查；EXE六项检查含普通Windows窗口内部旋转并目视确认网格可见，未控制桌面鼠标。

最终构建 `results/windtrace_scene_fix_20261103_build1/`；本轮测试、裁剪复现、截图、安装／快捷方式记录见 `results/windtrace_scene_fix_20261103_r1/` 和build1/installation.json。EXE SHA256为 `6aa23c909e124a5dc337879d6f6ff973211db927e3b9effb37fbcdbeedf84a54`。详见 [报告13](codex-repo-13.md)。仅修改查看器／部署相关内容，不动数值源码、旧协议／锁和原始实验结果。

## 16. 当前交接与下一项未完成任务（2026-11-03）

### 16.1 已完成与本轮保存范围

现有单飞行.wtr格式、离线导出／独立审计、三维／曲线、只读参数搜索、真实／估计显示、原版主题、相机跟随与裁剪修复、后台读取与错误提示、Windows打包／安装已完成。源码在apps/windtrace；后处理在analysis/export_windtrace_flight.m及tools；格式说明在docs/interfaces；轻量证据在examples/windtrace_flight_20261102；阶段报告10–13记录各阶段实际验证和当时限制。

用户本轮明确要求更新交接并push。因此保存上述已完成源码、文档与轻量证据到WindTrace_merge，不把EXE／DLL、dist、虚拟环境、Python缓存、results构建或原始MAT／完整真实.wtr纳入Git。运行包是本机生成物，clone后需按应用README构建。既有三份完整日志交付与安装路径仍留在本机。没有合并main、重飞或改变实验协议。准确提交与推送状态以git status／rev-parse和origin对应分支核对。

### 16.2 下一项任务：欢迎页＋手动选择最近日志【未完成】

**用户确定的行为**：启动显示欢迎页，最近日志列出来，由用户点击打开。

- 普通双击EXE、无显式文件参数启动时，始终停在欢迎页；即使QSettings已有recent_file，也不能自动读取或切到三维。
- 欢迎页保留“打开飞行日志…”入口，同时列出本机最近打开的日志，提供可识别的文件名与路径；用户点击条目后才走已有后台读取、校验和三维准备流程。
- 保留最近文件记录的便利；当前只有单个recent_file，需要兼容迁移为最近列表。失效路径应有明确提示，不静默加载另一份日志，不扫描或生成新实验数据。
- 手动打开成功后更新最近列表；失败显示原因并允许重选。无已加载日志时，播放／时间轴／曲线／导出继续禁用。
- 显式命令行传入.wtr是用户主动选定文件，保留该入口；不把无参数启动的最近记录当作显式输入。
- 保留已经认可的卡片比例、抽屉布局、飞机配色、网格开关与真实／估计显示；不修改.wtr契约、控制器、分配器或实验数据。

**当前事实**：源码app.py仍在无文件、非截图启动时调用restore_recent；main_window.py仍从QSettings读取recent_file并自动load_async。已安装EXE行为相同，SHA仍为第15节的6aa23c90…，没有因本轮记录待办而更新。第14节和报告12中“自动恢复最近日志”描述的是已经实现的旧行为，不是新的目标。

**实施后的验收**：预置有效recent_file／最近列表并普通启动，确认欢迎页可见、三维未加载、播放禁用；点击最近项后才成功加载；无历史／路径失效／读取失败均可恢复；已有参数搜索、坐标与相机网格回归仍通过。届时需要更新现有“自动恢复最近日志”测试的预期、增加列表与点击测试，再重新打包到项目内apps路径并核验快捷方式。**本轮不实施、不把任务标为完成。**

其他仍未完成事项保持原边界：新飞行包装入口自动“一飞一交付”、旧F8字段适配未接入；新15/15Hz五方法正式批未获启动批准；C盘受阻重复工作树尚未移除。不得借本次push开展这些工作。
