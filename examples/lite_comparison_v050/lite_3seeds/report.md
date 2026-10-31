# 分配器比较：资格、种子波动与二维权衡

|工况|负载|模式|资格|完成方法|种子|饱和最大%|姿态峰值°|位置峰值m|估计姿态RMS°|原因|
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|
|M0|0.6|lite|rankable|5|3|0|3.77489|0.445757|1.31438|全部预定义门禁通过；不是统计排名|
|M2b|0.6|lite|rankable|5|3|0|3.78169|0.445767|1.31568|全部预定义门禁通过；不是统计排名|

完成30/30，失败0，未运行0。失败不补造指标；status/provenance记录全部计划。门禁按全部请求种子的主窗最坏值，不按方法均值。位置只报告不设门槛。rankable仅为比较资格；效应量比值≥1才标distinguishable，不是显著性或综合排名。

## M0 / lite / 60%：rankable

全部预定义门禁通过；不是统计排名。

|方法|主窗姿态°|偏航°|共同预测力矩Nm|PWM步变°|总变差°|饱和%|位置m|
|---|---:|---:|---:|---:|---:|---:|---:|
|DA_NS|1.74192|0.784703|0.00848679|0.0494547|767.491|0|0.274219|
|WLS|1.74192|0.784703|0.00848679|0.0494547|767.491|0|0.274219|
|DCA|1.74001|0.782739|0.000812672|0.578779|9099.54|0|0.274393|
|PCA_STATIC|1.74192|0.784703|0.00848679|0.0494547|767.491|0|0.274219|
|PCA_PREDICTIVE|1.74005|0.78274|6.49312e-17|0.622006|9888.26|0|0.274392|

### 方法差异与种子波动

