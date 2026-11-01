# M2b / lite 八字轨迹与十二状态比较

> 文档类型：实验指南。本协议独立于 v0.5 的20秒悬停主比较，不覆盖已有结果。

本实验让原五方法跟踪同一八字位置参考，观察静态PCA和预测PCA的跟踪表现与分配代价。只增加参考、实验入口、离线评价和绘图，不修改物理、控制器、估计器、分配器或旧协议。

## 固定协议

|项目|设置|
|---|---|
|工况 / 反馈|M2b / lite，原六自由度对象与非理想传感器|
|方法|DA_NS、WLS、DCA、PCA_STATIC、PCA_PREDICTIVE|
|种子|1:3，共15条全新轨迹；同一种子五方法共用参考和预生成随机输入|
|八字位置|NED：x=2 sin(θ) m，y=sin(2θ) m，z=-10 m|
|相位|巡航周期20秒，累计两圈；6–10秒平滑加速、10–46秒巡航、46–50秒平滑减速|
|总时长|52秒：初始悬停6秒、运动44秒、末端保持2秒|
|航向|0°|
|M2b舵效|线性映射，六通道倍率[1.2,1,0.8,1,1.2,1]，不进入名义分配模型|
|负载|保留既有0.6名义偏航能力负载，2秒加载、50秒卸载，原0.5秒平滑过渡|
|采样 / 限幅|800Hz控制、333Hz PWM、±40°硬限幅；M2b不启用tanh/28°映射|
|评价窗|主窗task=[6,50]秒，另报cruise=[10,46]、whole=[0,52]、transient=[0,6]|

相位加速使用五次平滑阶跃的积分，减速使用其互补积分；两段各贡献2秒等效相位时间，加上36秒巡航，累计40秒即两圈。端点位置、速度、加速度连续。主窗包含平滑起止，未通过裁剪尖峰追逐方法排名。

## 十二状态目标的实际含义

|状态|目标来源|单位 / 坐标|
|---|---|---|
|x、y、z|五方法共用的八字外部位置指令|m / NED|
|vx、vy、vz|上述位置参考的解析时间导数|m/s / NED|
|roll、pitch、yaw|各次运行的L.desired_euler_rad；位置环根据lite估计生成，航向给定0°|° / 原SHC09姿态约定|
|p、q、r|各次运行的L.omega_reference_rad_s；姿态环实际输出|°/s / SHC09机体系|

现有位置环为位置误差比例项加速度阻尼，不接收轨迹速度/加速度前馈。因此速度目标只供离线评价，可能出现共同的轨迹相位滞后；不能宣称已实现十二个独立状态指令的前馈跟踪。roll/pitch和p/q/r是反馈生成的目标，不是跨方法完全一致的外部目标。

新列inner_rate_command_rmse_deg_s评价真实角速度与实际角速度指令的差。旧rate_rmse_deg_s仍保留原定义，不重解释为该指标。欧拉角误差用atan2(sin(error),cos(error))处理角度环绕。真值只用于传感器生成与离线评价，不向lite新增真值反馈。

## 运行与绘图

在仓库根目录运行MATLAB，输出标签应唯一；已有目录会拒绝覆盖：

```matlab
ca_setup;
s = run_figure8_lite_comparison;
test_figure8_results(s.output_dir);
```

随后把实际s.output_dir传给绘图工具：

```powershell
python tools/plot_figure8_lite.py results/figure8_lite_M2b_实际标签
```

参考生成器为[ca_figure8_reference.m](../../experiments/ca_figure8_reference.m)，入口为[run_figure8_lite_comparison.m](../../experiments/run_figure8_lite_comparison.m)，绘图为[plot_figure8_lite.py](../../tools/plot_figure8_lite.py)。需要MATLAB现有依赖以及Python的NumPy、Matplotlib，不引入PX4固件依赖。

## 图与数据

- 十二状态RMSE箱线图：五方法各三个种子的单次运行指标，叠加全部原始点和同种子配对线。不是把时间采样作为独立试验。
- 九项效果/代价箱线图：位置、速度、姿态、角速度指令、名义共同预测力矩残差、实际/名义舵效力矩差、PWM活动、饱和、姿态估计误差。
- 加载瞬态及全程箱线图：沿用预先定义的[0,6]和[0,52]秒窗口，保留加载/卸载峰值，不用运动主窗均值掩盖瞬态。
- 静态PCA及预测PCA十二状态跟踪图：预先固定seed1，展示目标、物理真值和lite/控制反馈估计；不挑最好种子。
- 五方法平面八字轨迹和同步位置误差曲线，不做相位对齐。
- 每条完整800Hz日志保留MAT；十二状态跟踪CSV为100Hz抽取，指标始终用完整采样重算。
- summary.csv、state_metrics.csv、aggregate_metrics.csv、paired_pca_deltas.csv、comparability.csv、provenance.csv、status.csv和report.md保留结果与来源。
- tracking_phase.csv只用巡航正弦拟合诊断相位滞后；所有跟踪指标仍按原时钟计算，不作相位对齐。peak_diagnostics.csv从完整MAT日志定位各窗峰值及当时的估计误差和舵角。

早期探索曾将既有5°姿态峰值、10%饱和、2°姿态估计RMS门槛直接用于八字主窗。这个任务资格设计已撤回：近悬停门禁缺少动态任务依据，不能据其排除八字轨迹或认定方法不可比较。原CSV和当时判定保留为历史记录；新研究采用独立的[F8平滑轨迹、前馈与先验门禁协议](../reference/f8_protocol.md)。三种子只能描述本批次差异，不能据此宣称显著性或某方法全局最好；名义预测残差接近零也不代表实际力矩或轨迹误差为零。

参考与结果验证分别见[test_figure8_reference.m](../../tests/test_figure8_reference.m)和[test_figure8_results.m](../../tests/test_figure8_results.m)。既有lite物理偏置0.05°/s预期失败仍是已知限制。

## 本次已完成结果

[五方法三种子证据](../../examples/figure8_lite_M2b_3seeds/README.md)：15/15完成，完整日志重算及六组冻结基线通过。原CSV因主窗姿态跟踪误差峰值5.345026°记为stress，该旧标签不再解释为动态任务资格。预测PCA相对静态PCA的加载窗峰值均值降低27.23%，但主窗位置RMSE基本不变、PWM步变RMS约增至12.61倍；DCA的瞬态表现与预测PCA接近。

后续[更激进八字与舵机动态失配筛选](../../examples/figure8_search_20261101/README.md)保留六个首轮及两个适应性补测候选，全部为WLS/seed2探索；原门禁筛选结论已停止用于新设计，未把这些结果追认为F8验收。[优先级/论文审计](../reference/figure8_priority_audit.md)同时澄清：原运动主窗内λ均为1，原舵角预测模型完全匹配，不能据此证明受限优先级或实机优势。
