# 共用四环控制器与五种分配器

本目录保存共用四环控制器、传感器链及历史PPID正式研究。历史入口 `run_ppid_pindi.m` 继续绑定原协议和正式锁。2026-11-04起，后续研究明确通过根目录 `shc09_gnss_config(seed,scenario)` 加载版本化的1000 s GNSS模型；场景可选 `"f8"` 或 `"takeoff55"`。控制器、分配器、物理模型和执行器不随本次GNSS修正改变，所有新运行使用新的独立结果目录。

## 控制与前馈

```text
F8位置/速度/加速度 ─→ 位置P ─→ 速度PID ─→ 推力与期望姿态
F8姿态/角速度/角加速度 ──────────────→ 姿态P ─→ 角速度P＋INDI ─→ 分配器
传感器 → PX4 ECL → 位置/速度/姿态、去偏陀螺 ────────────────↑
```

`P` 表示比例控制。五种方法只更换分配器：DA_NS、WLS、DCA、PCA_STATIC、PCA_PREDICTIVE。伪逆 EXAMPLE_PINV 仅用于开发公共控制器，不作为正式五方法中的第六项。

| 环路 | 共同实现 | 频率 |
|---|---|---:|
| 位置 | `v_sp = v_ff + K_pos .* (p_ref - p_hat)`，速度分量限幅 | 25 Hz |
| 速度 | 加速度前馈＋P＋限幅积分－滤波的测量速度微分；输出限幅时冻结积分 | 50 Hz |
| 姿态 | 旋转矩阵/规范化四元数误差，经比例增益修正参考机体角速度 | 100 Hz |
| 角速度 | 参考角加速度＋角速度比例误差，再作 INDI 增量补偿 | 400 Hz |
| 分配 | 共同虚拟需求、名义舵效、舵角模型与 PWM 预测时序 | 400 Hz |
| 传感器/对象 | IMU 与对象积分；PWM 事件处额外拆分积分步长 | 800 Hz |
| EKF | 归档 PX4 ECL 主滤波约 100 Hz；输出观察器按 IMU 传播 | 实测计数核验 |
| PWM | 精确非整比时钟，不把 400 Hz 计算等同于 400 Hz 下发 | 333 Hz |
| GNSS / 气压 / 磁计 | 各自独立观测与延迟 | 5 / 50 / 50 Hz |

角加速度统一写为 `gamma`（γ），单位 rad/s²。轨迹参考的机体向量先转到当前估计机体系：`T = R_hat' * R_ff`，`omega_ff = T * omega_ref`，`gamma_ff = T * gamma_ref - cross(omega_hat, omega_ff)`。最后一项来自坐标运输，不是姿态反馈误差的导数。

```text
omega_sp = omega_ff + K_att .* e_att
gamma_sp = gamma_ff + K_rate .* (omega_sp - omega_hat)
nu_h = B0 * delta_feedback - gamma_hat
nu_c = gamma_sp
```

`delta_feedback` 来自已下发 PWM 和名义舵机模型重构，经与角加速度历史一致的 H2 滤波；`gamma_hat` 从去偏陀螺差分、一拍历史和 H1 滤波生成。历史父F8协议的H1/H2均为8 Hz；takeoff55场景沿用其原有15/15 Hz覆盖。本次只修改GNSS相关时间，不调整滤波。原通用测量函数中 `alpha` 字段仍表示这个角加速度估计，不修改旧函数命名。

DA_NS/WLS/DCA 接收 `nu_h + nu_c`。PCA 正常模式保留 `nu_h`，对完整 `nu_c` 缩放；预测版在名义 PWM 终点模型中使用同一需求拆分。不能只缩放比例误差而保留前馈，也不能把预测终点等式当成当前真实舵效等式。

位置/速度/姿态/角速度共十二状态的计划参考保持几何一致；速度和角速度前馈分别进入相应指令，加速度和角加速度前馈分别进入两个虚拟加速度目标。姿态内环指令可因位置误差而偏离纯轨迹姿态，日志同时保留计划参考与内部姿态指令。

## 测量、估计和任务坐标

