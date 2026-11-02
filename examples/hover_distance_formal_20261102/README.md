# hover_distance标称滤波85%压力批轻量证据

[完整报告](report.md) · [主指标图](analysis_v2/figures/05_tracking_summary.png) · [逐条指标](audit/audited_per_run_metrics.csv)

五方法×501–503共15条40秒飞行，原驱动12 completed/3 failed；DA_NS三条完成飞行后被旧日志度/rad单位检查拒绝。补充审计按原分配器1e-7 rad容差核验，15条有效，无气动越界和发散；原失败JSON及状态完整保留。

本包只复制表、图、协议、来源和审计摘要，不包含原始MAT、完整tracks/geometry或构建产物。重型原始证据留在本地results/hover_distance_formal_20261102_r1。source_provenance.json记录原始来源，manifest.json覆盖除自身外的全部本包文件。既有内层manifest保留原字节。

这是8/8 Hz标称滤波批。后续15/15 Hz仅完成两方法工程调参，尚未运行新的五方法正式批。三种子不作显著性、实机或全局最优结论。
