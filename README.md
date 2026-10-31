# Ducted-Fan-SHC09-matlab

> 文档类型：当前。发布基线为 v0.5.0。

这是一个 SHC09 六舵面涵道风扇的 MATLAB 仿真平台，用同一套模型比较五种控制分配器。

A MATLAB benchmark for comparing five control allocators on the same SHC09 simulation.

## 当前能做什么

- M0/M2b 两个工况的 ideal/lite 都已通过现有比较门禁。
- ideal 是真值透传模式，用作理想参考上界（oracle）。它不是现实反馈。
- lite 使用传感器估计反馈，仍是实验候选（experimental），没有完成全部估计器验收。
- 默认模式仍是 ideal。LitePhysicalBias 物理偏置测试仍为预期失败。
- 当前分支还包含离线 PX4（开源飞控项目）命名日志视图和目录整理，尚未合并到 main。

M0 是名义对象，M2b 是既定的舵效结构失配工况。
通过门禁只表示允许比较，不表示五种方法都能互相区分。

## 五分钟跑一次

需要 MATLAB R2025b 和 Optimization Toolbox（优化工具箱）。
在 MATLAB 中进入仓库根目录，然后运行：

```matlab
ca_setup;
o = shc09_airframe("lite");
r = main(5,o);
all = main_comparison(o);
```

`main(5,o)` 用预测 PCA 方法跑一次两秒悬停。
`main_comparison(o)` 用相同参考和预生成噪声比较五种方法。
编号 1～5 依次为 DA_NS（直接分配与零空间迭代）、WLS（加权最小二乘）、
DCA（动态分配）、静态 PCA、预测 PCA。
PCA 表示按补偿和跟踪优先级分配；算法细节放在文档中。

默认不保存文件。需要落盘时，在 o 中设置 save_results=true 和新的 output_tag。
不要覆盖已有结果目录。

## 检查安装和旧数值

```matlab
ca_setup;
run_project_tests(false);
run_platform_tests;
test_platform_baseline;
```

分别检查旧 14 项、平台 6 项，以及冻结数值基线。
冻结基线比较完整非耗时日志和 PWM（舵机脉冲调制）时序。
这些测试不会启动完整 60 次主比较。

文档改动后可在仓库终端检查本地链接：

```powershell
python tools/check_docs_links.py
```

该工具只用 Python 标准库，不访问网络或仓库外文件。

## ideal 与 lite 怎么选

|模式|反馈从哪里来|适合做什么|当前限制|
|---|---|---|---|
|ideal|真实姿态、位置透传和原陀螺链|理想参考上界与冻结回归|不是现实传感器反馈|
|lite|陀螺、加计、磁计、气压和卫星定位测量|估计反馈下的 M0/M2b 分配比较|仍为 experimental，物理偏置门禁未过|

比较门禁看主窗内每条轨迹的最坏值：姿态峰值≤5°、饱和≤10%。
lite 还要求姿态估计均方根误差≤2°；气动越界必须为零。
位置误差只报告，不拿方法平均值替代单条轨迹门禁。

## 想做正式分配比较

```matlab
ca_setup;
s = allocation_comparison_app;
```

默认是 M0/M2b、ideal/lite、五种方法、三个种子。
没有缓存时会跑 60 次 20 秒仿真；已有缓存时只补缺项。
只想检查入口时，先用两秒示例，不要误启动整套研究。
结果按可比性、方法差异、种子波动和二维权衡分别报告，不给总分。
M4 不在当前默认比较范围；旧扫描结论只作为历史证据。

## 去哪个目录找东西

|目录|内容|
|---|---|
|platform/|总线、调度、模块、仿真与日志|
|models/|SHC09 物理模型和参考数据|
|allocators/|五种分配器与一个接口示例|
|configs/|配置、预设和固定比较选择|
|analysis/|离线指标、绘图与日志导出|
|apps/|常用入口；experimental/ 是实验入口，legacy/ 是旧研究入口|
|experiments/|固定研究协议和兼容研究函数|
|tests/|测试、夹具和冻结基线|
|docs/|按任务组织的指南、参考、历史与证据|
|examples/|随仓库分发的轻量结果|
|results/|本机运行结果和缓存，不进 Git|
|archive/|本机历史副本和运行日志，不参与当前构建|

旧 main_* 和 plot_main_* 名称保留，运行 ca_setup 后仍可调用。
顶层只保留少量运行、测试和构建入口。

## 文档从这里开始

先看 [文档导航](docs/README.md)，再按需要选一份：

- [比较指南](docs/guides/allocation_comparison_guide.md)：怎么比较分配器和读结果。
- [lite 阅读顺序](docs/guides/lite/README.md)：修复、峰值诊断和方法差异。
- [PX4 日志字段](docs/guides/px4_log_map.md)：帧、单位和离线 MAT/CSV 导出。
- [平台与插件指南](docs/guides/platform_plugin_guide.md)：怎样接入新分配器。
- [仓库地图](docs/repository_map.md)：活跃代码、历史和生成目录。
- [当前状态与下一步](HANDOFF.md)：当前分支、已完成项和停止边界。

## 能相信到什么程度

这不是数字孪生，不是飞控固件，也没有完成实机验证。
模型依据参考方程和气动表；源码一致不等于实机标定。
三种子只描述本批差异和波动，不宣称统计显著性或实机优势。
完整结果保留在本地 results；Git 只保存代码和轻量证据。

## 已知限制

- LitePhysicalBias 仍约 0.061°/s，高于 0.05°/s 门限，没有放宽。
- 模拟和名义执行器的时间常数、速率限制匹配（tau/rate matched）。
- 陀螺附加延迟与计算附加延迟（gyro/compute delay）均为 0。
- 缺少实机标定，不代表完整飞行包线内都有效。
- PX4 命名导出不是固件兼容层，不生成 ULog（PX4 的日志文件格式）。

本轮只整理结构、文档、入口和日志；不改控制链，不开新研究。
