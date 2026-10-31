# v0.5.0：估计反馈比较轻量证据

> 文档类型：证据。按生成时的协议和版本理解。

M0/M2b×ideal/lite×五方法×seeds1:3完成60/60，四组均rankable。lite峰值5.4697°/5.4861°→3.7749°/3.7817°，饱和0%、估计RMS≤1.316°、气动越界0。ideal30次全新复跑，与v0.4完整非耗时日志逐条一致。

- [统一报告](comparison_3seeds/report.md)、[可比性](comparison_3seeds/comparability.csv)、[效应量](comparison_3seeds/effect_sizes.csv)、[Pareto](comparison_3seeds/pareto.csv)：180行summary、204行效应量、540行Pareto、60项status/provenance。
- [lite单独报告](lite_3seeds/report.md)与[ideal单独报告](ideal_3seeds/report.md)：分别保留两个模式的结果。
- [修复前诊断](../../docs/guides/lite/peak_diagnosis.md)、[修复机制与CSV处理](../../docs/guides/lite/fix.md)、[方法差异及种子波动](../../docs/guides/lite/results.md)。
- [修复前峰值](diagnosis/peaks.csv)、[修复后峰值](diagnosis_after/peaks.csv)及相应邻域：离线读取每种方法/种子的原数值日志，不修改原日志。
- [CSV恢复预检](../../docs/lite_comparison_validation/csv_resume/preflight.json)、[ideal逐位对照](../../docs/lite_comparison_validation/ideal/v040_vs_v050_exact.csv)、[发布验证](../../docs/release_validation/v0.5.0/release_checks.json)。此前停止记录作为历史证据保留，当前CSV及lite主窗回归已经通过。

lite主窗跟踪和位置差异小于种子波动，共同预测力矩残差/PWM活动超过既定效应量规则；不宣称所有方法两两可区分、显著性或全局最优。LitePhysicalBias仍按0.05°/s预期失败，lite experimental、默认ideal。M4本轮未跑，v0.4扫描只作历史证据。

完整MAT日志和缓存在本地results，不随Git发布。克隆后以 `ca_setup; s=allocation_comparison_app;` 冷启动复现；无缓存时60次20秒，后续按当前指纹复用。门禁、负载、主窗、物理、共享控制器、五算法均未放宽或修改。完成发布后停止本轮开发。
