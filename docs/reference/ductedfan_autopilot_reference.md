# DuctedFanUAV-Autopilot 对 F8 的参考核查

> 文档类型：代码参考审计。2026-11-01，只读远端源码；未克隆、编译、修改或运行该飞控仓库，未把 README 的功能介绍当作本地闭环验证结果。

参考仓库为[mengchaoheng/DuctedFanUAV-Autopilot](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot)，默认分支 `df-main`，本次固定提交 **[2e53639f57216f1d4b7a5b9a400464bab21e400d](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/commit/2e53639f57216f1d4b7a5b9a400464bab21e400d)**。以下链接全部指向该提交，避免以后分支变化导致参考不一致。它提供了专门的 SHC09、谐波八字、INDI 和 PCA 工程实现，比只读 PX4 通用参数更直接；不同平台的默认值和验证结论仍需分开。

## 1. 可以直接借鉴的轨迹结构

[FlightTaskFigureEight.cpp，第341–415行](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/src/modules/flight_mode_manager/tasks/FigureEight/FlightTaskFigureEight.cpp#L341)使用 `q(φ)=[A sinφ,B sin2φ]`，并明确构造：

- 位置 `p(φ)`；
- 速度 `p_φ φ_dot`；
- 加速度 `p_φφ φ_dot² + p_φ φ_ddot`。

三者同时写入轨迹设定值。参数化形式在激活时根据加速度上界约束相位角速度；另一分支按地速和路径导数求相位速度。接入段由位置平滑器输出位置、速度、加速度和 jerk，不能把接入段的 jerk 输出误当成巡航段完整高阶前馈；代码在巡航时将水平 jerk 设为 NaN。

[HarmonicTrajectory2D.hpp](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/src/lib/motion_planning/HarmonicTrajectory2D.hpp)将圆、椭圆和八字统一为谐波参考，并提供相位的一、二阶解析导数。这支持 F8 采用同一曲线生成全部参考，避免单独拼装 p/v/a 造成不一致。本地另外用九次相位速度平滑和四阶解析导数支持已有几何姿态环，属于明确标注的扩展，不声称原文件已经提供 snap 或三轴角加速度接口。

## 2. 设定值必须真正进入控制链

[PositionControl.cpp，第103–164行](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/src/modules/mc_pos_control/PositionControl/PositionControl.cpp#L103)读取轨迹 p/v/a，位置环向速度设定叠加位置误差项，速度环向加速度设定叠加反馈项。它既包含常规 PID，也包含满足反馈有效条件时的 acceleration INDI 分支；[第280–310行](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/src/modules/mc_pos_control/PositionControl/PositionControl.cpp#L280)再进行增量推力修正、倾角限制和悬停推力映射。

本地 F8 借鉴“参考前馈 + 反馈修正 + 共同限制”的结构，采用 `a_ref + Kp e_p + Kv e_v`，保持原反馈增益。它不是该项目完整的串级 PID／INDI 移植；两种结构的增益不能只按参数名直接照抄。旧近悬停路径保留，新路径由显式开关启用，并用冻结基线检查旧路径数值。

[AttitudeControl.cpp，第285–355行](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/src/modules/mc_att_control/AttitudeControl/AttitudeControl.cpp#L285)还加入了二阶姿态参考模型；[第667–699行](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/src/modules/mc_att_control/AttitudeControl/AttitudeControl.cpp#L667)分别处理命令航向速率与模型误差驱动的预期速率，后者有独立增益和限幅。这与通用 PX4 v1.16 的姿态控制路径有区别，但也不能将它解释为直接消费轨迹 snap 的三轴角加速度控制器。本地 F8 采用已有几何控制接口消费解析 ω/α，不替换姿态误差定义或五个分配算法。

## 3. SHC09 推力与遥控杆量

[22005_SHC09，第44–58行](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/ROMFS/px4fmu_common/init.d/airframes/22005_SHC09#L44)明确写出：

`u_T = THR_MDL_FAC × x² + (1−THR_MDL_FAC) × x`，其中 `u_T` 为归一化推力，`x` 是电机输出控制量；该配置令 `THR_MDL_FAC=1`。随后电机模型使用 `ω=x×ω_max` 和 `F=k_T ω²`。

|量|该仓库 SHC09 配置|当前 MATLAB 模型|
|---|---:|---:|
|质量|2.1 kg|2.1 kg|
|静止推力系数|2.937612e−5 N/(rad/s)²|2.8964e−5 N/(rad/s)²|
|最大转速|1200 rad/s|1200 rad/s|
|静止最大轴向推力|42.3016 N（配置取值）|41.70816 N|
|悬停归一化推力|0.4865（配置取值）|约0.492824（模型计算）|

差异已记录，不以参考仓库的数字覆盖本地物理参数。用户给出的“遥控器杆量约70%时推力2100 gf”仍只是单点观测，既不等于表中的 `u_T`，也不能据此确定最大推力。[该项目控制集成说明第8.2节](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/CONTROL_ALLOCATION_AND_INDI.md#82-%E8%B4%A8%E9%87%8F%E6%9C%80%E5%A4%A7%E6%8E%A8%E5%8A%9B%E4%B8%8E-hover-thrust-%E7%9A%84%E4%B8%80%E8%87%B4%E6%80%A7)要求用日志里的 `actuator_motors.control[0]` 核对质量、最大推力和悬停推力的一致性，不能用最终 PWM 或遥控杆量代替。

## 4. 执行器时延与优先级应如何借鉴

[22019_sihsim_SHC09](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/ROMFS/px4fmu_common/init.d-posix/airframes/22019_sihsim_SHC09)明确使用 `SIH_T_TAU=0.03`、`SIH_SV_TAU=0.03`，rate INDI 反馈延迟为0.022 s；它继承的 Classic 配置有另一套反馈延迟。参考工程默认的统一30 ms不能当作当前飞行器六舵机实测。本地仍保持用户批准的真实24–40 ms、估计30 ms失配假设。

[CONTROL_ALLOCATION_AND_INDI.md，第3.3节](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/CONTROL_ALLOCATION_AND_INDI.md#33-pca-priority-split)要求本周期存在显式 priority split：higher 来自 `xyz_indi_feedback`，lower 为完整需求减 higher；缺少 split 或不满足轴条件时退回 INV。[ControlAllocationLPCA.cpp](https://github.com/mengchaoheng/DuctedFanUAV-Autopilot/blob/2e53639f57216f1d4b7a5b9a400464bab21e400d/src/lib/control_allocation/control_allocation/ControlAllocationLPCA.cpp)也执行这些前置检查。因此验证 PCA 不能只看方法名称；必须记录 split、求解状态、回退和实际缩放。该项目中的 physical allocation feedback 是名义物理矩阵与最终执行器设定值的回算，不能冒称实测力矩。

文档第8节引用的实飞日志主要是 **22002／DF4**，不是当前本地 SHC09 的 F8 飞行验证；不能将其中的稳定性、反馈延迟或推力标定结论直接移植。本地不据此修改五方法、物理、气动表或已冻结门槛。

## 5. 本次落地与边界

- [F8-v1 协议](f8_protocol.md)已预先分开参考预检、数据有效性、真实倾角／推力包线、任务跟踪和优先级激励。
- 新参考真正消费速度、加速度以及名义几何 ω/α 前馈；旧控制路径和旧六组冻结基线保持数值一致。
- 外围完整 acceleration INDI、二阶姿态参考模型或反馈延迟辨识若后续纳入，需另立实验版本，不在读到参考后暗改 F8-v1。
- 本次没有运行该飞控的 SIH／SITL／HITL，没有生成 ULog，没有实机参数写入或飞行授权；F8 正式30条与五方法箱线图结果需在实际完成后单独报告。
