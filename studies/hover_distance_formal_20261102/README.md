# 85%滚转权限正式深度饱和批

本批已完成，禁止用相同输出目录重复运行。15条均完成40秒且补充审计有效；原驱动保留12条completed、3条DA_NS旧命令容差单位检查失败。正式报告为根目录codex-repo-8.md和results/hover_distance_formal_20261102_r1/report.md；最终图表在该批analysis_v2/，原失败记录保留。没有调参或重飞。

2026-11-02用户明确批准沿用501预检配置，直接比较五方法×501/502/503；λ_min仅报告，无门槛。不调整控制、传感器、估计器、PWM、限幅、外扰或参考，不改旧协议和旧锁。

本目录的protocol.json是本批运行前固定的新授权与分析协议。hdf_run调用原hd_config(seed,.85,280)与ppid_simulate；501的cfg/model/ref/plan和实验输入签名必须精确匹配原预检。hdf_metrics仅扩充真值恢复、λ极值时刻等报告指标，不改变控制闭环。新锁只写到新结果目录formal_lock.json。

```matlab
% 必须使用从未存在过的新输出目录；每条只运行一次。
root=ca_setup();addpath(fullfile(root,'research','hover_distance_formal_20261102'));
study=hdf_run('hover_distance_formal_20261102_r1');
```

首次正式批启动后不重复执行上述命令。原status.csv和failures/不覆写，任何补充审计另存audit/。后处理使用tests/audit_hover_distance_formal.m和tools/plot_hover_distance_formal.py，只读MAT，不重新仿真。

旧hd_check_log把命令边界容差写为1e-7度，而分配器原配置为1e-7弧度。正式飞行后的旧审计若因此失败，原失败记录保留；补充审计单独按原cfg.constraint_tolerance检查命令，真实舵角、舵速和其他契约不放宽。两种审计状态必须并列报告，不能隐藏失败。

主窗[10,22)，恢复窗[22,32)；22–22.5秒仍有原定义的平滑卸载。恢复判据在估计和真值域分别计算；未达到为缺失。主表给三种子均值、标准差和逐种子；成对差值同时报告主指标与偏航代价，DCA排序不预设，不宣称显著性、实机优势或全局最优。
