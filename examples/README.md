# 示例数据

> 文档类型：证据。按生成时的协议和版本理解。

[mismatch_round2](mismatch_round2/README.md)保存重构前第二轮结构失配基准的轻量CSV和PNG，原件未改。`summary/status/relative_to_M0`用于成败、窗口及相对比较；`M4_time_bins/priority_activity`区分收敛尾迹和优先级活动；`wls_sensitivity`展示固定权重敏感性；`M0_hold_vs_legacy`检查低速模型影响。

完整协议见[第二轮说明](../docs/history/vane_mismatch_round2.md)。原30次结果已完成、没有气动外推，本轮不重跑、不携带大型log.mat。仓库的`results/`被忽略，不是运行源码的依赖。

从根目录执行`ca_setup; smoke=mismatch_app();`仅得到两秒M0/M2b、十次配对烟雾；`plot_mismatch_ladder(smoke.output_dir)`可验证绘图管线，不复现20秒结论。完整复现使用旧`main_mismatch_ladder`默认协议，写新时间标签；该耗时任务不属于本轮平台验收。

这些结果只说明单组配对种子、ideal导航、真实/名义tau30ms下的机制。M4主要差异为收敛速度，主窗PCA没有缩减/回退，不是优先级优势证据；不能据此宣称实机优势、统计显著性或全动态鲁棒。原始图可直接查看，完整历史日志不随项目发布。
