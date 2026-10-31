# PX4命名日志视图与导出

> 文档类型：当前。

本层是只读分析工具，输入既有log和名义model/cfg，输出一个PX4风格命名的值结构；不更改内部topic、Shc09Bus、模块接口、控制/分配/估计/物理，也不更改原日志字段。**不是PX4固件兼容层，不生成ULog/.ulg，不引入PX4固件、ECL桥接或外部四元数工具箱依赖。**

## 使用

```matlab
ca_setup;
% log需带原始time_for_metrics或time_s，时间单位为秒。
px4 = px4_log_view(log,model,cfg);
files = px4_log_export(log,'results/px4_export_new',model,cfg);
% 也可读取含L/c/r的比较缓存，或含log/cfg/model/ref的MAT。
files = px4_log_export('results/some_run/log.mat','results/px4_export_other');
```

输出固定为 `px4.mat`（变量px4）和 `px4_log.csv`（每个原控制采样时刻一行的宽表）。禁止覆盖已有同名输出。MAT路径输入支持L或log；优先使用显式model/cfg，否则读取model/m、cfg/c，必要时用完整cfg在离线侧重建名义ca_model。日志无时间列时仅取同MAT内ref/r.time_s；不从采样频率猜测原时间。直接值结构缺时间则报错。模型不足时视图保留可读raw量，对无法转换的字段输出NaN。

这里的vehicle字段表示**已记录物理状态的离线命名视图**，不冒充估计器原生uORB消息。估计和测量量另保留在shc09.measured_euler_rad、measured_omega_rad_s、estimated_position_ned、estimated_velocity_ned。meta声明姿态来源、推力基准和语义边界；不会反馈到控制器。

## 坐标与姿态

内部R为SHC09 body→NED，机体前向为y。定义C把SHC09向量变成FRD：

```matlab
C = [0 1 0; -1 0 0; 0 0 1];
R_frd_to_ned = R * C';
xyz_frd = C * xyz_shc09;
```

C*C'=I、det(C)=1。四元数为Hamilton标量在前 `[q0 q1 q2 q3]`，表示FRD body→NED；每行归一化、q0≥0。算法按最大分量分支，覆盖接近180°的姿态，不依赖Aerospace Toolbox。q0规范化可能在180°附近换号，不把相邻四元数差当角速度。

输入优先取log.rotation（N×3×3；非歧义时也接受3×3×N，单帧接受3×3），否则由log.euler_rad逐行重建R。N=3的3×3×3按N在首维解释。`px4.shc09.rotation`保存转换前R；已有矩阵不修改，无矩阵时明确标记为欧拉角重建。原R非正交时报错，缺失姿态保持NaN。

位置/速度始终NED，完全不乘C。机体系omega、alpha、力矩、推力、比力/加速度计、陀螺和磁场向量乘C，宽表行向量等价于右乘C'。

## 字段映射

|内部来源|导出字段|单位/说明|
|---|---|---|
|原时间time_for_metrics或time_s|time_s；timestamp_us；各topic.timestamp|秒；uint64微秒，round(time_s*1e6)|
|rotation或euler_rad|vehicle_attitude.q；shc09.rotation|无量纲四元数FRD→NED；原SHC09→NED矩阵|
|position_ned_m|vehicle_local_position.x/y/z；shc09.position_ned|m，NED|
|velocity_ned_m_s|vehicle_local_position.vx/vy/vz；shc09.velocity_ned|m/s，NED|
|omega_rad_s|vehicle_angular_velocity.xyz；shc09.omega|rad/s，前者FRD，后者原机体系|
|true_alpha_rad_s2|vehicle_angular_acceleration.xyz；shc09.alpha|rad/s²，前者FRD|
|v_h、v_c|shc09.v_h、shc09.v_c、shc09.alpha_total|rad/s²，原机体系的优先级分解及其和|
|model.inertia（或J）与v_h+v_c|vehicle_torque_setpoint.xyz；shc09.torque_nm|Nm，前者FRD，后者原机体系的名义换算|
|motor_rad_s、k_T0|max归一化vehicle_thrust_setpoint.xyz；shc09.motor_rad_s、thrust_n、thrust_body_n|无量纲FRD向量；rad/s、N及原机体N向量|
|motor_command_rad_s|shc09.motor_command_rad_s|rad/s，原始指令另存，不混同实际转速|
|command_rad、model.command_lower/upper|actuator_servos.control；shc09.command_rad、vane_deg|[-1,1]无量纲；原rad和等效舵角°|
|actual_delta_rad|shc09.actual_vane_deg|实际舵角°，区别于命令|
|raw_specific_force_m_s2或sensor_imu.accel|sensor_accel.xyz；shc09.accel|m/s²，测量比力，不是去重力后的NED加速度|
|raw_gyro_rad_s或sensor_imu.gyro|sensor_gyro.xyz；shc09.gyro|rad/s，原始陀螺，含日志中实际记录的偏置/地转项|
|raw_mag_gauss或sensor_mag.field|sensor_mag.xyz；shc09.mag|gauss|
|baro_height_m/baro_pressure_pa或sensor_baro.height/pressure_pa|sensor_baro.height/pressure_pa；shc09.baro_height_m/baro_pressure_pa|m/Pa，只保留原有值，不从高度反推压力|
|gnss_position_ned_m或sensor_gnss.position|shc09.gnss_position_ned；sensor_gps.lat/lon/alt|原NED m；有原点才转换为度/度/m|
|measured_euler_rad、measured_omega_rad_s、估计位置速度|同名或对应shc09原始列|原帧和原单位，无真值替换|
|aero_torque_nm、disturbance_torque_nm|同名shc09原始列|Nm，原机体系，不冒充名义setpoint|

