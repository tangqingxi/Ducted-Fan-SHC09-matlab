# v0.5 lite 方法差异与种子波动

M0/M2b、0.6负载、20秒、五方法、seeds 1:3 全部完成。主窗仍为[6,16]，四个工况/模式组均为rankable。以下只解释lite主窗；资格通过与方法间可区分是两个判断。三种子仅描述本批次效应与方向，无p值或显著性结论。

## 修复前后

|工况|原峰值°|新峰值°|新饱和最大%|新估计RMS最大°|资格|
|---|---:|---:|---:|---:|---|
|M0|5.46969|3.77489|0|1.31438|rankable|
|M2b|5.48613|3.78169|0|1.31568|rankable|

跨全部方法及请求种子取最坏值，气动越界均为0。位置峰值仅报告，无新增位置门槛。修复与[诊断记录](lite_comparison_fix.md)说明GNSS连续修正的机制和滞后代价。

## 方法均值极差与池化种子波动

|工况|指标|方法均值极差|池化种子标准差|比值|规则标记|
|---|---|---:|---:|---:|---|
|M0|姿态RMS（°）|0.00191457|0.282308|0.00678184|not_distinguishable|
|M0|偏航RMS（°）|0.00196416|0.0161033|0.121972|not_distinguishable|
|M0|角速度RMS（°/s）|0.16029|0.642481|0.249486|not_distinguishable|
|M0|共同预测力矩残差（Nm）|0.00848679|0.000284436|29.8373|distinguishable|
|M0|PWM步变RMS（°）|0.572551|0.00711297|80.494|distinguishable|
|M0|饱和（%）|0|nan|nan|not_distinguishable|
|M0|位置RMS（m）|0.000174454|0.0256199|0.00680931|not_distinguishable|
|M2b|姿态RMS（°）|0.00247162|0.283424|0.00872058|not_distinguishable|
|M2b|偏航RMS（°）|0.00265947|0.0166997|0.159252|not_distinguishable|
|M2b|角速度RMS（°/s）|0.167469|0.645507|0.259438|not_distinguishable|
|M2b|共同预测力矩残差（Nm）|0.00838192|0.000283343|29.5822|distinguishable|
|M2b|PWM步变RMS（°）|0.581524|0.0072664|80.0292|distinguishable|
|M2b|饱和（%）|0|nan|nan|not_distinguishable|
|M2b|位置RMS（m）|0.000176231|0.0256719|0.00686472|not_distinguishable|

比值为方法均值极差/方法内池化种子标准差，达到1才标distinguishable。零池化方差的比值保留NaN，不能造无限大效应。标记是该指标在本组数据中的整体规则判断，不能推出任意两方法均可区分；尤其DA_NS/WLS/静态PCA的接近结果不因整组其他方法差异而自动分开。十四个主指标已由Python按原CSV独立核算。

## M0/lite：逐方法均值 ± 种子标准差

|方法|姿态RMS°|偏航RMS°|角速度RMS°/s|共同预测力矩Nm|PWM步变°|位置RMS m|
|---|---:|---:|---:|---:|---:|---:|
|DA_NS|1.74192 ± 0.281|0.784703 ± 0.0158|4.83215 ± 0.624|0.00848679 ± 0.000367|0.0494547 ± 0.0005|0.274219 ± 0.0256|
|WLS|1.74192 ± 0.281|0.784703 ± 0.0158|4.83215 ± 0.624|0.00848679 ± 0.000367|0.0494547 ± 0.0005|0.274219 ± 0.0256|
|DCA|1.74001 ± 0.284|0.782739 ± 0.0166|4.67186 ± 0.67|0.000812672 ± 7.38e-06|0.578779 ± 0.00791|0.274393 ± 0.0256|
|PCA_STATIC|1.74192 ± 0.281|0.784703 ± 0.0158|4.83215 ± 0.624|0.00848679 ± 0.000367|0.0494547 ± 0.0005|0.274219 ± 0.0256|
|PCA_PREDICTIVE|1.74005 ± 0.284|0.78274 ± 0.0166|4.67434 ± 0.669|6.49312e-17 ± 3.21e-18|0.622006 ± 0.0138|0.274392 ± 0.0256|

