# 平台职责与PX4概念映射

这里是MATLAB单线程平台化重构，不是PX4移植、固件控制器替换、SITL或数字孪生。名称相似表示职责边界相似，不代表消息格式或执行语义完全一致。

| PX4概念 | 本项目位置 | 具备的行为 | 边界 |
|---|---|---|---|
| uORB | platform/msg/Shc09Bus | 最新样本、仿真时间、发布序号、订阅 | 无异步队列、线程、DDS或固件消息布局 |
| work queue/scheduler | platform/scheduler | 整数频率事件、rate group、优先级；PWM积分边界 | 控制网格沿用旧参考循环，无墙上实时执行 |
| parameters | platform/params | declare/get/set/validate/log和cfg适配 | 仿真取快照，无自动在途热更新 |
| commander | platform/modules/commander | arm/mode/failsafe最小状态 | 无完整解锁检查和执行器安全门控 |
| sensors / EKF2 | sensors、estimator及ECL桥接 | 测量滤波；可选固定官方归档ECL融合 | 默认ideal导航；非当前完整EKF2固件，需JVM |
| position/attitude/rate | platform/modules对应目录 | 原位置环、几何姿态控制和INDI | 控制律不是PX4原实现 |
| control_allocator | platform/modules/control_allocator | 名义上下文、显式插件分派、状态发布 | 无固件参数元数据或在线混控重配置 |
| actuator effectiveness | effectiveness | 原SHC09与hover_linear名义B/界/配平/tau | 不辨识实际气流/舵效 |
| actuator output | platform/modules/actuator_output | 333Hz候选命令锁存topic | 无硬件PWM波形或驱动总线 |
| logger | platform/logger及旧analysis | topic历史和兼容CSV/MAT | 不是ULog协议；真值另由sim日志保存 |
| simulator interface | platform/sim | 唯一真实状态、传感器生成、事件间原物理积分 | 无MAVLink/SITL/HIL通讯 |

## 单位和坐标必须显式转换

SHC09保留来源工程前向y、侧向x、轴向z坐标；导航位置是NED。ECL边界已有明确SHC09到FRD变换，不能据目录名假定整个飞行器改成PX4 FRD。

`vehicle_torque_setpoint`在这里携带`v_h/v_c`（rad/s²角加速度），`vehicle_thrust_setpoint`携带电机rad/s命令，不与PX4固件的Nm/归一化推力消息互换。未来固件接入要重新审核坐标、单位、时钟、估计延迟和解锁安全条件。

## 当前时序

800Hz控制产生候选舵命令，333Hz精确PWM事件锁存；同刻先控制后锁存，物理与名义舵机按事件间隔推进。rate-group通用接口具有确定优先级测试；实际仿真保留原控制参考循环以保持数值，调用scheduler划分PWM边界。求解桌面耗时没有进入对象延迟。

更多见[架构](architecture.md)、[平台](../platform/README.md)及[模块topic表](../platform/modules/README.md)。
