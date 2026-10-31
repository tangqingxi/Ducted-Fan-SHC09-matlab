# v0.5 WIP：lite第一轮与停止证据

未发布v0.5.0。lite第一轮30/30全新完成，M0/M2b均rankable，但新增主窗回归在CSV空error_id列的类型处理上失败；按硬停止条件终止，ideal正式30次未开始。本目录不代表完成发布验收。

- [修复前一页诊断](../../docs/lite_comparison_peak_diagnosis.md)、[完整修复与停止说明](../../docs/lite_comparison_fix.md)、[失败记录](../../docs/lite_comparison_validation/peak_regression_failure.json)。
- [lite报告](lite_3seeds/report.md)、[可比性](lite_3seeds/comparability.csv)、[效应量](lite_3seeds/effect_sizes.csv)、[Pareto](lite_3seeds/pareto.csv)。90行summary、30项status/provenance、102行效应量、270行Pareto。
- [原峰值完整向量](diagnosis/peaks.csv)与[峰值邻域](diagnosis/peak_neighborhoods.csv)：30轨迹分别定位全程与主窗峰值，读取原数值日志，没有重跑旧研究。

lite主窗最坏姿态峰值从5.4697°/5.4861°降至3.7749°/3.7817°；饱和均0%、估计RMS最大1.3144°/1.3157°、气动越界0。当前lite数值资格通过，不能据此宣称ideal不变验证、新回归测试或整版验收已经通过。既有14/14、平台6/6和冻结六组基线通过；物理偏置仍按0.05°/s门限预期失败。

主窗姿态、偏航、角速度、位置的方法均值差均小于池化种子波动；共同预测力矩残差和PWM步变的极差/池化比值分别约29.6～29.8、80.0～80.5，可按既定规则区分整组效应。饱和均零、比值NaN。不能推出所有方法两两可区分，不作显著性或实机优势结论。

完整日志及缓存留在本地results，不入Git。旧v0.4证据保留。没有第二轮调参，没有复跑M4或其他功能。默认ideal，lite仍experimental。