|二维代价轴|误差轴|几何非支配候选|
|---|---|---|
|command_step_rms_deg|yaw_rmse_deg|WLS, DCA|
|command_step_rms_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC|
|command_step_rms_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|command_total_variation_deg|yaw_rmse_deg|WLS, DCA|
|command_total_variation_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC|
|command_total_variation_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|yaw_rmse_deg|DCA|
|saturation_percent|rate_rmse_deg_s|DCA|
|saturation_percent|common_predicted_torque_error_rms_nm|PCA_PREDICTIVE|

## M2b/lite：逐方法均值 ± 种子标准差

|方法|姿态RMS°|偏航RMS°|角速度RMS°/s|共同预测力矩Nm|PWM步变°|位置RMS m|
|---|---:|---:|---:|---:|---:|---:|
|DA_NS|1.7426 ± 0.283|0.785085 ± 0.0165|4.83586 ± 0.628|0.00838192 ± 0.000366|0.049395 ± 0.000455|0.27422 ± 0.0257|
|WLS|1.7426 ± 0.283|0.785085 ± 0.0165|4.83586 ± 0.628|0.00838192 ± 0.000366|0.049395 ± 0.000455|0.27422 ± 0.0257|
|DCA|1.74013 ± 0.285|0.782425 ± 0.0168|4.66839 ± 0.672|0.000809259 ± 6.83e-06|0.630919 ± 0.00853|0.274396 ± 0.0256|
|PCA_STATIC|1.7426 ± 0.283|0.785085 ± 0.0165|4.83586 ± 0.628|0.00838192 ± 0.000366|0.049395 ± 0.000455|0.27422 ± 0.0257|
|PCA_PREDICTIVE|1.74027 ± 0.285|0.78293 ± 0.017|4.67352 ± 0.671|6.5858e-17 ± 3.14e-18|0.622033 ± 0.0138|0.274396 ± 0.0256|

|二维代价轴|误差轴|几何非支配候选|
|---|---|---|
|command_step_rms_deg|yaw_rmse_deg|DA_NS, WLS, DCA, PCA_STATIC, PCA_PREDICTIVE|
|command_step_rms_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC, PCA_PREDICTIVE|
|command_step_rms_deg|common_predicted_torque_error_rms_nm|WLS, PCA_PREDICTIVE|
|command_total_variation_deg|yaw_rmse_deg|DA_NS, WLS, DCA, PCA_STATIC|
|command_total_variation_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC|
|command_total_variation_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|yaw_rmse_deg|DCA|
|saturation_percent|rate_rmse_deg_s|DCA|
|saturation_percent|common_predicted_torque_error_rms_nm|PCA_PREDICTIVE|

候选集依赖两轴，几何非支配不代表统计优势。共同预测力矩来自名义模型，预测PCA接近数值底限不意味着真实力矩误差为零；tau仍匹配。PWM活动代价需与跟踪误差分开解释，不合成总分或全局排名。

## 证据与边界

[完整统一报告](../examples/lite_comparison_v050/comparison_3seeds/report.md) · [效应量](../examples/lite_comparison_v050/comparison_3seeds/effect_sizes.csv) · [Pareto](../examples/lite_comparison_v050/comparison_3seeds/pareto.csv) · [独立核算](lite_comparison_validation/products/independent_lite_primary_effects.csv)。

lite仍experimental，LitePhysicalBias继续按0.05°/s门限保留约0.061°/s预期失败；默认ideal。M4本轮未复跑，不把v0.4旧扫描描述成v0.5结果。没有实机标定或显著性结论。
