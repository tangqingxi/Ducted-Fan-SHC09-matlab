# Ducted-Fan-SHC09-matlab

SHC09 六舵面过驱动涵道飞行器的 MATLAB 六自由度仿真与控制分配基准。五种分配器共用位置外环、几何姿态控制、INDI、传感器链、执行器与物理模型。

需要 MATLAB 与 Optimization Toolbox；迁移验证使用 MATLAB R2025b。基础仿真不需要 Python、C++编译器或PX4固件。可选官方ECL导航桥接另需Python 3与支持C++14的g++，当前桥接在Windows验证。

## 快速运行

克隆或下载后，在MATLAB中打开仓库根目录，然后运行：

```matlab
ca_setup;
r = main(5, struct('duration_s',2, 'flight_mode',"position_hold", ...
    'initial_position_ned_m',[0;0;-10], 'position_reference_ned_m',[0;0;-10], ...
    'aero_low_speed_model',"hold_90", 'aero_extrapolation_policy',"error", ...
    'show_figures',false,'save_figures',false));
```

编号1～5分别为DA_NS、WLS、DCA、PCA_STATIC、PCA_PREDICTIVE，也支持`main("DCA", overrides)`。`main_comparison(overrides)`一次运行五方法。各次输出写入`results/`，不纳入Git。

## 结构失配基准

```matlab
study = main_mismatch_ladder;
plot_mismatch_ladder(study.output_dir);
```

默认六工况×五方法：20秒固定点、60%偏航负载、6～16秒主评价窗。M0中性、M1统一增益、M2零空间探针、M2b行空间失配、M3单舵弱化、M4非线性饱和。WLS主权重[1,1,1000]，控制器和其余算法不随工况改动。

默认全局配置保留`legacy`低速模型以兼容历史；此基准显式选择`hold_90`，V≤1m/s采用90°涵道角，1～2m/s平滑混合力，阈值外仍检查原始迎角，严格拒绝气动表外推。详见[第二轮协议](docs/vane_mismatch_round2.md)。

[轻量示例结果](examples/mismatch_round2/README.md)只含CSV与图片，包含30次正式运行汇总。原12GB级历史日志、checkpoint、构建文件和归档不随源码发布。示例结果是单种子、理想导航、匹配执行器条件下的机制检查，不代表实机精度或统计显著性；M4主要体现补偿收敛速度，主窗内PCA没有发生优先级缩减。

## 项目测试

```matlab
report = run_project_tests;
```

默认14项测试覆盖参考物理模型、五分配器、旧闭环回归、滤波/随机输入、优先级和失配协议。旧回归只使用`tests/legacy_reference`及小型`tests/fixtures`，不依赖父工程或历史结果目录。参考源码和旧校对器不自动加入运行路径。

## 可选官方ECL导航

仓库提供固定版本PX4-ECL和Matrix源码及原许可证，无需额外克隆。先验证或构建：

```powershell
python tools/build_px4_ecl.py --verify-only
# 将编译器加入PATH，或用--compiler指定本机g++路径。
python tools/build_px4_ecl.py --compiler 'C:\mingw64\bin\g++.exe'
```

```matlab
r = main_realistic(5);
report = run_project_tests(true);
```

也可先设置`CXX`环境变量，再在MATLAB运行`build_px4_ecl_bridge`。构建产物位于`build/`，不提交Git。这里是官方2024归档ECL核心的离线桥接，不是完整PX4 SITL或当前完整EKF2固件。真实tau使用异质缓变参数，控制器/分配器只得到名义模型。该导航入口的历史工况曾发生气动表外推，用于接线检查，正式比较应明确适用域策略。来源及坐标约定见[导航说明](docs/px4_ecl_reference.json)。

## 其他实验

`main_priority_pilot`：12秒短阶跃边界实验；`main_priority_direction_study`：固定/转向负载与长驻留；`main_candidate_screen`：有限轨迹筛查；`main_ws_gnc_hover`：正弦力矩扰动；`main_disturbance_benchmark`与`main_disturbance_monte_carlo`：配对随机扰动与重复试验。各协议使用不同假设，不能混合排名。

恢复A/B需要先生成源实验，发布包不携带旧的大型comparison.mat：

```matlab
source = main_priority_direction_study(struct('output_tag','restore_source', ...
    'cases',"turning", 'show_figures',false,'make_plots',false, ...
    'simulation_overrides',struct('predictive_restore_mode',"legacy_norm")));
ab = main_restore_ab(struct('source_tag','restore_source','show_figures',false));
```

## 工程结构

`models/shc09`物理对象与气动表；`drivers/actuators`执行器；`modules`测量、估计、控制和五分配器；`simulation`公共时钟；`experiments`协议；`analysis`日志和绘图；`tests`独立校对；`tools`可选构建；`examples`轻量示例；`third_party`固定依赖。

物理模型保留参考工程前向y的坐标约定。800Hz控制、333Hz PWM、±40°舵角、600°/s速率与30ms名义tau均为公开仿真假设。位置外环无轨迹速度/加速度前馈。气动表覆盖涵道0～130°、机翼−20～130°；默认record会记录外推，error会在物理子步越界时报错。源码一致性不等于实机标定。

[架构](docs/architecture.md) · [物理校对](docs/physical_model_audit.md) · [算法适配](docs/method_adaptations.md) · [第三方来源与许可](THIRD_PARTY_NOTICES.md)。历史审计文档中的本地results路径属于原研究记录，不作为此发布包的依赖。
