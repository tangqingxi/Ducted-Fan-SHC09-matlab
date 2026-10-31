# 标准分配比较 v0.4.0：轻量证据

[完整使用与结论指南](../../docs/allocation_comparison_guide.md) · [发布验证](../../docs/release_validation/v0.4.0/release_checks.json)。

- [主比较完整报告](main_3seeds/report.md)：M0/M2b×ideal/lite×五方法×seeds 1:3，60/60完成；本次复用35份、补跑25次。
- [主比较可比性](main_3seeds/comparability.csv)：两个ideal工况rankable，两个lite工况因姿态峰值超过5°为stress。
- [效应量](main_3seeds/effect_sizes.csv)：204行，逐方法均值、种子标准差、样本数及极差/池化波动比；三种子不是显著性。
- [Pareto](main_3seeds/pareto.csv)：540行九种二维轴；stress不提供候选前沿，没有单一综合排名。
- [汇总](main_3seeds/summary.csv)、[状态](main_3seeds/status.csv)、[来源](main_3seeds/provenance.csv)、[门禁快照](main_3seeds/predefined_gates.json)：180行分窗指标与60项来源。
- [M4扫描](m4_load_sweep/report.md)：30/30、0.4/0.5/0.6负载；lite均未过固定门禁，M4不进入本版本主排名。

原始数值日志与缓存仅保留本地results，不随Git发布；provenance中的本机路径只用于定位原证据。克隆后可执行 `ca_setup; s=allocation_comparison_app;` 重新生成；初次无缓存时会运行60次20秒仿真，后续可断点复用。

lite仍experimental、默认ideal、物理偏置门禁仍失败；真实/名义tau及速率匹配，求解耗时未注入控制延迟，无实机标定。本轮没有可视化、执行器真实化或lite v2开发。