CUAV V5 Nano＋NEO V2 为用户指定硬件；实现是单套 ICM20689 类 IMU 的误差模型假设，并非复刻实际固件。实际主用传感器、固件版本和标定日志未知，不模拟冗余切换。采用已有归档 PX4 ECL 桥接，不使用 lite，也不回退真值。ECL 上游版本及编译参数见 `build/px4_ecl/build_manifest.json` 和 `third_party/source_manifest.json`。

真值只进入对象积分、传感器生成和离线评价。控制器的参数为反馈结构、参考结构、经过裁剪的名义模型、公共控制参数和测量历史；分配器沿用名义模型接口。控制器不获得真实角加速度、真实舵角、真实零偏或真实执行器时间常数。去偏角速度使用 EKF 零偏估计。

| 测量项 | 本研究设置 | 依据类别 |
|---|---|---|
| IMU | 800 Hz；100 Hz 低通；2.5 ms 传输延迟 | 工程假设 |
| 陀螺白噪声密度 | 0.006 °/s/√Hz；离散采样标准差为密度×√(800/2) | 芯片类别设计假设，待实测 |
| 加计白噪声密度 | 0.0014682 m/s²/√Hz；同样按带宽换算 | 芯片类别设计假设，待实测 |
| 陀螺残余偏置 | [0.03, −0.02, 0.04] °/s；随机游走 0.001 °/s/√s | 工程假设 |
| 加计残余偏置 | [0.04, −0.03, 0.06] m/s²；随机游走 0.0002 m/s²/√s | 工程假设 |
| GNSS 更新/延迟 | 5 Hz；100 ms延迟 | 沿用现有测量调度、缓冲区及ECL接收设置 |
| GNSS 总位置误差标准差 | N/E每轴2.1233045007 m；D轴3.5 m | 水平采用2.5 m CEP的各向同性高斯换算；垂直为保守工程假设 |
| GNSS 白噪声标准差 | N/E每轴0.35 m；D轴0.6 m | 沿用原研究工程假设 |
| GNSS 慢变标准差 | N/E每轴2.0942592969 m；D轴3.4481879299 m | 按总方差减白噪声方差计算 |
| GNSS 慢变相关时间 | N/E/D统一1000 s | 长相关一阶Gauss–Markov工程模型，按物理秒定义 |
| GNSS 速度噪声 | N/E/D每轴σ=0.08 m/s | 沿用原协议，不将标称速度精度直接等同于σ |
| 气压 | 50 Hz，30 ms 延迟，σ=0.25 m，偏置 +0.4 m | 工程假设 |
| 磁计 | 50 Hz，10 ms 延迟，σ=0.003 gauss，偏置 [0.001,−0.001,0.002] gauss | 工程假设 |

### GNSS误差模型、参数来源与适用边界

**当前版本**为 [gnss_v2/protocol.json](gnss_v2/protocol.json)（`SHC09-GNSS-GM-v2-1000s`）。原 [protocol.json](protocol.json)、[ppid_config.m](ppid_config.m)、[ppid_noise.m](ppid_noise.m) 及 `formal_lock.json` 保持原字节：它们仍是历史60 s实验的来源。新配置通过 [gnss_v2/ppid_gnss_v2_config.m](gnss_v2/ppid_gnss_v2_config.m) 加载原场景后覆盖相关时间，并校验父协议SHA及所有误差幅值；新的后续仿真必须明确选择新入口，不向旧正式批追加结果，也不更新旧锁。

```matlab
[cfg,model,ref,plan] = shc09_gnss_config(501,"takeoff55");
experiment = ppid_noise(cfg,ref,plan);
L = ppid_simulate(cfg,model,ref,"PCA_PREDICTIVE",experiment,plan);
```

上述代码说明一次后续运行的加载链，不作为自动批量运行命令。旧正式驱动继续原锁校验，新批需独立协议、输出目录和来源记录。

对每个N/E/D轴，将位置观测误差写为独立白噪声与慢变分量之和：

$$
\epsilon_{i,k}=b_{i,k}+\sigma_{\mathrm{white},i}v_{i,k},\qquad
\sigma_{\mathrm{slow},i}=
\sqrt{\sigma_{\mathrm{total},i}^{2}-\sigma_{\mathrm{white},i}^{2}}.
$$

