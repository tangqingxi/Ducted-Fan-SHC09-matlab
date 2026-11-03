# 起飞型hover_distance单条预检快看

批次：hover_distance_takeoff_precheck_20261103_r1；seed501，PCA_PREDICTIVE，15/15Hz；工程预检通过：True。

本次只飞一条50秒，不是五方法比较或泛化确认。地面坐标起始、悬停转速配平，无接地／解锁／地效模型。

源MAT：`results/hover_distance_takeoff_precheck_20261103_r1/logs/PCA_PREDICTIVE_s501.mat`；SHA256：`94dc2016903838c7a7fa3687b0d449b0781422793ddfa9c05fd68667f454eb05`。
首要交付物：`logs/wtr/precheck_20261103_r1/PCA_PREDICTIVE_s501.wtr`，其manifest记录配置、指标、字节数、SHA与来源。

0–8秒五次爬升，8–10秒偏航起振，12–24秒滚转扰动，24–34秒恢复，尾部保持高度、48–50秒收转。
main只含高度、滚转、偏航角速度及正常模式λ四组PNG/PDF；浅色阴影为12–24秒。没有十二状态附录。
tables/metrics.csv为800Hz状态与400Hz事件指标；状态图100Hz，λ图400Hz，未平移或拟合轨迹。

## 起飞与主窗指标

| 指标 | 估计／反馈 | 真值 |
|---|---:|---:|
|8秒高度 m|9.9630813|9.9696066|
|8秒垂速 NED m/s|-0.040357552|-0.048077658|
|10–12秒高度RMS m|0.060604496|0.024690107|
|10–12秒垂速RMS m/s|0.031704419|0.043783676|
|主窗水平RMS m|0.13158949|2.6077111|
|主窗滚转RMS °|1.2810798|1.2599019|
|主窗偏航速率RMS °/s|8.5111071|6.7875916|

正常缩放占空比：13.8958%；λ_min=0.13884763，时刻21.67s；mode1=0.354167%。
最大真值倾角：3.2701196°；推力指令峰值比：0.54926279。
全程实际舵速RMS：170.72377°/s；总行程：33741.016°。

## 复现命令与保护

```matlab
run_hover_distance_takeoff('20261103_r1'); % 已存在批次会拒绝；不要重飞本条
```
```powershell
python tools/plot_hover_distance_takeoff.py 20261103_r1
```

MATLAB入口需预先设置WINDTRACE_PYTHON。结果、容器、图目录均拒绝覆盖；失败保留，不调参重试。
工程起飞／稳定判断值写于飞前takeoff_protocol.json，并非修改旧协议。是否进入正式批由用户另行决定。
