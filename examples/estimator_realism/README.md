# Stage5估计反馈对比轻量结果

summary.csv包含E1三组配对种子、ideal/lite五方法，以及E2单种子两个窗口；status.csv记录40/40，advantages.csv给出静态PCA/DCA和静态PCA/预测PCA主指标比值（大于1表示分母方法误差更小）。完整配置在本地results的新标签，不携带大型状态日志。

从根目录执行`ca_setup; study=estimator_comparison_app;`复现40次固定设计，较耗时；快速入口仍是两秒shc09_airframe("lite")。E3没有运行，不能判断估计反馈下M4/M2b排序。原oracle六工况示例不改。

E1滚转/俯仰2°、偏航5°，12秒；E2保留20秒M0/60%负载协议。WLS在E1沿用全局权重、E2沿用协议权重，两工况不混合排名。仅3/1组种子，不主张显著性。传感器与估计链整体变化，真实/名义tau仍匹配，不能精确归因真值或时间常数各自贡献。

[估计器真实化报告](../../docs/estimator_realism_report.md)列出模式、参数、验收及解释。来源与执行代码哈希见provenance.json。

**验收限制：** completed仅表示40次仿真执行完成。后续真实闭环偏置检查为0.0610°/s，超过0.05°/s；候选估计器未完全通过验收，数据是探索性结果，不是已验证现实平台证据。