慢变分量采用平稳初始化的一阶Gauss–Markov过程：

$$
b_{i,k+1}=\phi b_{i,k}
+\sigma_{\mathrm{slow},i}\sqrt{1-\phi^2}\,w_{i,k},
\qquad
\phi=\exp(-\Delta t/1000).
$$

其中 $v_{i,k}$、$w_{i,k}$ 为独立标准高斯变量，三轴随机抽样逻辑和流种子保持原实现；初始慢变状态沿用 $b_{i,0}=\sigma_{\mathrm{slow},i}z_i$。因此平稳总体方差满足 $\sigma_{\mathrm{total},i}^2=\sigma_{\mathrm{slow},i}^2+\sigma_{\mathrm{white},i}^2$。

原生成器在800 Hz时间网格预生成误差，故 $\Delta t=1/800=0.00125$ s，单步 $\phi\approx0.999998750000781$；GNSS每160拍取一次观测，0.2 s间隔的相关系数为 $\phi^{160}=\exp(-0.2/1000)\approx0.999800019999$。1000 s对应800000个生成步后相关系数衰减至 $e^{-1}$，**不是1000个采样点**。GNSS更新率仍为5 Hz，不改变预生成随机数次序。一个55秒窗口远短于相关时间，其样本标准差通常不能代表上述平稳总体标准差。

参数依据如下：

