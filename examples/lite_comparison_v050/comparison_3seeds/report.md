# 分配器比较：资格、种子波动与二维权衡

|工况|负载|模式|资格|完成方法|种子|饱和最大%|姿态峰值°|位置峰值m|估计姿态RMS°|原因|
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|
|M0|0.6|ideal|rankable|5|3|0|0.00526349|9.7767e-05|0|全部预定义门禁通过；不是统计排名|
|M0|0.6|lite|rankable|5|3|0|3.77489|0.445757|1.31438|全部预定义门禁通过；不是统计排名|
|M2b|0.6|ideal|rankable|5|3|0|0.00523503|0.000835175|0|全部预定义门禁通过；不是统计排名|
|M2b|0.6|lite|rankable|5|3|0|3.78169|0.445767|1.31568|全部预定义门禁通过；不是统计排名|

完成60/60，失败0，未运行0。失败不补造指标；status/provenance记录全部计划。门禁按全部请求种子的主窗最坏值，不按方法均值。位置只报告不设门槛。rankable仅为比较资格；效应量比值≥1才标distinguishable，不是显著性或综合排名。

## M0 / ideal / 60%：rankable

全部预定义门禁通过；不是统计排名。

|方法|主窗姿态°|偏航°|共同预测力矩Nm|PWM步变°|总变差°|饱和%|位置m|
|---|---:|---:|---:|---:|---:|---:|---:|
|DA_NS|0.00232631|0.00100808|0.0010865|0.0401491|638.443|0|4.15402e-05|
|WLS|0.00232631|0.00100808|0.0010865|0.0401491|638.443|0|4.15402e-05|
|DCA|0.00218208|0.000904992|0.000723277|0.625391|9952.85|0|4.29641e-05|
|PCA_STATIC|0.00232631|0.00100808|0.0010865|0.0401491|638.443|0|4.15402e-05|
|PCA_PREDICTIVE|0.00215464|0.000917147|6.03405e-17|0.692295|11023.1|0|4.13714e-05|

### 方法差异与种子波动

|窗口|指标|方法均值极差|池化种子标准差|比值|可区分标记|
|---|---|---:|---:|---:|---|
|whole|attitude_rmse_deg|0.332805|7.32582e-05|4542.91|distinguishable|
|whole|yaw_rmse_deg|0.332808|7.3646e-05|4519.02|distinguishable|
|whole|rate_rmse_deg_s|1.82465|0.000350081|5212.07|distinguishable|
|whole|common_predicted_torque_error_rms_nm|0.00391886|5.03301e-06|778.631|distinguishable|
|whole|command_step_rms_deg|0.646299|0.00523345|123.494|distinguishable|
|whole|command_total_variation_deg|20761.6|159.689|130.013|distinguishable|
|whole|saturation_percent|0|NaN|NaN|not_distinguishable|
|whole|position_rmse_m|1.38607e-06|9.54036e-06|0.145285|not_distinguishable|
|whole|moment_model_error_rms_nm|3.78668e-09|2.53964e-08|0.149103|not_distinguishable|
|whole|allocation_demand_error_rms_rad_s2|0.808289|0.000950935|849.993|distinguishable|
|whole|common_residual_rms|0.752838|0.000124686|6037.87|distinguishable|
|whole|nominal_command_torque_error_rms_nm|0.0143775|9.38868e-05|153.137|distinguishable|
|whole|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|whole|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|whole|estimated_attitude_rmse_deg|0|NaN|NaN|not_distinguishable|
|whole|estimated_position_rmse_m|0|NaN|NaN|not_distinguishable|
|whole|bias_rmse_max_axis_deg_s|NaN|NaN|NaN|not_distinguishable|
|task|attitude_rmse_deg|0.00017167|8.20646e-05|2.09189|distinguishable|
|task|yaw_rmse_deg|0.000103089|8.91958e-05|1.15576|distinguishable|
|task|rate_rmse_deg_s|0.000741652|0.000717745|1.03331|distinguishable|
|task|common_predicted_torque_error_rms_nm|0.0010865|8.3978e-06|129.379|distinguishable|
|task|command_step_rms_deg|0.652146|0.0057327|113.759|distinguishable|
|task|command_total_variation_deg|10384.7|91.9551|112.932|distinguishable|
|task|saturation_percent|0|NaN|NaN|not_distinguishable|
|task|position_rmse_m|1.59269e-06|1.1476e-05|0.138784|not_distinguishable|
|task|moment_model_error_rms_nm|5.13814e-09|3.03669e-08|0.169202|not_distinguishable|
|task|allocation_demand_error_rms_rad_s2|0.393731|0.00252358|156.021|distinguishable|
|task|common_residual_rms|0.0303715|0.000189475|160.293|distinguishable|
|task|nominal_command_torque_error_rms_nm|0.0141286|9.32022e-05|151.591|distinguishable|
|task|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|task|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|task|estimated_attitude_rmse_deg|0|NaN|NaN|not_distinguishable|
|task|estimated_position_rmse_m|0|NaN|NaN|not_distinguishable|
|task|bias_rmse_max_axis_deg_s|NaN|NaN|NaN|not_distinguishable|
|transient|attitude_rmse_deg|0.429629|9.1164e-05|4712.7|distinguishable|
|transient|yaw_rmse_deg|0.429631|9.14848e-05|4696.2|distinguishable|
|transient|rate_rmse_deg_s|2.35568|0.000312934|7527.71|distinguishable|
|transient|common_predicted_torque_error_rms_nm|0.00497894|4.44507e-06|1120.1|distinguishable|
|transient|command_step_rms_deg|0.644586|0.00493183|130.699|distinguishable|
|transient|command_total_variation_deg|6233.48|43.7543|142.465|distinguishable|
|transient|saturation_percent|0|NaN|NaN|not_distinguishable|
|transient|position_rmse_m|1.27127e-06|4.43752e-06|0.286481|not_distinguishable|
|transient|moment_model_error_rms_nm|3.17296e-09|2.35809e-08|0.134556|not_distinguishable|
|transient|allocation_demand_error_rms_rad_s2|0.996576|0.0010718|929.817|distinguishable|
|transient|common_residual_rms|0.971521|0.000137553|7062.88|distinguishable|
|transient|nominal_command_torque_error_rms_nm|0.014453|9.65007e-05|149.771|distinguishable|
|transient|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|transient|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|transient|estimated_attitude_rmse_deg|0|NaN|NaN|not_distinguishable|
|transient|estimated_position_rmse_m|0|NaN|NaN|not_distinguishable|
|transient|bias_rmse_max_axis_deg_s|NaN|NaN|NaN|not_distinguishable|