|窗口|指标|方法均值极差|池化种子标准差|比值|可区分标记|
|---|---|---:|---:|---:|---|
|whole|attitude_rmse_deg|0.0847586|0.0322084|2.63157|distinguishable|
|whole|yaw_rmse_deg|0.174858|0.0392101|4.45952|distinguishable|
|whole|rate_rmse_deg_s|0.954038|0.160697|5.93686|distinguishable|
|whole|common_predicted_torque_error_rms_nm|0.00897365|0.00146211|6.13747|distinguishable|
|whole|command_step_rms_deg|0.59774|0.0129764|46.0637|distinguishable|
|whole|command_total_variation_deg|18441.2|161.281|114.342|distinguishable|
|whole|saturation_percent|0|NaN|NaN|not_distinguishable|
|whole|position_rmse_m|6.45799e-05|0.00962509|0.00670953|not_distinguishable|
|whole|moment_model_error_rms_nm|2.22645e-06|0.000277512|0.00802289|not_distinguishable|
|whole|allocation_demand_error_rms_rad_s2|0.88416|0.00950668|93.0041|distinguishable|
|whole|common_residual_rms|0.746554|0.0194377|38.4075|distinguishable|
|whole|nominal_command_torque_error_rms_nm|0.0198092|0.000854894|23.1715|distinguishable|
|whole|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|whole|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|whole|estimated_attitude_rmse_deg|0.000471081|0.0112505|0.0418722|not_distinguishable|
|whole|estimated_position_rmse_m|3.34354e-05|0.00970944|0.0034436|not_distinguishable|
|whole|bias_rmse_max_axis_deg_s|9.51881e-05|0.0186337|0.0051084|not_distinguishable|
|task|attitude_rmse_deg|0.00191457|0.282308|0.00678184|not_distinguishable|
|task|yaw_rmse_deg|0.00196416|0.0161033|0.121972|not_distinguishable|
|task|rate_rmse_deg_s|0.16029|0.642481|0.249486|not_distinguishable|
|task|common_predicted_torque_error_rms_nm|0.00848679|0.000284436|29.8373|distinguishable|
|task|command_step_rms_deg|0.572551|0.00711297|80.494|distinguishable|
|task|command_total_variation_deg|9120.77|107.838|84.5782|distinguishable|
|task|saturation_percent|0|NaN|NaN|not_distinguishable|
|task|position_rmse_m|0.000174454|0.0256199|0.00680931|not_distinguishable|
|task|moment_model_error_rms_nm|1.68829e-06|0.000432877|0.00390016|not_distinguishable|
|task|allocation_demand_error_rms_rad_s2|0.404824|0.00109541|369.564|distinguishable|
|task|common_residual_rms|0.208743|0.00544422|38.3422|distinguishable|
|task|nominal_command_torque_error_rms_nm|0.0151886|4.88148e-05|311.148|distinguishable|
|task|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|task|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|task|estimated_attitude_rmse_deg|0.000339292|0.167548|0.00202504|not_distinguishable|
|task|estimated_position_rmse_m|5.74745e-05|0.0253916|0.00226352|not_distinguishable|
|task|bias_rmse_max_axis_deg_s|0.000133275|0.0180602|0.00737947|not_distinguishable|
|transient|attitude_rmse_deg|0.183984|0.449159|0.409619|not_distinguishable|
|transient|yaw_rmse_deg|0.340587|0.0834322|4.08219|distinguishable|
|transient|rate_rmse_deg_s|1.36848|1.15494|1.18489|distinguishable|
|transient|common_predicted_torque_error_rms_nm|0.0109109|0.00336454|3.24292|distinguishable|
|transient|command_step_rms_deg|0.666671|0.0314747|21.1811|distinguishable|
|transient|command_total_variation_deg|5582.22|61.4503|90.8412|distinguishable|
|transient|saturation_percent|0|NaN|NaN|not_distinguishable|
|transient|position_rmse_m|0.000177511|0.0774106|0.00229311|not_distinguishable|
|transient|moment_model_error_rms_nm|7.64679e-07|0.00045067|0.00169676|not_distinguishable|
|transient|allocation_demand_error_rms_rad_s2|1.1586|0.0257091|45.0659|distinguishable|
|transient|common_residual_rms|0.936074|0.0422443|22.1586|distinguishable|
|transient|nominal_command_torque_error_rms_nm|0.0273371|0.00202674|13.4882|distinguishable|
|transient|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|transient|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|transient|estimated_attitude_rmse_deg|0.000472312|0.279481|0.00168996|not_distinguishable|
|transient|estimated_position_rmse_m|2.95751e-05|0.0948806|0.000311709|not_distinguishable|
|transient|bias_rmse_max_axis_deg_s|0.000143577|0.0330773|0.00434064|not_distinguishable|

### 主窗二维候选前沿

|代价轴|误差轴|数值候选方法|
|---|---|---|
|command_step_rms_deg|yaw_rmse_deg|WLS, DCA|
|command_total_variation_deg|yaw_rmse_deg|WLS, DCA|
|saturation_percent|yaw_rmse_deg|DCA|
|command_step_rms_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC|
|command_total_variation_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC|
|saturation_percent|rate_rmse_deg_s|DCA|
|command_step_rms_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|command_total_variation_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|common_predicted_torque_error_rms_nm|PCA_PREDICTIVE|

DCA相对静态PCA的主窗均值比：偏航0.997497、共同力矩0.0957573、PWM步变11.7032、总变差11.8562；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

PCA_PREDICTIVE相对静态PCA的主窗均值比：偏航0.997498、共同力矩7.65086e-15、PWM步变12.5773、总变差12.8839；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

不同两轴的候选集合可能不同。共同力矩误差低但PWM步变/总变差高表示活动代价；饱和的方向另查，不能合成单一分数。候选前沿是几何非支配，不是统计显著性。

## M2b / lite / 60%：rankable

全部预定义门禁通过；不是统计排名。

