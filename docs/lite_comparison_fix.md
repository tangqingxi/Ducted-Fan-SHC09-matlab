# v0.5：lite 估计反馈比较

本记录针对 M0/M2b、0.6 偏航负载、20 秒、五方法、seeds 1:3；沿用主窗 [6,16] 和 5°/10%/2°/气动越界零的全部门禁。先完成[修复前峰值诊断](lite_comparison_peak_diagnosis.md)，再固定第一轮候选。第一轮lite已完成30/30且两工况均rankable。用户恢复任务后，CSV空列修复与lite峰值回归通过，ideal三十次及发布回归已完成；完整60次四组均rankable。

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

每个方法/种子逐条过门禁，并非对峰值取均值。前一轮新增测试曾因全空error_id列被CSV推断为非文本而停止；[历史失败记录](lite_comparison_validation/peak_regression_failure.json)保持原样，不改写成通过。前一轮回归的退出挂起也保留[原始记录](lite_comparison_validation/iteration1/shutdown.json)。

## CSV空列修复与本轮验收

比较分析入口将status、error_message及分组文本列转成string并把缺失值置空；error_id在contains前同样显式转换。不填充完成状态，也不把普通空错误列当审计失败。CacheMismatch/TopicAudit仍判invalid，空status仍判stress。5°/10%/2°、气动越界、窗口、方法和种子覆盖规则均未改变。

新增CSV往返测试覆盖：全空error_id/error_message的正常完成记录仍rankable；显式NaN错误列不报错；CacheMismatch及TopicAudit拒绝；空状态不能冒充完成。原边界、单个NaN、缺失种子和位置非门槛测试保持通过。保存的lite三十条轨迹峰值回归也已通过，见[恢复预检](lite_comparison_validation/csv_resume/preflight.json)。

本轮CSV改动位于analysis层，数值引擎仍为26778efe81951624e488fb4efd0bec08e6fcc44cf6da5450ce799c8ac5d08286，与已完成lite完全一致，故保留lite30次。该引擎不同于v0.4，ideal须全新跑30次并逐条对照v0.4完整非耗时日志。正式ideal30/30全新完成，完整非耗时日志对v0.4逐条一致；本轮旧14/14、平台6/6、六组冻结基线与比较器回归通过，LitePhysicalBias仍按0.05°/s预期失败。预检、ideal与产品批次正常退出0；回归断言全部通过后MATLAB退出挂起，闲置约7分钟后仅清理本次进程，清理退出码1单独记录。统一60次全部命中本轮引擎缓存，产品数值与各模式源结果一致，无额外正式仿真。[完整结果](lite_comparison_results.md)与[发布验证](release_validation/v0.5.0/release_checks.json)。

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
