# 对象侧舵效结构失配第一阶段

本文件保留第一轮12秒/80%协议的实现记录。当前默认入口已升级为第二轮20秒/60%负载保持，详见[vane_mismatch_round2.md](vane_mismatch_round2.md)；历史结果不改写。

本阶段仅改变六自由度对象的舵面力矩。控制器、五种分配器、优先级LP及恢复算法保持原样。`ca_allocator_config`白名单不增加字段；`ca_model`不读取真实舵效配置，其名义力矩及角加速度矩阵不变。

`vane_gain_scale`默认六个1，要求六个正有限实数，本实验取0.7～1.2。`vane_deflection_map`为`linear/tanh/stall`；`vane_saturation_deg`默认28°，允许20～40°。历史配置缺字段时采用中性值。

对象先保留参考模型±40°限幅，再映射真实舵角。`C_eff=baseC*diag(gains)`，力矩为被动力矩加`C_eff*delta_eff`；中性配置沿用原乘法和相加次序。`actual_torque_matrix`为`C_eff`，非线性时它本身不是局部雅可比。六列`vane_incremental_gain`是`gains.*map_derivative`；力矩雅可比第i列等于未缩放气流效能矩阵第i列乘该值。导数针对限幅后的舵角，限幅点处不宣称对未限幅命令可微。stall超过特征角时允许局部斜率为负。

`moment_model_error_nm`是实际舵面力矩与名义线性舵面力矩之差的二范数，排除被动项和外扰；包含气流标量变化和新增舵效失配。M0动态过程中不必为零，不把这个指标单独解释成结构误差。

```matlab
% 在MATLAB中打开本仓库根目录后运行以下命令。
study = main_mismatch_ladder;
```

默认五工况×五方法，每次12秒，协议复用80%偏航负载及±2m位置阶跃。公共初态仍为名义悬停配平，不按真实参数重新配平。陀螺种子20261029、姿态种子43001、扰动种子24001；同一份参考和随机序列跨工况、方法共享。WLS保留原[1000,1000,1]权重，预测PCA保留minimum_change。位置外环仍没有轨迹速度/加速度前馈，不把阶跃误差解释为精确轨迹跟踪。

本阶段显式固定ideal导航、真实/名义tau均30ms、真实tau缓变关闭，以隔离舵效变量。既有`main_realistic`的ECL与异质缓变tau保留，本轮不进行联合实验。旧入口及已有结果不改变。

`aero_extrapolation_policy="error"`强制覆盖控制采样、物理子段起点及积分中点。任意失败即保存信息、写报告后结束，不继续后续工况、不切换record、不修改迎角。新目录必须不存在，以`mismatch_ladder_`开头。两秒M0/M2烟雾测试也使用严格门禁。

输出包括cases/summary/status/relative_to_M0、公共输入、源码快照、每方法MAT和控制/PWM CSV。失败不生成虚构完整日志。主窗4～10秒，whole为全时长；烟雾测试均为0～2秒。饱和率按任一PWM命令触及公共限幅统计。非PCA的mode不解释为优先级回退。

`test_vane_mismatch`验证40个参考状态、局部导数、限幅顺序、名义B、白名单及非法配置；`test_mismatch_runner`检查两秒十次运行、文件/列/配对/零越界。四项既有回归在完整源码隔离副本执行，避免其固定路径重写旧results。

若严格物理门禁失败，验收未通过，不能给出完整M0～M4排名。后续执行器二阶/死区/命令延迟与多种子统计留待确认，不在本阶段实现。
