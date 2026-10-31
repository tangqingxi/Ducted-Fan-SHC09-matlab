# 公共位置外环的偏航构造修复

> 文档类型：历史。

二维位置机动揭示：旧的`b2=cross(b3,heading)`、`b1=cross(b2,b3)`将航向向量投影到推力法平面，所得欧拉偏航角在双轴倾斜时不一定等于输入偏航。8秒驻留诊断版中，输入0°偏航而期望姿态本身偏航峰值约4.66°。因此不能直接把所有相对0°偏航误差归因于分配器。

新模式`position_attitude_mode="exact_yaw"`保持期望推力方向b3，先将其旋转到给定yaw坐标：

```text
v = Rz(-yaw) * b3
roll = asin(-v_y)
pitch = atan2(v_x, v_z)
R = Rz(yaw) * Ry(pitch) * Rx(roll)
```

当前公共外环限制确保推力向上，解位于常规滚转/俯仰范围；这样同时满足`R(:,3)=b3`和期望欧拉偏航。修复不改位置/速度/姿态/角速度增益，不改推力幅值、电机命令或分配器。

`legacy_projection`完整保留旧构造；旧配置缺少该字段时也采用旧模式。新`ca_config`默认`exact_yaw`。原函数文本另存`archive/position_control_before_yaw_fix_20261030.m.txt`，旧实验的配置和源码快照不覆盖。

`test_position_attitude_yaw`用45组多偏航/双轴位置输入独立检验：新偏航误差为0，推力方向和电机指令与旧构造一致，旋转矩阵正交，单轴零偏航与旧构造一致。另一次测试还核对了原分配/闭环回归。检查数据在`results/validation/position_attitude_yaw_fix.mat`。

8秒、旧构造的fixed/turning原始数据在`results/priority_direction_L80_dwell8_20261030`，应作为问题定位数据。修正后10秒驻留数据另用`results/priority_direction_L80_dwell10_exactyaw_20261030`，两版不能直接混成单因素统计比较。