传感器topic仅离线读取log.topic_log快照的time_s/data；从不访问活跃总线。原始IMU平面日志优先，mag与GNSS也支持表中平面字段。没有原始测量时不能拿omega、物理姿态或位置生成虚构传感器数据。

## 名义力矩与优先级

严格先在SHC09机体系中计算 `alpha_total=v_h+v_c`、`tau_shc09=J*alpha_total`，再 `tau_frd=C*tau_shc09`。J用model.inertia或model.J，单位kg·m²；弧度无量纲，因此结果是Nm。缺J时为NaN。v_h/v_c本身不是PX4 torque，二者原样保留，不能从单个tau字段恢复其优先级分解。

本任务按要求在vehicle_torque_setpoint.xyz中放**名义J换算的Nm**，不是实测气动力矩，也不包含从真实对象读取的效能矩阵。[PX4官方VehicleTorqueSetpoint](https://docs.px4.io/main/en/msg_docs/VehicleTorqueSetpoint)的xyz是归一化值；因此本文件虽用PX4命名，单位契约与固件消息有意不同，不能直接回放进PX4。

## 推力和舵机归一化

静态风扇代理 `T=k_T0*motor_rad_s²`，取实际转速日志，不伪装成记录过的原生推力指令，也不等同含来流、机翼/涵道升阻力的总气动力。系数从model.k_T0或model.parameters.Duct.k_T0读取；标准SHC09推力向量为 `[0;0;-T]`，再转FRD。

归一化基准 `T_ref=k_T0*omega_max²`：最大转速来自model.omega_m_max或model.parameters.omega_m_max，数值写入px4.meta.thrust_reference_n。标准参数k_T0=2.8964e-5、omega_max=1200，基准41.70816N。`vehicle_thrust_setpoint.xyz=C*[0;0;-T]/T_ref`，最大转速时z=-1。缺系数则raw T及PX4量NaN；只缺最大转速则raw T仍可计算，归一化字段NaN。无归一化基准时不取经验常数或臆造比例。原转速超出模型基准时保留超界归一化结果，不隐藏超界；这也是离线视图而非固件消息的边界。

舵机按 `2*(command-lower)/(upper-lower)-1`，支持非对称六维界。导出control限于[-1,1]，同时保存shc09.servo_control_unclipped与servo_out_of_range，以及原command/vane_deg，不掩盖原命令超界；缺界或非有限命令时control保持NaN。该限幅只作用于新导出值，不更改原日志或执行器。

## 时间、传感器与地理坐标

主时间必须有限、非负、严格递增；微秒计数为uint64(round(time_s*1e6))，不排序、不平移或修改原秒值。高于MHz的采样可能舍入到相同微秒，timestamp_us按非递减语义；限制整数转换不超过double的精确整数范围。MAT保留double时间原值，CSV浮点列写17位有效数字，整型时间按十进制整数写出；MATLAB读取建议VariableNamingRule='preserve'，需要整型类型时显式将timestamp列设为uint64。

平面日志imu/mag/baro/gnss_sample_time_s，或sensor_imu.sample_time_s、sensor_mag/baro/gnss.source_time_s可用时换算timestamp_sample，并保留shc09.*_sample_time_s。未知采样时间或对准段遗留的负秒不能伪造uint64：timestamp_sample=0、timestamp_sample_valid=false，原负秒/NaN仍保留；有效t=0则valid=true。快照按相同发布时间（容差1ns）对齐主行；辅助传感器只写fresh观测，不插值、不保持最后值，缺测NaN。重复发布同一时刻取最后一个新测量。源日志已去掉topic历史时，不根据配置延迟重建mag/baro/GNSS或采样时间。

GNSS只有cfg.navigation_origin=[lat_deg,lon_deg,alt_m]有限可用才转换。水平用球面方位等距反投影，R=6371000m，与归档ECL的本地球面投影约定一致；alt=origin_alt-down。它是原NED观测的地理表达，不是WGS84椭球高精度大地测量；原点海拔基准沿用cfg，不猜测椭球/海拔互换。无原点时lat/lon/alt全NaN，保留原GNSS NED。无GNSS时即使有原点也不填假坐标。

## 宽表与验证

点号列名保持原样，例如vehicle_attitude.q0…q3、vehicle_angular_velocity.xyz0…xyz2、actuator_servos.control0…control5、shc09.v_h0…v_c2。标量列不加索引；向量从0编号；shc09.rotation0…rotation8按MATLAB列主序对应矩阵(i,j)，索引=(i-1)+3*(j-1)。meta保留在MAT，不复制到每个CSV行。

执行 `ca_setup; test_px4_log_export; run_project_tests(false); test_platform_baseline;`。新测试用非对角J、接近180°姿态、稀疏带延迟观测和缺参夹具，再导出一个2秒实际日志；检查坐标/单位/时间、原输入不变、CSV表头及没有.ulg产物。只跑要求的旧14项和冻结基线，不跑60次主比较、E1/E2或完整失配阶梯。

[新测试记录](../px4_log_validation/export_final_v2_checks.json) · [旧回归记录](../px4_log_validation/regression.json) · [旧14项](../px4_log_validation/project_tests.csv) · [冻结基线](../px4_log_validation/baseline.csv)。完整MAT/CSV留在本地results，实际路径见新测试记录，不纳入Git。

姿态命名参考[PX4官方VehicleAttitude](https://docs.px4.io/main/en/msg_docs/VehicleAttitude)，推力命名参考[VehicleThrustSetpoint](https://docs.px4.io/main/en/msg_docs/VehicleThrustSetpoint)。本层不承诺与任何PX4版本的消息布局、单位、重置计数或Flight Review兼容。