### 主窗二维候选前沿

|代价轴|误差轴|数值候选方法|
|---|---|---|
|command_step_rms_deg|yaw_rmse_deg|WLS, DCA|
|command_total_variation_deg|yaw_rmse_deg|WLS, DCA|
|saturation_percent|yaw_rmse_deg|DCA|
|command_step_rms_deg|rate_rmse_deg_s|WLS, DCA, PCA_PREDICTIVE|
|command_total_variation_deg|rate_rmse_deg_s|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|rate_rmse_deg_s|PCA_PREDICTIVE|
|command_step_rms_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|command_total_variation_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|common_predicted_torque_error_rms_nm|PCA_PREDICTIVE|

DCA相对静态PCA的主窗均值比：偏航0.897737、共同力矩0.665697、PWM步变15.5767、总变差15.5892；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

PCA_PREDICTIVE相对静态PCA的主窗均值比：偏航0.909795、共同力矩5.55368e-14、PWM步变17.2431、总变差17.2656；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

不同两轴的候选集合可能不同。共同力矩误差低但PWM步变/总变差高表示活动代价；饱和的方向另查，不能合成单一分数。候选前沿是几何非支配，不是统计显著性。

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

## M2b / ideal / 60%：rankable

全部预定义门禁通过；不是统计排名。

|方法|主窗姿态°|偏航°|共同预测力矩Nm|PWM步变°|总变差°|饱和%|位置m|
|---|---:|---:|---:|---:|---:|---:|---:|
|DA_NS|0.00233538|0.00103316|0.00108953|0.040154|638.526|0|0.000274108|
|WLS|0.00233538|0.00103316|0.00108953|0.040154|638.526|0|0.000274112|
|DCA|0.00224656|0.00106182|0.00072413|0.679567|10495.8|0|0.000157333|
|PCA_STATIC|0.00233538|0.00103316|0.00108953|0.040154|638.526|0|0.000274108|
|PCA_PREDICTIVE|0.00215639|0.000923764|6.4587e-17|0.692368|11024.4|0|0.00015747|

### 方法差异与种子波动

