# v0.5：lite 估计反馈比较

本记录针对 M0/M2b、0.6 偏航负载、20 秒、五方法、seeds 1:3；沿用主窗 [6,16] 和 5°/10%/2°/气动越界零的全部门禁。先完成[修复前峰值诊断](lite_comparison_peak_diagnosis.md)，再固定第一轮候选。第一轮lite已完成30/30且两工况均rankable；新增主窗回归在CSV导入类型上失败，已按硬停止条件终止，尚未发布。

## 改动及适用边界

修复前 seed1 五方法均在 10.9 秒达到约 5.47°：新 GNSS 观测使估计位置/速度跳变，公共位置控制器随之改变姿态参考，而估计姿态和陀螺偏置没有同步尖峰。seed2/3 的主窗峰值原已低于 5°，所以需要统一机制修复并覆盖全部种子。

估计器继续按原位置/速度融合时间常数计算观测修正，将修正累积为待注入量；每个 IMU 步注入 `1-exp(-dt/0.1)` 的剩余量。下一次观测创新包含待注入量，避免重复累计尚未施加的修正。统一 0.1 秒取自 5Hz GNSS 周期的一半，在完整复跑前固定，所有工况、方法、种子相同。首次 GNSS 初始化和气压融合保留原路径，INS 传播、Mahony 姿态/偏置增益、原始噪声及偏置假设均未改。

该处理只重分配每次 GNSS 修正的时间形状；会引入导航修正滞后，不能声称闭环传递特性完全不变。合成测量单元测试检验修正总量、指数衰减和真值 topic 隔离，完整闭环再评价姿态、饱和、估计 RMS 与气动门禁。没有在控制器或指标中删除峰值，没有修改参考负载、主窗、五算法，也没有读取 plant truth。默认仍为 ideal。

生产代码仅涉及三个允许文件：`shc09_estimator_lite_module.m`、`shc09_lite_params.m` 与 `ca_realism_defaults.m` 的 lite 专用新参数 `lite_gnss_correction_tau_s`。数值引擎指纹因此变化；lite 30 次首先全新复跑，通过后再全新跑 ideal 30 次并对照 v0.4 完整非耗时日志，而不混用旧指纹缓存。

## 验收记录

第一轮30/30全新完成，0失败、0未运行，两个lite工况均rankable；没有第二轮调参。

|工况|修复前峰值°|修复后峰值°|饱和最大%|估计姿态RMS最大°|气动越界|
|---|---:|---:|---:|---:|---:|
|M0|5.469686|3.774890|0|1.314381|0|
|M2b|5.486132|3.781685|0|1.315679|0|

每个方法/种子逐条过门禁，并非对峰值取均值。旧14/14、平台6/6、冻结六组基线和比较器测试已通过。LitePhysicalBias仍约0.061°/s，按原0.05°/s保留预期失败。全部断言与验证文件已完成，但回归MATLAB在退出阶段挂起；只清理了本次闲置工作进程，详见[退出记录](lite_comparison_validation/iteration1/shutdown.json)，不将清理后的退出码冒充正常退出。

新增主窗回归未通过：从CSV读回的全空error_id列被推断为非文本，allocation_comparability调用contains时报“第一个参数必须为文本”。这是新增测试的导入类型处理遗漏；没有修改既有可比性实现。测试在逐项数值门禁断言之后、重新计算comparability时中止，不能把它记为通过。

已按“任何测试破坏立即停止”终止。ideal预检批次退出码1，正式ideal 30次尚未开始，未验证本轮ideal对v0.4完整30轨迹不变性。现仅有lite的comparability/effect_sizes/pareto/report，未生成本轮统一60次产品，不合并main、不打tag、不推送。下一步需用户恢复任务后先修正测试读入列类型；无需改变估计器参数或门禁。[失败记录](lite_comparison_validation/peak_regression_failure.json)。

## 复现

```matlab
ca_setup;
s = allocation_comparison_app( ...
    'cases',["M0","M2b"], 'modes','lite', 'seeds',1:3, ...
    'use_cached',false, 'output_tag','allocation_comparison_lite_rankable');
% 在结果完整且属于当前引擎后读取全部三十条轨迹的固定门禁。
test_lite_comparison_rankable(s.output_dir);
```

每次使用未存在的 output_tag，保留旧结果。新增默认回归读取版本化轻量 CSV；完整 MAT 日志、缓存与本机运行日志仅保留在 results/archive，不随 Git 交付。三种子用于描述本批次方法差异和波动，不提供显著性或实机结论。M4 本轮未复跑，v0.4 的扫描仍是历史证据，不据本次 M0/M2b 修复推断 M4 通过。