- **水平总误差**：沿用本项目将NEO V2标称2.5 m按CEP解释的口径，在二维零均值、各向同性高斯假设下，以 $\sigma=2.5/\sqrt{2\ln2}$ 换算为每轴2.1233045007 m。[CUAV原资料](https://doc.cuav.net/gps/neo-series-gnss/en/neo-v2.html)及[现行页面](https://doc.cuav.net/en/gnss/neo-series/neo-v2.html)给出水平精度2.5 m；现行页面未明确CEP统计定义，因而CEP解释属于本研究采用的假设，不将产品精度直接当作实测每轴σ。
- **垂直总误差**3.5 m为保守工程假设；**白噪声幅值**[0.35,0.35,0.6] m及**速度噪声**0.08 m/s沿用原研究假设，没有根据本次飞行结果调参。
- **1000 s相关时间**参考[MathWorks gpsSensor](https://www.mathworks.com/help/uav/ref/gpssensor-system-object.html)的一阶Gauss–Markov位置噪声模型和公开小型无人机导航建模。MathWorks的 `DecayFactor` 是无量纲衰减因子，文档默认0.999，不是一个直接标为1000 s的物理参数；其1 Hz示例可对应约999.5 s的指数相关时间。本项目独立指定物理时间1000 s并按实际步长计算φ，不直接在800 Hz处套用0.999。[Beard/McLain教材配套作者代码](https://github.com/byu-magicc/mavsim_public/blob/main/mavsim_python/parameters/sensor_parameters.py)使用5 Hz GPS和 `gps_k=1/1100 s⁻¹`，支持千秒量级长相关建模；本项目采用1000 s，未照搬其误差幅值。
- **实飞ULog**可用于核对观测频率、记录间隔和测量质量，不据此宣称已辨识出NEO V2慢变标准差和相关时间。

这组参数用于**控制算法与控制分配仿真的代表性工程工况**，不代表对某台GNSS接收机定位误差的精确复现。五方法同种子共用相同随机误差过程；测量仍由各自闭环状态生成。

GNSS位置观测仍从延迟缓冲区读取：接收调用索引为k时，来源索引为 `k−round(800×0.1)=k−80`；fresh由来源索引的5 Hz节拍决定。误差诊断使用该来源时刻的真值和噪声，测量时间戳、100 ms延迟和ECL接收逻辑均不因本次模型版本改变。

静置含噪测量对准 30 s 后，在飞行前计算一次 `navigation_origin_offset = EKF_position - reference_initial_position`。飞行全程固定此值，定义起飞点附近的相对任务坐标，不使用真值、飞行后拟合或动态重置。日志保留原始 EKF 坐标和偏移，同时报告原始绝对定位误差。任务跟踪分数仍为对象真值与事先规划轨迹的差，未作事后平移。此设计不保证 GNSS 全球坐标精度。

## 历史v1.1开发、冻结与正式运行（60 s协议）

`protocol.json` 在首条开发飞行前固定了增益、误差、验收阈值和正式种子。第一次伪逆开发发现任务原点与 GNSS 导航坐标没有绑定，保留为 v1.0 的未达标证据。v1.1 仅加入上述飞行前局部任务原点，增益、噪声和阈值未改；第二条伪逆通过后再冻结正式来源。

正式批为五方法×种子 401/402/403，共 15 条，种子与开发 9301 分离。每条 52 s；主评价窗 [6,50] s，巡航窗 [10,46] s。沿用旧 F8PR-Y60-F075 的几何：北/东半幅 3/1.5 m、20 s 位置周期、高度 10 m、偏航 ±60°、巡航运动时钟 0.75 Hz、平滑起停。

执行器沿用真实 τ=[24,27,30,33,36,40] ms，名义 τ=30 ms，舵角 ±40°，舵速 600 °/s。公共增益数值、积分与限幅均见机器协议。新的宽松任务要求为水平 RMS≤4 m/峰值≤8 m，高度 RMS≤2 m/峰值≤4 m，航向 RMS≤15°/峰值≤45°，倾角≤45°且气动越界=0。它们不替代或放宽旧 F8 协议，也不等于实机飞行许可。

原F8依赖同时固定了M2b线性舵效增益[1.2,1,0.8,1,1.2,1]和0.6名义偏航能力负载：2 s加载、50 s卸载、0.5 s平滑过渡，无风/额外平动力。它们不是新控制器里可读的真实参数。轻量包effective_configurations.json从已保存正式日志导出完整实际配置，便于检查这些继承项。

正式锁 `formal_lock.json` 在正式仿真启动前写入，覆盖原数值引擎、新目录全部 MATLAB 数值源码、机器协议、原轨迹实验函数与 JSON、入口及 ECL 可执行文件。开发通过后只补强了锁覆盖和驱动的字符串比较，未改控制器、传感器、协议或对象。运行每条前检查锁，不允许覆盖既有输出目录。修改锁中源码后不能把新增运行混入本正式批。

协议的 `status` 及锁的 `formal_runs_started=false` 是各自写入时的快照，不是运行进度查询。冻结后不为更新进度而改写数值协议；实际完成状态以对应 results 批次的 `status.csv` / `completion.json` 为准。

```matlab
% 新输出后缀须唯一；不重复运行已经完成的正式批。
pilot = run_ppid_pindi('pilot','output_tag','new_pilot_tag');
ca_setup; addpath('studies/ppid_pindi');
test_ppid_pindi_results(pilot.output_dir);
% 本分支正式锁已存在，勿再次冻结或覆盖；正式批已另立唯一输出目录。
```

现有日志的后处理不运行仿真：

```matlab
ca_setup; addpath('studies/ppid_pindi');
test_ppid_pindi_results(fullfile(pwd,'results','ppid_pindi_formal_20261101_locked_v11'));
audit_ppid_pindi_priority(fullfile(pwd,'results','ppid_pindi_formal_20261101_locked_v11'));
```

```powershell
python tools/plot_ppid_pindi.py results/ppid_pindi_formal_20261101_locked_v11
```

绘图工具拒绝覆盖已存在的 figures；不需要重复绘图来使用现有图。完整 MAT 日志、100 Hz 绘图轨迹留在 results，不进入 Git。评分使用完整 800 Hz 日志，轻量交付中的降采样轨迹只供展示。不能根据三个种子宣称统计显著性、实机优势或已验证优先级保护；后者还需要实际缩放/回退激励和独立几何核验。

本批求解耗时在离线主机上计时，未把每次求解耗时作为额外物理计算延迟注入。400 Hz 更新计数不代表已通过实机实时期限验证。日志保存了估计误差、偏置、位置方差与观测更新标记，但没有完整 EKF 创新历史和逐项在线数据年龄；这两项留作后续增强，不能将设计计划中的诊断项目写成已经完成。
