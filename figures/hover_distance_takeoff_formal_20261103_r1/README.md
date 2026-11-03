# 起飞型hover_distance：55秒五方法正式比较

批次：`hover_distance_takeoff_formal_20261103_r1`。最终时间线预检1条通过后，五方法×501/502/503完成15条；共享15/15Hz。

0–12秒五次爬升、12–15秒稳定，15–27秒滚转扰动，27–37秒恢复，37–55秒保持高度、53–55秒收转。本批没有降落段。

与旧40秒实现相同，15秒开始0.5秒平滑加载，27秒开始0.5秒平滑卸载；载入到卸载指令间隔12秒，扰动包络到27.5秒归零。恢复窗起始0.5秒包含原样保留的卸载过程。

主表只评价半开区间[15,27)，起飞／尾部不纳入主指标。表内为三种子均值 ± 样本标准差；这是本批波动，不是置信区间或显著性。

| 方法 | 估计位置RMS m | 真值位置RMS m | 估计滚转RMS ° | 真值滚转RMS ° | 估计偏航速率RMS °/s | 真值偏航速率RMS °/s |
|---|---:|---:|---:|---:|---:|---:|
|DA_NS|0.1930759 ± 0.0437|1.944869 ± 0.641|2.611466 ± 0.175|2.579559 ± 0.166|10.27078 ± 3.11|11.21269 ± 2.63|
|WLS|0.2035469 ± 0.0406|1.943842 ± 0.634|2.871936 ± 0.0121|2.82901 ± 0.0165|4.555164 ± 0.207|6.743684 ± 0.129|
|DCA|0.1681667 ± 0.0509|1.949832 ± 0.644|1.374655 ± 0.364|1.30735 ± 0.367|5.722829 ± 0.227|2.711454 ± 0.456|
|PCA_STATIC|0.1856413 ± 0.0472|1.946832 ± 0.638|2.371402 ± 0.342|2.330805 ± 0.343|24.93393 ± 9.86|25.02839 ± 9.5|
|PCA_PREDICTIVE|0.1682779 ± 0.0506|1.950005 ± 0.644|1.416696 ± 0.376|1.350926 ± 0.38|7.337816 ± 1.44|5.198139 ± 1.91|

| 方法 | λ缩放占空 % | λ_min均值 | mode1 % | 舵速RMS °/s | 六舵面行程 ° | 舵指令触限占空 % | PWM总步变 ° |
|---|---:|---:|---:|---:|---:|---:|---:|
|DA_NS|不适用|不适用|0|89.05927|4824.84|9.961806|12063.74|
|WLS|不适用|不适用|0|91.7039|4966.848|10.53704|12419.91|
|DCA|不适用|不适用|0|230.0084|12570.26|7.347222|157694.1|
|PCA_STATIC|5.166667|0.2492341|0|130.3109|6180.424|13.42824|16791.54|
|PCA_PREDICTIVE|13.47917|0.1128436|0.2916667|201.4528|10614.98|9.395833|149939.9|

舵面触限占空定义为主窗六舵面×状态样本中|指令|≥39.9°的比例；λ只用于PCA正常模式，回退另报；PWM步变不是机械损耗或能耗。

## 成对比较与消融

差值=前者−后者；误差和活动量为负才是降低。每项必须同时看逐种子差值及波动，不能只看均值。

