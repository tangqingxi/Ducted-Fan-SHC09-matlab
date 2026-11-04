# 起飞型hover_distance单条预检

独立50秒变体：seed501、PCA_PREDICTIVE、H1/H2=15/15Hz，仅允许一次模拟。旧40秒参考、协议、控制器、分配器、传感器、估计器、PWM与仿真器均不改。

0–8秒五次平滑爬升至NED[0,0,-10]，提供解析位置／速度／加速度；8–10秒偏航平滑起转，48–50秒收转。12–24秒为旧85%滚转正弦压力序列整体平移2秒，偏航主窗速率相位也匹配旧序列；24–34秒恢复，之后保持高度，不降落。滚转权限仍由模型读取，不用约1.7N·m初估替换实际1.213133995N·m。

本模型从悬停配平转速和地面坐标开始，不含接地、解锁、转速爬升或地效。起飞工程检查在protocol中先固定：8秒高度误差≤1米，10–12秒高度RMS≤0.5米、垂速RMS≤0.3m/s，估计和真值分别判断。它们不修改旧协议，也不构成实机飞行许可。另检查估计器／气动／有限状态／推力和倾角饱和，失败不调参重飞。

```matlab
setenv('WINDTRACE_PYTHON','E:/Ducted-Fan-SHC09-matlab/.venv/Scripts/python.exe');
r=run_hover_distance_takeoff('20261103_r1');
```

结果写results/hover_distance_takeoff_precheck_<tag>；首要容器写logs/wtr/precheck_<tag>/PCA_PREDICTIVE_s501.wtr；快看图由tools/plot_hover_distance_takeoff.py写figures/hover_distance_takeoff_precheck_<tag>。三个目录均拒绝覆盖，不调用正式批。仅示例命令，不得重复已存在的tag。

仿真器的PWM缓冲按52秒分配；50秒需要16651个事件，小于17318容量，本变体不修改仿真器。电机指令未被旧仿真器记录，推力饱和通过离线重放原控制函数检查，并核对记录的控制信号；没有额外对象仿真。