|窗口|指标|方法均值极差|池化种子标准差|比值|可区分标记|
|---|---|---:|---:|---:|---|
|whole|attitude_rmse_deg|0.32604|7.13348e-05|4570.56|distinguishable|
|whole|yaw_rmse_deg|0.325541|7.84072e-05|4151.93|distinguishable|
|whole|rate_rmse_deg_s|1.78095|0.000338575|5260.13|distinguishable|
|whole|common_predicted_torque_error_rms_nm|0.00417143|5.09038e-06|819.474|distinguishable|
|whole|command_step_rms_deg|0.646344|0.00555006|116.457|distinguishable|
|whole|command_total_variation_deg|20758.1|166.421|124.732|distinguishable|
|whole|saturation_percent|0|NaN|NaN|not_distinguishable|
|whole|position_rmse_m|0.000496057|5.28868e-06|93.796|distinguishable|
|whole|moment_model_error_rms_nm|0.000435698|1.012e-06|430.53|distinguishable|
|whole|allocation_demand_error_rms_rad_s2|0.792549|0.000981013|807.889|distinguishable|
|whole|common_residual_rms|0.73454|0.000111463|6589.98|distinguishable|
|whole|nominal_command_torque_error_rms_nm|0.0144129|9.30511e-05|154.893|distinguishable|
|whole|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|whole|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|whole|estimated_attitude_rmse_deg|0|NaN|NaN|not_distinguishable|
|whole|estimated_position_rmse_m|0|NaN|NaN|not_distinguishable|
|whole|bias_rmse_max_axis_deg_s|NaN|NaN|NaN|not_distinguishable|
|task|attitude_rmse_deg|0.000178991|8.16428e-05|2.19237|distinguishable|
|task|yaw_rmse_deg|0.000138057|9.55085e-05|1.44549|distinguishable|
|task|rate_rmse_deg_s|0.000959483|0.00111209|0.862777|not_distinguishable|
|task|common_predicted_torque_error_rms_nm|0.00108953|8.92196e-06|122.118|distinguishable|
|task|command_step_rms_deg|0.652214|0.00606767|107.49|distinguishable|
|task|command_total_variation_deg|10385.9|94.4967|109.908|distinguishable|
|task|saturation_percent|0|NaN|NaN|not_distinguishable|
|task|position_rmse_m|0.00011678|1.94884e-05|5.99227|distinguishable|
|task|moment_model_error_rms_nm|0.000477002|1.26912e-07|3758.52|distinguishable|
|task|allocation_demand_error_rms_rad_s2|0.393843|0.00255062|154.411|distinguishable|
|task|common_residual_rms|0.0305357|0.000199614|152.974|distinguishable|
|task|nominal_command_torque_error_rms_nm|0.0141322|9.38223e-05|150.628|distinguishable|
|task|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|task|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|task|estimated_attitude_rmse_deg|0|NaN|NaN|not_distinguishable|
|task|estimated_position_rmse_m|0|NaN|NaN|not_distinguishable|
|task|bias_rmse_max_axis_deg_s|NaN|NaN|NaN|not_distinguishable|
|transient|attitude_rmse_deg|0.422337|9.15948e-05|4610.92|distinguishable|
|transient|yaw_rmse_deg|0.421634|8.98638e-05|4691.92|distinguishable|
|transient|rate_rmse_deg_s|2.30494|0.000326811|7052.82|distinguishable|
|transient|common_predicted_torque_error_rms_nm|0.005456|8.06101e-06|676.838|distinguishable|
|transient|command_step_rms_deg|0.644528|0.00502988|128.14|distinguishable|
|transient|command_total_variation_deg|6230.01|44.3282|140.543|distinguishable|
|transient|saturation_percent|0|NaN|NaN|not_distinguishable|
|transient|position_rmse_m|0.000693775|6.18344e-06|112.199|distinguishable|
|transient|moment_model_error_rms_nm|0.0003354|1.27644e-06|262.763|distinguishable|
|transient|allocation_demand_error_rms_rad_s2|0.974206|0.00110525|881.435|distinguishable|
|transient|common_residual_rms|0.948864|0.000142216|6672|distinguishable|
|transient|nominal_command_torque_error_rms_nm|0.0145434|9.69085e-05|150.074|distinguishable|
|transient|mode1_percent|NaN|NaN|NaN|not_distinguishable|
|transient|mode2_percent|NaN|NaN|NaN|not_distinguishable|
|transient|estimated_attitude_rmse_deg|0|NaN|NaN|not_distinguishable|
|transient|estimated_position_rmse_m|0|NaN|NaN|not_distinguishable|
|transient|bias_rmse_max_axis_deg_s|NaN|NaN|NaN|not_distinguishable|

### 主窗二维候选前沿

|代价轴|误差轴|数值候选方法|
|---|---|---|
|command_step_rms_deg|yaw_rmse_deg|WLS, PCA_PREDICTIVE|
|command_total_variation_deg|yaw_rmse_deg|WLS, PCA_PREDICTIVE|
|saturation_percent|yaw_rmse_deg|PCA_PREDICTIVE|
|command_step_rms_deg|rate_rmse_deg_s|WLS, DCA, PCA_PREDICTIVE|
|command_total_variation_deg|rate_rmse_deg_s|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|rate_rmse_deg_s|PCA_PREDICTIVE|
|command_step_rms_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|command_total_variation_deg|common_predicted_torque_error_rms_nm|WLS, DCA, PCA_PREDICTIVE|
|saturation_percent|common_predicted_torque_error_rms_nm|PCA_PREDICTIVE|

DCA相对静态PCA的主窗均值比：偏航1.02774、共同力矩0.664625、PWM步变16.924、总变差16.4375；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

PCA_PREDICTIVE相对静态PCA的主窗均值比：偏航0.894112、共同力矩5.92796e-14、PWM步变17.2428、总变差17.2654；饱和变化0个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。

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