|方法|主窗姿态°|偏航°|共同预测力矩Nm|PWM步变°|总变差°|饱和%|位置m|
|---|---:|---:|---:|---:|---:|---:|---:|
|DA_NS|1.7426|0.785085|0.00838192|0.049395|766.076|0|0.27422|
|WLS|1.7426|0.785085|0.00838192|0.049395|766.076|0|0.27422|
|DCA|1.74013|0.782425|0.000809259|0.630919|9628.36|0|0.274396|
|PCA_STATIC|1.7426|0.785085|0.00838192|0.049395|766.076|0|0.27422|
|PCA_PREDICTIVE|1.74027|0.78293|6.5858e-17|0.622033|9889.14|0|0.274396|

### 方法差异与种子波动

|窗口|指标|方法均值极差|池化种子标准差|比值|可区分标记|
|---|---|---:|---:|---:|---|
|whole|attitude_rmse_deg|0.080913|0.0287789|2.81154|distinguishable|
|whole|yaw_rmse_deg|0.167725|0.0401586|4.17657|distinguishable|
|whole|rate_rmse_deg_s|0.91293|0.141232|6.46406|distinguishable|
|whole|common_predicted_torque_error_rms_nm|0.00884827|0.00140144|6.31371|distinguishable|
|whole|command_step_rms_deg|0.603304|0.0127222|47.4213|distinguishable|
|whole|command_total_variation_deg|18440.8|159.623|115.527|distinguishable|
|whole|saturation_percent|0|NaN|NaN|not_distinguishable|
|whole|position_rmse_m|4.44576e-05|0.00948601|0.00468665|not_distinguishable|
|whole|moment_model_error_rms_nm|0.00161323|0.00885721|0.182137|not_distinguishable|
|whole|allocation_demand_error_rms_rad_s2|0.869278|0.00846083|102.741|distinguishable|
|whole|common_residual_rms|0.7275|0.0186921|38.9202|distinguishable|
|whole|nominal_command_torque_error_rms_nm|0.0198075|0.000834989|23.7219|distinguishable|
|whole|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|whole|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|whole|estimated_attitude_rmse_deg|0.000660585|0.0137403|0.0480763|not_distinguishable|
|whole|estimated_position_rmse_m|4.2051e-05|0.00968939|0.00433991|not_distinguishable|
|whole|bias_rmse_max_axis_deg_s|8.40012e-05|0.0186315|0.00450857|not_distinguishable|
|task|attitude_rmse_deg|0.00247162|0.283424|0.00872058|not_distinguishable|
|task|yaw_rmse_deg|0.00265947|0.0166997|0.159252|not_distinguishable|
|task|rate_rmse_deg_s|0.167469|0.645507|0.259438|not_distinguishable|
|task|common_predicted_torque_error_rms_nm|0.00838192|0.000283343|29.5822|distinguishable|
|task|command_step_rms_deg|0.581524|0.0072664|80.0292|distinguishable|
|task|command_total_variation_deg|9123.06|111.011|82.1816|distinguishable|
|task|saturation_percent|0|NaN|NaN|not_distinguishable|
|task|position_rmse_m|0.000176231|0.0256719|0.00686472|not_distinguishable|
|task|moment_model_error_rms_nm|0.00142214|0.0095465|0.14897|not_distinguishable|
|task|allocation_demand_error_rms_rad_s2|0.403927|0.00101883|396.46|distinguishable|
|task|common_residual_rms|0.218445|0.00565218|38.648|distinguishable|
|task|nominal_command_torque_error_rms_nm|0.015123|4.56694e-05|331.142|distinguishable|
|task|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|task|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|task|estimated_attitude_rmse_deg|0.00051628|0.168166|0.00307006|not_distinguishable|
|task|estimated_position_rmse_m|5.9295e-05|0.0254022|0.00233425|not_distinguishable|
|task|bias_rmse_max_axis_deg_s|0.000128398|0.018071|0.0071052|not_distinguishable|
|transient|attitude_rmse_deg|0.177942|0.450798|0.394727|not_distinguishable|
|transient|yaw_rmse_deg|0.329767|0.0847619|3.89051|distinguishable|
|transient|rate_rmse_deg_s|1.29515|1.14068|1.13542|distinguishable|
|transient|common_predicted_torque_error_rms_nm|0.0106737|0.0033062|3.2284|distinguishable|
|transient|command_step_rms_deg|0.694346|0.0303821|22.8538|distinguishable|
|transient|command_total_variation_deg|5579.43|54.3694|102.621|distinguishable|
|transient|saturation_percent|0|NaN|NaN|not_distinguishable|
|transient|position_rmse_m|0.000276681|0.0772302|0.00358254|not_distinguishable|
|transient|moment_model_error_rms_nm|0.00167375|0.00872183|0.191903|not_distinguishable|
|transient|allocation_demand_error_rms_rad_s2|1.13835|0.0237751|47.8798|distinguishable|
|transient|common_residual_rms|0.906293|0.0401805|22.5556|distinguishable|
|transient|nominal_command_torque_error_rms_nm|0.0273865|0.00198818|13.7747|distinguishable|
|transient|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|transient|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|transient|estimated_attitude_rmse_deg|0.000346293|0.278842|0.0012419|not_distinguishable|
|transient|estimated_position_rmse_m|4.85375e-05|0.0948851|0.00051154|not_distinguishable|
|transient|bias_rmse_max_axis_deg_s|0.00011256|0.0330461|0.00340615|not_distinguishable|