| 比较 | 指标 | seed501 | seed502 | seed503 | 均值差 ± 样本SD |
|---|---|---:|---:|---:|---:|
|PCA_PREDICTIVE − DA_NS|estimated_horizontal_rmse_m|-0.03263834|-0.02259667|-0.01915921|-0.02479807 ± 0.007|
|PCA_PREDICTIVE − DA_NS|estimated_roll_rmse_deg|-1.388416|-1.20934|-0.9865542|-1.19477 ± 0.201|
|PCA_PREDICTIVE − DA_NS|estimated_yaw_rate_rmse_deg_s|-5.039744|-4.981816|1.222657|-2.932968 ± 3.6|
|PCA_PREDICTIVE − DA_NS|main_servo_rate_rms_deg_s|110.4566|110.4266|116.2975|112.3935 ± 3.38|
|PCA_PREDICTIVE − DA_NS|main_command_limit_occupancy|-0.007673611|-0.01128472|0.001979167|-0.005659722 ± 0.00686|
|PCA_PREDICTIVE − WLS|estimated_horizontal_rmse_m|-0.04471575|-0.03686377|-0.02422762|-0.03526905 ± 0.0103|
|PCA_PREDICTIVE − WLS|estimated_roll_rmse_deg|-1.798932|-1.51871|-1.048077|-1.455239 ± 0.379|
|PCA_PREDICTIVE − WLS|estimated_yaw_rate_rmse_deg_s|3.355378|1.156915|3.835664|2.782652 ± 1.43|
|PCA_PREDICTIVE − WLS|main_servo_rate_rms_deg_s|105.9128|108.1629|115.171|109.7489 ± 4.83|
|PCA_PREDICTIVE − WLS|main_command_limit_occupancy|-0.01677083|-0.01677083|-0.0006944444|-0.01141204 ± 0.00928|
|PCA_PREDICTIVE − DCA|estimated_horizontal_rmse_m|0.0006154094|-0.0001882781|-9.356011e-05|0.0001111904 ± 0.000439|
|PCA_PREDICTIVE − DCA|estimated_roll_rmse_deg|0.03285738|0.03836506|0.05490236|0.0420416 ± 0.0115|
|PCA_PREDICTIVE − DCA|estimated_yaw_rate_rmse_deg_s|2.178499|0.1748164|2.491644|1.614987 ± 1.26|
|PCA_PREDICTIVE − DCA|main_servo_rate_rms_deg_s|-28.14062|-29.5333|-27.99275|-28.55556 ± 0.85|
|PCA_PREDICTIVE − DCA|main_command_limit_occupancy|0.02461806|0.0171875|0.01965278|0.02048611 ± 0.00378|
|PCA_PREDICTIVE − PCA_STATIC|estimated_horizontal_rmse_m|-0.02125903|-0.01612912|-0.01470222|-0.01736346 ± 0.00345|
|PCA_PREDICTIVE − PCA_STATIC|estimated_roll_rmse_deg|-1.028771|-0.8953954|-0.9399494|-0.9547051 ± 0.0679|
|PCA_PREDICTIVE − PCA_STATIC|estimated_yaw_rate_rmse_deg_s|-27.15544|-18.18557|-7.447319|-17.59611 ± 9.87|
|PCA_PREDICTIVE − PCA_STATIC|main_servo_rate_rms_deg_s|69.01304|71.90236|72.51023|71.14188 ± 1.87|
|PCA_PREDICTIVE − PCA_STATIC|main_command_limit_occupancy|-0.04149306|-0.0475|-0.03197917|-0.04032407 ± 0.00783|
|PCA_STATIC − DA_NS|estimated_horizontal_rmse_m|-0.0113793|-0.00646755|-0.004456992|-0.007434615 ± 0.00356|
|PCA_STATIC − DA_NS|estimated_roll_rmse_deg|-0.3596453|-0.3139447|-0.04660485|-0.240065 ± 0.169|
|PCA_STATIC − DA_NS|estimated_yaw_rate_rmse_deg_s|22.11569|13.20376|8.669976|14.66314 ± 6.84|
|PCA_STATIC − DA_NS|main_servo_rate_rms_deg_s|41.44355|38.5242|43.78727|41.25167 ± 2.64|
|PCA_STATIC − DA_NS|main_command_limit_occupancy|0.03381944|0.03621528|0.03395833|0.03466435 ± 0.00134|
|PCA_STATIC − WLS|estimated_horizontal_rmse_m|-0.02345672|-0.02073465|-0.009525402|-0.01790559 ± 0.00738|
|PCA_STATIC − WLS|estimated_roll_rmse_deg|-0.7701613|-0.6233142|-0.1081277|-0.5005344 ± 0.348|
|PCA_STATIC − WLS|estimated_yaw_rate_rmse_deg_s|30.51081|19.34249|11.28298|20.37876 ± 9.66|
|PCA_STATIC − WLS|main_servo_rate_rms_deg_s|36.89974|36.26058|42.6608|38.60704 ± 3.53|
|PCA_STATIC − WLS|main_command_limit_occupancy|0.02472222|0.03072917|0.03128472|0.02891204 ± 0.00364|

PCA_PREDICTIVE与PCA_STATIC比较预测环节；PCA_STATIC与DA_NS/WLS比较优先级结构。预测PCA与DA_NS/WLS/DCA的滚转／位置变化和偏航跟踪代价必须成对解释，不预设DCA排序。

## 交付与审计

- `tables/metrics.csv`为15条完整指标，包含估计＋真值、λ最小时刻／最长缩放／回退、恢复时间和超调。恢复未达到时保留NaN，不填零。
- `tables/summary.csv`为五方法三种子均值、样本SD及极差；`paired_differences.csv`为逐种子配对差。
- `appendix/`每方法一页seed501十二状态PNG/PDF；三种子状态极值见两张state_extrema表。主窗极值与全程代表页用途不同。
- `.wtr`逐条在`logs/wtr/hover_distance_takeoff_formal_20261103_r1/`，manifest含参数、指标、bytes、SHA和源MAT；逐字段审计不推进仿真。
- DA_NS独立审计使用原始1e-7rad容差，旧1e-7degree判据只记录其是否会误判，不用于本批门禁。
- 第一条DA_NS保存／导出后，原驱动指标累加器初始化报错；管理性续跑只补14条not_run，没有重飞任何已完成飞行。原冻结源码和锁在执行期间保持不变，错误日志与例外记录保留。
- metrics内precheck_passed只用于先决PCA_PREDICTIVE预检表达式，非PCA的该字段不适用，不能用它判断正式有效性；正式执行与数据有效性分别看status和data_valid。
- 所有状态指标使用原生800Hz、分配事件400Hz；状态图100Hz、λ图400Hz；PWM保留18316个真实333Hz事件。舵面差分与PWM步变按区间右端时间落窗。

五方法在每个种子共用同一参考、初态、预生成误差／扰动、控制器、估计器、B、δ̂接口、PWM时序与限幅；ν_h/ν_c由共同公式计算，闭环数值随分配器作用分叉，并非参考不一致。

地面坐标起始仍采用既有悬停转速配平，没有解锁／起转／接地／地效模型。真值只评分，不反馈；无事后位置平移或相位拟合。

这是工程调参配置下的比较，种子501参与先决预检，不是独立泛化确认。不宣称统计显著、实机优势或全局最优。

## 来源和复现

公共引擎：`d4c19f329e92fb6b0b272498837d926e33312846d32f31fc35622b6f518cb750`；完整研究源码SHA在批次sources/source_lock/formal_lock中。

```matlab
run_hover_distance_takeoff_formal('20261103_r1'); % 仅记录原命令；已有目录拒绝重跑
```
```powershell
python tools/deliver_hover_takeoff_formal.py hover_distance_takeoff_formal_20261103_r1
```

运行需WINDTRACE_PYTHON指向含SciPy环境。源码、原始MAT及旧协议／锁不由后处理修改。图目录及清单拒绝覆盖；新运行必须另立新tag。本批不提交或push。
