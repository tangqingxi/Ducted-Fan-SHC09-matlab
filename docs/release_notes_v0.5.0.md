# v0.5.0：估计反馈比较

2026-10-31（Asia/Shanghai）。M0/M2b的ideal/lite均在既有门禁下可比较；发布后停止本轮开发。

## 完成与机制

固定20秒、0.6负载、主窗[6,16]、五方法、seeds1:3，共60/60，0失败、0未运行。lite第一轮30次保留，本轮全新跑ideal30次，完整非耗时日志逐条与v0.4一致。统一当前引擎缓存重放60项，新增正式研究仿真0次。

|工况|原lite峰值°|新lite峰值°|饱和最大%|估计姿态RMS最大°|气动越界|资格|
|---|---:|---:|---:|---:|---:|---|
|M0|5.469686|3.774890|0|1.314381|0|rankable|
|M2b|5.486132|3.781685|0|1.315679|0|rankable|

诊断发现seed1五方法10.9秒的GNSS离散修正引起姿态参考阶跃。只在lite内部把待注入的位置/速度修正按统一0.1秒时间常数展开，创新考虑剩余修正，保留原融合增益和测量噪声。该处理有导航修正滞后代价，不宣称传递特性完全不变。没有用真值反馈、改参考负载或主窗。

CSV全空error_id被readtable推断为数值时，contains曾报错。现在入口明确将error_id及status/error_message等文本列转成string、缺失置空。正常完成仍rankable；CacheMismatch/TopicAudit仍invalid，空status仍stress。原数值门禁和覆盖规则不变。

## 验证与产品

- 新CSV往返、原门禁边界/NaN/缺失种子、lite完整三种子峰值回归通过。
- test_allocation_comparison的两秒40项、独立重复、缓存、故障处理及隔离通过。
- 旧14/14、平台6/6、冻结六组非耗时SHA与PWM逐位一致。
- ideal30/30与v0.4完整非耗时日志逐位一致。当前引擎26778efe81951624e488fb4efd0bec08e6fcc44cf6da5450ce799c8ac5d08286，lite隔离审计全部verified_absent。
- 180行summary、4行comparability、204行effect_sizes、540行pareto及60项status/provenance；两个模式分别报告。
- lite十四个主窗主指标由Python独立核算。跟踪和位置的方法差异小于种子波动，共同预测力矩/PWM步变超过既定效应量规则；rankable不表示五方法两两可区分。

[统一报告](../examples/lite_comparison_v050/comparison_3seeds/report.md) · [lite方法差异与波动](lite_comparison_results.md) · [修复机制](lite_comparison_fix.md) · [发布验证](release_validation/v0.5.0/release_checks.json)。历史WIP失败与退出挂起记录保留，不冒充本次通过；本次预检、ideal及产品批次正常退出0；回归断言全部完成后发生MATLAB退出挂起，闲置约7分钟后仅清理本次进程，[退出记录](lite_comparison_validation/csv_resume/regression/shutdown.json)保留退出码1，不冒充正常退出0。发布引用以推送后的远端SHA核验为准。

## 已知限制与未做

LitePhysicalBias仍约0.061°/s >0.05°/s，按原门限保留预期失败。lite继续experimental、默认ideal。三种子不是显著性证明；共同预测力矩来自名义模型，预测残差接近数值底限不代表真实力矩零误差。tau/速率仍匹配，无实机标定或全局最优结论。

本轮不复跑M4扫描或全量失配阶梯、E1/E2，不做执行器/参数不确定性、可视化或lite v2。不修改物理、气动、五算法、共享控制器、旧协议、ideal估计器或5°/10%/2°/气动越界门禁。所有旧日志/缓存/证据保留，本地完整MAT不入Git。完成发布后停止。
