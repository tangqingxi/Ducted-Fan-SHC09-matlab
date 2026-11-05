# hover_distance的INDI补偿滤波工程调参

本轮已完成20/20条（12条粗扫、8条复核），无失败。建议15/15Hz，三种子两方法等权滚转残差4.74103%，种子标准差0.423837个百分点；502均值5.19605%，并非逐种子全部达标。完整报告为根目录codex-repo-9.md，调参表见results/hover_distance_filter_report_20261102_r1/。未运行新五方法15条，未创建正式运行锁，待用户决定。不得重跑已存在的输出目录。

2026-11-02用户批准只扫8/8、10/10、12/12、15/15、12/8、8/12 Hz六组；15/15为一次性特例，不扩网格。先在501用PCA_PREDICTIVE和DCA各跑一条，再对最优两组在502/503复核。所有旧协议、锁、旧结果和标称批保持原样。

用户进一步固定：滚转分量的0.5Hz残差幅值比为主指标，三轴幅值范数并列；完成本轮调参表与残差后停止，五方法15条正式批须另等用户决定。本入口不含正式批运行分支。

唯一覆盖为plan.controller.indi_output_filter_hz和indi_input_filter_hz，不改cfg或父协议。每条输入与标称批精确比较，恢复这两字段后plan也必须完全相同。包含plan的完整输入签名随滤波变化，原cfg/model/ref/experiment签名保持不变。

主窗[10,22)，仅400Hz控制更新点；外扰由已有确定性序列插值用于离线评价。残差为nu_h+J^-1*M_dist，按六个完整周期的复数傅里叶投影归一化。正余弦最小二乘独立核验幅值归一化。外扰真值不进入控制器。

两方法等权，三种子等权；位置/滚转跟踪与PCA排名不参与选型。相差≤0.1个百分点时优先实际舵速RMS，再按PWM步变、总行程、固定候选顺序。高频指令活动定义为主窗400Hz指令FFT的绝对频率≥20Hz部分RMS，它不是单独分离出的随机传感器噪声。

```matlab
% 下面只说明入口；已经存在的输出目录会被拒绝，不能重跑本轮。
root=ca_setup();addpath(fullfile(root,'research','hover_distance_filter_20261102'));
study=hft_run('coarse','hover_distance_filter_coarse_20261102_r1');
```

每阶段运行前保存sources.json、source_lock.json、protocol副本和全部输入；每条只运行一次，失败保留failures与已产生MAT。源码以hft_sources联合旧引擎摘要单独冻结，禁止中途修改。原旧日志检查保持原样，不修改旧单位容差；本轮只跑两种方法，不产生新的DA_NS运行或正式审计。

选型与表图：tools/summarize_hover_filter_tuning.py。只读标称批：tools/export_hover_filter_baseline.m。独立审计：tests/audit_hover_filter_tuning.m。相位超前不实现、不试飞。结论只称工程调参，不称泛化确认。
