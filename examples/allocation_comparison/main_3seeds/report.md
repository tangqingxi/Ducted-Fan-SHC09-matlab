# 分配器比较：资格、种子波动与二维权衡

|工况|负载|模式|资格|完成方法|种子|饱和最大%|姿态峰值°|位置峰值m|估计姿态RMS°|原因|
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|
|M0|0.6|ideal|rankable|5|3|0|0.00526349|9.7767e-05|0|全部预定义门禁通过；不是统计排名|
|M0|0.6|lite|stress|5|3|2.19153|5.46969|0.469231|1.4045|主窗姿态峰值超过5度|
|M2b|0.6|ideal|rankable|5|3|0|0.00523503|0.000835175|0|全部预定义门禁通过；不是统计排名|
|M2b|0.6|lite|stress|5|3|2.01141|5.48613|0.46914|1.40651|主窗姿态峰值超过5度|

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

## M0 / lite / 60%：stress

主窗姿态峰值超过5度。

压力或无效工况不排名，数值差异也不升级为候选前沿；退化量级见开头最坏值及以下方法均值。

|方法|主窗姿态°|偏航°|共同预测力矩Nm|PWM步变°|总变差°|饱和%|位置m|
|---|---:|---:|---:|---:|---:|---:|---:|
|DA_NS|1.93359|0.793031|0.0255538|0.309617|1665.95|0|0.26964|
|WLS|1.93359|0.793031|0.0255538|0.309617|1665.95|0|0.26964|
|DCA|1.93118|0.793079|0.00647646|2.54239|17988|1.7212|0.269897|
|PCA_STATIC|1.93359|0.793031|0.0255538|0.309617|1665.95|0|0.26964|
|PCA_PREDICTIVE|1.9323|0.791128|0.0061792|2.21556|17102.8|2.04143|0.269909|

Pareto各行统一标stress_not_ranking，pareto_candidate与pareto_efficient均false；numeric_non_dominated仅保留几何诊断。不得将压力点包装成算法排名。

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

## M2b / lite / 60%：stress

主窗姿态峰值超过5度。

压力或无效工况不排名，数值差异也不升级为候选前沿；退化量级见开头最坏值及以下方法均值。

|方法|主窗姿态°|偏航°|共同预测力矩Nm|PWM步变°|总变差°|饱和%|位置m|
|---|---:|---:|---:|---:|---:|---:|---:|
|DA_NS|1.93569|0.794504|0.0254487|0.309947|1676.56|0|0.269677|
|WLS|1.93569|0.794504|0.0254487|0.309947|1676.56|0|0.269677|
|DCA|1.93166|0.792632|0.00644443|2.57773|18600.3|1.67117|0.269954|
|PCA_STATIC|1.93569|0.794504|0.0254487|0.309947|1676.56|0|0.269677|
|PCA_PREDICTIVE|1.92704|0.790754|0.00609286|2.23518|17218.6|1.82127|0.269881|

Pareto各行统一标stress_not_ranking，pareto_candidate与pareto_efficient均false；numeric_non_dominated仅保留几何诊断。不得将压力点包装成算法排名。

## 怎样读本结果

whole/task/transient=[0,20]/[6,16]/[0,6]；两秒烟雾三个窗口均[0,2]，不作正式结论。均值、方法内种子标准差和样本数逐方法保留；池化按(n−1)加权。任何方法缺失请求种子，跨五方法极差/池化比值保留NaN；单种子或零池化方差的比值NaN，不造无限大效应。

3种子只能描述本组效应与方向，无p值、显著性或全局最优。lite仍experimental且偏置门禁失败，平台默认ideal。tau匹配、无实机标定；原生残差不跨不同目标排名。allocation demand/common residual为rad/s²，共同预测力矩经名义J换算为Nm，不能替代实际力矩模型误差。真值仅测量生成与离线评价，没有反馈兜底。

[汇总](summary.csv) · [可比性](comparability.csv) · [效应量](effect_sizes.csv) · [Pareto](pareto.csv) · [状态](status.csv) · [来源](provenance.csv)
