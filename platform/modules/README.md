# 模块topic与参数

默认800Hz控制网格；“积分段”指相邻控制/PWM事件之间。模块不自己推进墙上时钟。

| 模块 | 订阅 | 发布 | 频率/触发 | 参数或固定模型 |
|---|---|---|---|---|
| sensors | sensor_imu、estimated_actuator_state | vehicle_angular_velocity、vehicle_angular_acceleration、filtered_actuator_state | 800Hz | H1/H2、延迟、可选预滤波/陷波 |
| estimator（ideal/oracle适配） | sensor_attitude、sensor_local_position | vehicle_attitude、vehicle_local_position | 800Hz | 显式ideal假设 |
| estimator（ECL导航融合） | sensor_navigation | vehicle_attitude、vehicle_local_position | 每IMU包800Hz，辅助传感器按原频率 | ECL桥接、坐标变换、地球自转固定量 |
| estimator（lite） | sensor_imu/mag/baro/gnss | vehicle_attitude、vehicle_local_position、vehicle_angular_velocity、estimator_health | IMU800Hz，GNSS5Hz，mag/baro50Hz | lite_attitude_kp/ki、位置/速度/气压时间常数、公开重力/磁场 |
| actuator_estimator | 积分接口的保持命令与上次delta_hat | estimated_actuator_state | 每积分段终点 | 白名单名义tau/限速 |
| commander | 入口arm/mode/failsafe命令 | vehicle_status | 初始化/显式调用 | 默认armed、原flight_mode；failsafe置未解锁 |
| position_control | vehicle_local_position、trajectory_setpoint | vehicle_attitude_setpoint、vehicle_thrust_setpoint | position_hold时800Hz | 位置/速度增益、姿态构造模式、固定名义质量/推力参数 |
| attitude_control | vehicle_attitude、vehicle_angular_velocity、vehicle_attitude_setpoint | vehicle_rates_setpoint | 800Hz | attitude_gain |
| rate_control | vehicle_angular_velocity/acceleration、filtered_actuator_state、vehicle_rates_setpoint | vehicle_torque_setpoint | 800Hz | rate_gain、名义B |
| control_allocator | vehicle_torque_setpoint、vehicle_thrust_setpoint、estimated_actuator_state | actuator_servos、actuator_motors、control_allocator_status | 800Hz | 注册插件、effectiveness、ca_allocator_config白名单 |
| actuator_output | actuator_servos、actuator_motors | actuator_outputs | 333Hz精确PWM边界 | 无额外滤波或延迟 |

## 消息载荷

- 姿态为3×3旋转矩阵；位置/速度是导航系NED，m、m/s，机体保留SHC09轴定义。
- 角速度`omega`为rad/s，角加速度`alpha`为rad/s²；滤波反馈舵角`delta_feedback`与模型状态`delta_hat`均rad、6×1。
- 姿态参考含`rotation/omega/alpha`，角速度参考含`omega/alpha`。位置模式保持原来的零角速度/角加速度前馈。
- `vehicle_torque_setpoint`为`v_h/v_c`角加速度需求拆分；原命名是PX4职责类比，不代表物理Nm。
- `actuator_servos`含6×1候选`command`和`source_time_s`；电机消息含`motor_command`（rad/s）。
- `actuator_outputs`含已锁存舵命令、控制源时间及同期电机命令；电机实际保持/动力学仍由sim原路径执行。
- `control_allocator_status`含`allocator`和任意`info`结构。新平台只要求清单通用字段；旧log兼容适配器继续复制历史专属字段。

## 边界与测试

原控制器函数原字节搬迁，包装只转换topic；`shc09_module_params`按职责截取配置，插件再经更严格白名单。sim才可生成测量或读取物理真值。导航生成在sim，融合模块仅收packet与观测。

最小commander不提供完整解锁检查、飞行模式管理或执行器安全门控；本轮不改变原实验输出。状态日志用于接口验证，不能解释为完整PX4安全实现。

从根目录运行`ca_setup; test_topic_chain; test_topic_logger;`；完整检查用`run_project_tests(false); run_platform_tests; test_platform_baseline;`。

## Stage5模式与隔离

`shc09_airframe("lite")`是研究候选，实际闭环偏置门禁未过；无参airframe、hover_app及底层cfg保持ideal，未完成现实默认切换。lite/ECL不发布sensor_attitude或sensor_local_position真值包，初始化只用静止传感器流，sim中的初态用于生成测量；估计器参数视图不含真实偏置/扰动/状态。

lite独占角速度topic，原测量滤波仅发布角加速度及历史舵角；不存在两个估计器共同发布。ECL保持原融合和角速度测量路径并新增健康topic。健康异常由sim断言停止，无fallback。真值姿态/位置/偏置误差只写入sim日志。

传感器缓存源时间在对准负时间和任务零时间之间统一映射；GNSS位置用测量速度外推延迟，气压用估计垂向速度外推。位置互补不是完整KF，不含导航协方差、一致性保证或真实硬件延迟鉴定。详细参数和E1/E2见[真实化报告](../../docs/estimator_realism_report.md)。