### 主窗二维候选前沿

|代价轴|误差轴|数值候选方法|
|---|---|---|
|command_step_rms_deg|yaw_rmse_deg|DA_NS, WLS, DCA, PCA_STATIC, PCA_PREDICTIVE|
|command_total_variation_deg|yaw_rmse_deg|DA_NS, WLS, DCA, PCA_STATIC|
|saturation_percent|yaw_rmse_deg|DCA|
|command_step_rms_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC, PCA_PREDICTIVE|
|command_total_variation_deg|rate_rmse_deg_s|DA_NS, WLS, DCA, PCA_STATIC|
|saturation_percent|rate_rmse_deg_s|DCA|
|command_step_rms_deg|common_predicted_torque_error_rms_nm|WLS, PCA_PREDICTIVE|
|command_total_variation_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|common_predicted_torque_error_rms_nm|PCA_PREDICTIVE|

DCA相对静态PCA的主窗均值比：偏航0.996613、共同力矩0.0965482、PWM步变12.7729、总变差12.5684；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

PCA_PREDICTIVE相对静态PCA的主窗均值比：偏航0.997256、共同力矩7.85715e-15、PWM步变12.593、总变差12.9088；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

不同两轴的候选集合可能不同。共同力矩误差低但PWM步变/总变差高表示活动代价；饱和的方向另查，不能合成单一分数。候选前沿是几何非支配，不是统计显著性。

## 怎样读本结果

whole/task/transient=[0,20]/[6,16]/[0,6]；两秒烟雾三个窗口均[0,2]，不作正式结论。均值、方法内种子标准差和样本数逐方法保留；池化按(n−1)加权。任何方法缺失请求种子，跨五方法极差/池化比值保留NaN；单种子或零池化方差的比值NaN，不造无限大效应。

3种子只能描述本组效应与方向，无p值、显著性或全局最优。lite仍experimental且偏置门禁失败，平台默认ideal。tau匹配、无实机标定；原生残差不跨不同目标排名。allocation demand/common residual为rad/s²，共同预测力矩经名义J换算为Nm，不能替代实际力矩模型误差。真值仅测量生成与离线评价，没有反馈兜底。

[汇总](summary.csv) · [可比性](comparability.csv) · [效应量](effect_sizes.csv) · [Pareto](pareto.csv) · [状态](status.csv) · [来源](provenance.csv)
